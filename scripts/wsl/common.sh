#!/usr/bin/env bash
# 各モジュールスクリプトの先頭でsourceする共通ヘルパー

log_info() {
    echo "[bluelamp-installer] $1"
}

log_error() {
    echo "[bluelamp-installer] ERROR: $1" >&2
}
