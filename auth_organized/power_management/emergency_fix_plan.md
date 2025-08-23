# 調査PC 緊急修復計画

## 現状
- PC: 192.168.111.163 (Tianbei GEM12, AMD Ryzen 9 6900HX)
- 状態: **完全オフライン** (ping応答なし)
- 問題: **26回の異常シャットダウン (2025/08/16)**

## 緊急対応手順

### Phase 1: 物理的確認 (PC電源投入後)
```powershell
# 1. 電源容量確認
Get-WmiObject -Class Win32_SystemEnclosure
Get-WmiObject -Class Win32_PowerManagementEvent

# 2. 温度監視開始
# HWiNFO64インストール → リアルタイム監視
```

### Phase 2: システム診断
```powershell
# メモリテスト実行
mdsched.exe

# ディスクチェック
chkdsk C: /f /r

# システムファイルチェック
sfc /scannow
```

### Phase 3: 電源設定最適化
```powershell
# 高パフォーマンスから省電力に変更
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e

# CPUの最大使用率を制限
powercfg /setacvalueindex 381b4222-f694-41f0-9685-ff5bb260df2e 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 80
```

## 根本原因別対策

### 電源不足の場合
- より高容量PSUへ交換（推奨: 750W以上）
- 不要な周辺機器の取り外し

### 熱暴走の場合  
- CPUクーラー清掃/交換
- サーマルペースト再塗布
- ケースファン追加

### メモリ不良の場合
- メモリ1枚ずつテスト
- 不良モジュール特定・交換

## モニタリング継続
- HWiNFO64による24時間監視
- 温度：CPU 70℃、GPU 80℃を上限
- 電圧：±5%以内の変動確認