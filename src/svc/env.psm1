function getEnvConfig() {
    return [envConfig]::new()
}
function getTableStorageConfig() {
    return [tableStorage]::new()
}
function getEncryptionConfig() {
    return [encryption]::new()
}

Class envConfig {
    [PSCustomObject]$data
    [PSCustomObject]$genereatedKey
    [PSCustomObject]$keyVaultConfig
    [PSCustomObject]$storedKey

    generateEncKey() {
        $CreateKey = New-Object Byte[] 64
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($CreateKey)
        $this.genereatedKey = $CreateKey
    }

    setKeyVaultConfig([PSCustomObject]$keyVaultConfig) {
        $this.keyVaultConfig = $keyVaultConfig
    }

    [void]sendKeyToVault([PSCustomObject]$secretValue) {
        $secret = ConvertTo-SecureString ($secretValue -join (",")) -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $this.keyVaultConfig.name -Name $this.keyVaultConfig.secret.name -SecretValue $secret
    }

    [PSCustomObject]getStoredKey() {
        $this.storedKey = Get-AzKeyVaultSecret -VaultName $this.keyVaultConfig.name -Name $this.keyVaultConfig.secret.name
        return ,$this.storedKey
    }
}
# $envConfig = [envConfig]::new()
# $envConfig.generateEncKey()
# $envConfig.setkeyVaultConfig($keyVaultConfig)
# $envConfig.sendKeyToVault($envConfig.genereatedKey)
# $storedKey = $envConfig.getStoredKey()

class tableStorage {
    [PSCustomObject]$storageConfig
    [PSCustomObject]$storageInfo
    [PSCustomObject]$diskListForBackup
    [PSCustomObject]$cloudTable

    setStorageConfig([PSCustomObject]$storageConfig) {
        $this.storageConfig = $storageConfig
        $this.storageInfo = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
    }

    setStorageConfigTyping([String]$resourceGroup, [String]$storageName) {
        $this.storageInfo = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageName
    }

    loadDiskListForBackup([PSCustomObject]$diskListForBackup) {
        $this.diskListForBackup = $diskListForBackup
    }

    [PSCustomObject]getCloudTable([String]$tableName) {
        $this.cloudTable = (Get-AzStorageTable -Name $tableName -Context $this.storageInfo.context).CloudTable
        return ,$this.cloudTable
    }
}
# $tableStorageConfig = [tableStorage]::new()
# $tableStorageConfig.setStorageConfig($storageConfig)
# $tableStorageConfig.loadDiskListForBackup($snapshotListsCSVs)




class encryption {
    [String]$encryptedKeyString
    [PSCustomObject]$secretKey

    setSecretKey([PSCustomObject]$secretKey) {
        $this.secretKey = $secretKey
    }

    [String]getEncryptedKeyString([PSCustomObject]$inputString) {
        $encryptedString = (ConvertTo-SecureString $inputString -AsPlainText -Force | ConvertFrom-SecureString -key $this.secretKey)
        return $encryptedString
    }

    [String]getDecryptedString([String]$inputStr) {
        $decrypted = ConvertTo-SecureString $inputStr -Key $this.secretKey
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($decrypted)
        $decryptedString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        return $decryptedString
    }
}