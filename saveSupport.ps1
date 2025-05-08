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

function Verify-Remote {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$rawContentUrl
    )
    begin {
        # No Begin block needed for this function
    }
    process {
        try {
            # Request a json response from GitHub
            $response = Invoke-WebRequest -Uri "$rawContentUrl/?format=json" -Method Get -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                # Attempt to parse
                try {
                    $jsonResponse = ConvertFrom-Json -InputObject $response.Content
                    # Check if the response is an array and contains at least one .ps1 file.
                    if ($jsonResponse -is [array]) {
                        foreach ($item in $jsonResponse) {
                            if ($item.type -eq "file" -and $item.name -like "*.ps1") {
                                return $true
                            }
                        }
                        # No .ps1 files were found in the listing.
                        return $false
                    }
                    else {
                        Write-Warning "Unexpected response from GitHub API: $($response.Content)"
                        return $false
                    }
                }
                catch {
                    # Malformed json
                    Write-Warning "Error parsing JSON response: $($_.Exception.Message)"
                    return $false
                }
            }
            else {
                Write-Warning 'Response not 200, GitHub unreachabale?'
                return $false
            }
        }
        catch {
            # Web errors
            Write-Warning "Error checking URL '$rawContentUrl': $($_.Exception.Message)"
            return $false # Return false on error
        }
    }
    end {
        # No End block needed for this function.
    }
} 

function Get-Function {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if (Test-Path -Path $Name -PathType Leaf) {
        try { . $Name }
        catch {
            Write-Error "Failed to execute script: $Name. Error: $($_.Exception.Message)"
            throw
        }
    }
    else {
        Write-Warning "Script does not exist: $Path"
    }
}

## Sanity Logic

try {
    $sanityCheck = Verify-Remote -rawContentUrl $rawContentUrl

    if ($sanityCheck) {
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

            # Find the SaveGame_x folders
            Get-Function -Name Set-LocationSchedule1Saves

            # Set working location
            Set-LocationSchedule1Saves

            #TODO: Prompt user for decision


        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Host "Script execution halted." -ForegroundColor Red
    # Fry, there's no such thing as 2!!
    exit 2
}
