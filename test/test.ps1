Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\tools.psm1
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\snapshotlib.psm1

$snapshotListsCSVs = Import-Csv -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\diskLists.csv"

$sa = Get-AzStorageAccount -ResourceGroupName ManualBackup -StorageAccountName pcwmanualbackup
$backupLists = Get-AzStorageTable -Name backupLists -Context $sa.Context
$cloudTable = (Get-AzStorageTable –Name $backupLists.Name –Context $sa.Context).CloudTable

<# Azure Table Storage에 데이터 입력
foreach ($snapshotListsCSV in $snapshotListsCSVs) {
    $rowKey = $snapshotListsCSV.vmName 
    $diskName = $snapshotListsCSV.Disk
    $resourceGroup = $snapshotListsCSV.resourceGroup
    Add-AzTableRow `
    -table $cloudTable `
    -partitionKey $resourceGroup `
    -rowKey ("$rowKey") -property @{"diskName"="$diskName";}
}
Get-AzTableRow -Table $cloudTable
[string]$filter2 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey", `
                        [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, "D-CH-RG")

$filterToDelete = Get-AzTableRow -Table $cloudTable -CustomFilter $filter2
$filterToDelete | Remove-AzTableRow -Table $cloudTable                        
#>
do {
    
} while ($true)