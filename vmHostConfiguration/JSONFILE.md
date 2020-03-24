# JSON Defaults File #
The JSON  used by the script contains a collection of default settings specific to one or more vcenter servers so that these do not
need to be coded within the script itself. A JSON file was chosen over CSV as some items use or could use multivalues - NTP for instance. 
Each collection is keyed off the __vcenter__ FQDN at the begining of each section. The example shows a configuration for two vcenters.

The collection includes:
* names for three separate distributed virtual switches - management, guest data and vmotion,
* the subnet mask and gateway information for the vmotion adapter(s),
* an array of NTP servers,
* an SNMP management string,
* and syslog connection information.
