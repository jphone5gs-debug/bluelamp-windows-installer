#Requires -Version 5.1

$script:StateDir = Join-Path $env:LOCALAPPDATA 'BlueLampInstaller'
$script:StatePath = Join-Path $script:StateDir 'state.json'
$script:LogPath = Join-Path $script:StateDir 'install.log'
$script:WslUser = 'bluelamp'
$script:WslBashEnvPath = "/home/$script:WslUser/.bluelamp_bash_env"
# 汎用的な"Ubuntu"ではなく専用名にすることで、利用者が既に持つ別のUbuntu(WSL)環境と衝突しないようにする
$script:WslDistroName = 'BlueLamp'

function Write-InstallLog {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [switch]$IsError
    )
    $prefix = '[BlueLampインストーラー]'
    $level = if ($IsError) { 'ERROR' } else { 'INFO' }
    if ($IsError) {
        Write-Host "$prefix $Message" -ForegroundColor Red
    } else {
        Write-Host "$prefix $Message" -ForegroundColor Cyan
    }
    try {
        if (-not (Test-Path $script:StateDir)) {
            New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
        }
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Add-Content -Path $script:LogPath -Value "$timestamp [$level] $Message" -Encoding UTF8
    } catch {
        $null = $_
    }
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'このスクリプトは管理者として実行する必要があります。PowerShellを「管理者として実行」で開き直してください。'
    }
}

function Save-InstallState {
    param([Parameter(Mandatory)] [string]$NextStep)
    if (-not (Test-Path $script:StateDir)) {
        New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
    }
    $state = [pscustomobject]@{
        NextStep   = $NextStep
        RepoPath   = $RepoRoot
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    $state | ConvertTo-Json | Set-Content -Path $script:StatePath -Encoding UTF8
}

function Read-InstallState {
    $reRunHint = 'irm https://raw.githubusercontent.com/jphone5gs-debug/bluelamp-windows-installer/main/install.ps1 | iex'
    if (-not (Test-Path $script:StatePath)) {
        throw "状態ファイルが見つかりません ($script:StatePath)。インストーラーを最初から再実行してください: $reRunHint"
    }
    try {
        Get-Content -Raw -Path $script:StatePath | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "状態ファイルの内容が壊れています ($script:StatePath)。ファイルを削除してインストーラーを最初から再実行してください: $reRunHint"
    }
}

function Remove-InstallState {
    # 自動実行フローの内部クリーンアップであり対話確認の対象ではないため、ShouldProcessは実装しない
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    # 完了後の後始末であり、失敗しても動作の正しさには影響しないため警告のみで継続する
    try {
        if (Test-Path $script:StatePath) {
            Remove-Item -Path $script:StatePath -Force -ErrorAction Stop
        }
    } catch {
        Write-InstallLog "状態ファイルの削除に失敗しましたが、インストール自体は完了しています: $_" -IsError
    }
}

function Invoke-DownloadWithRetry {
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] [string]$OutFile,
        [int]$MaxAttempts = 3,
        [int]$TimeoutSec = 600
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec $TimeoutSec
            return
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw "ダウンロードに失敗しました ($Uri): $_"
            }
            Write-InstallLog "ダウンロードに失敗しました。再試行します ($attempt/$MaxAttempts): $Uri" -IsError
            Start-Sleep -Seconds 5
        }
    }
}

function Invoke-WslScript {
    param(
        [Parameter(Mandatory)] [string]$ScriptPath,
        [switch]$NeedsBashEnv,
        [string]$FailureMessage = 'WSL内スクリプトの実行に失敗しました'
    )
    # common.shの内容を結合してから渡す。各wsl呼び出しは新規bashプロセスのため
    # 個別にsourceする手段がなく、結合が最も単純な共有方法となる
    $commonPath = Join-Path (Split-Path -Parent $ScriptPath) 'common.sh'
    $content = ((Get-Content -Raw -Path $commonPath) + "`n" + (Get-Content -Raw -Path $ScriptPath)) -replace "`r?`n", "`n"
    # PowerShell 5.1のstdinパイプはCRLFを挿入するため、base64経由で安全に渡す
    $contentB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    # echo|base64|bash パターンは bash がスクリプトを stdin から読むため、
    # 子プロセス(claude/bluelamp1等)が残りのスクリプト内容を stdin から消費し
    # bash が構文エラーになる。/tmp ファイル経由で実行することで回避する。
    $tmpFile = '/tmp/bluelamp_wsl_run.sh'
    if ($NeedsBashEnv) {
        wsl.exe -d $script:WslDistroName -u $script:WslUser -- bash -c "echo '$contentB64' | base64 -d > '$tmpFile' && env BASH_ENV='$($script:WslBashEnvPath)' bash '$tmpFile'; _rc=`$?; rm -f '$tmpFile'; exit `$_rc"
    } else {
        wsl.exe -d $script:WslDistroName -u $script:WslUser -- bash -c "echo '$contentB64' | base64 -d > '$tmpFile' && bash '$tmpFile'; _rc=`$?; rm -f '$tmpFile'; exit `$_rc"
    }

    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (終了コード: $LASTEXITCODE)"
    }
}
