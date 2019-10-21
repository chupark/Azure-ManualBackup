<#
.SYNOPSIS
VM 이름과 Disk 이름을 생성하는 테이블을 만듬

.DESCRIPTION
Long description

.PARAMETER vms
[PSCustomObject] Get-AzVM 이 들어옴

.EXAMPLE
vmNameMatchedWithDisk -$vms (Get-AzVM)

.NOTES
General notes
#>

function vmNameMatchedWithDisk() {
    param (
        [PSCustomObject]$vms
    )
    Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\tools.psm1 -Force
    $col = @("vmName", "Disk")
    $table = MakeTable -TableName "vm-disk" -ColumnArray $col
    foreach ($vm in $vms ){
        $row = $table.NewRow()
        $row.vmName = $vm.Name
        $row.Disk = $vm.StorageProfile.OsDisk.Name
        $table.Rows.Add($row)
        if ($vm.StorageProfile.DataDisks) {
            foreach ($dataDisk in $vm.StorageProfile.DataDisks) {
                $row = $table.NewRow()
                $row.vmName = $vm.Name
                $row.Disk = $dataDisk.Name
                $table.Rows.Add($row)
            }
        }
    }

    return ,$table
}

<#
.SYNOPSIS
Storage Account Table Storage로부터 백업할 Disk 정보를 받아옴

.DESCRIPTION
Long description

.PARAMETER storageConfig
storageConfig.json 정보를 읽음

.PARAMETER programEnv
env.json 정보를 읽음

.EXAMPLE
getBackupItems -storageConfig $storageConfig -programEnv $env
$backupDiskLists output은 createDiskSnapshot.ps1 에서 사용할 변수

.NOTES
General notes
#>
function getBackupItems() {
    param (
        [Object]$storageConfig,
        [Object]$programEnv
    )
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $getStorageTable = (Get-AzStorageTable -Name $programEnv.vmListsForBackup -Context $sa.Context).CloudTable
    $backupDiskLists = Get-AzTableRow -Table $getStorageTable
    
    return ,$backupDiskLists
}

<#
function createDiskSnapshot() {
    param (
        [Object]$backupDiskLists,
        [String]$today
    )
    [Array]$backedupDiskLists = @()
    foreach ($backupDiskList in $backupDiskLists) {
        $diskSnapShotName = "BS-" + $backupDiskList.RowKey + "-D-" + $today
        try {
            $sourceDisk = Get-AzDisk -ResourceGroupName $backupDiskList.PartitionKey -DiskName $backupDiskList.RowKey -ErrorAction SilentlyContinue
            if($sourceDisk) {
                $diskSnapshotConfig = New-AzSnapshotConfig -SourceUri $sourceDisk.Id -Location $sourceDisk.Location -CreateOption copy        
                $diskSnapshot = New-AzSnapshot -SnapshotName $diskSnapShotName -Snapshot $diskSnapshotConfig -ResourceGroupName $sourceDisk.ResourceGroupName
            } else {
                
            }
        } catch {
            Write-Output $_.Exception
        } finally {

        }
        $backedupDiskLists += $diskSnapShotName
    }

    return ,$backedupDiskLists
}
#>


<#
.SYNOPSIS


.DESCRIPTION
Long description

.PARAMETER backedupDiskLists
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function getMadenSnapshot() {
    param (
        [PSCustomObject]$backedupDiskLists
    )
    [Object]$madenSnapshotList = @()

    try {
        $snapshots = Get-AzSnapshot
        foreach ($backupDiskList in $backedupDiskLists) {
            $madenSnapshotList += $snapshots | Where-Object {$_.Name -eq $backupDiskList.diskName}
        }
    } catch {
        Write-Output $_.Exception
    } finally {
    
    }
    return $madenSnapshotList
}


function snapshotSendToBlob() {
    param(
        [PSCustomObject]$encryptedSASs,
        [PSCustomObject]$storageConfig,
        [PSCustomObject]$vmNameMatchedWithDisk,
        [PSCustomObject]$secretKey
    )
    $sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    $saContext = $sa.Context
    New-AzStorageTable -Name "savedLists" -Context $sa.Context
    $savedLists = (Get-AzStorageTable -Name "savedLists" -Context $saContext).CloudTable

    foreach ($encryptedSAS in $encryptedSASs) {
        $Matches = $null
        $bb = ConvertTo-SecureString $encryptedSAS.encryptedSAS -Key $secretKey
        $SASBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($bb)
        $sasURI = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($SASBSTR)

        $storageAccountName = $storageConfig.destination.saName
        $encryptedSAkey = ConvertTo-SecureString $storageConfig.destination.auth.key1 -Key $secretKey
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptedSAkey)
        $storageAccountKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $destinationVHDFileName = $encryptedSAS.RowKey + ".vhd"
        $destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
        
        $tmpMatching = $encryptedSAS.RowKey -match "BS-(?<diskName>.+)-D-[0-9`-]{0,50}"
        $vmName = ($vmNameMatchedWithDisk | Where-Object {$_.Disk -eq $Matches.diskName}).vmName

        $containerName = $storageConfig.destination.backup.container
        $snapshotName = $encryptedSAS.RowKey
        $resourceGroup = $encryptedSAS.resourceGroup
        $destinationBlobUrl = $destinationContext.BlobEndPoint + $containerName
        $resourceType = encryptedSASs.resourceType
        Add-AzTableRow `
        -table $savedLists `
        -partitionKey "$vmName" `
        -rowKey ("$snapshotName") `
        -property @{"vhdFile"="$destinationVHDFileName"; "resourceGroup"="$resourceGroup"; "storageAccount"="$storageAccountName"; "container"="$containerName"; "backupBlobUrl"="$destinationBlobUrl"; "resourceType"="$resourceType";}

        Start-AzStorageBlobCopy -AbsoluteUri $sasURI `
                                -DestContainer $containerName `
                                -DestContext $destinationContext `
                                -DestBlob $destinationVHDFileName
    }
}

function checkTransationStatus() {
    param (
        [PSCustomObject]$storageConfig
    )
    $storageAccountName = $storageConfig.destination.saName
    $encryptedSAkey = ConvertTo-SecureString $storageConfig.destination.auth.key1 -Key $secretKey
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptedSAkey)
    $storageAccountKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    do {
        $processing = Get-AzStorageBlob -Context $destinationContext -Container $storageConfig.destination.backup.container | Get-AzStorageBlobCopyState -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Start-Sleep -Seconds 1
        $pending = $processing | Where-Object {$_.Status -eq "pending"}
        Write-Host Remain jobs.... $pending.count -ForegroundColor Green
    } while ($pending)

    return $pending
}

function createSnapshotLock() {
    param (
        [PSCustomObject]$programEnv,
        [PSCustomObject]$encryptedSASs
    )
    foreach ($resource in $encryptedSASs) {
        New-AzResourceLock -LockLevel CanNotDelete `
                           -LockName $programEnv.lock.name `
                           -ResourceName $resource.RowKey `
                           -ResourceType $resource.resourceType `
                           -ResourceGroupName $resource.resourceGroup `
                           -LockNotes $programEnv.lock.note `
                           -Force
    }
}

function removeSnapshotLock() {
    param (
        [PSCustomObject]$programEnv,
        [PSCustomObject]$encryptedSASs
    )
    foreach ($resource in $encryptedSASs) {
        Remove-AzResourceLock -LockName $programEnv.lock.name `
                              -ResourceName $resource.RowKey `
                              -ResourceType $resource.resourceType `
                              -ResourceGroupName $resource.resourceGroup `
                              -Force
    }
}

<#
$snapshotResourceGroupName = <스냅샷 리소스 그룹>
$snapShotName = <스냅샷 이름>
$sasExpiryDuration = <스냅샷 SAS URL 만료 시간 (초)>

$storageAccountName = <저장소 계정 이름>
$storageAccountKey = <저장소 계정 Key>
$destinationVHDFileName = <저장소 계정에 저장될 파일 이름> + ".vhd"
$storageContainerName = <저장소 계정 컨테이너 이름>
        
$sas = Grant-AzSnapshotAccess -ResourceGroupName $snapshotResourceGroupName `
                              -SnapshotName $snapShotName `
                              -DurationInSecond $sasExpiryDuration `
                              -Access Read

$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName `
                                           -StorageAccountKey $storageAccountKey

Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS `
                        -DestContainer $storageContainerName `
                        -DestContext $destinationContext `
                        -DestBlob $destinationVHDFileName    

#>