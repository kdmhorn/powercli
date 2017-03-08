# Snippets and one-liners
# Returns all IP addresses on Virtual machines

Get-VM | Select Name,@{N='IP Address';E={
    @($_.guest.IPAddress | where{[ipaddress]::Parse($_).AddressFamily -eq 'InterNetwork'}
    $_.Guest.IpAddress | where{[ipaddress]::Parse($_).AddressFamily -eq 'InterNetworkv6'}) -join ','
    }}
