#!/usr/bin/env bash
# 웹 빌드를 뽑아 gh-pages 브랜치로 배포한다.
#
#   bash tools/deploy_web.sh
#
# **PowerShell 에서도 그대로 친다** — Git Bash 가 PATH 에 있으면 돈다.
# (PowerShell 로 옮겨 적지 말 것: 이 저장소 경로에 한글이 들어 있어서 .ps1 은
#  인코딩이 깨진다 — CLAUDE.md 의 "`.ps1` 안에 한글 경로 금지".)
#
# 왜 orphan 브랜치인가: 빌드는 소스가 아니다. 38MB wasm 이 매번 히스토리에 쌓이면
# 저장소가 못 쓰게 되므로 **브랜치를 통째로 갈아 끼운다**(--force).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
WT="${TMPDIR:-/tmp}/bloodlord_ghp_$$"

cd "$ROOT"

echo "== 1/3  웹 빌드 =="
"$GODOT" --headless --path . --export-release "Web" "build/web/index.html" \
	2>&1 | tail -3

echo "== 2/3  gh-pages 워크트리 =="
git worktree prune
rm -rf "$WT"
git worktree add --detach "$WT" >/dev/null
cd "$WT"
git checkout --orphan gh-pages >/dev/null 2>&1
git rm -rf . >/dev/null 2>&1 || true
cp "$ROOT/build/web"/* .
# Jekyll 이 밑줄로 시작하는 파일을 걸러내는 사고를 미리 막는다.
touch .nojekyll
git add -A -f

echo "== 3/3  푸시 =="
git commit -q -m "웹 빌드 $(date +%Y-%m-%d) ($(cd "$ROOT" && git rev-parse --short HEAD))"
git push -u origin gh-pages --force 2>&1 | tail -3

cd "$ROOT"
git worktree remove --force "$WT" >/dev/null 2>&1 || true
git worktree prune
echo
echo "끝. 몇 분 뒤 열린다:  https://baeyeongjin.github.io/bloodload/"
