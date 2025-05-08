function Set-LocationSchedule1Saves {
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
    # Set the current location to the save directory.
    Set-Location -Path $saveLocation
}