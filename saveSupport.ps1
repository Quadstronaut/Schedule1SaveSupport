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
$timeStarted = Get-Date

function Get-Function {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$functionName
    )
    if (Test-Path -Path $functionName -PathType Leaf) {
        try { . $functionName }
        catch {
            Write-Error "Failed to execute script: $functionName. Error: $($_.Exception.Message)"
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
    $zipEncode = 'aHR0cHM6Ly9naXRodWIuY29tL0dpdEtBZ2VIdWIvU2NoZWR1bGUxU2F2ZVN1cHBvcnQvYXJjaGl2ZS9yZWZzL2hlYWRzL21hc3Rlci56aXA='
    $directoryFound = Test-Path -Path $s1ssPath
    if (-not($directoryFound)) {
        New-Item -Path $s1ssPath -ItemType Directory -Force -ErrorAction Stop -Verbose
        try {
            # Make a temp location
            $tempDirName = New-Guid #guids avoids collisions, simpler to implement than Get-Random
            $tempDirPath = Join-Path -Path $env:TEMP -ChildPath $tempDirName
            New-Item -Path $tempDirPath -ItemType Directory -Force -ErrorAction Stop -Verbose

            # Download zip to temp
            $zipBytes = [System.Convert]::FromBase64String($zipEncode)
            $zipUrl = [System.Text.Encoding]::UTF8.GetString($zipBytes)
            Write-Host "Downloading scripts from GitHub to $tempDirPath" -ForegroundColor Cyan
            $zipFile = Join-Path -Path $tempDirPath -ChildPath 's1ss_temp.zip'
            Invoke-WebRequest -Uri $ZipUrl -OutFile $zipFile -ErrorAction Stop -UseBasicParsing -Verbose

            # Extract the contents
            Write-Host "Extracting scripts to $s1ssPath" -ForegroundColor Cyan
            Expand-Archive -Path $zipFile -DestinationPath $s1ssPath -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Error downloading or extracting scripts: $($_.Exception.Message)"
            throw  # Re-throw the error to be caught by calling script
        }
        finally {
            # Clean up
            Write-Host "Extraction complete, cleaning up temporary files." -ForegroundColor Green
            Remove-Item -Path $tempDirPath -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        # Look for existing vault
        $vaultPath = Join-Path -Path $s1ssPath -ChildPath 'Vault'
        $localVaultFound = Test-Path $vaultPath -PathType Container
        try {
            $ReadyToSupport = $false
            while (-not($ReadyToSupport)) {
                if (-not($localVaultFound)) {
                    ## New Vault
                    New-Item -path $vaultPath -ItemType Directory -Force -ErrorAction Stop -Verbose
                    $ReadyToSupport = $true
                }
                else {
                    ## Load Vault
                    class SaveGame {
                        #Game.json
                        $GameVersion
                        $OrganisationName
                        #Metadata.json
                        $LastPlayedDate
                        #Time.json
                        $ElapsedDays
                        #Player_0/Inventory.json
                        $CashBalance
                        #Money.json
                        $OnlineBalance
                        # Path to SaveGame
                        $pathSaveGame
                    }
                }
            }
            
        }
        catch {
            
            #TODO: Is this useful?
        }
        finally {
            # Load all the things

            $saveDirectories = @($s1ssPath)

        }

        ## Save Support Super System

        $mnemonicLoop = $true
        while ($true -eq $mnemonicLoop) {
            # TODO: Menu for user input
            Write-Host "Schedule 1 Save Support`n"
            Write-Host 'Make a selection:'
            Write-Host 'B) Backup a save'
            Write-Host 'I) Inspect a save'
            Write-Host 'L) List saves'
            Write-Host 'M) Modify a save'
            Write-Host 'R) Restore a save'
            Write-Host 'Q) Quit'
            $userInput = Read-Host "Select a number or Q to exit"
            Clear-Host
            switch ($userInput.ToUpper()) {
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
    exit 2 # "But Fry, there's no such thing as 2!" -Bender
}