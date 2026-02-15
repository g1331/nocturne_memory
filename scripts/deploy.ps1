$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-ServiceContainerId {
    param([string]$ServiceName)
    $id = (docker compose ps -q $ServiceName).Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Container for service '$ServiceName' was not created."
    }
    return $id
}

function Wait-ServiceState {
    param(
        [string]$ServiceName,
        [string]$ExpectedState,
        [int]$TimeoutSeconds = 120
    )

    $id = Get-ServiceContainerId -ServiceName $ServiceName
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $state = (docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $id).Trim()
        if ($state -eq $ExpectedState) {
            Write-Host "$ServiceName status: $state"
            return
        }

        if ($state -eq "exited" -or $state -eq "dead") {
            throw "Service '$ServiceName' is not running (state: $state)."
        }

        Start-Sleep -Seconds 2
    }

    throw "Timed out waiting for '$ServiceName' to reach state '$ExpectedState'."
}

Require-Command -Name "docker"

docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose plugin is not available."
}

docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker daemon is not running."
}

Write-Host "Starting containers (build + up)..."
docker compose up -d --build

try {
    Wait-ServiceState -ServiceName "backend" -ExpectedState "healthy" -TimeoutSeconds 180
    Wait-ServiceState -ServiceName "web" -ExpectedState "running" -TimeoutSeconds 120
    Wait-ServiceState -ServiceName "mcp-sse" -ExpectedState "running" -TimeoutSeconds 120
}
catch {
    Write-Host "Deployment failed. Showing recent logs..." -ForegroundColor Red
    docker compose logs --no-color --tail=200 backend web mcp-sse
    throw
}

Write-Host ""
Write-Host "Deployment completed."
Write-Host "Web UI:     http://localhost:18080"
Write-Host "MCP SSE:    http://localhost:18081/sse"

