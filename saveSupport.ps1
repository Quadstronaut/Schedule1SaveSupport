<#
.SYNOPSIS
    Schedule 1 Save Support script from Hell.
.DESCRIPTION
    This script manages Schedule 1 savegames in ways Tyler never wanted...
.NOTES
    Author: Kage@GitHub Quadstronaut@Schedule1
    Version: 1.0
    GitHub Repository: https://github.com/GitKageHub/Schedule1SaveSupport
#>

## Functions

# Check if the script is running with administrative privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "Error: This script requires administrative privileges to run." -ForegroundColor Red
    Write-Host ""
    Write-Host "To run this script with administrator rights, please follow these steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1.  Click the Start button (usually in the bottom-left corner of your screen)." -ForegroundColor Cyan
    Write-Host "  2.  Type 'PowerShell' (or 'pwsh' for PowerShell 7) in the search bar." -ForegroundColor Cyan
    Write-Host "  3.  Right-click on 'Windows PowerShell' (or 'PowerShell 7') in the search results." -ForegroundColor Cyan
    Write-Host "  4.  Select 'Run as administrator' from the context menu." -ForegroundColor Cyan
    Write-Host "  5.  If prompted, click 'Yes' to allow the app to make changes to your device." -ForegroundColor Cyan
    Write-Host "  6.  Once the elevated PowerShell window is open, navigate to the location of this script" -ForegroundColor Cyan
    Write-Host "      using the 'cd' command (e.g., cd ~\Downloads\saveSupport.ps1)." -ForegroundColor Cyan
    Write-Host "  7.  Finally, run the script again by typing its name and pressing Enter." -ForegroundColor Cyan
    Write-Host "  8.  Close this PowerShell window now that you've completed all steps." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Sorry about the inconvenience, testing deemed it necessary."
    exit
}

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
        $player_0 = Join-Path -Path $SaveFolder -ChildPath 'Players\Player_0'
        $inventoryFile = Join-Path $player_0 "Inventory.json"
        if (Test-Path $inventoryFile) {
            $inventoryData = Get-Content -Path $inventoryFile -Raw | ConvertFrom-Json
            foreach ($item in $inventoryData.Items) {
                $itemObject = $item | ConvertFrom-Json
                if ($itemObject.DataType -eq "CashData") {
                    $save.CashBalance = "{0:N0}" -f ([int]$itemObject.CashBalance)
                    break # Assuming only one CashData entry
                }
            }
        }

        # Load Money.json
        $moneyFile = Join-Path $SaveFolder "Money.json"
        if (Test-Path $moneyFile) {
            $moneyData = Get-Content -Path $moneyFile -Raw | ConvertFrom-Json
            $save.OnlineBalance = "{0:N0}" -f ([int]$moneyData.OnlineBalance)
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
        return
    }

    # Get the subdirectories within the Saves directory (should be the Steam ID).
    $steamIdDirectories = Get-ChildItem -Path $schedule1SavesPath -Directory

    if ($steamIdDirectories.Count -eq 0) {
        Write-Warning "No Steam ID directories found in '$schedule1SavesPath'."
        return
    }

    # Assume the first directory is the correct Steam ID.  This is usually the case.
    $steamIdDirectory = $steamIdDirectories[0]
    $saveLocation = Join-Path -Path $schedule1SavesPath -ChildPath $steamIdDirectory.Name

    # Check if the final save location exists.
    if (-not (Test-Path -Path $saveLocation -PathType 'Container')) {
        Write-Warning "The Schedule 1 save directory does not exist at '$saveLocation'."
        return
    }

    # Handle location based on return flag.
    if ($Return) {
        return $saveLocation
    }
    else {
        Set-Location -Path $saveLocation
    }
}

function Show-SaveGames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TitleSingular,
        [Parameter(Mandatory = $true)]
        [string]$TitlePlural,
        [Parameter(Mandatory = $false)]
        [array]$SaveData = 0 # A default is required because this could be a null value
    )
    if ($SaveData.Count -gt 0) {
        if ($SaveData.Count -eq 1) {
            Write-Host "--- $TitleSingular ---"
        }
        else {
            Write-Host "--- $TitlePlural ---"
        }
        $SaveData | Format-Table GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance -AutoSize
    }
}

$localDirName = 'S1SS' # goes the snake
$localLowPath = "$env:USERPROFILE\AppData\LocalLow"
$s1ssPath = Join-Path -Path $localLowPath -ChildPath $localDirName
$directoryFound = Test-Path -Path $s1ssPath

# Prepare to handle saves
if (-not($directoryFound)) {
    New-Item -Path $s1ssPath -ItemType Directory -Force -ErrorAction Stop -Verbose
}
else {
    # Look for existing vault
    $vaultPath = Join-Path -Path $s1ssPath -ChildPath 'Vault'
    $localVaultFound = Test-Path $vaultPath -PathType Container
    if (-not($localVaultFound)) {
        New-Item -path $vaultPath -ItemType Directory -Force -ErrorAction Stop -Verbose
    }
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

    # Eat moar RAM
    $savepathSchedule1 = Set-LocationSchedule1Saves -Return $true
    $activeSaves = @()
    $vaultedSaves = @()
    $unexpectedSaves = @()

    # Active Saves
    Write-Host "DEBUG: Active Saves"
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
    Write-Host "DEBUG: Unexpected Saves"
    $expectedSaveFolders = 1..5 | ForEach-Object { "SaveGame_$_" }
    Get-ChildItem -Path $savepathSchedule1 -Directory | Where-Object { $_.Name -notin $expectedSaveFolders } | ForEach-Object {
        $unexpectedSavePath = $_.FullName
        $loadedSave = Get-SaveGame -SaveFolder $unexpectedSavePath
        if ($loadedSave) {
            $unexpectedSaves += $loadedSave
        }
    }

    # Vaulted Saves
    Write-Host "DEBUG: Vaulted Saves"
    if (Test-Path $vaultPath -PathType Container) {
        Get-ChildItem -Path $vaultPath -Directory | ForEach-Object {
            $vaultedSavePath = $_.FullName
            $loadedSave = Get-SaveGame -SaveFolder $vaultedSavePath
            if ($loadedSave) {
                $vaultedSaves += $loadedSave
            }
        }
    }
    $totalSaves = $activeSaves.Count + $unexpectedSaves.Count + $vaultedSaves.Count

    ## Save Support : Main

    $mnemonicLoop = $true
    while ($true -eq $mnemonicLoop) {
        Clear-Host
        Write-Host ' ____  _ ____ ____'
        Write-Host '/ ___|/ / ___/ ___|'
        Write-Host '\___ \| \___ \___ \'
        Write-Host ' ___) | |___) |__) |'
        Write-Host '|____/|_|____/____/'
        Write-Host "Active saves in GameSave folder: $($activeSaves.Count)`n"
        if ($activeSaves.Count -ne $totalSaves) {
            if ($unexpectedSaves.Count -gt 0) {
                Write-Host "Unexpected saves in GameSave folder: $($unexpectedSaves.Count)"
            }
            if ($vaultedSaves.Count -gt 0) {
                Write-Host "Vaulted saves in S1SS folder: $($vaultedSaves.Count)"
            }
        }
        Write-Host 'Make a selection:'
        Write-Host 'B) Backup a save'
        Write-Host 'D) Delete a save'
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
            'D' {
                #TODO: BACKUP a save
            }
            'I' {
                #TODO: INSPECT a save
            }
            'L' {
                # List Saves
                Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
                Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
                Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
                Pause
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
$timeComplete = Get-Date
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