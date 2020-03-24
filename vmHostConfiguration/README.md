# VM Host Configuration Script (vmHostConfiguration) #
This script is used to place a network attached vSphere host into a vSphere managed environment helping to insure that the same steps are reproduced each time a host is added.

## Prerequisites ##
To run, the script requires three files - the __vmHostConfiguration.ps1__ script file, the __vSphereDefaults.json__ JSON file, and a CSV file for input (__vmhost-sample.csv__ is provided).

As written, the script requires one or more VMhosts that have been installed to a minimum configuration and connected and reachable on a network (IPv4 configured). The host should have a DNS entry, but will work if the IP address is substituted for FQDN in the CSV file. 
