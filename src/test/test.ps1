Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\tools.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\snapshotlib.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\storagequery.psm1 -Force

# <!-- Load All Configs
$programEnv = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\env.json" -Force | ConvertFrom-Json
$storageConfig = $programEnv.storageConfig
$keyVaultConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\keyvaultinfo.json" -Force | ConvertFrom-Json
$today=Get-Date -Format "yyyy-MM-dd--HH-mm"
$vms = Get-AzVM
$secretKey = (Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name).SecretValueText.Split(",")
# -->

$backupDiskLists = getBackupItems -storageConfig $storageConfig -programEnv $programEnv

# <!-- create DiskSnapShot & load lists
foreach ($backupDiskList in $backupDiskLists) {
    Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\createDiskSnapshot.ps1 `
              -ArgumentList $backupDiskList, $today, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job
$backedupDiskLists = selectByPartitionKey -storageConfig $storageConfig -table "disktmp" -partitionKey "diskName"
$madenSnapshotList = getMadenSnapshot -backedupDiskLists $backedupDiskLists
# -->


# <!-- generate Snapshot SAS uri & load lists
foreach ($madenSnapshot in $madenSnapshotList) {
    Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\generateSnapshotSAS.ps1 `
              -ArgumentList $madenSnapshot, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job
$encryptedSASs = selectByPartitionKey -storageConfig $storageConfig -table "sas" -partitionKey "encryptedSAS"
# -->

# <!-- Send To Blob
$vmNameMatchedWithDisk = vmNameMatchedWithDisk -vms $vms
snapshotSendToBlob -encryptedSASs $encryptedSASs -storageConfig $storageConfig -vmNameMatchedWithDisk $vmNameMatchedWithDisk -secretKey $secretKey
# -->

# Check Transation
$pending = checkTransationStatus -storageConfig $storageConfig

# <!-- Revoke SAS url
if(!$pending) {
    foreach ($encryptedSAS in $encryptedSASs) {
        Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\revokeSnapshotSAS.ps1 -ArgumentList $encryptedSAS
    }
}
deleteByPartitionKey -storageConfig $storageConfig -table "disktmp" -partitionKey "diskName"
deleteByPartitionKey -storageConfig $storageConfig -table "sas" -partitionKey "encryptedSAS"
# ->


New-AzResourcELock
## Load Data
$savedLists = selectByTableName -storageConfig $storageConfig -table "savedLists"
deleteByTableName -storageConfig $storageConfig -table "savedLists"
$savedLists | Where-Object {$_.TableTimestamp -le (Get-Date)}
##########################################################################################################################################


### Secure String Test ##########################################################################################################
# $aa = ConvertTo-SecureString $storageConfig.auth.key1 -AsPlainText -Force | ConvertFrom-SecureString -key (1..32)
# $bb = ConvertTo-SecureString $aa -Key (1..32)
# $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($bb)
# $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
#################################################################################################################################

## 
### Test
##$zz = $aa -match  "(?<year>.+)-(?<month>.+)-(?<day>.+)--(?<hour>.+)-(?<minute>.+)"
##Get-Date -Year $Matches.year -Month $Matches.month -Day $Matches.day -Hour $Matches.hour -Minute $Matches.minute -Second 0

#################################################################################################################################
<#
deleteByPartitionKey -storageConfig $storageConfig -table "disktmp" -partitionKey "diskName"
deleteByPartitionKey -storageConfig $storageConfig -table "sas" -partitionKey "encryptedSAS"
deleteByPartitionKey -storageConfig $storageConfig -table "savedLists"
deleteByTableName -storageConfig $storageConfig -table "backupLists"
#>
<#
$savedLists
$vmNameMatchedWithDisk = vmNameMatchedWithDisk -vms $vms
$tmpMatching = ($encryptedSAS.RowKey -match "BS-(?<diskName>.+)-D-[0-9`-]{0,50}").vmName
$Matches.diskName

$vmNameMatchedWithDisk | Where-Object {$_.Disk -eq $Matches.diskName}

$vms = Get-AzVM
$madenSnapshotList

Get-AzSnapshot | Remove-AzSnapshot
#>
$bb = "1q2w3e4"
$enc = [system.Text.Encoding]::UTF8
$enc.getBytes($bb)
$aa = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35)
$storageConfig.enc.powershellKey
$aa.GetType()

$bb | ConvertFrom-SecureString -Key $aa
$tmpMatching = $encryptedSAS.RowKey -match "BS-(?<diskName>.+)-D-[0-9`-]{0,50}"
$vmName = ($vmNameMatchedWithDisk | Where-Object {$_.Disk -eq $Matches.diskName})


<# key Vault Test#>
$CreateKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($CreateKey)
$secretValue = ConvertTo-SecureString ($CreateKey -join (",")) -AsPlainText -Force
Get-AzKeyVault -ResourceGroupName RG-KeyStore -VaultName pcw-keystore
$KeyFileName = "manualBackupKey"
Set-AzKeyVaultSecret -VaultName $encry -Name $KeyFileName -SecretValue $secretValue
$secret = Get-AzKeyVaultSecret -VaultName pcw-keystore -Name $KeyFileName
$secretKey = $secret.SecretValueText.Split(",")

$saKey = ConvertTo-SecureString "a2+eBel+7CzmS/vS8zSYPcSalvHQskkyXisfpMVGsqtVtUYMxk5YUHnso5GduyIUrjlamRNg0nV1dVq7z/GN5w==" -AsPlainText -Force
$securedPasswd = $saKey | ConvertFrom-SecureString -Key $secretKey

<# decryption #>
$decryptedTest = ConvertTo-SecureString $securedPasswd -Key $secretKey
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($decryptedTest)
[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$CreateKey | out-file "$KeyStoragePath\$KeyFileName"
$bb | ConvertFrom-SecureString -Key $CreateKey

$GetKey = Get-Content "$KeyStoragePath\$KeyFileName"
$CredentialsStoragePath = "C:\Users\cwpark\Desktop\cw"
$CredentialsFileName = "Username@YourDomainDotCom.securestring"
$PasswordSecureString = Read-Host -AsSecureString
$PasswordSecureString | ConvertFrom-SecureString -key $GetKey | Out-File -FilePath "$CredentialsStoragePath\$CredentialsFileName"

$disks = Import-Csv -Path "C:\Users\cwpark\backup-vm-list-carrot.csv"
$disk.vmName
$asdfDate = Get-Date
$dddd = [String]$asdfDate.Year + "-" + [String]$asdfDate.Month + "-" + [String]$asdfDate.Day
foreach ($disk in $disks) {
    $sourceDisk = Get-AzDisk -ResourceGroupName $disk.diskResourceGroup -DiskName $disk.diskName
    if ($sourceDisk) {
        $diskSnapShotName = "BackupSnapshot-" + $disk.vmName + "-" + $disk.diskName + "-" + $dddd
        $diskSnapshotConfig = New-AzSnapshotConfig -SourceUri $sourceDisk.Id -Location $sourceDisk.Location -CreateOption copy        
        $diskSnapshot = New-AzSnapshot -SnapshotName $diskSnapShotName -Snapshot $diskSnapshotConfig -ResourceGroupName $sourceDisk.ResourceGroupName
    }
}

$sourceDisk = Get-AzDisk -ResourceGroupName $backupDiskList.PartitionKey -DiskName $backupDiskList.RowKey -ErrorAction SilentlyContinue
$diskSnapshotConfig = New-AzSnapshotConfig -SourceUri $sourceDisk.Id -Location $sourceDisk.Location -CreateOption copy
$diskSnapshot = New-AzSnapshot -SnapshotName $diskSnapShotName -Snapshot $diskSnapshotConfig -ResourceGroupName $sourceDisk.ResourceGroupName