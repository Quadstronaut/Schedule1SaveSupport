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
    Pause ; exit
}

# Telemetry
$timeStarted = Get-Date

function Get-TimeWasted {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$timeStarted
    )
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
}

function Get-SaveGame {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SaveFolder,
        [Parameter(Mandatory = $true)]
        [int]$saveIndex  # Added $saveIndex parameter
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
        $save.saveIndex = $saveIndex # Use the parameter
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
        [array]$SaveData = @()
    )
    if ($SaveData.Count -gt 0) {
        if ($SaveData.Count -eq 1) {
            Write-Host "--- $TitleSingular ---"
        }
        else {
            Write-Host "--- $TitlePlural ---"
        }
        $SaveData | Format-Table saveIndex, GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance -AutoSize
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
# Look for existing vault
$vaultPath = Join-Path -Path $s1ssPath -ChildPath 'Vault'
$localVaultFound = Test-Path $vaultPath -PathType Container
if (-not($localVaultFound)) {
    New-Item -path $vaultPath -ItemType Directory -Force -ErrorAction Stop -Verbose
}

class SaveGame {
    $saveIndex
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
$saveIndexValue = 1
$savePathSchedule1 = Set-LocationSchedule1Saves -Return $true
$activeSaves = @()
$unexpectedSaves = @()
$vaultedSaves = @()

# Active Saves
for ($i = 1; $i -le 5; $i++) {
    $saveFolderName = "SaveGame_$i"
    $saveGamePath = Join-Path $savePathSchedule1 $saveFolderName
    if (Test-Path $saveGamePath -PathType Container) {
        $loadedSave = Get-SaveGame -SaveFolder $saveGamePath -saveIndex $saveIndexValue # Pass the index
        $saveIndexValue++
        if ($loadedSave) {
            $activeSaves += $loadedSave
        }
    }
}

# Unexpected Saves
$expectedSaveFolders = 1..5 | ForEach-Object { "SaveGame_$_" }
Get-ChildItem -Path $savePathSchedule1 -Directory | Where-Object { $_.Name -notin $expectedSaveFolders } | ForEach-Object {
    $unexpectedSavePath = $_.FullName
    $loadedSave = Get-SaveGame -SaveFolder $unexpectedSavePath -saveIndex $saveIndexValue # Pass the index
    $saveIndexValue++
    if ($loadedSave) {
        $unexpectedSaves += $loadedSave
    }
}

# Vaulted Saves
if (Test-Path $vaultPath -PathType Container) {
    Get-ChildItem -Path $vaultPath -Directory | ForEach-Object {
        $vaultedSavePath = $_.FullName
        $loadedSave = Get-SaveGame -SaveFolder $vaultedSavePath -saveIndex $saveIndexValue # Pass the index
        $saveIndexValue++
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
    Write-Host 'B) Backup - Game > Vault'
    Write-Host 'C) Cleanup manual backups - permanent!'
    Write-Host 'D) Delete a save - also permanent!'
    Write-Host 'I) Inspect a save, closely'
    Write-Host 'L) List all saves'
    Write-Host 'M) Mix up a save, cheater'
    Write-Host 'R) Restore - Vault > Game'
    Write-Host 'Q) Quit'
    $userInput = Read-Host "Select a number or Q to exit"
    switch ($userInput.ToUpper()) {
        'B' {
            Clear-Host
            Write-Host '______            _'
            Write-Host '| ___ \          | |'
            Write-Host '| |_/ / __ _  ___| | ___   _ _ __'
            Write-Host "| ___ \/ _` |/ __| |/ / | | | '_ \"
            Write-Host '| |_/ / (_| | (__|   <| |_| | |_) |'
            Write-Host '\____/ \__,_|\___|_|\_\\__,_| .__/'
            Write-Host '                            | |'
            Write-Host '                            |_|'
            $activeSavesCount = $activeSaves.Count
            do {
                Clear-Host
                Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
                $userInput = Read-Host "Please enter a value between 1 and $activeSavesCount"
                $isValidInput = ($null -ne $userInput -as [int] -and $userInput -ge 1 -and $userInput -le $activeSavesCount) -or ($userInput.ToUpper -eq 'C')
                if (-not $isValidInput) {
                    Write-Error "Invalid input. Please enter a number between '1' and `'$activeSavesCount`' or 'C' to Cancel."
                }
            } until ($isValidInput)
            # Arrays start from 0, people start from 1
            $selectedIndex = [int]$userInput - 1
            Write-Host "You've selected save #$userInput"
            do {
                $userInput = Read-Host "Are you sure? y/n"
                $isValidInput = ($userInput.ToUpper -eq 'N') -or ($userInput.ToUpper -eq 'Y')
                if (-not $isValidInput) {
                    Write-Error "Invalid input. Please enter a 'n' or 'y'."
                }
            } until ($isValidInput)
            Write-Host "You selected the following:`n$activeSaves[$selectedIndex]"
            Start-Sleep -Seconds 2
            $newFolderName = New-Guid
            $newVaultPath = Join-Path -Path $vaultPath -ChildPath $newFolderName
            New-Item -ItemType Directory -Path $newVaultPath -Force -ErrorAction Stop -Verbose
            Copy-Item -Path (Join-Path -Path $activeSaves[$selectedIndex].FullName -ChildPath "*") -Destination $newVaultPath -Recurse -Force -ErrorAction Continue -Verbose
            Pause
        }
        'C' {
            Clear-Host
            Write-Host ' _____ _'
            Write-Host '/  __ \ |'
            Write-Host '| /  \/ | ___  __ _ _ __  _   _ _ __'
            Write-Host "| |   | |/ _ \/ _` | '_ \| | | | '_ \"
            Write-Host '| \__/\ |  __/ (_| | | | | |_| | |_) |'
            Write-Host ' \____/_|\___|\__,_|_| |_|\__,_| .__/'
            Write-Host '                               | |'
            Write-Host '                               |_|'
            do {
                Clear-Host
                if ($unexpectedSaves.Count -ne 0) {
                    Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
                    Write-Host 'This will delete ALL shown saves.' -ForegroundColor Yellow
                }
                $userInput = Read-Host 'Are you sure? y/n'
            } until (($userInput.ToUpper() -eq 'N') -or ($userInput.ToUpper() -eq 'Y'))
            if ($userInput.ToUpper() -eq 'Y') {
                $total = $unexpectedSaves.count
                $i = 1
                $progPercent = "{0:n2}" -f ([math]::round($i / $total, 4) * 100)
                Write-Progress -Activity "Cleaning up..." -Status "$i of $total - $progPercent% Complete:" -PercentComplete $progPercent
                foreach ($item in $unexpectedSaves) {
                    $progPercent = "{0:n2}" -f ([math]::round($i / $total, 4) * 100)
                    Write-Progress -Activity "activityName" -Status "$i of $total - $progPercent% Complete:" -PercentComplete $progPercent
                    Remove-Item -Path $unexpectedSaves[$g].pathSaveGame -Recurse -Force -ErrorAction Continue -Verbose
                    $i++
                }
                Clear-Variable -Name unexpectedSaves -ErrorAction SilentlyContinue
                Pause
            }
            else {
                Clear-Host
                Write-Host "Whew..."
                Start-Sleep -Seconds 1
                Write-Host "Close one" -NoNewline
                for ($g = 1; $g -le 3; $g++) {
                    Start-Sleep -Milliseconds 420
                    Write-Host "." -NoNewline
                }
                Start-Sleep -Milliseconds 321
            }
        }
        'D' {
            Clear-Host
            Write-Host '______     _      _'
            Write-Host '|  _  \   | |    | |'
            Write-Host '| | | |___| | ___| |_ ___'
            Write-Host '| | | / _ \ |/ _ \ __/ _ \'
            Write-Host '| |/ /  __/ |  __/ ||  __/'
            Write-Host '|___/ \___|_|\___|\__\___|'
            $userInput = 'x'
            $unexpectedSavesCount = $unexpectedSaves.Count
            $activeSavesCount = $activeSaves.Count
            $vaultedSavesCount = $vaultedSaves.Count
            Write-Host "Choose a set of saves."
            $choices = @{}
            $optionNumber = 1

            # Display the categories
            if ($activeSavesCount -gt 0) {
                Write-Host "$optionNumber. Active ($activeSavesCount)"
                $choices[$optionNumber] = "Active"
                $optionNumber++
            }
            else {
                Write-Host "Hey! Buddy! You gotta play the game first!" -ForegroundColor Red
            }

            if ($unexpectedSavesCount -gt 0) {
                Write-Host "$optionNumber. Unexpected Saves ($unexpectedSavesCount)"
                $choices[$optionNumber] = "Unexpected"
                $optionNumber++
            }

            if ($vaultedSavesCount -gt 0) {
                Write-Host "$optionNumber. Vaulted ($vaultedSavesCount)"
                $choices[$optionNumber] = "Vaulted"
                $optionNumber++
            }

            # Get category from user
            do {
                $selection = Read-Host "Enter the number corresponding to your choice:"
            } until ($choices.ContainsKey([int]$selection))

            # List saves and prompt for index to target
            $selectedSaveType = $choices[[int]$selection]
            if ($selectedSaveType -eq "Active") {###
                Clear-Host
                Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
                # Get saveindex from user
                do {
                    # Display the valid indexes to the user
                    Write-Host "Available Save Indexes:" -NoNewline
                    if ($activeSaves.Count -gt 0) {
                        $validIndices = $activeSaves | ForEach-Object { $_.saveIndex } | Sort-Object
                        Write-Host ($validIndices -join ", ")
                    }
                    # Get a selection
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                    $selectedSave = $activeSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                    $isValid = $selectedSave.Count -gt 0
                    if (-not $isValid) {
                        Write-Host "Invalid selection.  Please choose a valid saveIndex."
                    }
                } until ($isValid)
                Remove-Item -Path $activeSaves[$selection] -Recurse -Force -ErrorAction Continue -Verbose
            }
            elseif ($selectedSaveType -eq "Unexpected") {###
                Clear-Host
                Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
                do {
                    # Display the valid indexes to the user
                    Write-Host "Available Save Indexes:" -NoNewline
                    if ($unexpectedSaves.Count -gt 0) {
                        $validIndices = $unexpectedSaves | ForEach-Object { $_.saveIndex } | Sort-Object
                        Write-Host ($validIndices -join ", ")
                    }
                    else {
                        Write-Host "No unexpected saves available."
                    }
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                    $selectedSave = $unexpectedSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                    $isValid = $selectedSave.Count -gt 0
                } until ($isValid)
                Remove-Item -Path 
            }
            elseif ($selectedSaveType -eq "Vaulted") {###
                do {
                    Clear-Host
                    Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                    $selectedSave = $vaultedSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                    $isValid = $selectedSave.Count -gt 0
                } until ($isValid)
            }
            Pause
        }
        'I' {

            Pause
        }
        'L' {
            Clear-Host
            Write-Host '  ___  _ _   _____'
            Write-Host ' / _ \| | | /  ___|'
            Write-Host '/ /_\ \ | | \ `--.  __ ___   _____  ___'
            Write-Host '|  _  | | |  `--. \/ _` \ \ / / _ \/ __|'
            Write-Host '| | | | | | /\__/ / (_| |\ V /  __/\__ \'
            Write-Host '\_| |_/_|_| \____/ \__,_| \_/ \___||___/'
            Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
            Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
            Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
            Pause
        }
        'M' {
            Clear-Host
            Write-Host '___  ____'
            Write-Host '|  \/  (_)'
            Write-Host '| .  . |___  __'
            Write-Host '| |\/| | \ \/ /'
            Write-Host '| |  | | |>  <'
            Write-Host '\_|  |_/_/_/\_\'
            Pause
        }
        'R' {
            Clear-Host
            Write-Host "______          _"
            Write-Host "| ___ \        | |"
            Write-Host "| |_/ /___  ___| |_ ___  _ __ ___"
            Write-Host "|    // _ \/ __| __/ _ \| '__/ _ \"
            Write-Host "| |\ \  __/\__ \ || (_) | | |  __/"
            Write-Host "\_| \_\___||___/\__\___/|_|  \___|"
            Pause
        }
        'Q' { Clear-Host ; $mnemonicLoop = $false }
        Default { $mnemonicLoop = $false }
    }
    # End of Mnemonic Loop   
}
Get-TimeWasted -timeStarted $timeStarted