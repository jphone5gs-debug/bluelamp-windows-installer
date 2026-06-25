#Requires -Version 5.1

function Import-UbuntuDistro {
    $existing = (wsl.exe -l -v 2>$null) -replace "`0", ''
    if ($existing | Select-String -Pattern '^\*?\s*Ubuntu\s' -Quiet) {
        Write-InstallLog 'Ubuntuは既に導入済みです。'
        return
    }

    # S-002のRestartNeeded誤検出により、WSLエンジン未初期化のままここに到達するケースがあるため再確認する
    wsl.exe --status > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'WSL機能が未初期化です。再起動が必要な可能性があります。スクリプトを再実行してください。'
    }

    # Canonical公式WSL rootfs配布元。バージョン固定(Ubuntu 24.04 LTS / noble)
    $rootfsUrl = 'https://cloud-images.ubuntu.com/wsl/releases/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
    $installPath = Join-Path $env:LOCALAPPDATA 'BlueLampInstaller\WSL\Ubuntu'
    $tarballPath = Join-Path $env:TEMP 'ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'

    Write-InstallLog 'Ubuntuのrootfsをダウンロードしています(約340MB、回線速度により数分かかります)...'
    try {
        Invoke-WebRequest -Uri $rootfsUrl -OutFile $tarballPath -UseBasicParsing
    } catch {
        throw "Ubuntu rootfsのダウンロードに失敗しました ($rootfsUrl): $_"
    }

    New-Item -ItemType Directory -Path $installPath -Force | Out-Null

    Write-InstallLog 'Ubuntuをインポートしています...'
    wsl.exe --import Ubuntu $installPath $tarballPath --version 2
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --import に失敗しました (終了コード: $LASTEXITCODE)"
    }
    Remove-Item -Path $tarballPath -Force -ErrorAction SilentlyContinue

    Write-InstallLog '非対話ユーザーを作成しています...'
    # wsl --import直後はroot既定ログインのため、ここで非対話ユーザーを作成しwsl.confで既定化する
    $userSetupScript = @'
set -euo pipefail
if ! id -u "$WSL_TARGET_USER" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$WSL_TARGET_USER"
    usermod -aG sudo "$WSL_TARGET_USER"
    echo "$WSL_TARGET_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$WSL_TARGET_USER"
    chmod 0440 "/etc/sudoers.d/90-$WSL_TARGET_USER"
fi
cat > /etc/wsl.conf <<EOF
[user]
default=$WSL_TARGET_USER
EOF
USER_HOME="/home/$WSL_TARGET_USER"
cat > "$USER_HOME/.bluelamp_bash_env" <<'BASHENV'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
BASHENV
chown "$WSL_TARGET_USER:$WSL_TARGET_USER" "$USER_HOME/.bluelamp_bash_env"
'@

    $userSetupScript | wsl.exe -d Ubuntu -u root -- env "WSL_TARGET_USER=$script:WslUser" bash -s --
    if ($LASTEXITCODE -ne 0) {
        throw "Ubuntu内の非対話ユーザー作成に失敗しました (終了コード: $LASTEXITCODE)"
    }

    # wsl.confは起動時にのみ読まれるため、再起動して既定ユーザーを反映させる
    wsl.exe --terminate Ubuntu

    $whoami = (wsl.exe -d Ubuntu -- whoami 2>$null).Trim()
    if ($whoami -ne $script:WslUser) {
        throw "既定ユーザーの切り替えに失敗しました (検出されたユーザー: '$whoami'、期待値: '$script:WslUser')"
    }
}
