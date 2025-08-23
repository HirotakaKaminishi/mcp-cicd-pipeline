# Check if MCP Server is running on Docker
# MCPサーバーがDocker上で動作しているか確認

Write-Host "=== CHECKING DOCKER & MCP SERVER STATUS ===" -ForegroundColor Green
Write-Host "Investigating MCP Server deployment on 192.168.111.200" -ForegroundColor Cyan

# 1. Check local Docker status
Write-Host "`n[1] Checking Local Docker Status..." -ForegroundColor Yellow
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($dockerVersion) {
        Write-Host "✓ Docker is installed (Version: $dockerVersion)" -ForegroundColor Green
        
        # List all containers
        Write-Host "`nRunning containers:" -ForegroundColor Cyan
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>$null
        
        Write-Host "`nAll containers (including stopped):" -ForegroundColor Cyan
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>$null
        
        # Check for MCP-related images
        Write-Host "`nDocker images:" -ForegroundColor Cyan
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>$null | Select-String -Pattern "mcp|react|node|app" -ErrorAction SilentlyContinue
        
    } else {
        Write-Host "✗ Docker is not running or not installed locally" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Docker not available on local system" -ForegroundColor Red
}

# 2. Check remote server (192.168.111.200) for Docker containers
Write-Host "`n[2] Checking Remote Server Ports..." -ForegroundColor Yellow

# Common Docker and application ports
$ports = @(
    @{Port=80; Service="HTTP/nginx"},
    @{Port=443; Service="HTTPS"},
    @{Port=8080; Service="MCP API/App"},
    @{Port=3000; Service="React Dev"},
    @{Port=3001; Service="React App"},
    @{Port=5000; Service="Python Flask/FastAPI"},
    @{Port=8000; Service="Python Django/FastAPI"},
    @{Port=9000; Service="PHP-FPM"},
    @{Port=2375; Service="Docker API (HTTP)"},
    @{Port=2376; Service="Docker API (HTTPS)"}
)

Write-Host "Testing ports on 192.168.111.200:" -ForegroundColor Cyan
foreach ($item in $ports) {
    $tcpTest = Test-NetConnection -ComputerName 192.168.111.200 -Port $item.Port -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($tcpTest) {
        Write-Host "✓ Port $($item.Port) ($($item.Service)): OPEN" -ForegroundColor Green
    } else {
        Write-Host "✗ Port $($item.Port) ($($item.Service)): CLOSED" -ForegroundColor Gray
    }
}

# 3. Check what's actually responding on open ports
Write-Host "`n[3] Checking Services on Open Ports..." -ForegroundColor Yellow

# Check port 80
try {
    $response80 = Invoke-WebRequest -Uri "http://192.168.111.200" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✓ Port 80 responding with:" -ForegroundColor Green
    Write-Host "  Status: $($response80.StatusCode)" -ForegroundColor Cyan
    Write-Host "  Headers: $($response80.Headers['Server'])" -ForegroundColor Cyan
    
    # Check for Docker container indicators
    if ($response80.Content -match "nginx" -or $response80.Headers['Server'] -match "nginx") {
        Write-Host "  → Likely running in Docker (nginx detected)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Port 80 not responding to HTTP" -ForegroundColor Red
}

# Check port 8080
try {
    $response8080 = Invoke-WebRequest -Uri "http://192.168.111.200:8080" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✓ Port 8080 responding" -ForegroundColor Green
} catch {
    Write-Host "✗ Port 8080 not responding to HTTP" -ForegroundColor Red
}

# 4. Check Docker Compose files
Write-Host "`n[4] Looking for Docker Compose Files..." -ForegroundColor Yellow

$composeFiles = @(
    "docker-compose.yml",
    "docker-compose.yaml", 
    "compose.yml",
    "compose.yaml",
    ".github/workflows/deploy.yml"
)

foreach ($file in $composeFiles) {
    $paths = @(
        "C:\Users\hirotaka\Documents\work\$file",
        "C:\Users\hirotaka\Documents\work\03_sample_projects\react_apps\$file",
        "C:\Users\hirotaka\Documents\work\02_deployment_tools\$file"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "✓ Found: $path" -ForegroundColor Green
            
            # Check content for MCP references
            $content = Get-Content $path -Raw
            if ($content -match "mcp|react|node") {
                Write-Host "  → Contains MCP/React/Node configuration" -ForegroundColor Cyan
            }
        }
    }
}

# 5. Check GitHub Actions deployment
Write-Host "`n[5] Checking GitHub Actions Deployment..." -ForegroundColor Yellow

$workflowPath = "C:\Users\hirotaka\Documents\work\.github\workflows"
if (Test-Path $workflowPath) {
    $workflows = Get-ChildItem -Path $workflowPath -Filter "*.yml"
    foreach ($workflow in $workflows) {
        Write-Host "Found workflow: $($workflow.Name)" -ForegroundColor Cyan
        $content = Get-Content $workflow.FullName -Raw
        if ($content -match "docker") {
            Write-Host "  → Uses Docker for deployment" -ForegroundColor Green
        }
    }
}

# 6. Summary
Write-Host "`n=== DOCKER & MCP STATUS SUMMARY ===" -ForegroundColor Green

# Analyze findings
$dockerLocal = docker ps 2>$null
$port80Open = Test-NetConnection -ComputerName 192.168.111.200 -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
$port8080Open = Test-NetConnection -ComputerName 192.168.111.200 -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue

Write-Host "`nFindings:" -ForegroundColor Yellow
Write-Host "• Local Docker: $(if($dockerLocal){'Running'}else{'Not running'})" -ForegroundColor Cyan
Write-Host "• Remote server 192.168.111.200:" -ForegroundColor Cyan
Write-Host "  - Port 80 (HTTP): $(if($port80Open){'✓ Open'}else{'✗ Closed'})" -ForegroundColor $(if($port80Open){'Green'}else{'Red'})
Write-Host "  - Port 8080 (MCP): $(if($port8080Open){'✓ Open'}else{'✗ Closed'})" -ForegroundColor $(if($port8080Open){'Green'}else{'Red'})

Write-Host "`nConclusion:" -ForegroundColor Yellow
if ($port80Open -and $port8080Open) {
    Write-Host "→ MCP Server is likely running on Docker at 192.168.111.200" -ForegroundColor Green
    Write-Host "→ Services are accessible on ports 80 and 8080" -ForegroundColor Green
} else {
    Write-Host "→ MCP Server may not be running in Docker currently" -ForegroundColor Yellow
    Write-Host "→ Or Docker containers may be stopped" -ForegroundColor Yellow
}

Write-Host "`nTo verify on remote server, SSH and run:" -ForegroundColor Cyan
Write-Host "  ssh user@192.168.111.200" -ForegroundColor White
Write-Host "  docker ps" -ForegroundColor White
Write-Host "  docker-compose ps" -ForegroundColor White