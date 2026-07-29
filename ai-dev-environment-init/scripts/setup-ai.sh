#!/usr/bin/env bash

setup_ai_main() {
  log_info 'Initializing AI development environment'
  install_profile ai-dev-environment "$@"
}
