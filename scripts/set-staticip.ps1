$netip = Get-NetIPConfiguration;
Get-NetAdapter | Set-NetIPInterface -DHCP Disabled;
Get-NetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $netip.IPv4Address.IpAddress -PrefixLength $netip.IPv4Address.PrefixLength -DefaultGateway $netip.IPv4DefaultGateway.NextHop;
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $netip.DNSServer.ServerAddresses;