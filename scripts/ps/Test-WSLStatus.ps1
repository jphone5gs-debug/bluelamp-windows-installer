#Requires -Version 5.1

function Test-WSLStatus {
    $wslFeature = $null
    $vmFeature = $null
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux'
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform'
    } catch {
        # 取得失敗時は未有効として続行し、Enable-WSLFeatureに処理を委ねる
        $null = $_
    }

    $ubuntuImported = $false
    try {
        # wsl.exeはUTF-16LEで出力するため、PowerShellでキャプチャするとnull文字が混入する場合がある
        # WSL未インストール環境ではwsl.exeが例外を投げる場合があるが、その場合はUbuntuImported=falseで継続する
        $distroList = (wsl.exe -l -v 2>$null) -replace "`0", ''
        $distroPattern = [regex]::Escape($script:WslDistroName)
        $ubuntuImported = ($distroList | Select-String -Pattern "^\*?\s*$distroPattern\s" -Quiet)
    } catch {
        $null = $_
    }

    [pscustomobject]@{
        WslFeatureEnabled = ($null -ne $wslFeature -and $wslFeature.State -eq 'Enabled')
        VmPlatformEnabled = ($null -ne $vmFeature -and $vmFeature.State -eq 'Enabled')
        UbuntuImported    = [bool]$ubuntuImported
        # 既存の保留中再起動(他の操作起因)を検知するためのフラグ。
        # 今回の有効化操作自体が再起動を要するかは Enable-WSLFeature の戻り値が正とする
        RestartNeeded     = ($null -ne $wslFeature -and $wslFeature.State -like '*Pending') -or
                            ($null -ne $vmFeature -and $vmFeature.State -like '*Pending')
    }
}
