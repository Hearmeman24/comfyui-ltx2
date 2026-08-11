#!/usr/bin/env bash
# Covers the boot-time DNS preflight in src/start_script.sh.
#
# Runs the real entrypoint against a stubbed PATH: every name-resolution tool is
# forced to fail (that is what RunPod global networking does to a pod), and the
# things the entrypoint would otherwise do to the filesystem (git/rm/cp/bash) are
# replaced by echo-only stubs so the test cannot touch /comfyui-ltx2.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="$REPO/src/start_script.sh"
failures=0

make_stubs() {
    # $1 = exit code for the resolver stubs
    local dir="$1" resolver_rc="$2" tool
    mkdir -p "$dir"
    # /bin/sh shebangs, not `env bash` — `bash` itself is stubbed below.
    for tool in getent nslookup host dig ping curl wget python3; do
        printf '#!/bin/sh\nexit %s\n' "$resolver_rc" > "$dir/$tool"
    done
    # coreutils `timeout` exists on the Ubuntu image but not on every dev box;
    # pass it through so the test measures resolution, not timeout semantics.
    printf '#!/bin/sh\nshift\nexec "$@"\n' > "$dir/timeout"
    printf '#!/bin/sh\necho "SYNC RAN: git $*"\nexit 0\n' > "$dir/git"
    printf '#!/bin/sh\necho "START RAN"\nexit 0\n' > "$dir/bash"
    for tool in rm cp; do
        printf '#!/bin/sh\nexit 0\n' > "$dir/$tool"
    done
    chmod +x "$dir"/*
}

run_entrypoint() {
    local dir="$1"
    PATH="$dir:$PATH" /bin/bash "$ENTRYPOINT" 2>&1
}

check() {
    local label="$1" condition="$2"
    if [ "$condition" = "ok" ]; then
        echo "  PASS  $label"
    else
        echo "  FAIL  $label"
        failures=$((failures + 1))
    fi
}

contains() {
    grep -qi -- "$2" <<< "$1" && echo ok || echo no
}

# --- 1. DNS blocked: fail fast, name RunPod global networking, sync never runs.
echo "case: name resolution blocked"
blocked="$(mktemp -d)"
make_stubs "$blocked" 1
out="$(run_entrypoint "$blocked")"; rc=$?
rm -rf "$blocked"

check "exits non-zero"                  "$([ "$rc" -ne 0 ] && echo ok || echo no)"
check "names global networking"         "$(contains "$out" 'global networking')"
check "names the RunPod pod settings"   "$(contains "$out" 'runpod')"
check "repo sync never ran"             "$(contains "$out" 'SYNC RAN' | grep -q ok && echo no || echo ok)"
check "start.sh never ran"              "$(contains "$out" 'START RAN' | grep -q ok && echo no || echo ok)"

# --- 2. DNS fine: preflight is silent and boot proceeds to the repo sync.
echo "case: name resolution working"
working="$(mktemp -d)"
make_stubs "$working" 0
out="$(run_entrypoint "$working")"; rc=$?
rm -rf "$working"

check "exits zero"                      "$([ "$rc" -eq 0 ] && echo ok || echo no)"
check "repo sync ran"                   "$(contains "$out" 'SYNC RAN')"
check "start.sh ran"                    "$(contains "$out" 'START RAN')"
check "no global-networking warning"    "$(contains "$out" 'global networking' | grep -q ok && echo no || echo ok)"

echo
if [ "$failures" -eq 0 ]; then
    echo "ALL PASS"
else
    echo "$failures CHECK(S) FAILED"
    exit 1
fi
