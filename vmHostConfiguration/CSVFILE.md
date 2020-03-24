# CSV Input File #
The CSV Input file is used to pass along a minimal amount of host specific information such as names, IPs and credentials to the script. 
It can contain one or hosts, with each host getting a line within the file. File name of the CSV file is not important to script 
execution.

It contains the following information:
* __Name__ - This is the FQDN of the host being added (or IP address if DNS/FQDN is not used for some reason)
* __localds__ - This field is used to rename the local datastore (_datastore1_)
* __vmip1 & vmip2__ - These are the IP addresses of the vMotion adapters.
* __cluster__ - This is the target cluster to place the host in.
* __vcenter__ - The target vcenter for the host - each host could be targeted to different vcenters
* __vswitch__ - Currently in sample but no longer needed as "vswitch0" is the name used in a base install/configuration
* __user__ - this is the local user name on the host - usually "root"
* __password__ - this is the default password put on the host when installed. While in plain text in this case, it is expected another process is later used to set the password to something more secure.
