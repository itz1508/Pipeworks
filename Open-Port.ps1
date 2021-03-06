function Open-Port
{
    <#
    .Synopsis
        Opens ports on the Windows Firewall
    .Description
        Opens ports on the Windows Firewall on the local machine
    .Example
        Open-Port 500
    .Link
        Close-Port
    #>
    [OutputType([Nullable])]
    param(
    # The port numbers to open
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [Uint32[]]$Port,
    # The name of the opened port.  Defaults to Port$PortNumber, i.e. Port21
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$Name,
    # The protocol for the port, either TCP or UDP.  The Default is TCP.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("TCP", "UDP")]
    [string]$Protocol = 'TCP',
    # The address pattern than can access the computer from that port
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$FromAddress = "*"
    )
    
    process {
        #region Initialize Profile
        $firewall = New-Object -ComObject HNetCfg.FwMgr
        $firewallProfile = $firewall.localpolicy.currentprofile
        #endregion Initialize Profile
        
        #region Processs Each Port
        foreach ($p in $port) {
            $portChanged = New-Object -ComObject HNetCfg.FWOpenPort
            if ($protocol -eq 'TCP') {
                $portChanged.Protocol = 6
            } elseif ($protocol -eq 'UDP') {
                $portChanged.Protocol = 17
            }
            $portChanged.Port = $p
            $portChanged.RemoteAddresses = $fromAddress
            $portChanged.Enabled = $true
            if ($name) {
                $portChanged.Name = $name
            } else {
                $portChanged.Name = "Port${P}"
            }
            $firewallProfile.GloballyOpenPorts.Add($portChanged)  
        }
        #endregion Processs Each Port
    }
}