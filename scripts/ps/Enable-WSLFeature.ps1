#Requires -Version 5.1

function Enable-WSLFeature {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'

    if ($wslFeature.State -eq 'Enabled' -and $vmFeature.State -eq 'Enabled') {
        Write-InstallLog 'WSL機能は既に有効化済みです。'
        return $false
    }

    $restartNeeded = $false
    try {
        if ($wslFeature.State -ne 'Enabled') {
            Write-InstallLog 'Windows機能 (WSL) を有効化しています...'
            $result = Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -NoRestart
            if ($result.RestartNeeded) { $restartNeeded = $true }
        }
        if ($vmFeature.State -ne 'Enabled') {
            Write-InstallLog 'Windows機能 (VirtualMachinePlatform) を有効化しています...'
            $result = Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -NoRestart
            if ($result.RestartNeeded) { $restartNeeded = $true }
        }
    } catch {
        throw "Windows機能の有効化に失敗しました: $_"
    }

    $restartNeeded
}
