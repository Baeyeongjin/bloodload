# 인계 — 다음 작업자에게 (2026-08-03, M1 전투 코어 이후)

**이 파일부터 읽고, 끝나면 이 파일을 새 상태로 덮어쓴다.**

## 0. 먼저 읽을 것

| 문서 | 단일 출처 |
|---|---|
| `UI_RULES.md` | UI 여백·정렬·크기. 눈대중 보정 금지 |
| `DESIGN.md` | 전체 설계. 특히 2장 전투, 3장 보스 |
| `STATS.md` | 스탯 구조와 해금 |
| `PLAN.md` | v1 범위 |
| `assets/bg/BG_RECIPE.md` | 배경 생성 규격 |

문서와 코드가 어긋나면 코드가 맞다. 발견하면 문서를 바로 고친다.

## 1. 검증 명령

```powershell
$GODOT = "C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --script tests/BalanceTest.gd
& $GODOT --headless --path . --script tests/GearTest.gd
& $GODOT --path . --rendering-method gl_compatibility --resolution 576x896 -- --autoshot --wait=8
```

Godot은 AppData 사용자 경로를 쓰므로 Codex 샌드박스에서는 실행 승인이 필요할 수 있다.
게임을 오래 띄우지 말고 위 명령이나 `--quit-after`로 끝을 정한다.

개발 플래그: `--autoshot`, `--wait=N`, `--tab=growth|gear|codex`, `--walk`.
`--tab=`이 가끔 다른 탭을 띄우는 기존 문제는 아직 남아 있다.

## 2. 현재 완료 상태

v1 기능에 더해 M1의 전투 코어(이전 인계 2-1~2-3)가 끝났다.

- 몹 22종 `{key}_attack` 연결, 공격 주기 `1.2 + hp_mult × 0.3`초
- 몹과 영웅 모두 7프레임 중 네 번째에 실제 타격
- `FRONT_X = 235`, `fx_cleave`는 맞은 몹 위치에서 5프레임 재생
- 영웅 HP/회복, 머리 위 체력 바와 전투 띠 HP 숫자
- 피격 `valentino_1_hurt` + 0.1초 흰 플래시
- 사망 시 상승+페이드 + `fx_death_blood`, 3초 뒤 최대 체력으로 부활
- 사망해도 스테이지는 유지하고 그 단계 처치 수만 0
- 체력/체력회복 스탯 `impl = true`
- 오프라인은 로스터 평균으로 생존 가능 여부를 결정론적으로 계산하고 가능한 단계까지만 전진

완료 기록: `docs/done/2026-08-03-m1-combat-core.md`.

## 3. 검증 결과

- `BalanceTest OK`
- `GearTest OK`
- 메인 씬 120프레임 로드 오류 없음
- 격리 저장본 40초 고속 전투(사망·부활 포함) 오류 없음
- 576×896 자동 캡처에서 HP 표시·전열 거리·타격 이펙트 확인

스크린샷은 테스트용 임시 경로에만 두고 리포에는 넣지 않았다.

## 4. 개발 환경 — GoPeak MCP

- 전역 설치 확인: `gopeak@2.3.8` (사용자가 기억한 2.3.1보다 최신)
- Codex 전역 MCP 이름: `gopeak`
- transport: stdio, profile: `compact`, 상태: enabled
- Godot 경로는 4.7 GUI 실행 파일로 등록
- **Codex 앱을 재시작해야 새 MCP 도구가 다음 작업에 주입된다.**

현재는 MCP 서버만 연결했다. 아래 고급 기능은 Godot 프로젝트 애드온이 별도로 필요하다.

- `godot_mcp_editor`: 씬/리소스 브리지(포트 6505)
- `godot_mcp_runtime`: 런타임 검사·스크린샷·입력(포트 7777)
- Godot LSP 6005 / DAP 6006

GoPeak core만으로도 프로젝트 탐색·실행·로그 수집은 가능하다. 애드온 설치는 다음 작업에서
MCP 연결을 먼저 확인한 뒤 필요 범위만 진행한다.

## 5. 다음 작업 — M1 나머지

### 5-1. 보스 전용 자산과 규칙 (`DESIGN.md` 3장)

1. 10단계 보스에 `boss_1~5_walk` 연결
2. 5단계 중간보스: 체력 ×3.5, 크기 ×1.3, 이름 접두어
3. 10단계 보스 제한시간 60초, 실패 시 같은 단계 재도전
4. 보스 공격 모션은 전용 자산이 아직 없으므로 기존 몹 attack을 임시 사용하되 문서에 명시

### 5-2. 자동 스킬 3종

`DESIGN.md` 2-2c를 따른다. 모션은 스킬별이 아니라 `attack`/`heavy`/`cast` 세 종류만 둔다.
우선순위는 흡혈 강타 → 피의 파도 → 망령 소환. 스킬별 정체성은 보유 이펙트로 가른다.

## 6. 주의점

- 현재 폴더는 `git status`가 저장소로 인식되지 않는다. `.git` 상태를 복구하거나 상위 저장소
  위치를 확인하기 전에는 git 기반 되돌리기를 전제로 작업하지 않는다.
- 오프라인 계산에 난수를 넣지 않는다.
- 실제 저장본을 건드리지 않는 장시간 검증은 `APPDATA`/`LOCALAPPDATA`를 `C:\tmp` 하위의
  테스트 전용 경로로 지정한 프로세스에서 실행한다.
- 살아 있는 문서는 더 늘리지 않는다. 완료 기록만 `docs/done/YYYY-MM-DD-*.md`에 둔다.
