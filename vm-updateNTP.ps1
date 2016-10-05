
#Initialize list of target NTP servers
$newntplist = "1.vmware.pool.ntp.org","2.vmware.pool.ntp.org","3.vmware.pool.ntp.org","4.vmware.pool.ntp.org"

$vmclusterlist = Get-Cluster
ForEach ($vmcluster in $vmclusterlist){
$vmhostlist = $vmcluster|Get-VMHost

#Loop through hosts, replace NTP and restart ntpd
	ForEach ($vmhost in $vmhostlist){
		write $vmhost.Name
		$ntplist = $vmhost|Get-VMHostNtpServer
		$vmhost|Remove-VMHostNtpServer -ntpserver $ntplist -Confirm:$false
		$vmhost|Add-VMHostNtpServer -NtpServer $newntplist
		$vmhost|Get-VMHostService |?{$_.key -eq 'ntpd'}|Start-VMHostService
		$vmhost|Get-VmHostService |?{$_.key -eq "ntpd"}|Set-VMHostService -policy "on"
		$ntplist = $null
	}
}
	