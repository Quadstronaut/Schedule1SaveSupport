function get-SaveGame {
    $saveFolder = 'C:\Users\Quadstronaut\AppData\LocalLow\TVGS\Schedule I\Saves\76561198005737452\SaveGame_1'
    $player_0 = Join-Path -Path $saveFolder -ChildPath 'Players\Player_0'
    $saveData = @{}
    $playerData = @{}

    # Save data
    Get-ChildItem -Path $saveFolder -Filter "*.json" | ForEach-Object {
        $fileNameWithoutExtension = $_.BaseName
        Write-Host "--- Processing File: $($_.Name) and storing in variable: $($fileNameWithoutExtension) ---"
        $content = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
        $saveData[$fileNameWithoutExtension] = $content
    }

    # Player data
    Get-ChildItem -Path $player_0 -Filter "*.json" | ForEach-Object {
        $fileNameWithoutExtension = $_.BaseName
        Write-Host "--- Processing File: $($_.Name) and storing in variable: $($fileNameWithoutExtension) ---"
        $content = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
        $playerData[$fileNameWithoutExtension] = $content

        # Specifically process the Inventory.json to extract CashBalance
        if ($fileNameWithoutExtension -eq "Inventory") {
            foreach ($itemString in $content.Items) {
                $itemObject = $itemString | ConvertFrom-Json
                if ($itemObject.DataType -eq "CashData") {
                    $playerData['CashBalance'] = $itemObject.CashBalance
                }
            }
        }
    }

    $playerData.CashBalance

    # To see the content of Game.json
    $saveData.Game

    # To access the OrganisationName from Game.json
    $saveData.Game.OrganisationName

    # To see the content of Products.json
    $saveData.Products

    # To access the DiscoveredProducts array from Products.json
    $saveData.Products.DiscoveredProducts

    # To access the first discovered product
    $saveData.Products.DiscoveredProducts[0]

    # To see the content of the first GenericSaveable object
    $saveData.GenericSaveables.Saveables[0]

    # To access the GUID of the first GenericSaveable object
    $saveData.GenericSaveables.Saveables[0].GUID
}