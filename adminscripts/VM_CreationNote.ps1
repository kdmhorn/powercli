<# 
.SYNOPSIS 
   VM_CreationNote replaces the VM Notes field with information on its creation such as
   date, time, template used etc.
   
.DESCRIPTION
   VM_CreationNote is run daily as a scheduled task. The script will scan the vCenter
   servers configured in variable $vcenterlist for VM create or clone events and parse 
   the event for relevant information for the VM creation.

.NOTES 
   File Name  : VM_CreationNote.ps1 
   Author     : KWH
   Version    : 1.01
   
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
    #20170301 - KWH - Removed canned VM Initialize script execution in favor of get-module

#>

#Load VMWare modules
Get-Module -Listavailable VMWare* | Import-Module

$AdminName = "account@domain.com"
$credfile = "c:\Scripts\credentials\admin-cred.txt"
$password = get-content $CredFile | convertto-securestring
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AdminName,$password

$vCenterServers = @("vcenter1","vcenter2","vcenter3")
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
