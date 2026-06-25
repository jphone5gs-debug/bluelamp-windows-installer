#!/usr/bin/env bash
set -euo pipefail

install_bluelamp_in_wsl() {
    if command -v bluelamp1 >/dev/null 2>&1; then
        local current_path
        current_path="$(command -v bluelamp1)"
        log_info "既にBlueLamp導入済みです: ${current_path}"
        return 0
    fi

    log_info "BlueLampをインストールしています (npm install -g bluelamp)..."
    if ! npm install -g bluelamp; then
        log_error "npm install -g bluelamp に失敗しました"
        exit 1
    fi

    if ! command -v bluelamp1 >/dev/null 2>&1; then
        log_error "BlueLampのインストール確認(bluelamp1)に失敗しました"
        exit 1
    fi

    local installed_path
    installed_path="$(command -v bluelamp1)"
    log_info "BlueLamp導入完了: ${installed_path}"
}

install_bluelamp_in_wsl
