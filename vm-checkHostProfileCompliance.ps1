$vmhpList = Get-VMHostProfile
ForEach ($vmhp in $vmhpList){
	write $vmhp.name
	Test-VMHostProfileCompliance -Profile $vmhp
}
