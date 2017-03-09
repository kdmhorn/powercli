<# 
.SYNOPSIS 
   vm-getHostHBA will return a list of HBA WWPN addresses from a given cluster
   
.DESCRIPTION
   vm-getHostHBA is useful when setting up a new host or cluster in VMWare
   to provide storage administrators a list of WWPN address for fiber connected
   HBAs for target and zoning purposes. It returns the addresses in a human-
   friendly format of xx:xx:xx:xx
   
   Utilizes GET-VIEventsPlus by Luc Dekfor faster event 

.NOTES 
   File Name  : vm-getHostHBA.ps1 
   Author     : KWH
   Version    : 1.00
   
.INPUTS
   No inputs required, assumes connected to vsphere with Connect-VIServer and
   all VMWare PowerCLI modules are loaded.
   
.OUTPUTS
   List of Hosts and their associated HBA addresses
    
.PARAMETER config
   No Parameters
   
.PARAMETER Outputpath
   No Parameters
   
.PARAMETER job
   No Parameters

.CHANGE LOG
	#
	
#>

Function Format-Address {
#Formats Addresses such as MAC and WWPN to Octet pairs formatted with ":"
	Param ($strADDRraw)
	[String] $strADDRHex = "{0:x}" -f $strADDRraw
	[String] $strADDRHexFormatted = ""
	For ($i=0;$i -lt 8;$i++)
	{
	    $strADDRHexFormatted += "{0}:" -f $($strADDRHex.SubString($i * 2, 2))
	}
	$strADDRHexFormatted = $strADDRHexFormatted.SubString(0, $strADDRHexFormatted.Length - 1)
	return $strADDRHexFormatted
}


## Change Lines below for list of hosts to git
$newline = `n`r

$hostList = Get-Cluster VMClusterName | Get-VMHost

ForEach ($vmhost in $hostList){
	$wwpnlist = $vmhost | Get-VMHostHba | Where {$_.type -eq 'FibreChannel'}
	Write $vmhost.Name
	ForEach ($wwpn in $wwpnlist){
		$formattedwwpn = Format-Address $wwpn.PortWorldWideName
		$writeline = $wwpn.Device + "    " + $formattedwwpn
		Write $writeline
		}
	Write $newline
	}