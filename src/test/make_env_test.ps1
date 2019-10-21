Start-Transcript -path "D:\logs\a.log" -Append -IncludeInvocationHeader 

## Import Custom Module
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\tools.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\snapshotlib.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\storagequery.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\encryption.psm1 -Force

## Imporv backup vm list
$snapshotListsCSVs = Import-Csv -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\diskLists.csv"

## Import script config
$programEnv = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\env.json" -Force | ConvertFrom-Json
$storageConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\storageInfo.json" -Force | ConvertFrom-Json
$keyVaultConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\keyvaultinfo.json" -Force | ConvertFrom-Json
$sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
$saContext = $sa.Context

# New-AzStorageContainer -Name $programEnv.backupBlobName -Context $sa.Context -Permission Off

## Creating Azure Storage Table Services
Write-Output "Creating Table"
New-AzStorageTable -Name $programEnv.vmListsForBackup -Context $sa.Context
New-AzStorageTable -Name $programEnv.completedBackupList -Context $sa.Context


## Get Table Storage Information
Write-Output "Writing VM lists for making snapshots"
$a = $programEnv.vmListsForBackup
$backupLists = (Get-AzStorageTable -Name $a -Context $saContext).CloudTable


## Writing Backup vm list to Table Services
Write-Output "Sends data to Azure Storage Table"
foreach ($snapshotListsCSV in $snapshotListsCSVs) {
    $vmName = $snapshotListsCSV.vmName 
    $rowKey = $snapshotListsCSV.Disk
    $resourceGroup = $snapshotListsCSV.resourceGroup
    Add-AzTableRow `
    -table $backupLists `
    -partitionKey $resourceGroup `
    -rowKey ("$rowKey") -property @{"vmName"="$vmName";}
}
selectByTableName -storageConfig $storageConfig -table $backupLists.Name

## Creating storage Account Key
# 단순히 SAS URL을 암호화 하기 위함.. key가 변경된다 해도 백업 및 이후 프로세스는 문제가 없음
# 다만 key 변경시, Table을 업데이트 해야 함
creationEncKey -keyVaultConfig $keyVaultConfig
$secret = getEncKey -keyVaultConfig $keyVaultConfig

$tmpcred = Get-Content -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\logincred.json" | ConvertFrom-Json
$encId = makeEncryptedString -secret $secret -inputString $tmpcred.clientId
$encPW = makeEncryptedString -secret $secret -inputString $tmpcred.password
$encTN = makeEncryptedString -secret $secret -inputString $tmpcred.tenant

$programEnv.loginCred.clientId = $encId
$programEnv.loginCred.password = $encPW
$programEnv.loginCred.tenant = $encTN

$configTable = (Get-AzStorageTable -Name "test" -Context $saContext).CloudTable
Add-AzTableRow -Table $configTable `
               -PartitionKey "config" `
               -RowKey "config" `
               -propertyName "env" `
               -jsonString ($programEnv | ConvertTo-Json)


selectByTableName -table "test" -storageConfig $storageConfig
selectByPartitionKey -table "test" -storageConfig $storageConfig -partitionKey "config"
deleteByTableName -table "test" -storageConfig $storageConfig


$entity = New-Object -TypeName "Microsoft.Azure.Cosmos.Table.DynamicTableEntity" -ArgumentList $PartitionKey, $RowKey
foreach ($hash in $hashtable.Keys) {
    #Write-Host $hash
    #Write-Host $hashtable.Item($hash)
    $hashtable.Item($hash)
    $entity.Properties.Add($hash, $programEnv2)
}



<## Meta
function createMeta() {
    날짜.. 등등
}
##>

## output 
$aaaa = Get-AzTableRow -Table $backupLists
Write-Output $aaaa

Stop-Transcript

<# Azure Table Storage 테스트
[string]$filter2 = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey", `
                        [Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal, "D-CH-RG")
$filterToDelete = Get-AzTableRow -Table $cloudTable -CustomFilter $filter2
$filterToDelete | Remove-AzTableRow -Table $backupLists                   

do {
    
} while ($true)

keyvault 키 암호화 풀기
$asdfyKey = Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name ($storageConfig.saName + "-" + $saKey.KeyName)
$asdfyKey.SecretValueText
$decryptedTest = ConvertTo-SecureString $asdfyKey.SecretValueText -Key $secret
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($decryptedTest)
[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
#>