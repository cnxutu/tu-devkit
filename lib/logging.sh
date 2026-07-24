#!/usr/bin/env bash
log() { printf '[%s] %s\n' "$1" "$2"; }
log_info() { log INFO "$1"; }
log_ok() { log OK "$1"; }
log_warn() { log WARN "$1" >&2; }
log_error() { log ERROR "$1" >&2; }
log_skip() { log SKIP "$1"; }
