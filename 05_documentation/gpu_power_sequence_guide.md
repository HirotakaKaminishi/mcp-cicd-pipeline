# GPU外部電源の正しい投入順序ガイド

## 🔴 重要：電源投入順序が間違うと即座にシャットダウンします

### 正しい電源投入順序

#### 【起動時】
1. **GPU外部PSU電源ON** ← 最初
2. **5秒待機**
3. **メインPC電源ON** ← 後から

#### 【シャットダウン時】
1. **Windowsシャットダウン実行**
2. **メインPC電源が完全にOFF確認**
3. **GPU外部PSU電源OFF** ← 最後

### なぜこの順序が重要か

#### 起動時にGPU PSUが先である理由：
- PCIeスロットが12V電源を期待している
- GPU PSUが後から投入されると電圧不安定
- マザーボードのPCIe制御チップが異常検出
- 保護回路が作動して即座シャットダウン

#### シャットダウン時にGPU PSUが後である理由：
- システムがGPUとの通信を正常終了する必要
- GPU PSUが先に切れるとGPUエラー発生
- 正常シャットダウンプロセスが中断される

## 電源管理の詳細設定

### 調査PCで設定確認コマンド：

```powershell
# 現在のPCIe電源管理設定確認
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -ErrorAction SilentlyContinue

# PCIeリンク電源管理確認
Get-WmiObject -Namespace root\wmi -Class MSPower_DeviceEnable | Where-Object {$_.InstanceName -match "PCI"}

# GPU電源状態確認
Get-WmiObject Win32_VideoController | Select-Object Name, Status, PowerManagementSupported
```

### BIOS設定推奨事項：

```
1. PCIe Power Management: Disabled
2. ASPM (Active State Power Management): Disabled  
3. PCI Express Native Power Management: Disabled
4. ErP Ready: Disabled
5. Deep Sleep: Disabled
```

## 自動化スクリプト

### 電源投入順序チェッカー：

```powershell
# GPU PSU状態監視スクリプト
while ($true) {
    $gpuPresent = Get-PnpDevice -Class Display | Where-Object {$_.Status -eq "OK" -and $_.Name -match "NVIDIA|GeForce|Radeon RX|RTX"}
    $systemUptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    
    if ($gpuPresent -and $systemUptime.TotalMinutes -lt 2) {
        Write-Host "$(Get-Date): GPU detected during startup - Power sequence OK" -ForegroundColor Green
        break
    } elseif (!$gpuPresent -and $systemUptime.TotalMinutes -gt 1) {
        Write-Host "$(Get-Date): WARNING - GPU not detected after boot!" -ForegroundColor Red
        Write-Host "Possible power sequence issue" -ForegroundColor Yellow
        break
    }
    
    Start-Sleep -Seconds 10
}
```

## トラブルシューティング

### 電源順序問題の症状：
- ✗ 起動直後のシャットダウン
- ✗ GPU not detected エラー
- ✗ PCIe device enumeration errors
- ✗ Kernel-Power Event ID 41

### 正しい順序での症状：
- ✓ 安定した起動
- ✓ GPU正常認識
- ✓ システムログにエラーなし

## 推奨解決策

### 短期対策（今すぐ実行）：
1. **厳密な電源順序を守る**
2. **両PSUを同じ電源タップに接続**
3. **UPS使用で電圧安定化**

### 長期対策（根本解決）：
1. **単一大容量PSU（850W+）への交換**
2. **GPU用独立回路の設置**
3. **電源同期装置の導入**

## 緊急時の対応

現在31回シャットダウンが発生している状況では：

```powershell
# 即座にGPUを無効化してテスト
$gpu = Get-PnpDevice -Class Display | Where-Object {$_.Name -match "NVIDIA|GeForce|Radeon RX|RTX"}
if ($gpu) {
    Disable-PnpDevice -InstanceId $gpu.InstanceId -Confirm:$false
    Write-Host "GPU無効化 - 統合グラフィックで安定性テスト開始"
}
```

**電源順序を正しく守ることで、シャットダウン問題が劇的に改善される可能性があります。**