<#
.SYNOPSIS
    Launcher for Schedule 1 Save Support scripts from GitHub.
.DESCRIPTION
    This script downloads and executes PowerShell scripts from a GitHub repository.
    It manages a local directory in AppData\LocalLow to store the downloaded scripts,
    placing them next to the game's TVGS folder.
.NOTES
    Author: Kage@GitHub Quadstronaut@Schedule1
    Version: 1.0
    GitHub Repository: https://github.com/GitKageHub/Schedule1SaveSupport
#>

## Functions

# Telemetry
$timeStart = Get-Date

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
    $localDirName = 'S1SS' # goes the snake
    $localLowPath = "$env:USERPROFILE\AppData\LocalLow"
    $s1ssPath = Join-Path -Path $localLowPath -ChildPath $localDirName

    # Ensure the local directory exists
    $directoryEnsured = Test-Path -Path $s1ssPath

    if (-not($directoryEnsured)) {
        New-Item -Path $s1ssPath -ItemType Directory -ErrorAction Stop
        #TODO: download scripts and unpack to $s1ssPath
    }
    else {
        # Look for existing vault
        $vaultPath = Join-Path -Path $s1ssPath -ChildPath 'Vault'
        $localVaultFound = Test-Path $vaultPath -PathType Container
        if (-not($localVaultFound)) {
            ## New Vault
            #TODO: Create new vault at $vaultPath
        }
        else {
            ## Load Vault
            #TODO: Load vault from $vaultPath
        }
        ## Save Support Super System

        # Set working location
        Get-Function -Name Set-LocationSchedule1Saves
        Set-LocationSchedule1Saves

        $mnemonicLoop = $true
        while ($true -eq $mnemonicLoop) {
            # TODO: Menu for user input
            Write-Host "Schedule 1 Save Support`n"
            Write-Host "Make a selection:"
            Write-Host "B) Backup a save"
            Write-Host "I) Inspect a save"
            Write-Host "L) List saves"
            Write-Host "M) Modify a save"
            Write-Host "R) Restore a save"
            Write-Host "Q) Quit"
            $userInput = Read-Host "Select a number, Q or 'empty' to exit"
            switch ($userInput) {
                'B' {
                    #TODO: BACKUP a save                   
                }
                'I' {
                    #TODO: INSPECT a save               
                }
                'L' {
                    #TODO: LIST saves                  
                }
                'M' {
                    #TODO: MODIFY a save            
                }
                'R' {
                    #TODO: RESTORE a save                   
                }
                'Q' { $mnemonicLoop = $false }
                Default { $mnemonicLoop = $false }
            }
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Host "Script execution halted." -ForegroundColor Red
    # Fry, there's no such thing as 2!!
    exit 2
}