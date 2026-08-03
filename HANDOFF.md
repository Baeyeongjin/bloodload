# 인계 — 다음 작업자에게 (2026-08-03, M1 완료)

**이 파일부터 읽고, 끝나면 새 상태로 덮어쓴다.**

## 1. 기준 문서

- `UI_RULES.md`: UI 여백·정렬·크기
- `DESIGN.md`: 전체 설계와 구현 순서
- `STATS.md`: 스탯 공식과 해금
- `PLAN.md`: v1 범위

문서와 코드가 어긋나면 코드가 맞다. 발견 즉시 문서를 고친다.

## 2. 완료 상태

M1 전투 전체가 끝났다.

- 영웅/몹 attack 4번째 프레임 타격, 전열 `FRONT_X = 235`
- 영웅 HP·회복·피격·사망·3초 부활과 결정론적 오프라인 생존 판정
- 5단계 중간보스: HP ×3.5, 크기 ×1.3, 접두어/배너/화면 흔들림
- 10단계 보스: `boss_1~5_walk`, 60초 제한, 실패 시 같은 단계 재도전
- 자동 스킬 3종: 흡혈 강타 → 피의 파도 → 망령 소환 우선순위
- `heavy`/`cast` 모션과 기존 이펙트를 재사용

완료 기록:

- `docs/done/2026-08-03-m1-combat-core.md`
- `docs/done/2026-08-03-m1-boss-skills.md`

## 3. 검증 명령

```powershell
$GODOT = "C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --script tests/BalanceTest.gd
& $GODOT --headless --path . --script tests/GearTest.gd
& $GODOT --headless --path . --script tests/CombatRulesTest.gd
& $GODOT --headless --path . --quit-after 600
```

보스 확인용 개발 플래그: `--stage=5|10|20|30|40|50`, `--autoshot`, `--wait=N`.

2026-08-03 결과: 세 테스트 OK, 메인 씬 600프레임 오류 없음, 576×896 캡처 정상.
격리 검증은 `APPDATA`/`LOCALAPPDATA`를 테스트 전용 폴더로 지정한다.

## 4. 다음 작업 — M2 정수 분리

`DESIGN.md` 1장과 11장을 따른다.

1. 저장 지갑에 `essence` 추가
2. 보스 처치와 약한 장비 분해에서 정수 획득
3. 장비 강화 비용을 피가 아니라 정수로 변경
4. 상단 HUD 또는 장비 창에 정수 잔액 표시
5. 기존 저장본 마이그레이션(키가 없으면 0)

보석·인장·하수인 조각은 아직 만들지 않는다. 단계별 재화 도입 원칙상 M2는 정수까지다.

그다음 M3에서는 장비 뽑기와 스킬 뽑기를 같은 마일스톤에 구현한다. 공용 규칙은
5등급 공개 확률(50/30/14/5/1), 10연 희귀+, 100연 전설 천장, 중복 조각, 마일리지다.
현재 자동 스킬 3종은 기본 지급으로 유지하고 뽑은 스킬 자동 장착 3칸으로 확장한다.

## 5. 환경·주의

- 저장소: `https://github.com/Baeyeongjin/bloodload.git`, 브랜치 `main`
- GoPeak MCP 서버는 전역 enabled지만 이번 작업에도 도구가 주입되지 않았다.
  Codex 앱 재시작 뒤 도구가 보이면 사용하고, 안 보여도 Godot CLI로 진행 가능하다.
- 보스 전용 attack 5종은 아직 없다. 현재 원본 몹 attack을 임시 사용한다.
- 오프라인 계산에는 난수를 넣지 않는다.
- 살아 있는 문서는 늘리지 말고 완료 기록만 `docs/done/`에 추가한다.
