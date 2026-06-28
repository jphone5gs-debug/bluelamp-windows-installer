#!/usr/bin/env bash
set -euo pipefail

invoke_bluelamp_login() {
    local token_file="${HOME}/.musuhi/portal-token.enc"

    if [[ -f "${token_file}" ]]; then
        log_info "BlueLampは既にログイン済みです。"
        return 0
    fi

    log_info "ブラウザでBlueLampポータルのログイン画面が開きます。ログインを完了してください。"
    # OAuth はブラウザで完了するため stdin は不要。</dev/null でログイン後のプロセスを即時終了させる
    bluelamp1 </dev/null || true

    if [[ ! -f "${token_file}" ]]; then
        log_error "ログインが完了していません。ブラウザでログインを完了してから、インストーラーを再度実行してください。"
        exit 1
    fi

    log_info "BlueLampのログインが完了しました。"
}

invoke_bluelamp_login
