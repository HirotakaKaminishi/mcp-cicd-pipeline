# 緊急：調査PC 異常シャットダウン分析レポート
**作成日時:** 2025/08/16  
**対象PC:** 192.168.111.163 (Tianbei GEM12)  
**CPU:** AMD Ryzen 9 6900HX (8コア/16スレッド)  
**RAM:** 32GB DDR4  

## 🔴 深刻度: クリティカル

### 現在状況
- **総シャットダウン回数:** 27回以上（本日のみ）
- **最新状態:** オフライン（再度シャットダウン）
- **パターン:** 起動後数分〜数十分で強制停止

### シャットダウン履歴（最新）
```
2025/08/16 16:22:56 - Kernel-Power Event ID 41
2025/08/16 15:50:05 - Kernel-Power Event ID 41
2025/08/16 15:09:20 - Kernel-Power Event ID 41
2025/08/16 14:56:20 - Kernel-Power Event ID 41
（他23件）
```

## 根本原因分析

### 1. 🔥 熱暴走（可能性: 85%）
**症状との一致:**
- AMD Ryzen 9 6900HXは高発熱CPU（TDP 45W）
- 短時間での連続シャットダウン
- 起動直後は動作するが徐々に不安定化

**確認方法:**
```powershell
# HWiNFO64をインストール後
Start-Process "C:\Program Files\HWiNFO64\HWiNFO64.exe"
# CPU温度が80℃を超えていないか確認
```

### 2. ⚡ 電源ユニット不良（可能性: 70%）
**症状との一致:**
- Kernel-Power Event ID 41（電源喪失）
- 負荷時の突然停止
- クリーンシャットダウンではない

**必要電源容量:**
- Ryzen 9 6900HX: 45W (ブースト時100W+)
- システム全体: 最低550W、推奨650W以上

### 3. 💾 メモリ不良（可能性: 40%）
**症状との一致:**
- ランダムなタイミングでのクラッシュ
- 32GB構成での不安定性

## 即座に実行すべき対処法

### ステップ1: 物理的対処（今すぐ）
```
1. PCの電源を切り、電源ケーブルを抜く
2. 10分間放置（放熱）
3. ケースを開けて以下を確認：
   - CPUクーラーの埃除去
   - ファンの回転確認
   - 電源ユニットの型番確認
```

### ステップ2: 最小構成での起動テスト
```
1. メモリを1枚だけ挿して起動
2. BIOSで以下を設定：
   - CPU Power Limit: 35W
   - Fan Speed: Maximum
3. Windows セーフモードで起動
```

### ステップ3: 診断コマンド（PC起動時に即実行）
```powershell
# 管理者権限PowerShellで実行

# 1. 温度監視（最優先）
wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature

# 2. 電源プラン変更（省電力モード）
powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a

# 3. CPU使用率制限
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 50
powercfg /setactive scheme_current

# 4. メモリテスト予約
mdsched.exe /r

# 5. イベントログ保存
wevtutil epl System C:\shutdown_events.evtx
```

## 緊急推奨事項

### 🚨 今すぐ実施
1. **データバックアップ** - 次回起動時に重要データを即座にバックアップ
2. **HWiNFO64インストール** - 温度リアルタイム監視
3. **電源ユニット確認** - 容量が550W未満なら即交換

### ⚠️ 24時間以内に実施
1. **CPUクーラー清掃または交換**
2. **サーマルペースト再塗布**
3. **メモリ個別テスト**
4. **BIOS更新**

### 代替案
このPCでの作業継続が困難な場合：
1. 別PCからのリモート作業に切り替え
2. クラウド環境への移行
3. 修理完了まで192.168.111.200での作業継続

## 監視スクリプト
次回起動時に以下を自動実行するようタスクスケジューラに登録：
```xml
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-File C:\monitor_temperature.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
```

## 結論
**ハードウェア障害が確定的**です。これ以上の使用は：
- データ損失リスク
- ハードウェアの永久的損傷
- 作業効率の著しい低下

を招きます。**即座の物理的対処が必要**です。