#Returns a list of Virtual machines along with the Version on VM tools installed

get-vm | % { get-view $_.id } | select Name, @{ Name="ToolsVersion"; Expression={$_.config.tools.toolsVersion}},@{ Name="ToolStatus"; Expression={$_.Guest.ToolsVersionStatus}}