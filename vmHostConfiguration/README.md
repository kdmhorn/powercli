# VM Host Configuration Script (vmHostConfiguration) #
This script is used to place a network attached vSphere host into a vSphere managed environment helping to insure that the same steps are reproduced each time a host is added.

## Background ##
In reviewing the script, it's probably helpful to understand the specific environment for which it is written. The script presumes that an administrator/engineer has installed ESXi on one or more hosts; provided a default root password to each installed host; configured the management network with an IP address, subnet mask and gateway on each host; entered DNS entries; and filled out the CSV file with the appropriate information.  

## Prerequisites ##
To run, the script requires three files - the __vmHostConfiguration.ps1__ script file, the __vSphereDefaults.json__ JSON file, and a CSV file for input (__vmhost-sample.csv__ is provided).

As written, the script requires one or more VMhosts that have been installed to a minimum configuration and connected and reachable on a network (IPv4 configured). The host should have a DNS entry, but will work if the IP address is substituted for FQDN in the CSV file.

### CSV Input File ###
See the [CSVFILE.md](CSVFILE.md) for details and definitions on the items placed in the CSV file.

### Defaults JSON File ###
See the [JSCONFILE.md](JSONFILE.md) for details and definitions of the data placed in the JSON file.

