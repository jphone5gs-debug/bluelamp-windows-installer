#!/usr/bin/env bash
# 各モジュールスクリプトの先頭でsourceする共通ヘルパー

log_info() {
    echo "[bluelamp-installer] $1"
}

log_error() {
    echo "[bluelamp-installer] ERROR: $1" >&2
}

# 一時的なネットワーク不調のみを対象とした有限回(既定3回)の再試行。
# 曖昧な無限リトライやフォールバックはしない(失敗し続ければ最終的にそのまま失敗させる)
retry() {
    local max_attempts="$1"
    shift
    local attempt=1
    until "$@"; do
        if [[ "${attempt}" -ge "${max_attempts}" ]]; then
            return 1
        fi
        log_info "失敗しました。再試行します (${attempt}/${max_attempts}): $*"
        attempt=$((attempt + 1))
        sleep 5
    done
}
