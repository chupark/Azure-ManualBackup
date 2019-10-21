function selectByPartitionKey() {
    param (
        [PSCustomObject]$storageConfig,
        [String]$table,
        [String]$partitionKey
    )
    $result = @()
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $saContext = $sa.Context
    $tbl = (Get-AzStorageTable -Name $table -Context $saContext).CloudTable
    [string]$filter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey", `
                       [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, $partitionKey)
    $result = Get-AzTableRow -Table $tbl -CustomFilter $filter
    return ,$result
}

function selectByTableName() {
    param (
        [PSCustomObject]$storageConfig,
        [String]$table,
        [String]$partitionKey
    )
    $result = @()
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $saContext = $sa.Context
    $tbl = (Get-AzStorageTable -Name $table -Context $saContext).CloudTable
    $result = Get-AzTableRow -Table $tbl
    return ,$result
}

function deleteByPartitionKey() {
    param (
        [PSCustomObject]$storageConfig,
        [String]$table,
        [String]$partitionKey
    )
    $result = @()
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $saContext = $sa.Context
    $tbl = (Get-AzStorageTable -Name $table -Context $saContext).CloudTable
    [string]$filter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey", `
                       [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, $partitionKey)
    $result = Get-AzTableRow -Table $tbl -CustomFilter $filter | Remove-AzTableRow -Table $tbl
    return ,$result
}

function deleteByTableName() {
    param (
        [PSCustomObject]$storageConfig,
        [String]$table
    )
    $result = @()
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $saContext = $sa.Context
    $tbl = (Get-AzStorageTable -Name $table -Context $saContext).CloudTable
    $result = Get-AzTableRow -Table $tbl | Remove-AzTableRow -Table $tbl
    return ,$result
}