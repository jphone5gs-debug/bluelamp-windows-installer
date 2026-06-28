#Requires -Version 5.1

function Enable-WSLFeature {
    $wslEnabled = $false
    $vmEnabled = $false
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
        $wslEnabled = ($wslFeature.State -eq 'Enabled')
        $vmEnabled = ($vmFeature.State -eq 'Enabled')
        # EnablePending = 有効化済み・再起動待ち。再度有効化を試みるとエラーになるためここで終了
        if (($wslFeature.State -like '*Pending') -or ($vmFeature.State -like '*Pending')) {
            Write-InstallLog 'WSL機能の有効化は完了済みです（再起動して続きを実行します）。'
            return $true
        }
    } catch { $null = $_ }

    if ($wslEnabled -and $vmEnabled) {
        Write-InstallLog 'WSL機能は既に有効化済みです。'
        return $false
    }

    Write-InstallLog 'WSL2を有効化しています...'

    # $ErrorActionPreference = 'Stop'環境ではネイティブコマンドのstderr出力が
    # NativeCommandErrorとして捕捉されterminatingになる場合があるためtry-catchで包む
    $wslInstallExitCode = 0
    try {
        wsl.exe --install --no-distribution
        $wslInstallExitCode = $LASTEXITCODE
    } catch {
        $wslInstallExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
    }

    if ($wslInstallExitCode -eq 0) {
        return $true
    }

    # wsl --installが失敗: wsl --updateでWSLカーネルを更新してから機能状態を再確認する
    Write-InstallLog 'WSLカーネル更新を試みています (wsl --update)...'
    $wslUpdateExitCode = 0
    try {
        wsl.exe --update
        $wslUpdateExitCode = $LASTEXITCODE
    } catch {
        $wslUpdateExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
    }

    if ($wslUpdateExitCode -eq 0) {
        # wsl --update成功後、機能が有効化されているか再確認する
        try {
            $recheckWsl = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
            $recheckVm = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
            $wslAfter = $recheckWsl.State -in @('Enabled', 'EnablePending')
            $vmAfter = $recheckVm.State -in @('Enabled', 'EnablePending')
            if ($wslAfter -and $vmAfter) {
                $needsRestart = ($recheckWsl.State -eq 'EnablePending') -or ($recheckVm.State -eq 'EnablePending')
                Write-InstallLog "WSL機能は有効化されています$(if ($needsRestart) { '（再起動して続きを実行します）' })。"
                return $needsRestart
            }
        } catch { $null = $_ }
        # Windows 11ではWSLがパッケージ型でOptionalFeatureに現れない場合があるため再起動を促す
        Write-InstallLog 'WSLカーネル更新完了。再起動して続きを実行します。'
        return $true
    }

    # wsl --updateも失敗: 旧Windows/企業環境向けDISMフォールバック
    Write-InstallLog 'Windows機能を直接有効化します (フォールバック)...'
    $restartNeeded = $false
    try {
        if (-not $wslEnabled) {
            Write-InstallLog 'Windows機能 (WSL) を有効化しています...'
            $result = Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart
            if ($result.RestartNeeded) { $restartNeeded = $true }
        }
        if (-not $vmEnabled) {
            Write-InstallLog 'Windows機能 (VirtualMachinePlatform) を有効化しています...'
            $result = Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -All -NoRestart
            if ($result.RestartNeeded) { $restartNeeded = $true }
        }
    } catch { throw "WSL2の有効化に失敗しました: $_" }
    $restartNeeded
}
