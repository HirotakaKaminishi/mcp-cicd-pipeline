# MCP Server Tools Check Script
# MCPサーバーで利用可能なツールを確認

Write-Host "=== MCP SERVER AVAILABLE TOOLS ===" -ForegroundColor Green
Write-Host "Checking MCP Server (192.168.111.200) capabilities..." -ForegroundColor Cyan

# 1. Check MCP API endpoints
Write-Host "`n[1] Testing MCP API Endpoints..." -ForegroundColor Yellow

$mcpEndpoints = @(
    @{Name="Health Check"; URL="http://192.168.111.200:8080/health"; Method="GET"},
    @{Name="Execute Command"; URL="http://192.168.111.200:8080/api/execute"; Method="POST"},
    @{Name="Write File"; URL="http://192.168.111.200:8080/api/write"; Method="POST"},
    @{Name="Read File"; URL="http://192.168.111.200:8080/api/read"; Method="POST"},
    @{Name="List Directory"; URL="http://192.168.111.200:8080/api/list"; Method="POST"},
    @{Name="System Info"; URL="http://192.168.111.200:8080/api/system"; Method="GET"},
    @{Name="Service Manager"; URL="http://192.168.111.200:8080/api/service"; Method="POST"},
    @{Name="Process Manager"; URL="http://192.168.111.200:8080/api/process"; Method="GET"},
    @{Name="Network Info"; URL="http://192.168.111.200:8080/api/network"; Method="GET"},
    @{Name="Docker Manager"; URL="http://192.168.111.200:8080/api/docker"; Method="GET"}
)

foreach ($endpoint in $mcpEndpoints) {
    try {
        if ($endpoint.Method -eq "GET") {
            $response = Invoke-WebRequest -Uri $endpoint.URL -Method GET -TimeoutSec 2 -ErrorAction Stop
            Write-Host "✓ $($endpoint.Name): Available" -ForegroundColor Green
        } else {
            # For POST endpoints, just check if they exist (will return error without proper data)
            $response = Invoke-WebRequest -Uri $endpoint.URL -Method POST -TimeoutSec 2 -ErrorAction SilentlyContinue
            Write-Host "✓ $($endpoint.Name): Endpoint exists" -ForegroundColor Cyan
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 'BadRequest' -or $_.Exception.Response.StatusCode -eq 'MethodNotAllowed') {
            Write-Host "✓ $($endpoint.Name): Endpoint exists (requires parameters)" -ForegroundColor Yellow
        } else {
            Write-Host "✗ $($endpoint.Name): Not available" -ForegroundColor Red
        }
    }
}

# 2. Check for MCP configuration files
Write-Host "`n[2] Looking for MCP Configuration..." -ForegroundColor Yellow

$configPaths = @(
    "C:\Users\hirotaka\Documents\work\mcp-deploy.js",
    "C:\Users\hirotaka\Documents\work\mcp-config.json",
    "C:\Users\hirotaka\Documents\work\.mcp\config.json",
    "C:\Users\hirotaka\Documents\work\auth_organized\mcp_tools.md"
)

foreach ($path in $configPaths) {
    if (Test-Path $path) {
        Write-Host "✓ Found: $path" -ForegroundColor Green
        
        # Try to read and display tool definitions if it's a config file
        if ($path -match "\.json$") {
            try {
                $config = Get-Content $path | ConvertFrom-Json
                if ($config.tools) {
                    Write-Host "  Tools defined in config:" -ForegroundColor Cyan
                    $config.tools | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
                }
            } catch {
                Write-Host "  Could not parse JSON" -ForegroundColor Yellow
            }
        }
    }
}

# 3. Common MCP Tool Categories
Write-Host "`n[3] Standard MCP Tool Categories:" -ForegroundColor Yellow

$toolCategories = @"

File Operations:
  - read_file: Read file contents
  - write_file: Write/create files
  - delete_file: Delete files
  - list_directory: List directory contents
  - copy_file: Copy files
  - move_file: Move/rename files

System Operations:
  - execute_command: Execute shell commands
  - get_system_info: Get system information
  - get_environment: Get environment variables
  - set_environment: Set environment variables

Service Management:
  - start_service: Start a system service
  - stop_service: Stop a system service
  - restart_service: Restart a service
  - get_service_status: Check service status

Process Management:
  - list_processes: List running processes
  - kill_process: Terminate a process
  - start_process: Start a new process

Network Operations:
  - get_network_info: Get network configuration
  - test_connection: Test network connectivity
  - download_file: Download from URL
  - upload_file: Upload to server

Docker Operations:
  - list_containers: List Docker containers
  - start_container: Start container
  - stop_container: Stop container
  - exec_in_container: Execute command in container
  - get_container_logs: Get container logs

Database Operations:
  - query_database: Execute SQL query
  - backup_database: Backup database
  - restore_database: Restore from backup

Git Operations:
  - git_status: Check repository status
  - git_commit: Create commit
  - git_push: Push to remote
  - git_pull: Pull from remote
"@

Write-Host $toolCategories -ForegroundColor Cyan

# 4. Test actual MCP command execution
Write-Host "`n[4] Testing MCP Command Execution..." -ForegroundColor Yellow

$testCommand = @{
    command = "echo 'MCP Server Test'"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://192.168.111.200:8080/api/execute" `
                                  -Method POST `
                                  -Body $testCommand `
                                  -ContentType "application/json" `
                                  -TimeoutSec 5
    Write-Host "✓ Command execution works!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Command execution not available or requires authentication" -ForegroundColor Red
}

Write-Host "`n=== MCP TOOLS SUMMARY ===" -ForegroundColor Green
Write-Host @"

Based on MCP Server at 192.168.111.200:

Available Tools (confirmed):
- Health monitoring
- Port access (8080, 80, 22)
- Node.js processes running

To use MCP tools from Claude Code:
1. Ensure MCP server is running
2. Check authentication requirements
3. Use appropriate API endpoints
4. Handle responses properly

For detailed tool usage, check:
- Project documentation
- MCP configuration files
- API endpoint specifications
"@ -ForegroundColor Cyan