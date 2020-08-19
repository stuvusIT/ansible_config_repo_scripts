#!/usr/bin/env python3
import yaml
import glob
import os
from copy import deepcopy
from datetime import datetime

# cd into stuvus_config
rpath=os.path.dirname(os.path.realpath(__file__))
os.chdir(rpath+'/..')

# get a list of all host configuration files
hostvar_files=glob.glob("./hosts/*.yml")
hostvar_files.extend(glob.glob("./hosts/*/*.yml"))

data = {}
hostvar_keys_of_interest = ['ip', 'hostname', 'type', 'description', 'organisation', 'groups']

# build hostname from host configuration path
def get_hostname(host_config_path):
    hostname = host_config_path.replace('.yml','')
    hostname = hostname.replace('./hosts/','')
    hostname = hostname.split('/')[0] # get the hostname not the filename (needed for hosts with multiple config files)
    return hostname

# get all ips from host configuration
def get_all_host_ips(host_config):
    ips = []

    if 'ansible_host' in host_config:
        ips.append(host_config['ansible_host'])

    # go over all configured interface types
    for interface_type in [ interface_type for interface_type in ['interfaces', 'bridges'] if interface_type in host_config]:
        for interface in host_config[interface_type]:
            if 'ip' in interface:
                ips.append(interface['ip'])
            if 'ips' in interface:
                for ip in interface['ips']:
                    ips.append(ip)
    ips = [ ip.split('/')[0] for ip in ips ] # get ips without CIDR
    return ips

# iterate over all hosts
for host_config_path in hostvar_files:
    # parse host configuration
    host_config_file = open(host_config_path)
    host_config = yaml.safe_load(host_config_file)
    host_config_file.close()

    # get and set the hostname
    host_config['hostname'] = get_hostname(host_config_path)

    host_ips = get_all_host_ips(host_config)
    for ip in host_ips:
        sort_ip = ''.join([ ip_part.zfill(3) for ip_part in ip.split('.') ])
        data[sort_ip] = deepcopy(host_config)
        data[sort_ip]['ip'] = ip
        try:
            data[sort_ip]['organisation'] = host_config['vm']['org']
        except KeyError:
            data[sort_ip]['organisation'] = '___-___'
        if 'vm' in data[sort_ip]:
            data[sort_ip]['type'] = ' vm '
        else:
            data[sort_ip]['type'] = ' hw '
        data[sort_ip]['groups'] = ", ".join(data[sort_ip]['_groups']) # pretty formate groups

format_string = '|'
separator_string = '|'
header_string = '|'
for info_key in hostvar_keys_of_interest:
    # maximum string length for relevant data
    max_key_length = max([ len(data[sort_ip][info_key]) for sort_ip in data])
    format_string += ' {%s:<%d} |' % (info_key, max_key_length) # can't use .format here since i need to build a format string
    separator_string += '{row_separator:{row_separator}<{length}}|'.format(row_separator = '-', length = max_key_length+2)
    header_string += ' {info_key:<{length}} |'.format(info_key = info_key, length = max_key_length)

# print table head
print("letztes Update {}\n".format(datetime.now()))
print(header_string)
print(separator_string)

# print all host information
for sort_ip in sorted(data):
    print(format_string.format(**data[sort_ip]))
