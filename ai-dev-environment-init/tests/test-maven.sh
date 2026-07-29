#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
HOME="$test_home"
source "$ROOT/lib/logging.sh"
source "$ROOT/lib/platform.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/scripts/bootstrap.sh"
configure_maven_mirrors
settings="$test_home/.m2/settings.xml"
[[ -f "$settings" ]]
grep -Fq 'https://maven.aliyun.com/repository/public' "$settings"
grep -Fq 'https://repo.huaweicloud.com/repository/maven/' "$settings"
configure_maven_mirrors
[[ "$(grep -Fc 'tu-devkit maven mirrors' "$settings")" == 1 ]]
printf 'maven mirror test passed\n'
