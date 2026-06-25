#Requires -Version 5.1

function Test-WSLStatus {
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
    } catch {
        throw "Windows機能の状態取得に失敗しました: $_"
    }

    $ubuntuImported = $false
    try {
        # wsl.exeはUTF-16LEで出力するため、PowerShellでキャプチャするとnull文字が混入する場合がある
        $distroList = (wsl.exe -l -v 2>$null) -replace "`0", ''
        $distroPattern = [regex]::Escape($script:WslDistroName)
        $ubuntuImported = ($distroList | Select-String -Pattern "^\*?\s*$distroPattern\s" -Quiet)
    } catch {
        throw "wsl -l -v の実行に失敗しました: $_"
    }

    [pscustomobject]@{
        WslFeatureEnabled = ($wslFeature.State -eq 'Enabled')
        VmPlatformEnabled = ($vmFeature.State -eq 'Enabled')
        UbuntuImported    = [bool]$ubuntuImported
        # 既存の保留中再起動(他の操作起因)を検知するためのフラグ。
        # 今回の有効化操作自体が再起動を要するかは Enable-WSLFeature の戻り値が正とする
        RestartNeeded     = ($wslFeature.State -like '*Pending') -or ($vmFeature.State -like '*Pending')
    }
}
