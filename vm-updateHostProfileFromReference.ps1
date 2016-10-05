$vmhpList = Get-VMHostProfile
ForEach ($vmhp in $vmhpList){
	write $vmhp.name
	$Spec = New-Object VMware.Vim.HostProfileHostBasedConfigSpec
	$Spec.Host = New-Object VMware.Vim.ManagedObjectReference
	$Spec.Host = $vmhp.ReferenceHost.ExtensionData.MoRef
	$Spec.useHostProfileEngine = $true
	$vmhp.ExtensionData.UpdateHostProfile($Spec)
}
