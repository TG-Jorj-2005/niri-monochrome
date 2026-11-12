#!/usr/bin/env bash
# Functional test of NiriService against a fake niri socket: parsing, initial sync, unknown/malformed
# events, disconnection and reconnection. Does not touch the running shell or the real compositor.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; sock="$tmp/niri.sock"; log="$tmp/qs.log"
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() {
  if [ -n "${srv:-}" ]; then kill "$srv" 2>/dev/null || true; fi
  if [ -n "${qsp:-}" ]; then kill "$qsp" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
python3 -I "$here/tests/fake-niri-server.py" "$sock" & srv=$!
sleep 0.3
NIRI_SOCKET="$sock" python3 "$here/tests/run-qml.py" "$here/selftest-niri.qml" > "$log" 2>&1 & qsp=$!
for _ in $(seq 1 100); do ! kill -0 "$qsp" 2>/dev/null && break; sleep 0.25; done
wait "$qsp"; test_status=$?
grep -E 'PASS|FAIL|RESULT|ERROR' "$log" | sed 's/^.*qml: //'
if [ "$test_status" -ne 0 ] || grep -qE 'FAIL|ERROR' "$log"; then grep -E '\[Niri\]|ERROR|WARN' "$log" | sed 's/^.*qml: //'; exit 1; fi
grep -q 'RESULT' "$log" || { echo "harness did not finish"; tail -20 "$log"; exit 1; }
exit 0
