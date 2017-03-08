#Snippets and one-liners
#Returns the VM AdvancedSetting for environment task and event retention

Get-AdvancedSetting -Entity $global:DefaultVIServer | where{$_.Name -match "event.max|task.max"}
