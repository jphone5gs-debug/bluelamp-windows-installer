#!/usr/bin/env bash
set -euo pipefail

invoke_bluelamp_login() {
    local token_file="${HOME}/.musuhi/portal-token.enc"

    if [[ -f "${token_file}" ]]; then
        log_info "BlueLampは既にログイン済みです。"
        return 0
    fi

    log_info "ブラウザでBlueLampポータルのログイン画面が開きます。ログインを完了してください。"
    # bluelamp1はInteractiveLoginを起動する。終了挙動はinvoke-claude-login.shと同様の前提(要実機確認)
    bluelamp1 || true

    if [[ ! -f "${token_file}" ]]; then
        log_error "ログインが完了していません。ブラウザでログインを完了してから、インストーラーを再度実行してください。"
        exit 1
    fi

    log_info "BlueLampのログインが完了しました。"
}

invoke_bluelamp_login
