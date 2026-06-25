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
    # claudeはOAuth完了後にREPLへ入るが、本スクリプトのstdinはここでEOFとなるため
    # REPLはEOFを受けて終了する想定。実機での挙動確認が必要(docs/SCOPE_PROGRESS.md Phase10参照)
    claude || true

    if [[ ! -f "${creds_file}" ]]; then
        log_error "ログインが完了していません。ブラウザでログインを完了してから、インストーラーを再度実行してください。"
        exit 1
    fi

    log_info "Claude Codeのログインが完了しました。"
}

invoke_claude_code_login
