function Get-QlikNode {
  [CmdletBinding()]
  param (
    [parameter(Position=0)]
    [string]$id,
    [string]$filter,
    [switch]$count,
    [switch]$full,
    [switch]$raw
  )

  PROCESS {
    $path = "/qrs/servernodeconfiguration"
    If( $id ) { $path += "/$id" }
    If( $full ) { $path += "/full" }
    If( $count -And (-not ($id -And $full)) ) { $path += "/count" }
    If( $raw ) { $rawOutput = $true }
    return Invoke-QlikGet $path $filter
  }
}

function New-QlikNode {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,Position=0)]
    [string]$hostname,
    [string]$name = $hostname,
    [string]$nodePurpose,
    [string[]]$customProperties,
    [string[]]$tags,

    [alias("engine")]
    [switch]$engineEnabled,

    [alias("proxy")]
    [switch]$proxyEnabled,

    [alias("scheduler")]
    [switch]$schedulerEnabled,

    [alias("printing")]
    [switch]$printingEnabled,

    [alias("failover")]
    [switch]$failoverCandidate
  )

  PROCESS {
    $conf = @{
      configuration=@{
        name=$name;
        hostName=$hostname;
      }
    }
    If ($engineEnabled) {
      $conf.configuration.engineEnabled = $engineEnabled.IsPresent;
    }
    If ($proxyEnabled) {
      $conf.configuration.proxyEnabled = $proxyEnabled.IsPresent;
    }
    If ($schedulerEnabled) {
      $conf.configuration.schedulerEnabled = $schedulerEnabled.IsPresent;
    }
    If ($printingEnabled) {
      $conf.configuration.printingEnabled = $printingEnabled.IsPresent;
    }
    If ($failoverCandidate) {
      $conf.configuration.failoverCandidate = $failoverCandidate.IsPresent;
    }
    If( $nodePurpose ) {
        $conf.configuration.nodePurpose = switch($nodePurpose) {
            Production { 0 }
            Development { 1 }
            Both { 2 }
        }
    }
    $json = ($conf | ConvertTo-Json -Compress -Depth 10)
    $container = Invoke-QlikPost "/qrs/servernodeconfiguration/container" $json
    #Write-Host "http://localhost:4570/certificateSetup"
    return Invoke-QlikGet "/qrs/servernoderegistration/start/$($container.configuration.id)"
  }
}

function Register-QlikNode {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,Position=0)]
    [string]$hostname = $($env:computername),
    [string]$name = $hostname,
    [string]$nodePurpose,
    [string[]]$customProperties,
    [string[]]$tags,

    [alias("engine")]
    [switch]$engineEnabled,

    [alias("proxy")]
    [switch]$proxyEnabled,

    [alias("scheduler")]
    [switch]$schedulerEnabled,

    [alias("printing")]
    [switch]$printingEnabled,

    [alias("failover")]
    [switch]$failoverCandidate
  )

  PROCESS {
    If( !$psBoundParameters.ContainsKey("hostname") ) { $psBoundParameters.Add( "hostname", $hostname ) }
    If( !$psBoundParameters.ContainsKey("name") ) { $psBoundParameters.Add( "name", $name ) }
    $password = New-QlikNode @psBoundParameters
    $postParams = @{__pwd="$password"}
    Invoke-WebRequest -Uri "http://localhost:4570/certificateSetup" -Method Post -Body $postParams -UseBasicParsing > $null
  }
}

function Remove-QlikNode {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelinebyPropertyName=$true,Position=0)]
    [string]$id
  )

  PROCESS {
    return Invoke-QlikDelete "/qrs/servernodeconfiguration/$id"
  }
}

function Update-QlikNode {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True,Position=0)]
    [string]$id,

    [string]$name,
    [ValidateSet("Production", "Development", "Both")]
    [string]$nodePurpose,
    [string[]]$customProperties,
    [string[]]$tags,
    [switch]$engineEnabled,
    [switch]$proxyEnabled,
    [switch]$schedulerEnabled,
    [switch]$printingEnabled,
    [switch]$failoverCandidate
  )

  PROCESS {
    $node = Get-QlikNode $id -raw
    If( $name ) { $node.name = $name }
    If( $nodePurpose ) {
        switch($nodePurpose) {
            Production { $node.nodePurpose = 0 }
            Development { $node.nodePurpose = 1 }
            Both { $node.nodePurpose = 2 }
        }
    }
    If( $customProperties ) {
      $prop = @(
        $customProperties | foreach {
          $val = $_ -Split "="
          $p = Get-QlikCustomProperty -filter "name eq '$($val[0])'"
          @{
            value = ($p.choiceValues -eq $val[1])[0]
            definition = $p
          }
        }
      )
      $node.customProperties = $prop
    }
    If( $tags ) { $node.tags = $tags }
    If( $psBoundParameters.ContainsKey("engineEnabled") ) { $node.engineEnabled = $engineEnabled.IsPresent }
    If( $psBoundParameters.ContainsKey("proxyEnabled") ) { $node.proxyEnabled = $proxyEnabled.IsPresent }
    If( $psBoundParameters.ContainsKey("schedulerEnabled") ) { $node.schedulerEnabled = $schedulerEnabled.IsPresent }
    If( $psBoundParameters.ContainsKey("printingEnabled") ) { $node.printingEnabled = $printingEnabled.IsPresent }
    If( $psBoundParameters.ContainsKey("failoverCandidate") ) { $node.failoverCandidate = $failoverCandidate.IsPresent }
    $json = $node | ConvertTo-Json -Compress -Depth 10
    return Invoke-QlikPut "/qrs/servernodeconfiguration/$id" $json
  }
}
