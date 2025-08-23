# Target PC Connector - 対象PCから調査側への接続
# 対象PC（192.168.111.163）で実行

param(
    [string]$InvestigationIP = "192.168.111.55",
    [int]$Port = 3333
)

Write-Host "=== Target PC Connector ===" -ForegroundColor Green
Write-Host "Connecting to Investigation Server: $InvestigationIP`:$Port" -ForegroundColor Cyan

function Send-PowerInvestigationData {
    param($writer)
    
    Write-Host "`n📊 Collecting power investigation data..." -ForegroundColor Yellow
    
    # 1. システム情報
    $writer.WriteLine("=== SYSTEM INFORMATION ===")
    $sysInfo = Get-ComputerInfo | Select-Object WindowsProductName, TotalPhysicalMemory, CsManufacturer, CsModel
    $writer.WriteLine($sysInfo | Out-String)
    
    # 2. 予期しないシャットダウン
    $writer.WriteLine("=== UNEXPECTED SHUTDOWNS (Event ID 6008) ===")
    try {
        $shutdowns = Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008} | Select-Object TimeGenerated, Message -First 10
        $writer.WriteLine($shutdowns | Out-String)
    } catch {
        $writer.WriteLine("Error getting shutdown events: $($_.Exception.Message)")
    }
    
    # 3. 電源関連イベント
    $writer.WriteLine("=== POWER-RELATED EVENTS ===")
    try {
        $powerEvents = Get-EventLog -LogName System -EntryType Error, Warning -Newest 20 | Where-Object {$_.Source -like "*Power*"}
        $writer.WriteLine($powerEvents | Out-String)
    } catch {
        $writer.WriteLine("Error getting power events: $($_.Exception.Message)")
    }
    
    # 4. 電源設定
    $writer.WriteLine("=== POWER CONFIGURATION ===")
    try {
        $powerConfig = powercfg /query
        $writer.WriteLine($powerConfig)
    } catch {
        $writer.WriteLine("Error getting power config: $($_.Exception.Message)")
    }
    
    # 5. 最後のウェイクアップ
    $writer.WriteLine("=== LAST WAKE INFORMATION ===")
    try {
        $lastWake = powercfg /lastwake
        $writer.WriteLine($lastWake)
    } catch {
        $writer.WriteLine("Error getting last wake: $($_.Exception.Message)")
    }
    
    $writer.WriteLine("=== INVESTIGATION DATA COMPLETE ===")
}

try {
    # 接続テスト
    Write-Host "Testing connection..." -ForegroundColor Yellow
    $testResult = Test-NetConnection -ComputerName $InvestigationIP -Port $Port -WarningAction SilentlyContinue
    
    if (-not $testResult.TcpTestSucceeded) {
        Write-Host "❌ Cannot connect to investigation server" -ForegroundColor Red
        Write-Host "Make sure investigation server is running on $InvestigationIP`:$Port" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "✅ Connection test successful" -ForegroundColor Green
    
    # TCP接続確立
    $tcpClient = [System.Net.Sockets.TcpClient]::new()
    $tcpClient.Connect($InvestigationIP, $Port)
    
    $stream = $tcpClient.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $writer = [System.IO.StreamWriter]::new($stream)
    $writer.AutoFlush = $true
    
    Write-Host "✅ Connected to investigation server" -ForegroundColor Green
    
    # ウェルカムメッセージ受信
    if ($stream.DataAvailable) {
        $welcome = $reader.ReadLine()
        Write-Host "Server: $welcome" -ForegroundColor Cyan
    }
    
    # 自動的に電源調査データを送信
    Write-Host "`n🔍 Sending power investigation data..." -ForegroundColor Yellow
    $writer.WriteLine("AUTO-INVESTIGATION-START")
    Send-PowerInvestigationData -writer $writer
    $writer.WriteLine("AUTO-INVESTIGATION-END")
    
    # インタラクティブモード
    Write-Host "`n💬 Interactive mode - Type commands or 'exit' to quit" -ForegroundColor Green
    Write-Host "Available commands: ping, status, help, power-logs, exit" -ForegroundColor Gray
    
    while ($tcpClient.Connected) {
        Write-Host "`nTarget> " -NoNewline -ForegroundColor Yellow
        $userInput = Read-Host
        
        if ($userInput.ToLower() -eq "exit") {
            $writer.WriteLine("exit")
            break
        }
        
        $writer.WriteLine($userInput)
        
        # 応答待機
        Start-Sleep -Milliseconds 500
        while ($stream.DataAvailable) {
            $response = $reader.ReadLine()
            Write-Host "Investigation Server: $response" -ForegroundColor Cyan
        }
    }
    
} catch {
    Write-Host "❌ Connection error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($tcpClient) {
        $tcpClient.Close()
        Write-Host "Connection closed" -ForegroundColor Yellow
    }
}

Read-Host "`nPress Enter to exit"