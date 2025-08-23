# Investigation Server - SSH代替リモート接続システム
# 調査側で実行：対象PCからの接続を受け入れ、コマンド実行結果を受信

param(
    [int]$Port = 3333,
    [string]$LogDir = "C:\Users\hirotaka\Documents\work\auth\logs"
)

Write-Host "=== Investigation Server ===" -ForegroundColor Green
Write-Host "Listening on port: $Port" -ForegroundColor Cyan
Write-Host "IP Address: 192.168.111.55" -ForegroundColor Yellow

# ログディレクトリ作成
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force
}

$logFile = "$LogDir\investigation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logEntry
}

try {
    # TCP リスナー作成
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $listener.Start()
    
    Write-Log "Server started on port $Port" "Green"
    Write-Log "Waiting for connection from target PC (192.168.111.163)..." "Yellow"
    
    # ファイアウォール規則追加（PowerShell経由）
    try {
        New-NetFirewallRule -DisplayName "Investigation Server" -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port -ErrorAction SilentlyContinue
        Write-Log "Firewall rule added for port $Port" "Green"
    } catch {
        Write-Log "Firewall rule may already exist or requires admin privileges" "Yellow"
    }
    
    Write-Host "`n📋 Instructions for Target PC:" -ForegroundColor Cyan
    Write-Host "1. Run PowerShell as Administrator on target PC" -ForegroundColor White
    Write-Host "2. Execute: Test-NetConnection -ComputerName 192.168.111.55 -Port $Port" -ForegroundColor White
    Write-Host "3. If successful, use telnet or custom script to connect" -ForegroundColor White
    Write-Host "`nPress Ctrl+C to stop server" -ForegroundColor Red
    
    while ($true) {
        if ($listener.Pending()) {
            $client = $listener.AcceptTcpClient()
            $clientEndpoint = $client.Client.RemoteEndPoint
            
            Write-Log "Connection established from: $clientEndpoint" "Green"
            
            # 接続処理
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.AutoFlush = $true
            
            # 接続確認メッセージ送信
            $welcome = "Investigation Server Connected - Ready for commands`n"
            $writer.WriteLine($welcome)
            Write-Log "Welcome message sent to $clientEndpoint" "Cyan"
            
            # コマンド処理ループ
            try {
                while ($client.Connected) {
                    if ($stream.DataAvailable) {
                        $command = $reader.ReadLine()
                        if ($command) {
                            Write-Log "Received command: $command" "Yellow"
                            
                            # 特別なコマンド処理
                            switch ($command.ToLower()) {
                                "exit" { 
                                    $writer.WriteLine("Connection closed by client")
                                    break 
                                }
                                "ping" { 
                                    $writer.WriteLine("pong - server alive") 
                                }
                                "status" { 
                                    $writer.WriteLine("Investigation server running on 192.168.111.55:$Port") 
                                }
                                "help" {
                                    $help = @"
Available commands:
- ping: Test connection
- status: Server status
- power-logs: Get power-related logs
- system-info: Get system information
- exit: Close connection
"@
                                    $writer.WriteLine($help)
                                }
                                "power-logs" {
                                    $writer.WriteLine("Power investigation commands for target PC:")
                                    $writer.WriteLine("Get-EventLog -LogName System | Where-Object {`$_.EventID -eq 6008} | Select-Object TimeGenerated,Message -First 10")
                                    $writer.WriteLine("powercfg /lastwake")
                                }
                                default { 
                                    $writer.WriteLine("Command received: $command (execute this on target PC)") 
                                }
                            }
                        }
                    }
                    Start-Sleep -Milliseconds 100
                }
            } catch {
                Write-Log "Client communication error: $($_.Exception.Message)" "Red"
            } finally {
                $client.Close()
                Write-Log "Connection closed: $clientEndpoint" "Yellow"
            }
        }
        Start-Sleep -Milliseconds 500
    }
    
} catch {
    Write-Log "Server error: $($_.Exception.Message)" "Red"
} finally {
    if ($listener) {
        $listener.Stop()
        Write-Log "Server stopped" "Yellow"
    }
}

Read-Host "`nPress Enter to exit"