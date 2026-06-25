#!/usr/bin/env bash
set -euo pipefail

install_claude_code_in_wsl() {
    # ネイティブインストーラーは~/.local/binに配置するが、非ログインシェルでは
    # .bashrc/.profileが読まれずPATHに乗らないため明示的に追加する
    export PATH="${HOME}/.local/bin:${PATH}"

    if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
        local current_version
        current_version="$(claude --version)"
        log_info "既にClaude Code導入済みです: ${current_version}"
        return 0
    fi

    log_info "Claude Code CLIをインストールしています..."
    if ! curl -fsSL https://claude.ai/install.sh | bash; then
        log_error "Claude Code CLIのインストールスクリプト実行に失敗しました"
        exit 1
    fi

    # 終了コードだけでなく実際に動作するかをここで確定させる(壊れたバイナリの早期検出)
    if ! claude --version >/dev/null 2>&1; then
        log_error "Claude Code CLIのインストール確認(claude --version)に失敗しました"
        exit 1
    fi

    local installed_version
    installed_version="$(claude --version)"
    log_info "Claude Code導入完了: ${installed_version}"
}

install_claude_code_in_wsl
