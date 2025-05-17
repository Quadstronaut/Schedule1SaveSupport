<#
.SYNOPSIS
  Schedule 1 Save Support script from Hell.
.DESCRIPTION
  This script manages Schedule 1 savegames in ways Tyler never conceived anyone would waste the time on. I like his
  import export feature, but that still requires me to manage my own files. Gross. I introduce to you the concept of
  a save vault. I'm reserving a folder right next to the game's where the saves are stored. I will move saves in and
  out of that folder for you, keeping track of all the details. No work, just managing your saves like an automation
  engineer does. Please make use of my GitHub repository GitKageHub/Schedule1SaveSupport to find documentation, report
  issues, etc.
.NOTES
  Author: Kage@GitHub Quadstronaut@Schedule1
  Version: 1.0
  GitHub Repository: https://github.com/GitKageHub/Schedule1SaveSupport


## Functions - These are the bits of code I reuse many times through the script.

# Check if the script is running with administrative privileges - testing shows this is necessary, though I don't believe that to be true.
# [ ]: Verify if this is truly a requirement
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
    Write-Host "The script would run fine but the files wouldn't actually move."
    Pause ; exit
}#>

# Telemetry
$timeStarted = Get-Date

function Get-TimeWasted {
    # [x]: Function tested - Get-TimeWasted
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
    # [ ]: Verify max condescension
    Write-Host "$milliseconds $millisecondString. Unbelievable."
}

function Get-SaveGame {
    # [ ]: Function tested - Get-SaveGame
    param(
        [Parameter(Mandatory = $true)]
        [string]$SaveFolder,
        [Parameter(Mandatory = $true)]
        [int]$saveIndex  # Added $saveIndex parameter
    )
    $save = [SaveGame]::new()
    $save.pathSaveGame = $SaveFolder
    try {
        # Load Game.json from SaveGame
        $gameFile = Join-Path $SaveFolder "Game.json"
        if (Test-Path $gameFile) {
            $gameData = Get-Content -Path $gameFile -Raw | ConvertFrom-Json
            $save.GameVersion = $gameData.GameVersion
            $save.OrganisationName = $gameData.OrganisationName
        }

        # Load Metadata.json from SaveGame
        $metadataFile = Join-Path $SaveFolder "Metadata.json"
        if (Test-Path $metadataFile) {
            $metaData = Get-Content -Path $metadataFile -Raw | ConvertFrom-Json
            $save.LastPlayedDate = $metaData.LastPlayedDate.Year, $metaData.LastPlayedDate.Month, $metaData.LastPlayedDate.Day, $metaData.LastPlayedDate.Hour, $metaData.LastPlayedDate.Minute, $metaData.LastPlayedDate.Second -join "-"
        }

        # Load Time.json from SaveGame
        $timeFile = Join-Path $SaveFolder "Time.json"
        if (Test-Path $timeFile) {
            $timeData = Get-Content -Path $timeFile -Raw | ConvertFrom-Json
            $save.ElapsedDays = $timeData.ElapsedDays
        }

        # Load Player_0\Inventory.json from SaveGame
        $player_0 = Join-Path -Path $SaveFolder -ChildPath 'Players\Player_0'
        $inventoryFile = Join-Path $player_0 "Inventory.json"
        if (Test-Path $inventoryFile) {
            $inventoryData = Get-Content -Path $inventoryFile -Raw | ConvertFrom-Json
            foreach ($item in $inventoryData.Items) {
                $itemObject = $item | ConvertFrom-Json
                if ($itemObject.DataType -eq "CashData") {
                    $save.CashBalance = "{0:N0}" -f ([int]$itemObject.CashBalance)
                    break # [ ]: Verify maximum CashData entry count
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
    # [ ]: Validate this data
    return $save
}

function Set-LocationSchedule1Saves {
    # [x]: Function tested - Set-LocationSchedule1Saves
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
    # [x]: Function tested - Show-SaveGames
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
        $SaveData | Format-Table saveIndex, GameVersion, OrganisationName, LastPlayedDate, ElapsedDays, CashBalance, OnlineBalance, pathSaveGame -AutoSize
    }
}



$localDirName = 'S1SS' # goes the snake
$localLowPath = "$env:USERPROFILE\AppData\LocalLow"
$s1ssPath = Join-Path -Path $localLowPath -ChildPath $localDirName
$directoryFound = Test-Path -Path $s1ssPath

# Prepare the target directory for S1SS operations
if (-not($directoryFound)) {
    New-Item -Path $s1ssPath -ItemType Directory -Force -ErrorAction Stop -Verbose
}
# Look for the presence of an existing vault of saves
$vaultPath = Join-Path -Path $s1ssPath -ChildPath 'Vault'
$localVaultFound = Test-Path $vaultPath -PathType Container
if (-not($localVaultFound)) {
    New-Item -path $vaultPath -ItemType Directory -Force -ErrorAction Stop -Verbose
}

class SaveGame {
    $saveIndex
    $GameVersion
    $OrganisationName
    $LastPlayedDate
    $ElapsedDays
    $CashBalance
    $OnlineBalance
    $pathSaveGame
}

$mnemonicLoop = $true
while ($true -eq $mnemonicLoop) {
    # Variables for working with savegames
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

    # Unexpected Saves in Schedule 1 folder - likely your manual backups
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
    $activeSavesPresent = $activeSaves.Count -gt 0
    $unexpectedSavesPresent = $unexpectedSaves.Count -gt 0
    $vaultedSavesPresent = $vaultedSaves.Count -gt 0

    ## Save Support : Main - This is the main execution logic of the script. Everything before this is foundation.

    Clear-Host # These labels are here to make sure you don't get lost.
    Write-Host ' ____  _ ____ ____'
    Write-Host '/ ___|/ / ___/ ___|'
    Write-Host '\___ \| \___ \___ \'
    Write-Host ' ___) | |___) |__) |'
    Write-Host '|____/|_|____/____/'
    Write-Host "Active saves in GameSave folder: $($activeSaves.Count)"
    if ($unexpectedSaves.Count -gt 0) {
        Write-Host "Unexpected saves in GameSave folder: $($unexpectedSaves.Count)"
    }
    if ($vaultedSaves.Count -gt 0) {
        Write-Host "Vaulted saves in S1SS folder: $($vaultedSaves.Count)"
    }
    Write-Host "`nMake a selection:"
    if ($activeSavesPresent) { Write-Host 'B) Backup - Game > Vault' }
    if ($unexpectedSavesPresent) { Write-Host 'C) Cleanup manual backups - permanent!' }
    Write-Host 'D) Delete a save - also permanent!'
    Write-Host "L) List all saves (Total saves: $totalSaves)"
    if ($vaultedSavesPresent) { Write-Host 'R) Restore - Vault > Game' }
    Write-Host 'Q) Quit'
    $userInput = Read-Host "Select a number or Q to exit"
    switch ($userInput.ToUpper()) {
        'B' {
            Clear-Host # This is all the code for selecting B for Backup
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
                Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
                $userInput = Read-Host "Please enter a value between 1 and $activeSavesCount"
                $isValidInput = ($null -ne $userInput -as [int] -and $userInput -ge 1 -and $userInput -le $activeSavesCount) -or ($userInput.ToUpper -eq 'C')
                if (-not $isValidInput) {
                    Write-Error "Invalid input. Please enter a valid saveIndex or 'C' to Cancel."
                }
            } until ($isValidInput)
            $selectedIndex = [int]$userInput - 1
            $newFolderName = New-Guid
            $newVaultPath = Join-Path -Path $vaultPath -ChildPath $newFolderName
            New-Item -ItemType Directory -Path $newVaultPath -Force -ErrorAction Stop -Verbose
            $sourcePath = Join-Path -Path $activeSaves[$selectedIndex].pathSaveGame -ChildPath "*"
            try {
                Copy-Item -Path $sourcePath -Destination $newVaultPath -Recurse -Force -ErrorAction Continue -Verbose -WhatIf
                Write-Host "Backup completed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Error $_.Exception.Message
                if ($_.Exception.InnerException) {
                    Write-Error "Inner Exception:"
                    Write-Error $_.Exception.InnerException.Message
                }
            }
            finally {
                Pause
            }
        }
        'C' {
            # This is all the code for selecting C for Cleanup
            Clear-Host
            Write-Host ' _____ _'
            Write-Host '/  __ \ |'
            Write-Host '| /  \/ | ___  __ _ _ __  _   _ _ __'
            Write-Host "| |   | |/ _ \/ _` | '_ \| | | | '_ \"
            Write-Host '| \__/\ |  __/ (_| | | | | |_| | |_) |'
            Write-Host ' \____/_|\___|\__,_|_| |_|\__,_| .__/'
            Write-Host '                               | |'
            Write-Host '                               |_|'
            Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
            do {
                Write-Host 'This will delete ALL shown saves.' -ForegroundColor Red
                $userInput = Read-Host 'Are you sure? y/n'
            } while ($userInput -notin 'y', 'Y', 'n', 'N')
            if ($userInput.ToUpper() -eq 'Y') {
                foreach ($item in $unexpectedSaves) {
                    Remove-Item -Path $item.pathSaveGame -Recurse -Force -ErrorAction Continue -Verbose
                }
                Pause
            }
        }
        'D' {
            Clear-Host # This is all the code for selecting D for Delete
            Write-Host '______     _      _'
            Write-Host '|  _  \   | |    | |'
            Write-Host '| | | |___| | ___| |_ ___'
            Write-Host '| | | / _ \ |/ _ \ __/ _ \'
            Write-Host '| |/ /  __/ |  __/ ||  __/'
            Write-Host '|___/ \___|_|\___|\__\___|'
            $userInput = 'x'
            Write-Host "Select an option of saves to delete from."
            $choices = @{}
            $optionNumber = 1

            # Active
            if ($activeSavesPresent) {
                Write-Host "$optionNumber. Active ($activeSavesCount)"
                $choices[$optionNumber] = "Active"
                $optionNumber++
            }
            else {
                Write-Host "Please read this in the voice of Cronk:"
                Write-Host "Hey! Buddy! You gotta play the game first!" -ForegroundColor Red
            }

            # Unexpected
            if ($unexpectedSavesPresent) {
                Write-Host "$optionNumber. Unexpected Saves ($unexpectedSavesCount)"
                $choices[$optionNumber] = "Unexpected"
                $optionNumber++
            }

            # Vaulted
            if ($vaultedSavesPresent) {
                Write-Host "$optionNumber. Vaulted ($vaultedSavesCount)"
                $choices[$optionNumber] = "Vaulted"
                $optionNumber++
            }

            # Answer me damnit!
            do {
                $selection = Read-Host "Enter the number corresponding to your choice:"
            } until ($choices.ContainsKey([int]$selection))

            # List saves and prompt for index to target
            $selectedSaveType = $choices[[int]$selection]
            # List "Active" saves
            if ($selectedSaveType -eq "Active") {
                Clear-Host
                Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
                # Get saveindex from user
                Write-Host "Available Save Indexes:" -NoNewline
                $validIndices = $activeSaves | ForEach-Object { $_.saveIndex } | Sort-Object
                Write-Host ($validIndices -join ", ")
                do {
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                } until ($validIndices.ContainsKey([int]$selection))
                $selectedSave = $activeSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                Remove-Item -Path $selectedSave.pathSaveGame -Recurse -Force -ErrorAction Continue -Verbose
            }
            # List "Unexpected" saves
            elseif ($selectedSaveType -eq "Unexpected") {
                Clear-Host
                Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
                $validIndices = $unexpectedSaves | ForEach-Object { $_.saveIndex } | Sort-Object
                Write-Host "Available Save Indexes:" -NoNewline
                Write-Host ($validIndices -join ", ")
                do {
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                } until ($validIndices.ContainsKey([int]$selection))
                $selectedSave = $unexpectedSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                Remove-Item -Path $selectedSave.pathSaveGame -Recurse -Force -ErrorAction Continue -Verbose
            }
            # List "Vaulted" saves
            elseif ($selectedSaveType -eq "Vaulted") {
                do {
                    Clear-Host
                    Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
                    $validIndices = $vaultedSaves | ForEach-Object { $_.saveIndex } | Sort-Object
                    $selection = Read-Host "Enter the saveIndex number corresponding to your choice:"
                } until ($validIndices.ContainsKey([int]$selection))
                $selectedSave = $vaultedSaves | Where-Object { $_.saveIndex -eq [int]$selection }
                Remove-Item -Path $selectedSave.pathSaveGame -Recurse -Force -ErrorAction Continue -Verbose
            }
            Pause
        }
        'I' {
            # This is all the code for selecting I for Inspect
            # TODO: Generate "Inspect" logo
            # ROADMAP: Write the Inspection feature
        }
        'R' {
            Clear-Host # This is all the code for selecting R for Restore
            Write-Host "______          _"
            Write-Host "| ___ \        | |"
            Write-Host "| |_/ /___  ___| |_ ___  _ __ ___"
            Write-Host "|    // _ \/ __| __/ _ \| '__/ _ \"
            Write-Host "| |\ \  __/\__ \ || (_) | | |  __/"
            Write-Host "\_| \_\___||___/\__\___/|_|  \___|"
            $vaultedSavesCount = $vaultedSaves.Count
            do {
                Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
                $userInput = Read-Host "Please enter a value between 1 and $vaultedSavesCount"
                $isValidInput = ($null -ne $userInput -as [int] -and $userInput -ge 1 -and $userInput -le $vaultedSavesCount) -or ($userInput.ToUpper -eq 'C')
                if (-not $isValidInput) {
                    Write-Error "Invalid input. Please enter a valid saveIndex or 'C' to Cancel."
                }
            } until ($isValidInput)
            $selectedIndex = [int]$userInput - 1
            $newFolderName = New-Guid
            $newVaultPath = Join-Path -Path $vaultPath -ChildPath $newFolderName
            New-Item -ItemType Directory -Path $newVaultPath -Force -ErrorAction Stop -Verbose
            $sourcePath = Join-Path -Path $vaultedSaves[$selectedIndex].pathSaveGame -ChildPath "*"
            try {
                Copy-Item -Path $sourcePath -Destination $newVaultPath -Recurse -Force -ErrorAction Continue -Verbose -WhatIf
                Write-Host "Backup completed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Error $_.Exception.Message
                if ($_.Exception.InnerException) {
                    Write-Error "Inner Exception:"
                    Write-Error $_.Exception.InnerException.Message
                }
            }
            finally {
                Pause
            }
            Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
            Pause
        }
        'S' {
            Clear-Host # This is all the code for selecting S for Saves
            Write-Host ' _____'
            Write-Host '/  ___|'
            Write-Host '\ `--.  __ ___   _____  ___'
            Write-Host ' `--. \/ _` \ \ / / _ \/ __|'
            Write-Host '/\__/ / (_| |\ V /  __/\__ \'
            Write-Host '\____/ \__,_| \_/ \___||___/'
            Show-SaveGames -TitleSingular 'Active Save' -TitlePlural 'Active Saves' -SaveData $activeSaves
            Show-SaveGames -TitleSingular 'Unexpected Save' -TitlePlural 'Unexpected Saves' -SaveData $unexpectedSaves
            Show-SaveGames -TitleSingular 'Vaulted Save' -TitlePlural 'Vaulted Saves' -SaveData $vaultedSaves
            Pause
        }
        'Q' { Clear-Host ; $mnemonicLoop = $false }
        Default { $mnemonicLoop = $false }
    }
    # End of Mnemonic Loop
}
Get-TimeWasted -timeStarted $timeStarted