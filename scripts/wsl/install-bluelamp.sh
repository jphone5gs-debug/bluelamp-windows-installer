#!/usr/bin/env bash
set -euo pipefail

install_bluelamp_in_wsl() {
    if command -v bluelamp1 >/dev/null 2>&1; then
        log_info "BlueLamp(npm)は既に導入済みです: $(command -v bluelamp1)"
    else
        log_info "BlueLampをインストールしています (npm install -g bluelamp)..."
        if ! retry 3 npm install -g bluelamp; then
            log_error "npm install -g bluelamp に失敗しました"
            exit 1
        fi
        if ! command -v bluelamp1 >/dev/null 2>&1; then
            log_error "BlueLampのインストール確認(bluelamp1)に失敗しました"
            exit 1
        fi
        log_info "BlueLamp導入完了: $(command -v bluelamp1)"
    fi

    # wsl -d BlueLamp -- bluelamp1 のような非ログインシェルでも使えるよう
    # /usr/local/bin にラッパーを作成する（nvm の PATH が読まれない環境向け）
    if [[ ! -x /usr/local/bin/bluelamp1 ]]; then
        local installed_path
        installed_path="$(command -v bluelamp1)"
        log_info "bluelamp1 をシステム共通 PATH に登録しています..."
        printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "${installed_path}" \
            | sudo tee /usr/local/bin/bluelamp1 > /dev/null
        sudo chmod +x /usr/local/bin/bluelamp1
    fi
}

install_bluelamp_in_wsl
