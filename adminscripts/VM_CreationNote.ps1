<# 
.SYNOPSIS 
   Patch-Cleanup is a script for automating the cleanup of snapshots created at 
   Lifespan from the Shavlik patching processes.
.DESCRIPTION
   Patch-Cleanup is run daily as a scheduled task. The script will scan the vCenter
   servers configured in variable $vcenterlist for snapshots older than 3 days
   and named "Protect Patch" and remove the snapshots.

.NOTES 
   File Name  : VM_CreationNote.ps1 
   Author     : KWH
   Version    : 1.03
   
.INPUTS
   No inputs required
.OUTPUTS
   No Output is produced
    
.PARAMETER config
   No Parameters
   
.PARAMETER Outputpath
   No Parameters
   
.PARAMETER job
   No Parameters

.CHANGE LOG
    #20160531 - KWH - Updated PowerCLI to use module rather than the pssnapin
    #20160531 - KWH - Removed LSVCENTR5 and LSVCENTER04 from the server list
    #20160531 - KWH - Added lsvcbcrvcs01 to the server list
	#20170301 - KWH - Removed canned VM Initialize script execution in favor of get-module

#>

#Load VMWare modules
Get-Module -Listavailable VMWare* | Import-Module

$AdminName = "svcvcoadmin@lsmaster.lifespan.org"
$credfile = "c:\Scripts\credentials\svcvcoadmin-cred.txt"
$password = get-content $CredFile | convertto-securestring
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AdminName,$password

$vCenterServers = @("lsvcrihvcs01.lifespan.org","lsvccorvcs01.lifespan.org","lsvcrihvcs02.lifespan.org","lsvccorvcs02.lifespan.org","lsvcbcrvcs01.lifespan.org")
ForEach ($vcenter in $vCenterServers){
	Connect-VIServer $vcenter  -Credential $Cred -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	$TargetVM = $null
	$StartDate = (Get-Date).AddDays(-1)
	$VIEvent = Get-VIEvent -maxsamples 100000 -Start $StartDate| where {$_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmBeingClonedEvent" -or $_.Gettype().Name -eq "VmBeingDeployedEvent"}

	$VIEvent|%{
		$NewNote = ""
		If ($_.DestName){
			$VM = Get-VM $_.DestName}
		Else{
			$VM = Get-VM (Get-View $_.VM.VM).Name}
		If ($VM){
			$NewNote = $VM.ExtensionData.Guest.GuestFullName+"`r`n"
			$NewNote = $NewNote+"Deployed: "+$_.CreatedTime.DateTime+"`r`n"
			$NewNote = $NewNote+"Deployed by "+$_.UserName+"`r`n"
			$NewNote = $NewNote+$_.FullFormattedMessage
			$VM|Set-VM -Notes $NewNote -Confirm:$false
		}
	}


Disconnect-VIServer -Confirm:$false}
