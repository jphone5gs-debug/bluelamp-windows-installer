#Requires -Version 5.1

function Enable-WSLFeature {
    $wslEnabled = $false
    $vmEnabled = $false
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
        $wslEnabled = ($wslFeature.State -eq 'Enabled')
        $vmEnabled = ($vmFeature.State -eq 'Enabled')
    } catch {
        $null = $_
    }

    if ($wslEnabled -and $vmEnabled) {
        Write-InstallLog 'WSL機能は既に有効化済みです。'
        return $false
    }

    Write-InstallLog 'WSL2を有効化しています...'
    # wsl --install はDISMより堅牢でソースファイルを自動解決する(Windows 10 21H2以降/Windows 11)
    wsl.exe --install --no-distribution
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    # フォールバック: wsl --installが利用できない旧Windows向け
    Write-InstallLog 'Windows機能を直接有効化します(フォールバック)...'
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
    } catch {
        throw "WSL2の有効化に失敗しました: $_"
    }
    $restartNeeded
}
