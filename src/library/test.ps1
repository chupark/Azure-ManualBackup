function ha() {
    Write-Host ha
}

function hahaha() {
    Write-Host hahaha
}


$sass = Grant-AzSnapshotAccess -ResourceGroupName "PCW-Grafana" `
-SnapshotName "OS-Snapshot-Grafana" `
-DurationInSecond 7200 `
-Access Read
$sass.AccessSAS
$sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
$destinationContext = New-AzStorageContext -StorageAccountName "chiwoo" -StorageAccountKey "ixe2qJRQoe0NStfl4XMFE5lsxLIVjfP/aOSiXAFVqUHQBBsjvpDFBkpTjJXDqer1Gju8yPx+mpZYFsUSsCx42w=="

Get-AzStorageBlob -Context $destinationContext -Container "grafana" | Get-AzStorageBlobCopyState -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
do {
    $processing = Get-AzStorageBlob -Context $destinationContext -Container "grafana" | Get-AzStorageBlobCopyState -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Start-Sleep -Seconds 1
    $pending = $processing | Where-Object {$_.Status -eq "pending"}
    Write-Host Remain jobs.... $pending.count -ForegroundColor Green
} while ($pending)

Start-AzStorageBlobCopy -AbsoluteUri $sass.AccessSAS `
-DestContainer "grafana" `
-DestContext $destinationContext `
-DestBlob "OS-Snapshot-Grafana"