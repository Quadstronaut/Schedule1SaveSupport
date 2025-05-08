$saveFolder = "Path/To/Save"
$saveData = @{}

Get-ChildItem -Path $saveFolder -Filter "*.json" | ForEach-Object {
    $fileNameWithoutExtension = $_.BaseName
    Write-Host "--- Processing File: $($_.Name) and storing in variable: $($fileNameWithoutExtension) ---"
    $content = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    $saveData[$fileNameWithoutExtension] = $content
}

# Now the content of each JSON file is stored in the $saveData hashtable
# You can access them like this:

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