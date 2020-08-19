#!/usr/bin/env python
# This script generates a mac address that is not currently in use in one of the existing hostvars. Optionally, a prefix can be specified to use instead of "AA:AA:AA:AA:". Colons may be omitted.
from random import randint
from optparse import OptionParser
from os.path import join, dirname
from yaml import safe_load
from os import walk
from re import match, search

usedMacs = set()


def main():
  global usedMacs

  p = OptionParser(
    description=
    'This script generates a mac address that is not currently in use in one of the existing hostvars. Optionally, a prefix can be specified to use instead of "AA:AA:AA:AA:". Colons may be omitted.',
    usage='%prog [options]')
  p.add_option(
    '--prefix', default='AA:AA:AA:AA:', type='string', dest='prefix', help='optional prefix')
  options, arguments = p.parse_args()

  # Find all hostfiles
  hostConfigFiles = listFiles('../hosts')

  # Parse every hostfile from yaml to dict
  for hostConfigFile in hostConfigFiles:
    hostConfig = readYAML(hostConfigFile)
    #extract and add all used macs to the global set
    addMac(hostConfig)

  # Check if prefix is valid and remove colons
  asNum = int(options.prefix.replace(':', ''), 16)
  prefix = options.prefix.replace(':', '')
  if len(prefix) >= 12:
    print(hexToMac(prefix[:12]))
    return

  # Calculate how many bytes need to be generated
  bytesToGenerate = 12 - len(prefix)
  maxNum = pow(16, bytesToGenerate) - 1

  # Generate an unused mac
  newMac = hexToMac(prefix + '%0.2X' % randint(0, maxNum))
  while newMac in usedMacs:
    newMac = hexToMac(prefix + '%0.2X' % randint(0, maxNum))
  print(newMac)


def listFiles(dirPath):
  '''List all yml files in a directory with their path relative to this script'''
  confDir = join(dirname(__file__), dirPath)
  ret = next(walk(confDir))[2]
  # Add path to filename and filter out non-yml files
  ret = [join(confDir, fileName) for fileName in ret if match(r'^[a-z0-9_-]*\.yml$', fileName)]
  return ret


def readYAML(path):
  '''Reads the yml file in the specified path and returns an equivalent dict'''
  fd = open(path, mode='r')
  obj = safe_load(fd)
  fd.close()
  return obj


def addMac(config):
  '''Adds all MAC addresses contained in this host configuration to the global set'''
  global usedMacs
  if 'interfaces' in config:
    for interface in config['interfaces']:
      if 'mac' in interface:
        usedMacs.add(interface['mac'])


def hexToMac(hexString):
  '''Converts a hexadecimal string to the MAC format, uppercase with colons inserted every two bytes'''
  return ':'.join([hexString[i:i + 2] for i in range(0, len(hexString), 2)]).upper()


if __name__ == '__main__':
  main()
