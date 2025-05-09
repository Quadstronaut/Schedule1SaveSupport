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

function Get-SaveGame {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SaveFolder
    )

    $save = [SaveGame]::new()
    $save.pathSaveGame = $SaveFolder

    try {
        # Load Game.json
        $gameFile = Join-Path $SaveFolder "Game.json"
        if (Test-Path $gameFile) {
            $gameData = Get-Content -Path $gameFile -Raw | ConvertFrom-Json
            $save.GameVersion = $gameData.GameVersion
            $save.OrganisationName = $gameData.OrganisationName
        }

        # Load Metadata.json
        $metadataFile = Join-Path $SaveFolder "Metadata.json"
        if (Test-Path $metadataFile) {
            $metaData = Get-Content -Path $metadataFile -Raw | ConvertFrom-Json
            $save.LastPlayedDate = $metaData.LastPlayedDate.Year, $metaData.LastPlayedDate.Month, $metaData.LastPlayedDate.Day, $metaData.LastPlayedDate.Hour, $metaData.LastPlayedDate.Minute, $metaData.LastPlayedDate.Second -join "-"
        }

        # Load Time.json
        $timeFile = Join-Path $SaveFolder "Time.json"
        if (Test-Path $timeFile) {
            $timeData = Get-Content -Path $timeFile -Raw | ConvertFrom-Json
            $save.ElapsedDays = $timeData.ElapsedDays
        }

        # Load Player_0\Inventory.json
        $inventoryFile = Join-Path $SaveFolder "player_0" "Inventory.json"
        if (Test-Path $inventoryFile) {
            $inventoryData = Get-Content -Path $inventoryFile -Raw | ConvertFrom-Json
            foreach ($item in $inventoryData.Items) {
                $itemObject = $item | ConvertFrom-Json
                if ($itemObject.DataType -eq "CashData") {
                    $save.CashBalance = $itemObject.CashBalance
                    break # Assuming only one CashData entry
                }
            }
        }

        # Load Money.json
        $moneyFile = Join-Path $SaveFolder "Money.json"
        if (Test-Path $moneyFile) {
            $moneyData = Get-Content -Path $moneyFile -Raw | ConvertFrom-Json
            $save.OnlineBalance = $moneyData.OnlineBalance
        }
    }
    catch {
        Write-Warning "Error loading data for save in '$SaveFolder': $($_.Exception.Message)"
        return $null
    }

    return $save
}

function Set-LocationSchedule1Saves {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [boolean]$Return = $false
    )
    # Construct the base path to the Schedule 1 saves.
    $schedule1SavesPath = Join-Path -Path $localLowPath -ChildPath "TVGS\Schedule I\Saves"

    # Check if the base saves directory exists.
    if (-not (Test-Path -Path $schedule1SavesPath -PathType 'Container')) {
        Write-Warning "The Schedule 1 saves directory does not exist at '$schedule1SavesPath'."
        return  # Exit the function if the base directory doesn't exist.
    }

    # Get the subdirectories within the Saves directory (should be the Steam ID).
    $steamIdDirectories = Get-ChildItem -Path $schedule1SavesPath -Directory

    # Check if there are any subdirectories.
    if ($steamIdDirectories.Count -eq 0) {
        Write-Warning "No Steam ID directories found in '$schedule1SavesPath'."
        return  # Exit if no Steam ID directory is found.
    }

    # Assume the first directory is the correct Steam ID.  This is usually the case.
    $steamIdDirectory = $steamIdDirectories[0]
    $saveLocation = Join-Path -Path $schedule1SavesPath -ChildPath $steamIdDirectory.Name

    # Check if the final save location exists.
    if (-not (Test-Path -Path $saveLocation -PathType 'Container')) {
        Write-Warning "The Schedule 1 save directory does not exist at '$saveLocation'."
        return  # Exit the function if the save directory doesn't exist.
    }

    # Handle location based on return flag.
    if ($Return) {
        return $saveLocation
    }
    else {
        Set-Location -Path $saveLocation
    }
}

## Sanity Logic


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
        Remove-Item -Path $tempDirPath -Recurse -Force -ErrorAction SilentlyContinue
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
    catch {}
    finally {}

    # Eat moar RAM
    $savepathSchedule1 = Set-LocationSchedule1Saves -Return $true
    $activeSaves = @()
    $vaultedSaves = @()
    $unexpectedSaves = @()

    # Active Saves
    for ($i = 1; $i -le 5; $i++) {
        $saveFolderName = "SaveGame_$i"
        $saveGamePath = Join-Path $savepathSchedule1 $saveFolderName
        if (Test-Path $saveGamePath -PathType Container) {
            $loadedSave = Get-SaveGame -SaveFolder $saveGamePath
            if ($loadedSave) {
                $activeSaves += $loadedSave
            }
        }
    }

    # Unexpected Saves
    $expectedSaveFolders = 1..5 | ForEach-Object { "SaveGame_$_" }
    Get-ChildItem -Path $savepathSchedule1 -Directory | Where-Object { $_.Name -notin $expectedSaveFolders } | ForEach-Object {
        $unexpectedSavePath = $_.FullName
        $loadedSave = Get-SaveGame -SaveFolder $unexpectedSavePath
        if ($loadedSave) {
            $unexpectedSaves += $loadedSave
        }
    }

    # Vaulted Saves
    if (Test-Path $vaultPath -PathType Container) {
        Get-ChildItem -Path $vaultPath -Directory | ForEach-Object {
            $vaultedSavePath = $_.FullName
            $loadedSave = Get-SaveGame -SaveFolder $vaultedSavePath
            if ($loadedSave) {
                $vaultedSaves += $loadedSave
            }
        }
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
                # List Saves
                Write-Host "--- Active Saves ---"
                $activeSaves | Format-Table GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance, pathSaveGame -AutoSize

                Write-Host "--- Unexpected Saves ---"
                $unexpectedSaves | Format-Table GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance, pathSaveGame -AutoSize

                Write-Host "--- Vaulted Saves ---"
                $vaultedSaves | Format-Table GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance, pathSaveGame -AutoSize
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
try {
    $timeComplete = Get-Date
}
finally {
    $timeTaken = $timeComplete - $timeStarted
    $days = $timeTaken.Days
    $hours = $timeTaken.Hours
    $minutes = $timeTaken.Minutes
    $seconds = $timeTaken.Seconds
    $milliseconds = $timeTaken.Milliseconds
    if ($days -ne 1) { $dayString = "days" } else { $dayString = "day" }
    if ($hours -ne 1) { $hourString = "hours" } else { $hourString = "hour" }
    if ($minutes -ne 1) { $minuteString = "minutes" } else { $minuteString = "minute" }
    if ($seconds -ne 1) { $secondString = "seconds" } else { $secondString = "second" }
    if ($milliseconds -ne 1) { $millisecondString = "milliseconds" } else { $millisecondString = "millisecond" }
    Write-Host "You just wasted " -NoNewline
    if ($days -gt 0) { Write-Host "$days $dayString, " -NoNewline }
    if ($hours -gt 0) { Write-Host "$hours $hourString, " -NoNewline }
    if ($minutes -gt 0) { Write-Host "$minutes $minuteString, " -NoNewline }
    if ($seconds -gt 0) { Write-Host "$seconds $secondString, " -NoNewline }
    Write-Host "$milliseconds $millisecondString. Unbelievable."
}
# Thanks for using my script. <3