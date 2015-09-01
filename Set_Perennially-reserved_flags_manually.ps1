# Set_Perennially-reserved_flags_manually.ps1 - set the perennially-reserved flag on a list of NAA IDs
[cmdletBinding()]
param(
    [string]$Vcenter,
    [string]$TargetCluster,
    [string[]]$NAAs,
    [string]$Quiet
    )

# Add the Powershell snapin if it is not already added
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null ) {
    Add-PsSnapin VMware.VimAutomation.Core
}

# get the PowerCLI version
$PowerCLIVersion=Get-PowerCLIVersion

# Ensure that we stop on all errors
$global:ErrorActionPreference = "Stop"

# Ignore the vcenter cert
# only on newer PowerCLI versions
if ($PowerCLIVersion.build -gt 435427) {
    set-PowerCLIConfiguration -invalidCertificateAction 'ignore' -confirm:$false | Out-Null
}
Set-PowerCLIConfiguration -DefaultVIServerMode 'single'  -confirm:$false | Out-Null

Write-Verbose "Connecting to vCenter $Vcenter"
$myVIServer = Connect-VIServer $Vcenter
 
# Get all hosts in the Target Cluster
$VMHosts = Get-Cluster $TargetCluster | Get-VMHost

Write-Verbose "Found the following hosts:"
$VMHosts | foreach { write-verbose "  $($_.Name)" }

Write-Verbose "Flagging the following RDM Disks:"
$NAAs | foreach { write-verbose "  $($_)" }

#Set perennial reservations 
Foreach ($vmhost in $vmhosts) {
    Write-verbose "Processing Host $($vmhost.Name)"
    $myesxcli = get-esxcli -VMhost $vmhost
    foreach($NAA in $NAAs) {
        # convert to lowercase
        $NAA=$NAA.ToLower()
		# http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1016106
		# Set the configuration to "PereniallyReserved".
		# setconfig method: void setconfig(boolean detached, string device, boolean perenniallyreserved)
		if (-not $Quiet) { write-host "On $($vmhost.name): Changing $($NAA) to perennially-reserved" }
		if ($Whatif) {
			Write-Host "WHATIF: Not making the change, because -WHATIF was specified"
		} else {
			$myesxcli.storage.core.device.setconfig($false, $NAA, $true)
		}
    }
}
