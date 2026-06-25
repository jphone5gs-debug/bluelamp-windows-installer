#Requires -Version 5.1

$script:StateDir = Join-Path $env:LOCALAPPDATA 'BlueLampInstaller'
$script:StatePath = Join-Path $script:StateDir 'state.json'
$script:WslUser = 'bluelamp'
$script:WslBashEnvPath = "/home/$script:WslUser/.bluelamp_bash_env"

function Write-InstallLog {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [switch]$IsError
    )
    $prefix = '[BlueLampインストーラー]'
    if ($IsError) {
        Write-Host "$prefix $Message" -ForegroundColor Red
    } else {
        Write-Host "$prefix $Message" -ForegroundColor Cyan
    }
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'このスクリプトは管理者として実行する必要があります。PowerShellを「管理者として実行」で開き直してください。'
    }
}

function Set-SecureTlsProtocol {
    # プロセス内のTLS既定値設定のみで対話確認の必要がないため、ShouldProcessは実装しない
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    # GitHub Raw等の配布元はTLS1.2必須だが、古いWindows 10は既定でTLS1.2が無効なため明示する
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
    if (-not (Test-Path $script:StatePath)) {
        throw "状態ファイルが見つかりません ($script:StatePath)。インストーラーを最初から再実行してください: irm https://raw.githubusercontent.com/jphone5gs-debug/bluelamp-windows-installer/main/install.ps1 | iex"
    }
    Get-Content -Raw -Path $script:StatePath | ConvertFrom-Json
}

function Remove-InstallState {
    # 自動実行フローの内部クリーンアップであり対話確認の対象ではないため、ShouldProcessは実装しない
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    if (Test-Path $script:StatePath) {
        Remove-Item -Path $script:StatePath -Force
    }
}

function Invoke-WslScript {
    # 対話処理(S-008/S-009)・非対話処理(S-007)とも標準出力はコンソールへ素通しする。
    # スクリプト内容はstdin経由で渡すため、ユーザーの対話操作はブラウザ側で行われる前提
    # (Claude Code OAuth・BlueLampポータルログインともURLを開いて完了する方式で、
    # ターミナルへのキー入力を必要としない)。
    param(
        [Parameter(Mandatory)] [string]$ScriptPath,
        [switch]$NeedsBashEnv,
        [string]$FailureMessage = 'WSL内スクリプトの実行に失敗しました'
    )
    # common.shの内容を結合してから渡す。各wsl呼び出しは新規bashプロセスのため
    # 個別にsourceする手段がなく、結合が最も単純な共有方法となる
    $commonPath = Join-Path (Split-Path -Parent $ScriptPath) 'common.sh'
    $content = (Get-Content -Raw -Path $commonPath) + "`n" + (Get-Content -Raw -Path $ScriptPath)

    if ($NeedsBashEnv) {
        $content | wsl.exe -d Ubuntu -u $script:WslUser -- env "BASH_ENV=$script:WslBashEnvPath" bash -s --
    } else {
        $content | wsl.exe -d Ubuntu -u $script:WslUser -- bash -s --
    }

    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (終了コード: $LASTEXITCODE)"
    }
}
