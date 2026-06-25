#Requires -Version 5.1

function Test-ResumeTaskRegistered {
    $null = schtasks /query /tn 'BlueLampInstallerResume' 2>$null
    $LASTEXITCODE -eq 0
}

function Register-ResumeTask {
    param([Parameter(Mandatory)] [string]$InstallScriptPath)

    if (Test-ResumeTaskRegistered) {
        schtasks /delete /tn 'BlueLampInstallerResume' /f | Out-Null
    }

    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallScriptPath`" -Resume"
    schtasks /create /tn 'BlueLampInstallerResume' /sc ONLOGON /tr $command /rl HIGHEST /f | Out-Null

    if (-not (Test-ResumeTaskRegistered)) {
        # 登録確認に失敗した場合、再起動すると再開不能になるため再起動自体を中止する
        throw '再起動後の再開タスクの登録に失敗しました。再起動を中止します。'
    }

    Write-InstallLog '再起動が必要です。再ログイン後、インストーラーが自動的に再開します。10秒後に再起動します...'
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}

function Unregister-ResumeTask {
    # 再開タスクは1回限りの発火とするため、再開実行の最初に必ず自己削除する
    if (Test-ResumeTaskRegistered) {
        schtasks /delete /tn 'BlueLampInstallerResume' /f | Out-Null
    }
}
