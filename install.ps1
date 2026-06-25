#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Resume
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $PSScriptRoot) {
    # irm | iex 実行時は$PSScriptRootが無くscripts/配下を参照できない。
    # schtasksの/trにも実ファイルパスが必要なため、ローカルにリポジトリを展開して自分自身を再実行する。
    $zipUrl = 'https://github.com/jphone5gs-debug/bluelamp-windows-installer/archive/refs/heads/main.zip'
    $localRoot = Join-Path $env:LOCALAPPDATA 'BlueLampInstaller'
    $repoPath = Join-Path $localRoot 'repo'
    $zipPath = Join-Path $localRoot 'repo.zip'
    $extractPath = Join-Path $localRoot 'repo_extract'

    Write-Host '[BlueLampインストーラー] インストーラー本体をローカルにダウンロードしています...' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $localRoot -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        throw "インストーラー本体のダウンロードに失敗しました ($zipUrl): $_"
    }

    if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Remove-Item -Path $zipPath -Force

    $extractedDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
    if (-not $extractedDir) {
        throw "ダウンロードしたアーカイブの展開結果が不正です: $extractPath"
    }

    if (Test-Path $repoPath) { Remove-Item -Path $repoPath -Recurse -Force }
    Move-Item -Path $extractedDir.FullName -Destination $repoPath
    Remove-Item -Path $extractPath -Recurse -Force

    & (Join-Path $repoPath 'install.ps1') @PSBoundParameters
    exit $LASTEXITCODE
}

# --- ここから先は $PSScriptRoot が実ファイルパスとして存在する状態 ---

$RepoRoot = $PSScriptRoot

. (Join-Path $RepoRoot 'scripts/ps/Common.ps1')
. (Join-Path $RepoRoot 'scripts/ps/Test-WSLStatus.ps1')
. (Join-Path $RepoRoot 'scripts/ps/Enable-WSLFeature.ps1')
. (Join-Path $RepoRoot 'scripts/ps/Register-ResumeTask.ps1')
. (Join-Path $RepoRoot 'scripts/ps/Import-UbuntuDistro.ps1')
. (Join-Path $RepoRoot 'scripts/ps/Show-CompletionGuide.ps1')

$wslDir = Join-Path $RepoRoot 'scripts/wsl'
$commonShPath = Join-Path $wslDir 'common.sh'

$wslParallelJobScript = {
    param($CommonPath, $ModulePath, $WslUser, $BashEnvPath, $NeedsBashEnv)
    $content = (Get-Content -Raw -Path $CommonPath) + "`n" + (Get-Content -Raw -Path $ModulePath)
    if ($NeedsBashEnv) {
        $content | wsl.exe -d Ubuntu -u $WslUser -- env "BASH_ENV=$BashEnvPath" bash -s --
    } else {
        $content | wsl.exe -d Ubuntu -u $WslUser -- bash -s --
    }
    if ($LASTEXITCODE -ne 0) {
        throw "WSL内スクリプトの実行に失敗しました (終了コード: $LASTEXITCODE): $ModulePath"
    }
}

try {
    Assert-Administrator

    if ($Resume) {
        Unregister-ResumeTask
        $nextStep = (Read-InstallState).NextStep
    } else {
        $nextStep = 'S-001'
    }

    if ($nextStep -eq 'S-001') {
        $status = Test-WSLStatus
        if (-not $status.WslFeatureEnabled -or -not $status.VmPlatformEnabled) {
            $restartNeeded = Enable-WSLFeature
            if ($restartNeeded) {
                Save-InstallState -NextStep 'S-004'
                Register-ResumeTask -InstallScriptPath (Join-Path $RepoRoot 'install.ps1')
                return
            }
        }
        $nextStep = 'S-004'
        Save-InstallState -NextStep $nextStep
    }

    if ($nextStep -eq 'S-004') {
        Import-UbuntuDistro
        $nextStep = 'S-005-006'
        Save-InstallState -NextStep $nextStep
    }

    if ($nextStep -eq 'S-005-006') {
        Write-InstallLog 'Node.jsとClaude Code CLIを並行して導入しています...'
        $nodeJob = Start-Job -Name 'S-005' -ScriptBlock $wslParallelJobScript -ArgumentList `
            $commonShPath, (Join-Path $wslDir 'install-node.sh'), $script:WslUser, $script:WslBashEnvPath, $true
        $claudeJob = Start-Job -Name 'S-006' -ScriptBlock $wslParallelJobScript -ArgumentList `
            $commonShPath, (Join-Path $wslDir 'install-claude-code.sh'), $script:WslUser, $script:WslBashEnvPath, $false

        Wait-Job $nodeJob, $claudeJob | Out-Null

        foreach ($job in @($nodeJob, $claudeJob)) {
            try {
                Receive-Job -Job $job -ErrorAction Stop | ForEach-Object { Write-Host $_ }
            } catch {
                Write-InstallLog "$($job.Name): $_" -IsError
            }
        }

        $failedJobs = @($nodeJob, $claudeJob) | Where-Object { $_.State -eq 'Failed' }
        Remove-Job $nodeJob, $claudeJob -Force

        if ($failedJobs) {
            throw "並列処理が失敗しました: $($failedJobs.Name -join ', ')"
        }

        $nextStep = 'S-007'
        Save-InstallState -NextStep $nextStep
    }

    if ($nextStep -eq 'S-007') {
        Invoke-WslScript -ScriptPath (Join-Path $wslDir 'install-bluelamp.sh') -NeedsBashEnv `
            -FailureMessage 'BlueLampのインストールに失敗しました'
        $nextStep = 'S-008-009'
        Save-InstallState -NextStep $nextStep
    }

    if ($nextStep -eq 'S-008-009') {
        # S-008/S-009は依存関係上は独立だが、対話的でコンソールを共有するため逐次実行する
        Invoke-WslScript -ScriptPath (Join-Path $wslDir 'invoke-claude-login.sh') `
            -FailureMessage 'Claude Codeのログインに失敗しました'
        Invoke-WslScript -ScriptPath (Join-Path $wslDir 'invoke-bluelamp-login.sh') -NeedsBashEnv `
            -FailureMessage 'BlueLampのログインに失敗しました'
        $nextStep = 'S-010'
        Save-InstallState -NextStep $nextStep
    }

    Show-CompletionGuide
    Remove-InstallState
} catch {
    Write-Host "[BlueLampインストーラー] 失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
