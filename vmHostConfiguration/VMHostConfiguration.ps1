<#
.NOTES
    Author:   Ken Horn
    Created:  March 6, 2019

.MODIFICATIONS
    20200306  -  Initial release of the script

.DESCRIPTION
    Script uses CSV files to host to virtual clusters in a virtual environment

.DEPENDENCIES
    VMware PowerCLI Module
    User defined JSON file containing information on one or more vcenter servers with the following information:

    ** Coming Soon **

    User defined CSV containing the following Column Headers:

    ** Coming Soon **


#>

Param(
    [string]$csvfile = $null
    )


### Script Functions
Function Get-CsvFromDialog{
## Gets a CSV from Windows Dialog

    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Title = 'Select input file for processing'
        Multiselect = $False
        Filter = 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*'} # Specified file types

    [void]$FileBrowser.ShowDialog()

    $FileBrowser.FileName

} #End Function


Function Set-TargetHostLocal{
 ### Sets items that are local to the target host
    Param(
        $HostRecord,
        $SnmpString
        )

    Write-Host Start Setting local host items on $HostRecord.Name ... -ForegroundColor Green
    Connect-VIServer $HostRecord.Name -User $HostRecord.user -Password $HostRecord.pw -Force | Out-Null
        ### Set Maintenance Mode
        Write-Host "`t...setting Maintenance Mode" -ForegroundColor Yellow
        Set-VMhost -State Maintenance -Confirm:$false | Out-Null

        ### Rename Local Datastore
        Write-Host "`t...Renaming local datastore to" $HostRecord.localds -ForegroundColor Yellow
        $datastore = Get-Datastore | Where {$_.Name -eq 'datastore1'}
        If ($datastore) {
            $datastore | Set-Datastore -Name $HostRecord.localds -Confirm:$false | Out-Null
        }

        ### Set SMTP
        Write-Host "`t...setting read-only smtp community" -ForegroundColor Yellow
        Get-VMHostSnmp | Set-VMHostSnmp -Enabled:$true -ReadOnlyCommunity $SnmpString -Confirm:$false | Out-Null

    Disconnect-VIServer $HostRecord..Name -Confirm:$false  | Out-Null
    Write-Host "`t...disconnected from host" -ForegroundColor Yellow

} #End Function


Function Add-TargetHostToCluster{
### Adds the new host to the Target Cluster, returns the host

    Param (
        $HostRecord
        )
    
    $AddClusterArgs = @{
        Name = $HostRecord.name
        Location = $(Get-Cluster $HostRecord.cluster)
        User = $HostRecord.user
        Password = $HostRecord.pw
        Force = $true
        }
        
    ### Add host to vCenter
    Write-Host "`t...adding host" $targethost.name"to cluster" $targethost.cluster -ForegroundColor Yellow
    $newvmhost = Add-VMHost @AddClusterArgs

    $newvmhost

} #End Function


Function Set-TargetHostNetworking{
### Does ALL the target host networking, returns nothing

    Param(
        $HostRecord,
        $virtualHost,
        $vcsettings
        )

    $mgmtDVSwitch = Get-VDSwitch -Name $vcsettings.mgmt
    $dataDVSwitch = Get-VDSwitch -Name $vcsettings.data
    $vmtnDVSwitch = Get-VDSwitch -Name $vcsettings.vmtn
    $mgmtPG = Get-VDPortgroup -Name $vcsettings.hostVNX -VDSwitch $mgmtDVSwitch
    $vmtn1PG = Get-VDPortgroup -Name $vcsettings.vmtnvnxa -VDSwitch $vmtnDVSwitch
    $vmtn2PG = Get-VDPortgroup -Name $vcsettings.vmtnvnxb -VDSwitch $vmtnDVSwitch

    ### Get-VMHost Adapters
    ForEach ($vmnic in $($virtualHost | Get-VMHostNetworkAdapter -Physical)) {
        $HostRecord | Add-Member -Name $vmnic.Name -Value $vmnic -MemberType NoteProperty
        }

    ### Add Host to dvSwitches
    Write-Host "    ...adding host to distributed virtual switches" -ForegroundColor Yellow
    $mgmtDVSwitch | Add-VDSwitchVMHost -VMHost $vmhost
    $dataDVSwitch | Add-VDSwitchVMHost -VMHost $vmhost
    $vmtnDVSwitch | Add-VDSwitchVMHost -VMHost $vmhost

    ### Migrate vmk0 and NICs to management dvSwitch
    Write-Host "`t...migrating management vmk and supporting NICs" -ForegroundColor Yellow
    Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $mgmtDVSwitch -VMHostPhysicalNic $HostRecord.vmnic0 -Confirm:$false | Out-Null
    Get-VMHostNetworkAdapter -Name vmk0 -VMHost $virtualHost | Set-VMHostNetworkAdapter -PortGroup $mgmtPG -Confirm:$false | Out-Null
    Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $mgmtDVSwitch -VMHostPhysicalNic $HostRecord.vmnic1 -Confirm:$false | Out-Null

    ### Add other Physical Adapters to appropriate guest data and vmotion dvSwitches
    Write-Host "`t...migrating other NICs to VDS" -ForegroundColor Yellow
    Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $dataDVSwitch -VMHostPhysicalNic ($HostRecord.vmnic2,$HostRecord.vmnic3) -Confirm:$false | Out-Null
    Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $vmtnDVSwitch -VMHostPhysicalNic ($HostRecord.vmnic4,$HostRecord.vmnic5) -Confirm:$false | Out-Null

    ### Rectify local PortGroups
    Write-Host "`t...recitfying local PortGroups" -ForegroundColor Yellow
    $virtualHost | Get-VirtualPortGroup -Name "VM Network" -Standard|Set-VirtualPortGroup -Name "deploy-only" | Out-Null 
    $virtualHost | Get-VirtualPortGroup -Name "Management Network" | Remove-VirtualPortGroup -Confirm:$false | Out-Null 

    ### Create vMotion NICs and Add to vmotion IP Stack
    Write-Host "`t...adding vMotion vmks" -ForegroundColor Yellow
    $esxcli = Get-EsxCli -VMhost $virtualHost -V2

	$tempvswitch = $virtualHost|New-VirtualSwitch -Name “temp” 
	Start-Sleep -Seconds 2
	New-VirtualPortGroup -VirtualSwitch $tempvswitch -Name “temp” -VLanId “4000” | Out-Null
	Start-Sleep -Seconds 2

    $esxcli.network.ip.netstack.add.Invoke(@{netstack = 'vmotion'; disabled = $false})| Out-Null
    $esxcli.network.ip.interface.add.Invoke(@{interfacename = 'vmk1'; portgroupname = 'temp'; netstack = 'vmotion'})| Out-Null
    $esxcli.network.ip.interface.ipv4.set.Invoke(@{interfacename = 'vmk1'; ipv4 = $HostRecord.vmip1; netmask = $vcsettings.vmtnMask; type = 'static'})| Out-Null
    Start-Sleep -Seconds 10
    $vmhost | Get-VMHostNetworkAdapter -Name 'vmk1' | Set-VMHostNetworkadapter -PortGroup $vmtn1PG -Confirm:$false | Out-Null
    Write-Host "`t...vmk1 added to host" -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    $esxcli.network.ip.interface.add.Invoke(@{interfacename = 'vmk2'; portgroupname = 'temp'; netstack = 'vmotion'})| Out-Null
    $esxcli.network.ip.interface.ipv4.set.Invoke(@{interfacename = 'vmk2'; ipv4 = $HostRecord.vmip2; netmask = $vcsettings.vmtnMask; type = 'static'})| Out-Null
    Start-Sleep -Seconds 10
    $vmhost | Get-VMHostNetworkAdapter -Name 'vmk2' | Set-VMHostNetworkadapter -PortGroup $vmtn2PG -Confirm:$false | Out-Null
    Write-Host "`t...vmk2 added to host" -ForegroundColor Yellow

	$tempvswitch | Remove-VirtualSwitch -Confirm:$false
	Start-Sleep -Seconds 2
    $esxcli.network.ip.route.ipv4.add.Invoke(@{netstack = 'vmotion'; gateway = $vcsettings.vmtnGW; network = 'default'})| Out-Null

} #End Function


###MAIN SCRIPT

If (!$csvfile){
    $csvfile = Get-CsvFromDialog
}

$hostlist = Import-Csv $csvfile

### Load Lifespan vSphere Standards Hash-Tables
$vcenterStandards = Get-Content .\vCenterStandards.json | ConvertFrom-Json


If (!$cred){
    $vccredential = Get-Credential -Message "Enter Username and password for vCenter Access:"}
Else{
    $vccredential = $cred
}


### Process the host list

ForEach ($targethost in $hostlist){

    $recVCStandard = $vcenterStandards | Where {$_.vcenter -eq $targethost.vcenter}

    Set-TargetHostLocal -HostRecord $targethost -SnmpString $recVCStandard.snmp

    Start-Sleep -Seconds 5

    Connect-VIServer $targethost.vcenter -Credential $vccredential | Out-Null
    Write-Host "Connected to vCenter..." -ForegroundColor Green

        $vmhost = Add-TargetHostToCluster -HostRecord $targethost

        Set-TargetHostNetworking -HostRecord $targethost -virtualHost $vmhost -vcsettings $recVCStandard

        ### Set NTP
        Write-Host "`t...setting and enabling NTP configuration" -ForegroundColor Yellow
  	    Add-VMHostNtpServer -vmhost $vmhost -ntpserver $recVCStandard.ntp -Confirm:$false | Out-Null
	    Get-VMHostFirewallException -VMHost $vmhost|where {$_.Name -eq "NTP Client"} | Set-VMHostFirewallException -Enabled:$true -Confirm:$false | Out-Null
	    Get-VMHostService -VMHost $vmhost | where {$_.key -eq "ntpd"} | Start-VMHostService | Out-Null
	    Get-VmHostService -VMHost $vmhost | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" | Out-Null

        ### Add Syslog
        Write-Host "`t...adding SYSLOG configuration" -ForegroundColor Yellow
        Get-VMHostFirewallException -VMHost $vmhost|Where {$_.Name -eq "syslog"} | Set-VMHostFirewallException -Enabled:$true -Confirm:$false | Out-Null
        Set-VMHostSysLogServer -VMHost $vmhost -SysLogServer $recVCStandard.syslog -Confirm:$false | Out-Null

        ### Supress HyperThread Warning
        Write-Host "`t...suppress Hyperthread warning" -ForegroundColor Yellow
        $vmhost|Get-AdvancedSetting -Name "UserVars.SuppressHyperthreadWarning" | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-Null

        ### CEIP Opt-Out
        Write-Host "`t...setting CEIP Opt-In" -ForegroundColor Yellow
        $vmhost|Get-AdvancedSetting -Name "UserVars.HostClientCEIPOptIn" | Set-AdvancedSetting -Value 2 -Confirm:$false | Out-Null

        ### Move local datastore to a datastore folder called 'Local'
        Write-Host "`t...move local datastore to folder" -ForegroundColor Yellow
        Get-Datastore $targethost.localds | Move-Datastore -Destination 'Local' -Confirm:$false | Out-Null

        ### Set VMHost Swap file location to target host local datastore
        Write-Host "`t...setting Virtual Machine swap file location" -ForegroundColor Yellow
        $vmhost | Set-VMHost -VMSwapfileDatastore $targethost.localds | Out-Null

        ### Set VMHost power policy to High Performance
        Write-Host "`t...setting VMHost to High Performance power policy" -ForegroundColor Yellow
        (Get-View ($vmhost | Get-View).ConfigManager.PowerSystem).ConfigurePowerPolicy(1)

    Disconnect-VIServer $viserver -Confirm:$false
    Write-Host "Completed host configuration for" $targethost.name -ForegroundColor Green
            
} #End ForEach

