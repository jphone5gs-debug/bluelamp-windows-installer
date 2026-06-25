#!/usr/bin/env bash
set -euo pipefail

install_node_in_wsl() {
    if command -v node >/dev/null 2>&1; then
        local current_version
        current_version="$(node -v)"
        log_info "既にNode.js導入済みです: ${current_version}"
        return 0
    fi

    local nvm_version="v0.40.1"
    local nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"

    log_info "nvm ${nvm_version} をダウンロードしています..."
    if ! retry 3 curl -fsSL "${nvm_install_url}" -o /tmp/nvm-install.sh; then
        log_error "nvm ${nvm_version} のダウンロードに失敗しました (URLが404になっている可能性があります: ${nvm_install_url})"
        exit 1
    fi

    log_info "nvm ${nvm_version} をインストールしています..."
    if ! bash /tmp/nvm-install.sh; then
        log_error "nvm ${nvm_version} のインストールスクリプト実行に失敗しました"
        rm -f /tmp/nvm-install.sh
        exit 1
    fi
    rm -f /tmp/nvm-install.sh

    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1091
    . "${NVM_DIR}/nvm.sh"

    log_info "Node.js LTSをインストールしています..."
    if ! nvm install --lts; then
        log_error "Node.js LTSのインストールに失敗しました"
        exit 1
    fi

    local installed_version
    installed_version="$(node -v)"
    log_info "Node.js導入完了: ${installed_version}"
}

install_node_in_wsl
