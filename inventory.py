#!/usr/bin/env python3

# This is the inventory script for Ansible.
# It reads all group and host vars from the corresponding directories and merges them.
# It expects a list of groups to be in each host as '_groups'.
# Lists are appended, dicts are merged.

from yaml import safe_load
from copy import deepcopy
from os.path import join, dirname
from os import walk
from json import dumps
from re import match, search


class InventoryErrors(Exception):
  def __init__(self, errors):
    if not isinstance(errors, list):
      errors = [errors]
    self.errors = errors


def readYAML(paths):
  '''
  Reads a list of files, and loads them as yaml content.
  The files must exist.
  Instead of being a list, the parameter can also be a single file

  :param list paths: List of paths of the files to read
  :param str paths: Single path to read
  '''
  # Ensure it's a list
  if not isinstance(paths, list):
    paths = [paths]

  obj = {}
  for f in paths:
    fd = open(f, mode='r')
    mergeDict(obj, safe_load(fd))
    fd.close()
  return obj


def mergeDict(a, b, overwrite=True):
  '''
  Merges two dicts.
  If the key is present in both dicts and `overwrite=True`, then the key from the
  second dict is used. If the key is present in both dicts and `overwrite=False`,
  then an error is raised.
  This goes unless the key contains a list or a dict. For dicts and lists,
  `overwrite` is ignored. For dicts, this function is called recursively. For
  lists, the lists are appended.

  :param dict a: The dict to merge into
  :param dict b: The dict to merge into a, overriding with the rules specified above
  '''
  for key in b:
    if key in a:
      if isinstance(a[key], dict) and isinstance(b[key], dict):
        mergeDict(a[key], b[key], overwrite=overwrite)
      elif isinstance(a[key], list) and isinstance(b[key], list):
        a[key] = a[key] + deepcopy(b[key])
      elif overwrite == False or type(a[key]) != type(b[key]):
        if a[key] != b[key]:
          raise InventoryErrors(f'There are conflicting definitions for `{key}`: `{a[key]}` and `{b[key]}`')
      else:
        a[key] = deepcopy(b[key])
    else:
      a[key] = deepcopy(b[key])


def listFiles(dirPath):
  '''
  List all yml files in a directory with their path relative to this script.
  Only .yml files will be found.

  This returns a dict with the key being the name of the yml file, and the value
  being either the path of the file relative to this file (in case of a single .yml file)
  or a list of yml files if they were grouped into a directory, where the key is the name of the
  directory. This resembles the behaviour of vanilla Ansible.

  :param str dirPath: Directory to scan for files
  '''
  confDir = join(dirname(__file__), dirPath)
  dirs = next(walk(confDir))[1]
  files = next(walk(confDir))[2]
  # Add path to filename and filter out non-yml files
  files = [join(confDir, fileName) for fileName in files if match(r'^[a-z0-9_.-]*\.yml$', fileName)]
  # Convert list to dict
  ret = {}
  for f in files:
    name = search(r'([a-z0-9_.-]*)\.yml$', f).group(1)
    ret[name] = f
  # List directories and add directories to paths
  for dir in dirs:
    ret[dir] = []
    for w in walk(join(confDir, dir)):
      for f in w[2]:
        if match(r'^[a-z0-9_.-]*\.yml$', f):
          ret[dir] += [join(join(confDir, dir), f)]

  return ret


def addHost(ansibleInventory, userConfig, hostName, hostConfig):
  '''
  Adds a host to the ansible configuraton.
  This is the core function of the script.
  It adds the host to the all group and to the groups that are specified in '_groups'.
  '_groups' may also be a string and may not exist. If it doesn't the host is added to the 'ungrouped' group to comply with Ansible's standards.
  If a group doesn't exist, an empty one is created.

  When the host is added to all groups, the variables are merged.
  First, the variables from the user config are used, then the 'all' group is used, then from each group, then from the host.

  :param dict ansibleInventory: Ansible inventory with groups. The hosts are added here
  :param dict userConfig: User config that is added to all hosts
  :param str hostName: Name of this host
  :param dict hostConfig: Configuration dict of this host
  '''
  errors = []

  # If no ansible_host is defined, try to find an interface that has an IP defined
  if 'ansible_host' not in hostConfig:
    if 'stuvus_host' in hostConfig:
      hostConfig['ansible_host'] = hostConfig['stuvus_host']
    elif 'interfaces' in hostConfig:
      for interface in hostConfig['interfaces']:
        if 'ip' in interface:
          hostConfig['ansible_host'] = interface['ip'].split('/')[0]
          break

  if 'ansible_host' not in hostConfig:
      errors.append('No stuvus_host or interface config given for ' + hostName)

  groups = hostConfig['_groups'] if '_groups' in hostConfig else ['ungrouped']

  # Support single-string group specifications
  if isinstance(groups, str):
    groups = [groups]

  if not isinstance(groups, list):
    errors.append(f"Expected a list for `_groups`, found: `{groups}`")

  groups.append('all')

  # Check if the host is a virtual machine and add the virtual group if so.
  if 'vm' in hostConfig:
    groups.append('virtual')

  # Make elements of `groups` unique
  groups = list(set(groups))

  # This loop builds the local variable `groupsConfig` which is used below
  groupsConfig = {}
  for groupName in groups:
    # Ensure this group exists in the global config part
    if groupName not in ansibleInventory:
      ansibleInventory[groupName] = {'hosts': [], 'vars': {}}

    # Add host name to group
    ansibleInventory[groupName]['hosts'].append(hostName)

    # Do not merge the `all` because it is already used to initialize the
    # `ansibleInventory['_meta']['hostvars'][hostName]`; see below this loop
    if groupName != 'all':
      # Merge group vars together, but don't allow overwrites
      try:
        mergeDict(groupsConfig, ansibleInventory[groupName]['vars'], overwrite=False)
      except InventoryErrors as e:
        errors.extend([ f'For host `{hostName}`: {error}' for error in e.errors ])

  # The priorities are coded here:
  mergedConfig = {}
  mergeDict(mergedConfig, userConfig)
  mergeDict(mergedConfig, ansibleInventory['all']['vars'])
  mergeDict(mergedConfig, groupsConfig)
  mergeDict(mergedConfig, hostConfig)

  # Remove the _groups dict
  mergedConfig.pop('_groups', None)

  ansibleInventory['_meta']['hostvars'][hostName] = mergedConfig

  if errors != []:
    raise InventoryErrors(errors)


if __name__ == '__main__':
  errors = []
  # Default config
  ansibleInventory = {
    '_meta': {
      'hostvars': {}
    },
    'all': {
      'hosts': [],
      'vars': {}
    },
    'ungrouped': {
      'hosts': [],
      'vars': {}
    },
    'virtual': {
      'hosts': [],
      'vars': {}
    }
  }
  # Read user configuration
  userConfig = {}
  try:
    userConfig = readYAML(join(dirname(__file__), '../user.yml'))
  except IOError:
    pass
  # Find files
  groupConfigFiles = listFiles('../groups')
  hostConfigFiles = listFiles('../hosts')
  # Parse groups
  for groupName, groupConfigs in groupConfigFiles.items():
    # Add to the ansible configuration.
    # The hosts list will be filled later
    ansibleInventory[groupName] = {'hosts': [], 'vars': readYAML(groupConfigs)}
  # Parse hosts
  for hostName, hostConfigs in hostConfigFiles.items():
    hostConfig = readYAML(hostConfigs)
    try:
      addHost(ansibleInventory, userConfig, hostName, hostConfig)
    except InventoryErrors as e:
      errors.extend(e.errors)
  # Check for errors
  if errors != []:
    e = Exception(''.join([ f'\t({i+1}):\t {e}' for i, e in enumerate(errors) ]))
    raise e
  # Print the result
  print(dumps(ansibleInventory))
