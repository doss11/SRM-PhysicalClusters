# Set_Perennially-reserved_flags.ps1 - set the perennially-reserved flag on all RDMM LUNS in a cluster
[cmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string]$Vcenter,

    [parameter(Mandatory=$true)]
    [string]$TargetCluster,

    [string]$Quiet,
	[switch]$WhatIf
    )

# Add the Powershell snapin if it is not already added
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null ) {
    Add-PsSnapin VMware.VimAutomation.Core
}

# get the PowerCLI version
$PowerCLIVersion=Get-PowerCLIVersion
write-debug "This is PowerCLI build $($PowerCLIVersion.build)"

# Ensure that we stop on all errors
$global:ErrorActionPreference = "Stop"

# Check that PowerCLi supoprts perenially-reserved
if ($PowerCLIVersion.build -lt 793510) {
    Throw "PowerCLI must be at least build 793510 -- This is build $($PowerCLIVersion.build)"
}


# Ignore the vcenter cert
# only on newer PowerCLI versions
if ($PowerCLIVersion.build -gt 435427) {
    set-PowerCLIConfiguration -invalidCertificateAction 'ignore' -confirm:$false | Out-Null
}
Set-PowerCLIConfiguration -DefaultVIServerMode 'single'  -confirm:$false | Out-Null

Function Write-Log {
    [cmdletbinding()]

    Param(
    [Parameter(Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,
    [Parameter(Position=1)]
    [string]$Path="$env:temp\PowerShellLog.txt"
    )
    
    #Pass on the message to Write-Verbose if -Verbose was detected
    Write-Verbose $Message
    
    #only write to the log file if the $LoggingPreference variable is set to Continue
    if ($LoggingPreference -eq "Continue")
    {
    
        #if a $loggingFilePreference variable is found in the scope
        #hierarchy then use that value for the file, otherwise use the default
        #$path
        if ($loggingFilePreference)
        {
            $LogFile=$loggingFilePreference
        }
        else
        {
            $LogFile=$Path
        }
        
        Write-Output "$(Get-Date) $Message" | Out-File -FilePath $LogFile -Append
    }

} #end function

$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$ScriptName = [io.path]::GetFilenameWithoutExtension($MyInvocation.MyCommand.Definition)

$LogDir=$ScriptPath
$LoggingFilePreference = "$Logdir\$($ScriptName).log"
$LoggingPreference='Continue'

Write-Log "$($MyInvocation.MyCommand.Name) Starting"

Write-Log "Connecting to vCenter $Vcenter"
$myVIServer = Connect-VIServer $Vcenter

Write-Log "Running against cluster $TargetCluster" 
# Get all hosts in the Target Cluster
$VMHosts = Get-Cluster $TargetCluster | Get-VMHost

Write-Log "Found the following hosts:"
$VMHosts | foreach { Write-Log "  $($_.Name)" }

# Find the ScsiCanonicalName for all RDM Disks attached to VMs in the Target Cluster
$RDMDisks = Get-VM -Location $TargetCluster | Get-HardDisk -DiskType "RawPhysical","RawVirtual"
Write-Log "Found $($RDMDisks.count) RDM Disks"
# log all of them
# $RDMDisks | foreach { Write-Log "  $($_.ScsiCanonicalName)" }

#Set perennial reservations 
Foreach ($vmhost in $vmhosts) {
    Write-Log "Processing Host $($vmhost.Name)"
    $myesxcli = get-esxcli -VMhost $vmhost
    foreach($RDMDisk in $RDMDisks) {
        $NAA=$RDMDisk.ScsiCanonicalName
        Write-Log "Checking perenniallyreserved flag on $NAA"
        Try {
            $myRDMs = $myesxcli.storage.core.device.list($NAA)
            $myRDM=$myRDMs[0]
            Write-Log "`$myRDM.IsPerenniallyReserved = $($myRDM.IsPerenniallyReserved)"
        }
        Catch {
            Write-Log "Errored trying to get Perenially-reserved status -- Continuing assuming it needs to be set"
        }
        if ($myRDM.IsPerenniallyReserved -eq $true) {
            Write-Log "On $($vmhost.name): $NAA $($RDMDisk.FileName) is already set to perennially-reserved"
        } Else {
            # http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1016106
            # Set the configuration to "PereniallyReserved".
            # setconfig method: void setconfig(boolean detached, string device, boolean perenniallyreserved)
            write-Log "On $($vmhost.name): Changing $NAA  $($RDMDisk.FileName) to perennially-reserved"
            if (-not $Quiet) { write-host "On $($vmhost.name): Changing $NAA  $($RDMDisk.FileName) to perennially-reserved" }
            if ($Whatif) {
                Write-Host "WHATIF: Not making the change, because -WHATIF was specified"
            } else {
                $myesxcli.storage.core.device.setconfig($false, $NAA, $true)
            }
        }
    }
}
