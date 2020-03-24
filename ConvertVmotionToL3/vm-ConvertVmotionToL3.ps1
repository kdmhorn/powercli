<#	Migrates existing vMotion adapters from standard to vmotion IP stack.
 	Script originally written and run in PowerCLI 6.3 R1.
	
	Known issue: In some cases, the SLEEP following adapter creation may not be high enough causing one 
	or more interfaces to remain on the temporary VSS created and preventing subsequent
	removal of the VSS. 
#>

#	Following lines are generic - modify appropriately for environment
$dnslist = "192.168.1.2","192.168.1.3"
$domlist = "company.org","internal.company.org"
$gateway = "192.168.1.1"
$network = "default"
$netstack = "vmotion"
$vmkmtu = 1500

$vmhostlist = Get-Cluster VM-Cluster | Get-VMHost
#$vmhostlist = Get-VMHost vmhost.company.org

ForEach ($vmhost in $vmhostlist){

write-host -ForeGroundColor green "Setting Up Network on" $vmhost.Name

	$esxcli2 = $vmhost|Get-EsxCli -V2

	$nsargs = $esxcli2.network.ip.netstack.add.CreateArgs()
	$niargs = $esxcli2.network.ip.interface.add.CreateArgs()
	$nisargs = $esxcli2.network.ip.interface.ipv4.set.CreateArgs()
	$dnsargs = $esxcli2.network.ip.dns.server.add.createargs()
	$domargs = $esxcli2.network.ip.dns.search.add.createargs()
	$rteargs = $esxcli2.network.ip.route.ipv4.add.createargs()
	
#	Enable standard vmotion netstack	
	$nsargs.netstack = $netstack
	$nsargs.disabled = $false
	$esxcli2.network.ip.netstack.add.Invoke($nsargs) | Out-Null
	
#	Set parameters that are standard to each adapter
	$niargs.netstack = $netstack
	$niargs.mtu = $vmkmtu
	$niargs.portgroupname = "temp"

	$nisargs.type = "static"
	
	$dnsargs.netstack = $netstack
	$domargs.netstack = $netstack

	$rteargs.netstack = $netstack
	$rteargs.gateway = $gateway
	$rteargs.network = $network


#	Get existing vmotion adapters from the host
	$vmkIntList = $vmhost|Get-VMHostNetworkAdapter | Where {$_.VMotionEnabled}
	
<#	Create temporary standard switch and portgroup. In original tests direct to DVS, 
	ports worked but were left in 'unknown' state. VLAN picked is arbitrary.
#>
	$tempvswitch = $vmhost|New-VirtualSwitch -Name “temp” 
	Start-Sleep -Seconds 2
	New-VirtualPortGroup -VirtualSwitch $tempvswitch -Name “temp” -VLanId “4000”
	Start-Sleep -Seconds 2

#	Set unique parameters from existing vmotion adapters, delete and re-create the vmotion adapter
	ForEach ($vmk in $vmkIntList){
		
		$niargs.interfacename = $vmk.Name

		$nisargs.interfacename = $vmk.Name
		$nisargs.ipv4 = $vmk.IP
		$nisargs.netmask = $vmk.SubnetMask
		
#		Remove existing adapter
		$vmk|Remove-VMHostNetworkAdapter -Confirm:$false

#		Add new adapter to the vmotion netstack
		$esxcli2.network.ip.interface.add.invoke($niargs) | Out-Null
		$esxcli2.network.ip.interface.ipv4.set.Invoke($nisargs) | Out-Null
		Start-Sleep -Seconds 10
		
#		Migrate new adapters to the original DVS portgroup
		$vmhost | Get-VMHostNetworkAdapter -Name $vmk.name | Set-VMHostNetworkadapter -PortGroup $vmk.PortGroupName -Confirm:$false

	}
	
#	Remove temporary virtual switch
	$tempvswitch|Remove-VirtualSwitch -Confirm:$false
	Start-Sleep -Seconds 2
	
#	Add DNS Servers to the vmotion netstack
	ForEach ($dnssrv in $dnslist){
		$dnsargs.server = $dnssrv
		$esxcli2.network.ip.dns.server.add.Invoke($dnsargs) | Out-Null
	}
	
#	Add Search Domains to the vmotion netstack
	ForEach ($domnam in $domlist){
		$domargs.domain = $domnam
		$esxcli2.network.ip.dns.search.add.Invoke($domargs) | Out-Null
	}

#	Add gateway address to the vmotion netstack
	$esxcli2.network.ip.route.ipv4.add.Invoke($rteargs) | Out-Null
	
}
