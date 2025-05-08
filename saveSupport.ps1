<#
.SYNOPSIS
    Launcher for Schedule 1 Save Support scripts from GitHub.
.DESCRIPTION
    This script downloads and executes PowerShell scripts from a GitHub repository.
    It manages a local directory in AppData\LocalLow to store the downloaded scripts,
    placing them next to the game's TVGS folder. This allows for easy updating of scripts
    by modifying the GitHub repository. This is configurable to different repos for the
    as a convenience to anyone who forks the project and wants to test or operate out of
    their own repository.
.NOTES
    Author: Kage@GitHub Quadstronaut@Schedule1
    Version: 1.0
    GitHub Repository: https://github.com/GitKageHub/Schedule1SaveSupport
#>

## User Configurable Variables - see .DESCRIPTION

# GitHub repository
$repoUrl = "GitKageHub/Schedule1SaveSupport"
$remoteDirName = "Functions"
$rawContentUrl = "https://raw.githubusercontent.com/$repoUrl/$remoteDirName"

## Functions

# Telemetry
$timeStart = Get-Date

function Invoke-ScriptFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if (Test-Path -Path $Name -PathType Leaf) {
        try {
            . $Name
            if (Get-Command -Name $Name -Function) {
                & $Name
            }
            else {
                Write-Warning "No function with the name '$Name' found in script '$Name'."
            }
        }
        catch {
            Write-Error "Failed to execute script or function: $Name. Error: $($_.Exception.Message)"
            throw
        }
    }
    else {
        Write-Warning "Script does not exist: $Name"
    }
}

## Sanity Logic

try {
    # %APPDATA%/LocalLow target
    $localDirName = "S1SS" # S1SS is the official target
    $localLowPath = "$env:USERPROFILE\AppData\LocalLow"
    $localDir = Join-Path -Path $localLowPath -ChildPath $localDirName

    # Ensure the local directory exists
    $directoryEnsured = Test-Path -Path $localDir
    if (-not($directoryEnsured)) {
        New-Item -Path $localDir -ItemType Directory -ErrorAction Stop
    }
    else {
        # Look for existing vault
        $localVault = Join-Path -Path $localDir -ChildPath 'S1SS_Vault'
        $localVaultFound = Test-Path $localVault -PathType Container
        if (-not($localVaultFound)) {
            ## New Vault
            #TODO: Create new vault at $localVault
        }
        else {
            ## Load Vault
            #TODO: Load vault from $localVault
        }
        ## Save Support Super System

        # Set working location
        Invoke-ScriptFunction -Name Set-LocationSchedule1Saves

        #while ($true) {
        #TODO: Menu for user input
        Get-Location
        # }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Host "Script execution halted." -ForegroundColor Red
    # Fry, there's no such thing as 2!!
    exit 2
}
