Function ConvertWWPNToHex {
	Param ($strWWPNraw)
	[String] $strWWPNHex = "{0:x}" -f $strWWPNraw
	[String] $strWWPNHexFormatted = ""
	For ($i=0;$i -lt 8;$i++)
	{
	    $strWWPNHexFormatted += "{0}:" -f $($strWWPNHex.SubString($i * 2, 2))
	}
	$strWWPNHexFormatted = $strWWPNHexFormatted.SubString(0, $strWWPNHexFormatted.Length - 1)
	return $strWWPNHexFormatted
}


## Change Lines below for list of hosts to git
$hostList = Get-Cluster RIH-CtxEpicNonProd|Get-VMHost

ForEach ($vmhost in $hostList){
	$wwpnlist = $vmhost|Get-VMHostHba|Where {$_.type -eq 'FibreChannel'}
	Write $vmhost.Name
	ForEach ($wwpn in $wwpnlist){
		$formattedwwpn = ConvertWWPNToHex $wwpn.PortWorldWideName
		$writeline=$wwpn.Device + "    " + $formattedwwpn
		Write $writeline
		}
	Write `n`r
	}