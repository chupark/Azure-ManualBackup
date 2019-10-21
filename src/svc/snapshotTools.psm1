function getSnapshotTools () {
    return [snapshotTools]::new()
}

class snapshotTools {
    [PSCustomObject]$storageConfig
    [PSCustomObject]$destinationStorageConfig
    [PSCustomObject]$storageInfo
    [PSCustomObject]$result
    [PSCustomObject]$table
    [Array]$madenSnapshotList
    [Object]$destinationBlobContext
    [Object]$key


    createSnapshotLock([PSCustomObject]$programEnv) {
        foreach ($madenSs in $this.madenSnapshotList) {
            New-AzResourcELock -LockName ($programEnv.lock.name) `
                               -LockNotes ($programEnv.lock.note) `
                               -LockLevel CanNotDelete `
                               -ResourceType $madenSs.Type `
                               -ResourceGroupName $madenSs.ResourceGroupName `
                               -ResourceName $madenSs.Name -Force
        }
    }

    snapshotSendToBlob([PSCustomObject]$encryptedSASs) {
        foreach($encryptedSAS in $encryptedSASs) {
            $secureSAS = ConvertTo-SecureString ($encryptedSAS.encryptedSAS) -Key $this.key
            $SASBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSAS)
            $sasURI = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($SASBSTR)
            $vmName = $encryptedSAS.vmName
            $snapshotName = $encryptedSAS.RowKey
            $destinationVHDFileName = $encryptedSAS.RowKey + ".vhd"
            $resourceGroup = $encryptedSAS.resourceGroup
            $storageAccountName = $this.storageConfig.destination.saName
            $containerName = $this.storageConfig.destination.container
            $destinationBlobUrl = $sasURI
            $resourceType = $encryptedSAS.resourceType
    
            try {
                
                Start-AzStorageBlobCopy -AbsoluteUri $destinationBlobUrl `
                                        -DestContainer $containerName `
                                        -DestContext $this.destinationBlobContext `
                                        -DestBlob $destinationVHDFileName

                Add-AzTableRow `
                    -table $this.table `
                    -partitionKey "$vmName" `
                    -rowKey ("$snapshotName") `
                    -property @{"vhdFile"="$destinationVHDFileName"; "resourceGroup"="$resourceGroup"; "storageAccount"="$storageAccountName"; "container"="$containerName"; "resourceType"="$resourceType";}

            } catch {
                Write-Output $_.Exception
            } finally {

            }
            
        }
    }

    removeSnapshotLock([PSCustomObject]$programEnv) {
        foreach ($madenSs in $this.madenSnapshotList) {
            Remove-AzResourceLock -LockName ($programEnv.lock.name) `
                               -ResourceType $madenSs.Type `
                               -ResourceGroupName $madenSs.ResourceGroupName `
                               -ResourceName $madenSs.Name -Force
        }
    }

    removeOldSnapshotBlob([PSCustomObject]$oldDatas) {
        foreach ($oldData in $oldDatas) {
            Get-AzStorageBlob -Container $oldData.container -Blob $oldData.vhdFile -Context $this.destinationBlobContext | Remove-AzStorageBlob
        }
    }



    [int]getBlobCopyState() {
        $processing = Get-AzStorageBlob -Context $this.destinationBlobContext -Container $this.storageConfig.destination.container | Get-AzStorageBlobCopyState -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $pending = $processing | Where-Object {$_.Status -eq "pending"}
        return $pending.count
    }

    setDestinationContext() {
        $destinationSAKey = (Get-AzStorageAccountKey -ResourceGroupName $this.storageConfig.destination.saResourceGroup -Name $this.storageConfig.destination.saName)[0].Value
        $this.destinationBlobContext = New-AzStorageContext -StorageAccountName $this.storageConfig.destination.saName -StorageAccountKey $destinationSAKey
    }


    setStorageConfig([PSCustomObject]$storageConfig) {
        $this.storageConfig = $storageConfig
        $this.storageInfo = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    }

    setKey([PSCustomObject]$key) {
        $this.key = $key
    }

    setTable([String]$table) {
        $saContext = $this.storageInfo.Context
        $this.table = (Get-AzStorageTable -Name $table -Context $saContext).CloudTable

    }
    
    setMadenSnapshot() {
        $this.madenSnapshotList = $null
        $backupedDiskList = @()
        try {
            $snapshots = Get-AzSnapshot
            foreach ($backupedDiskList in $this.result) {
                $this.madenSnapshotList += $snapshots | Where-Object {$_.Name -eq $backupedDiskList.RowKey}
            }
        } catch {
            Write-Output $_.Exception
        } finally {
        
        }
    }

    [PSCustomObject]selectByTableName() {
        $this.result = $null
        $this.result = Get-AzTableRow -Table $this.table
        return $this.result
    }

    [PSCustomObject]selectByDateBefore($dateBefore) {
        $this.result = $null
        $filter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterConditionForDate("Timestamp", [Microsoft.Azure.Cosmos.Table.QueryComparisons]::LessThan, $dateBefore)
        $this.result = Get-AzTableRow -Table $this.table -CustomFilter $filter
        return $this.result
    }

    deleteByTableName() {
        $this.result = $null
        Get-AzTableRow -Table $this.table | Remove-AzTableRow -Table $this.table
    }

    ## Delete 
    deleteByDateBefore([PSCustomObject]$dateBefore) {
        $this.result = $null
        $filter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterConditionForDate("Timestamp", [Microsoft.Azure.Cosmos.Table.QueryComparisons]::LessThan, $dateBefore)
        $this.result = Get-AzTableRow -Table $this.table -CustomFilter $filter | Remove-AzTableRow -Table $this.table
    }

}