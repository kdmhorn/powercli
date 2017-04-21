<# 
.SYNOPSIS 
   Use VM_ShutdownNotes to update the Notes on virtual machines recently shutdown.
   Information includes the date/time and the user responsible for the shutdown.
   
.DESCRIPTION
   VM_ShutdownNotes is run daily as a scheduled task requiring no interaction. 
   The script will take in vCenter events for the latest 24 hour period filtering
   for vm shutdownguest and poweroff events and parse the data.
   Uses Get-VIEventsPlus by LucD for performance

.NOTES 
   File Name  : VM_ShutdownNotes.ps1 
   Author     : Ken Horn
   Version    : 1.00
   
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
	#20170320    Initial Creation

#>

# Get-VIEventPlus Function by LucD below.
<#   
 .SYNOPSIS  Returns vSphere events    
 .DESCRIPTION The function will return vSphere events. With
 	the available parameters, the execution time can be
 	improved, compered to the original Get-VIEvent cmdlet. 
 .NOTES  Author:  Luc Dekens   
 .PARAMETER Entity
 	When specified the function returns events for the
 	specific vSphere entity. By default events for all
 	vSphere entities are returned. 
 .PARAMETER EventType
 	This parameter limits the returned events to those
 	specified on this parameter. 
 .PARAMETER Start
 	The start date of the events to retrieve 
 .PARAMETER Finish
 	The end date of the events to retrieve. 
 .PARAMETER Recurse
 	A switch indicating if the events for the children of
 	the Entity will also be returned 
 .PARAMETER User
 	The list of usernames for which events will be returned 
 .PARAMETER System
 	A switch that allows the selection of all system events. 
 .PARAMETER ScheduledTask
 	The name of a scheduled task for which the events
 	will be returned 
 .PARAMETER FullMessage
 	A switch indicating if the full message shall be compiled.
 	This switch can improve the execution speed if the full
 	message is not needed.   
 .EXAMPLE
 	PS> Get-VIEventPlus -Entity $vm
 .EXAMPLE
 	PS> Get-VIEventPlus -Entity $cluster -Recurse:$true
 #>
 function Get-VIEventPlus {
 	 
 	param(
 		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$Entity,
 		[string[]]$EventType,
 		[DateTime]$Start,
 		[DateTime]$Finish = (Get-Date),
 		[switch]$Recurse,
 		[string[]]$User,
 		[Switch]$System,
 		[string]$ScheduledTask,
 		[switch]$FullMessage = $false
 	)
 
 	process {
 		$eventnumber = 100
 		$events = @()
 		$eventMgr = Get-View EventManager
 		$eventFilter = New-Object VMware.Vim.EventFilterSpec
 		$eventFilter.disableFullMessage = ! $FullMessage
 		$eventFilter.entity = New-Object VMware.Vim.EventFilterSpecByEntity
 		$eventFilter.entity.recursion = &{if($Recurse){"all"}else{"self"}}
 		$eventFilter.eventTypeId = $EventType
 		if($Start -or $Finish){
 			$eventFilter.time = New-Object VMware.Vim.EventFilterSpecByTime
 			if($Start){
 				$eventFilter.time.beginTime = $Start
 			}
 			if($Finish){
 				$eventFilter.time.endTime = $Finish
 			}
 		}
 		if($User -or $System){
 			$eventFilter.UserName = New-Object VMware.Vim.EventFilterSpecByUsername
 			if($User){
 				$eventFilter.UserName.userList = $User
 			}
 			if($System){
 				$eventFilter.UserName.systemUser = $System
 			}
 		}
 		if($ScheduledTask){
 			$si = Get-View ServiceInstance
 			$schTskMgr = Get-View $si.Content.ScheduledTaskManager
 			$eventFilter.ScheduledTask = Get-View $schTskMgr.ScheduledTask |
 			where {$_.Info.Name -match $ScheduledTask} |
 			Select -First 1 |
 			Select -ExpandProperty MoRef
 		}
 		if(!$Entity){
 			$Entity = @(Get-Folder -Name Datacenters)
 		}
 		$entity | %{
 			$eventFilter.entity.entity = $_.ExtensionData.MoRef
 			$eventCollector = Get-View ($eventMgr.CreateCollectorForEvents($eventFilter))
 			$eventsBuffer = $eventCollector.ReadNextEvents($eventnumber)
 			while($eventsBuffer){
 				$events += $eventsBuffer
 				$eventsBuffer = $eventCollector.ReadNextEvents($eventnumber)
 			}
 			$eventCollector.DestroyCollector()
 		}
 		$events
 	}
 } #End Get-VIEventsPlus

#Now back to normal programming
#Load VMWare modules
Get-Module -Listavailable VMWare* | Import-Module

#Run parameters - Change below if username or vcenter list source changes
$dayBtwnRuns = 1
$AdminName = "username"
$credfile = "c:\Scripts\common\credentials\runtime-cred.txt"
$vcfile = "c:\Scripts\Common\inputlists\vcenterlist.txt"

$vmCreationTypes = @() #Remark out any event types not desired below
$vmShutdownTypes += "VmStoppingEvent"
$vmShutdownTypes += "VmGuestShutdownEvent"
$newline = "`r`n"

#Convert Password and username to credential object
$password = get-content $CredFile | convertto-securestring
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $AdminName,$password

#Load vCenter List
$vCenterServers = Get-Content $vcfile

If ($daysBtwnRuns -gt 0) {$daysBtwnRuns = -$daysBtwnRuns}
$Today = Get-Date
$StartDate = ($Today).AddDays($dayBtwnRuns)

ForEach ($vcenter in $vCenterServers){
	Connect-VIServer $vcenter  -Credential $Cred -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
	$TargetVM = $null
    $VIEvent = @()
	$Today = Get-Date
	$StartDate = ($Today).AddDays($dayBtwnRuns)
	$VIEvent = Get-VIEventPlus -Start $StartDate -Finish $Today -EventType $vmShutdownTypes

	$VIEvent|%{
        $VM = $null
		$NewNote = ""
        $existingNote = ""
		$targetvm = If ($_.DestName) {$_.DestName} Else {$_.VM.Name}
		$VM = Get-VM $targetVM | Where {$_.powerState -eq 'poweredOff'} 	
		
		If ($VM){
            $existingNote = $VM.Notes
			$NewNote += "Shutdown: "+$_.CreatedTime.ToLocalTime().DateTime+$newline
			$NewNote += "Shutdown by "+$_.UserName+$newline
			$NewNote += $_.FullFormattedMessage+$newline+$newline+$existingNote
			Set-VM -VM $VM.Name -Notes $NewNote -Confirm:$false
		}
	}
    
    
Disconnect-VIServer -Confirm:$false}
