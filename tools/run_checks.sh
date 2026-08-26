#!/bin/bash
# tests/ 전부를 돌려 한 줄씩 결과를 찍는다. 자세한 건 docs/CHECKS.md.
#
#   bash tools/run_checks.sh            # 전부
#   bash tools/run_checks.sh Trait Pet  # 이름에 그 글자가 든 것만
#
# **APPDATA 격리는 예외 없다** — 안 하면 사장님 저장본으로 돌아간다.
# 검사마다 따로 준다: 넷씩 병렬로 도는데 한 폴더를 나눠 쓰면 서로 덮어쓴다.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
ISO_ROOT="${ISO_ROOT:-/c/Users/kpo02/AppData/Local/Temp/claude}"
LIMIT="${LIMIT:-200}"     # 한 검사에 줄 최대 초. 프로브는 이보다 오래 걸린다
JOBS="${JOBS:-4}"

[ -x "$GODOT" ] || { echo "Godot 을 못 찾았다: $GODOT"; exit 1; }

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

run_one() {
  local t; t=$(basename "$1" .gd)
  local iso="$ISO_ROOT/godot_iso_$t"
  local log code
  log=$(APPDATA="$iso" timeout "$LIMIT" "$GODOT" --headless \
        --rendering-method gl_compatibility --path . --script "tests/$t.gd" 2>&1)
  code=$?
  rm -rf "$iso" 2>/dev/null
  if [ $code -eq 124 ]; then
    # 가드가 있는데도 여기 걸리면 진짜로 오래 걸리는 것이다(프로브).
    printf 'TIMEOUT  %s (%ss)\n' "$t" "$LIMIT" >> "$OUT"
  elif grep -q "Assertion failed" <<<"$log"; then
    printf 'FAIL     %s | %s\n' "$t" \
      "$(grep -m1 'Assertion failed' <<<"$log" | sed 's/.*Assertion failed: //')" >> "$OUT"
  elif grep -qE "Parse Error|Failed to load script" <<<"$log"; then
    printf 'PARSE    %s\n' "$t" >> "$OUT"
  elif grep -qE "^SCRIPT ERROR" <<<"$log"; then
    printf 'ERROR    %s | %s\n' "$t" \
      "$(grep -m1 '^SCRIPT ERROR' <<<"$log" | cut -c1-100)" >> "$OUT"
  else
    printf 'ok       %s\n' "$t" >> "$OUT"
  fi
}

n=0
for f in tests/*.gd; do
  if [ $# -gt 0 ]; then
    keep=0
    for pat in "$@"; do case "$f" in *"$pat"*) keep=1;; esac; done
    [ $keep -eq 1 ] || continue
  fi
  run_one "$f" &
  n=$((n + 1))
  [ $((n % JOBS)) -eq 0 ] && wait
done
wait

sort "$OUT" | grep -v '^ok' || true
printf -- '-----\n통과 %s / %s\n' "$(grep -c '^ok' "$OUT")" "$(wc -l < "$OUT")"
grep -qv '^ok' "$OUT" && exit 1 || exit 0
