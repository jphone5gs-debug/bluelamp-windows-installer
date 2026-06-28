#!/usr/bin/env bash
set -euo pipefail

invoke_claude_code_login() {
    export PATH="${HOME}/.local/bin:${PATH}"
    local creds_file="${HOME}/.claude/.credentials.json"

    if [[ -f "${creds_file}" ]]; then
        log_info "Claude Codeは既にログイン済みです。"
        return 0
    fi

    log_info "ブラウザでClaude Codeのログイン画面が開きます。ログインを完了してください。"
    # OAuth はブラウザで完了するため stdin は不要。</dev/null でREPLを即時終了させる
    claude </dev/null || true

    if [[ ! -f "${creds_file}" ]]; then
        log_error "ログインが完了していません。ブラウザでログインを完了してから、インストーラーを再度実行してください。"
        exit 1
    fi

    log_info "Claude Codeのログインが完了しました。"
}

invoke_claude_code_login
