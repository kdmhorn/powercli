# Snippets and one-liners
# Returns the time a VM was powered off if the event exists
# Note: vCenter only retains tasks and events for 30 days by default

$vmlist = Get-VM | Where {$_.PowerState -eq 'PoweredOff'} 
ForEach ($vm in $vmlist){
	$vm | Get-VIEvent -Types Info -MaxSamples ([int]::MaxValue) | `
	Where {$_.fullFormattedMessage -match "Power Off"} | `
	Sort-Object -property createdTime |  select -last 1 | %{
		Write-Host $_.vm.name $_.createdTime | Out-Default}
}
