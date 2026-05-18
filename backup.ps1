# Backup do servidor Minecraft (Fabric + Docker).
# Uso: .\backup.ps1
#      .\backup.ps1 -Full          # copia a pasta inteira (exceto lixo pesado)
#      .\backup.ps1 -NoRestart     # não para / não sobe o container

param(
    [switch]$Full,
    [switch]$NoRestart,
    [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath("Desktop")) "mc-backups")
)

$ErrorActionPreference = "Stop"
$ServerRoot = $PSScriptRoot
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$dest = Join-Path $BackupRoot "backup_$timestamp"
$stoppedByScript = $false

$essentialItems = @(
    "world",
    "mods",
    "config",
    "defaultconfigs",
    "server.properties",
    "ops.json",
    "whitelist.json",
    "banned-players.json",
    "banned-ips.json"
)

function Write-Step([string]$Message) {
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Invoke-DockerCompose([string[]]$ComposeArgs) {
    Push-Location $ServerRoot
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & docker compose @ComposeArgs 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose $($ComposeArgs -join ' ') falhou (codigo $LASTEXITCODE)"
        }
    }
    finally {
        $ErrorActionPreference = $prevEap
        Pop-Location
    }
}

function Start-MinecraftServer {
    Invoke-DockerCompose @("up", "-d", "minecraft")
}

function Stop-MinecraftServer {
    Invoke-DockerCompose @("stop", "minecraft")
}

try {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Write-Step "Destino: $dest"

    if (-not $NoRestart) {
        Write-Step "A parar o servidor (docker compose stop minecraft)..."
        Stop-MinecraftServer
        $stoppedByScript = $true
        Start-Sleep -Seconds 2
    }
    else {
        Write-Host ">> Aviso: -NoRestart - o mundo pode estar em uso (session.lock)." -ForegroundColor Yellow
    }

    if ($Full) {
        Write-Step "Backup completo da pasta do servidor..."
        $excludeDirs = @(".git", "logs", "crash-reports", "debug", ".cache", "libraries", "versions", ".fabric")
        Get-ChildItem -Path $ServerRoot -Force | ForEach-Object {
            if ($excludeDirs -contains $_.Name) { return }
            if ($_.Name -like "backup*.ps1") { return }
            Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
        }
    }
    else {
        Write-Step "A copiar mundo, mods, configs e listas de jogadores..."
        foreach ($item in $essentialItems) {
            $source = Join-Path $ServerRoot $item
            if (-not (Test-Path $source)) { continue }
            Copy-Item -Path $source -Destination $dest -Recurse -Force
        }
    }

    $mode = if ($Full) { "completo (sem .git/logs/libraries)" } else { "essencial" }
    $readmeLines = @(
        "Backup criado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Origem: $ServerRoot",
        "Modo: $mode",
        "",
        "Restaurar (com servidor parado):",
        "  1. docker compose stop minecraft",
        "  2. Copiar o conteudo desta pasta para $ServerRoot",
        "  3. docker compose up -d minecraft"
    )
    Set-Content -Path (Join-Path $dest "README-restore.txt") -Value ($readmeLines -join "`n") -Encoding UTF8

    $sizeMb = [math]::Round((Get-ChildItem $dest -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-Host ""
    Write-Host "Backup concluido: $dest - $sizeMb MiB" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($stoppedByScript) {
        Write-Step "A subir o servidor (docker compose up -d minecraft)..."
        Start-MinecraftServer
    }
}
