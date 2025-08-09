#!/usr/bin/env python3

from yaml import safe_load, dump
from os.path import join, dirname
from os import listdir
from sys import exit


def role2task(name, config):
    """Converts a role to a playbook task.

    Parameters:
    name (str): Name of this role
    config (dict): Dictionary containing roles.yaml

    Returns:
    str:The role as Ansible playbook task
    """
    hosts = [name]
    tags = ['_{}'.format(name)]
    if name in config:
        if 'hosts' in config[name]:
            hosts += config[name]['hosts']
        if 'tags' in config[name]:
            tags += config[name]['tags']
        if 'all' in hosts:
            hosts = ['all']
        if 'excludes' in config[name]:
            hosts += ['!{}'.format(e) for e in config[name]['excludes']]

    return {
      'name': 'Execute role {}'.format(role),
      'hosts': hosts,
      'become': True,
      'roles': [name],
      'gather_facts': False,
      'tags': tags,
      'pre_tasks': [{
            'name': 'Gather facts',
            'setup': {},
            'when': 'not ansible_facts'
      }]
    }


def resolve(name, deps, allRoles, resolved, unresolved):
    """Resolves dependencies of a role recursively

    Parameters:
    name (str): Name of this role
    deps (list of str): Names of dependencies of this role
    allRoles (dict): Dictionary of all roles for finding deps
    resolved (list of str): List of resolved role names
    unresolved (list of str): List of unresolved role names
    """
    unresolved.append(name)

    if name in resolved:
        return  # Already resolved

    for dep in deps:
        found = False
        if dep in resolved:
            found = True
        if not found:
            if dep in unresolved:
                print('Circular dependency: {} <-> {}'.format(name, dep))
                exit(1)
            resolve(dep, allRoles[dep], allRoles, resolved, unresolved)
    resolved.append(name)
    unresolved.remove(name)


if __name__ == '__main__':
    config = {}  # roles.yaml contents
    playbook = []  # Playbook to write
    # These are dicts of dependency lists
    earlyRoles = {}  # Roles to execute at the beginning
    roles = {}  # Roles to execute in the middle
    lateRoles = {}  # Roles to execute in the end

    # Read config
    with open(join(dirname(__file__), '../roles.yaml')) as configFile:
        config = safe_load(configFile)

    # Stat roles
    for role in listdir(join(dirname(__file__), '../roles')):
        early = False
        late = False
        after = []
        if role in config:
            if 'early' in config[role]:
                early = config[role]['early']
            if 'late' in config[role]:
                late = config[role]['late']
            if 'after' in config[role]:
                after = config[role]['after']
        if early and late:
            print('Role {} has both early and late set'.format(role))
            exit(1)
        if early:
            earlyRoles[role] = after
        elif late:
            lateRoles[role] = after
        else:
            roles[role] = after

    # Resolve dependencies
    resolved = []
    for r in [earlyRoles, roles, lateRoles]:
        for name, deps in r.items():
            resolve(name, deps, r, resolved, [])

    # Build playbook
    for role in resolved:
        playbook.append(role2task(role, config))

    # Write out
    with open(join(dirname(__file__), '../.playbook.yaml'), 'w') as out:
        out.write(dump(playbook, default_flow_style=False))
