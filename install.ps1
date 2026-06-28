#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Resume
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-FatalErrorAndExit {
    param($ErrorRecord)
    Write-Host "[BlueLampインストーラー] 失敗しました: $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    Write-Host '[BlueLampインストーラー] もう一度同じコマンドを実行すれば、完了済みの手順はスキップして続きから再開します。' -ForegroundColor Yellow
    # $script:LogPathはCommon.ps1 dot-source後に定義される。bootstrap失敗時は未定義のため存在確認する
    if ($script:LogPath) {
        try {
            $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Add-Content -Path $script:LogPath -Value "$ts [ERROR] 失敗しました: $($ErrorRecord.Exception.Message)" -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            $null = $_
        }
    }
    exit 1
}

function Invoke-BootstrapDownloadWithRetry {
    # Common.ps1のInvoke-DownloadWithRetryと同等だが、この時点ではまだdot-source不可なため複製する
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] [string]$OutFile,
        [int]$MaxAttempts = 3
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 120
            return
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw "ダウンロードに失敗しました ($Uri): $_"
            }
            Write-Host "[BlueLampインストーラー] ダウンロードに失敗しました。再試行します ($attempt/$MaxAttempts): $Uri" -ForegroundColor Red
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $PSScriptRoot) {
    # irm | iex 実行時は$PSScriptRootが無くscripts/配下を参照できない。
    # schtasksの/trにも実ファイルパスが必要なため、ローカルにリポジトリを展開して自分自身を再実行する。
    try {
        $zipUrl = 'https://github.com/jphone5gs-debug/bluelamp-windows-installer/archive/refs/heads/main.zip'
        $localRoot = Join-Path $env:LOCALAPPDATA 'BlueLampInstaller'
        $repoPath = Join-Path $localRoot 'repo'
        $zipPath = Join-Path $localRoot 'repo.zip'
        $extractPath = Join-Path $localRoot 'repo_extract'

        Write-Host '[BlueLampインストーラー] インストーラー本体をローカルにダウンロードしています...' -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $localRoot -Force | Out-Null

        Invoke-BootstrapDownloadWithRetry -Uri $zipUrl -OutFile $zipPath

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
    } catch {
        Write-FatalErrorAndExit $_
    }

    # システムの実行ポリシーでローカル.ps1ファイルの実行が無効な場合があるため、
    # schtasks再開タスクと同じ-ExecutionPolicy Bypassで新規プロセスとして起動する
    # (irm | iexによる文字列実行自体は実行ポリシーの対象外だが、`&`でのローカルファイル実行は対象になる)
    $installerPath = Join-Path $repoPath 'install.ps1'
    # 日本語WindowsのPowerShell 5.1はBOMなしUTF-8をShift-JISとして読む。
    # GitHub上はBOMなしのまま維持し、展開後に全.ps1ファイルへBOMを付与する。
    # Expand-ArchiveがBOMを除去する場合の防衛的処理も兼ねる。
    $bom = [byte[]](0xEF, 0xBB, 0xBF)
    Get-ChildItem -Path $repoPath -Filter '*.ps1' -Recurse | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($bytes.Length -gt 0 -and $bytes[0] -ne 0xEF) {
            [System.IO.File]::WriteAllBytes($_.FullName, [byte[]]($bom + $bytes))
        }
    }
    if ($Resume) {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$installerPath" -Resume
    } else {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$installerPath"
    }
    # exit を使うと irm|iex のホストPowerShellウィンドウが閉じてしまうため使用しない
    # if ($PSScriptRoot) ガードにより以降のメインコードはiexコンテキストでは実行されない
}

# --- ここから先は $PSScriptRoot が実ファイルパスとして存在する状態（-File実行時のみ）---
if (-not $PSScriptRoot) { return }

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
    param($CommonPath, $ModulePath, $WslUser, $BashEnvPath, $NeedsBashEnv, $DistroName)
    $content = ((Get-Content -Raw -Path $CommonPath) + "`n" + (Get-Content -Raw -Path $ModulePath)) -replace "`r?`n", "`n"
    $contentB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    if ($NeedsBashEnv) {
        wsl.exe -d $DistroName -u $WslUser -- env "BASH_ENV=$BashEnvPath" bash -c "echo '$contentB64' | base64 -d | bash"
    } else {
        wsl.exe -d $DistroName -u $WslUser -- bash -c "echo '$contentB64' | base64 -d | bash"
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
            $commonShPath, (Join-Path $wslDir 'install-node.sh'), $script:WslUser, $script:WslBashEnvPath, $true, $script:WslDistroName
        $claudeJob = Start-Job -Name 'S-006' -ScriptBlock $wslParallelJobScript -ArgumentList `
            $commonShPath, (Join-Path $wslDir 'install-claude-code.sh'), $script:WslUser, $script:WslBashEnvPath, $false, $script:WslDistroName

        Wait-Job $nodeJob, $claudeJob | Out-Null

        foreach ($job in @($nodeJob, $claudeJob)) {
            try {
                Receive-Job -Job $job -ErrorAction Stop | ForEach-Object {
                    Write-Host $_
                    try {
                        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                        Add-Content -Path $script:LogPath -Value "$ts [INFO] $_" -Encoding UTF8 -ErrorAction SilentlyContinue
                    } catch {
                        $null = $_
                    }
                }
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
        # bash -l でログインシェルを起動することで .bashrc → nvm が読み込まれ
        # claude/bluelamp1 が PATH に乗る。base64パイプを経由しないため
        # 子プロセスによる stdin 消費・構文エラー問題が根本から起きない。

        # S-008: Claude Code OAuth ログイン
        $credsFile = "/home/$script:WslUser/.claude/.credentials.json"
        wsl.exe -d $script:WslDistroName -u $script:WslUser -- test -f $credsFile
        if ($LASTEXITCODE -eq 0) {
            Write-InstallLog 'Claude Codeは既にログイン済みです。'
        } else {
            Write-InstallLog 'ブラウザでClaude Codeのログイン画面が開きます。ログインを完了してください。'
            wsl.exe -d $script:WslDistroName -u $script:WslUser -- bash -l -c 'claude </dev/null || true'
            wsl.exe -d $script:WslDistroName -u $script:WslUser -- test -f $credsFile
            if ($LASTEXITCODE -ne 0) {
                throw 'Claude Codeのログインが完了していません。インストーラーを再実行してください。'
            }
            Write-InstallLog 'Claude Codeのログインが完了しました。'
        }

        # S-009: BlueLamp ポータルログイン
        $tokenFile = "/home/$script:WslUser/.musuhi/portal-token.enc"
        wsl.exe -d $script:WslDistroName -u $script:WslUser -- test -f $tokenFile
        if ($LASTEXITCODE -eq 0) {
            Write-InstallLog 'BlueLampは既にログイン済みです。'
        } else {
            Write-InstallLog 'ブラウザでBlueLampポータルのログイン画面が開きます。ログインを完了してください。'
            wsl.exe -d $script:WslDistroName -u $script:WslUser -- bash -l -c 'bluelamp1 </dev/null || true'
            wsl.exe -d $script:WslDistroName -u $script:WslUser -- test -f $tokenFile
            if ($LASTEXITCODE -ne 0) {
                throw 'BlueLampのログインが完了していません。インストーラーを再実行してください。'
            }
            Write-InstallLog 'BlueLampのログインが完了しました。'
        }

        $nextStep = 'S-010'
        Save-InstallState -NextStep $nextStep
    }

    Remove-InstallState
    Show-CompletionGuide
} catch {
    Write-FatalErrorAndExit $_
}
