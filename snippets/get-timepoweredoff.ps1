$vmlist = Get-VM | Where {$_.PowerState -eq 'PoweredOff'} 
ForEach ($vm in $vmlist){
	$vm | Get-VIEvent -Types Info | Where {$_.fullFormattedMessage -match "Powered Off"} | `
	Sort-Object -property createdTime |  select -last 1 | %{
		Write-Host $_.vm.name $_.createdTime | Out-Default}
}
