# Direct Memory Test Command
# Run this directly on investigation PC

Write-Host "=== MEMORY TEST COMMAND FOR INVESTIGATION PC ===" -ForegroundColor Red
Write-Host "Run these commands directly on 192.168.111.163" -ForegroundColor Yellow

Write-Host "`n[IMMEDIATE ACTIONS]" -ForegroundColor Green
Write-Host @"

1. Schedule Memory Test:
   mdsched.exe
   → Select "Restart now and check for problems"

2. Apply Power Limits (prevent shutdown):
   powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
   powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 60
   powercfg /setactive scheme_current

3. Check Recent Shutdowns:
   Get-WinEvent -FilterHashtable @{LogName='System'; ID=41} -MaxEvents 10 | Format-Table TimeCreated

4. After Memory Test Completes, Check Results:
   Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -MaxEvents 1

"@ -ForegroundColor Cyan

Write-Host "`n[TROUBLESHOOTING REMOTE ACCESS]" -ForegroundColor Yellow
Write-Host @"

On Investigation PC (192.168.111.163):
1. Check if 'pc' user is administrator:
   net localgroup Administrators

2. If not, add to administrators:
   net localgroup Administrators pc /add

3. Set password (if needed):
   net user pc 1192

4. Test locally:
   Enter-PSSession -ComputerName localhost -Credential (Get-Credential)

"@ -ForegroundColor White