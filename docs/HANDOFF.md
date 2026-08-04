# 인계 — 다음 작업자에게

> 마지막 업데이트: 2026-08-04 (레인 처리량·오프라인 정합·테스트 복구·스킬 미발동 수정)

**이 파일부터 읽고, 끝나면 새 상태로 덮어쓴다.**

## 1. 기준 문서

- `DESIGN.md`: 전체 설계와 구현 순서
- `STATS.md`: 스탯 공식과 해금
- `PLAN.md`: v1 범위
- `UI_RULES.md`: UI 여백·정렬·크기
- `BG_RECIPE.md` / `PIXELLAB_ARMOR_IDS.md`: 자산 생성 규격

문서와 코드가 어긋나면 **코드가 맞다.** 발견 즉시 문서를 고친다.
날짜별 작업 기록만 `daily/` 에 쌓고 살아 있는 문서는 늘리지 않는다.

## 2. 완료 상태

M1 전투 · M2 정수 · M3 뽑기까지 끝났고, 그 위에 08-04 전투 개편이 얹혀 있다.

- 진행 구조: 큰 단계 100 × 세부 구간 10, 화면 표기 `1-1`~`100-10`
- **모든 구간에 제한시간** (일반 60초 / 중간보스 45 / 보스 60). 초과 → 그 구간 처음부터
- 사망 시 그 자리 부활 폐지 → 1.2초 뒤 구간 재시작
- **대시 전투**: 영웅이 화면 가운데(288)에 서서 적에게 달려가 때린다.
  몹은 화면 기준 고정 칸(좌3+우3)에 서고 **양방향**으로 나온다
- 처치 60마리, 칸이 비면 즉시 보충(`_refill_lanes`)
- 스킬 20종(형태 4 × 등급 5), 장착 6칸, 조합 버프, 조각 레벨업·승급
- 장비는 **소환에서만** 나온다(전투 드랍 폐지). 보관함·상세·합성·분해 확인창
- 도감 = 몹별 지식 레벨(처치 10/100/500/2000/10000), 레벨당 그 몹 상대 피해 +4%
- 소환 레벨 10단계, 레전더리 2레벨·신화 5레벨 해금

## 3. 검증 명령

```powershell
$GODOT = "C:/Users/user/Godot/Godot_v4.7-stable_win64_console.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --script tests/BalanceTest.gd
& $GODOT --headless --path . --script tests/GearTest.gd
& $GODOT --headless --path . --script tests/SkillTest.gd
& $GODOT --headless --path . --script tests/CombatRulesTest.gd
```

2026-08-04 결과: **네 개 모두 OK (exit 0)**, `--import` 에러 0.

개발 플래그: `--stage=1-5|1-10|50-10|100-10`, `--autoshot`, `--wait=N`,
`--tab=growth|gear|codex`, `--status`, `--rates`, `--bulk=salvage|fuse[:all]`,
`--skills=N`. 기존 내부 숫자 형식(`--stage=10`)도 계속 받는다.

> **캡처·렌더는 반드시 저장본을 격리해서 돌린다.** `$env:APPDATA` / `$env:LOCALAPPDATA`
> 를 임시 폴더로 바꾼 뒤 실행할 것. 사장님 저장본으로 돌리면 창이 2초간 실제로 떠 있어서
> 버튼이 눌린다 — 예전에 장비가 분해된 사고가 있었다.

> `.import` 파일 1,772개가 매번 modified 로 뜬다. 내용은 안 바뀐다(Godot 은 LF, 저장소는
> CRLF). 커밋 전에 `git checkout -- "*.import"` 로 턴다. 끝내려면 `git add --renormalize .`
> 정규화 커밋이 한 번 필요하다 — `.gitattributes` 선언만으로는 안 끝난다.

## 4. 최우선 — 밸런스 재설계

**세 문제의 뿌리가 하나라 따로 고치면 어긋난다.** 수치 근거는
`daily/2026-08-04-lane-throughput-and-balance-audit.md` 7장에 있다.

| 문제 | 실측 |
|---|---|
| 공격력이 너무 강하다 | 첫날 일반 몹 TTK **0.21초** = 초당 4.8마리. 처리량 상한은 1.8마리라 영웅이 시간의 90%를 논다 |
| 곡선이 뒤집혔다 | 첫날→1주 적 ×49.2 vs DPS ×6.9 (**7배 뒤처짐**), 1주→1개월은 ×17.6 vs ×17.1 (거의 균형) |
| 체력이 너무 낮다 | 몹 공격은 `enemy_power × 4` 로 지수, 체력은 합연산 +2%/Lv. 100단계에서 **한 대에 9번 죽는다** |

근본 원인: **공격력만 곱연산이다.** `hero_damage = 4.0 × 공격력Lv` 는 레벨당 +100%인데
`STATS.md` 는 +2%(합연산)라고 적혀 있다 — 문서와 코드가 **50배** 어긋나고,
STATS 1장의 "합연산은 무한, 곱연산은 유한" 규칙을 공격력이 어기고 있다.

`hero_damage` 를 문서대로 되돌리면 DPS 가 60배 떨어져 TTK 표가 전부 무효가 되고
`BalanceTest` 체크포인트가 다 깨진다. 적 HP 곡선(`enemy_power`)을 같이 다시 잡아야 한다.

> `STATS.md` 4장(전체 DPS 공식)과 `DESIGN.md` 8장(수치 곡선)을 **같이 열고** 시작할 것.
> 조정은 레벨당 효과가 아니라 **비용 지수와 적 곡선으로** 한다(STATS 6장).

## 5. 그다음 — 가호(ward) 등급 성장

**스킬 소환 풀의 25%가 죽어 있다.** 레전더리 `불멸의 심장`과 커먼 `피의 결계`가 완전히
같다 — `SHAPES["ward"]` 의 `duration 6.0` · `bonus 0.30` 이 표에서 그대로 복사되고
`cooldown` 은 등급이 아니라 레벨만 보기 때문이다.

`power` 가 0 이라 `power()` 로는 등급이 안 갈린다(그래서 `rank()` 가 따로 있다).
`ward_bonus(key, lv)` 같은 걸 만들어 등급·레벨을 곱하고 `_skill_data` 가 그걸 쓰게 한다.
**레전더리 가호에 얼마를 줄지는 결정이 필요하다** — 지속시간이냐 배수냐 둘 다냐.

## 6. 남은 목록 (08-04 인계에서 이어짐)

1. **8프레임 통일** — `idle`/`walk`/`hurt` 5프레임, `attack`/`heavy`/`cast` 7프레임을 8로.
   `dash`/`sweep`/`ward` 는 9라 그대로. PixelLab `animate_image(frame_count=8)`.
   > 타격 지점은 이제 **비율**(`Foe.IMPACT_RATIO = 3/7`)이라 프레임 수를 바꿔도
   > 따라간다. 예전의 `IMPACT_FRAME = 3` 함정은 없어졌다.
2. **스킬 상세보기 창** — 기존 장비 상세창 틀 재사용. 값은 `_skill_data(key)` 에 다 있다.
   > 폰트 함정: `Lv.` 는 이 블랙레터에서 `ℒ𝔇` 로 읽힌다. `레벨 N` 으로 쓸 것.
3. **업적 / 스테이지 보상** — 보석 수급처. `FoeTiers.CODEX_REWARDS` 와 같은 틀
   (`{"need":…, "gem":…}`)을 쓰면 코드가 거의 안 는다.
4. **스킬바 상시 노출 검토** — VFX 20종이 다 찼으니 이제 판단 가능.
5. **`MAX_FOES 5` vs 칸 6개** — `want = 5` 일 때 오른쪽 3 + 왼쪽 2 라 왼쪽 마지막 칸을
   안 쓴다. 6으로 올릴지 검토.

## 7. 환경·주의

- 저장소: `https://github.com/Baeyeongjin/bloodload.git`, 브랜치 `main`
- GoPeak MCP 서버는 `.codex/config.toml`(Codex) 과 작업 폴더 `.mcp.json`(Claude Code) 에
  등록돼 있다. 도구가 안 보이면 앱을 재시작하고, 안 보여도 Godot CLI 로 검증할 수 있다.
- **오프라인 계산에는 난수를 넣지 않는다.** 실시간과 같은 벽 앞에서 멈춰야 한다 —
  `Balance.stage_seconds()` 가 DPS 병목과 처리량 병목 중 느린 쪽을 쓴다.
- 테스트의 굴림 검사는 `seed()` 로 고정돼 있다. 지우면 `GearTest` 가 2% 확률로 깨진다.
- 문서 수정은 **Edit 으로** 한다. PowerShell 로 한글 파일을 치환하면 인코딩이 깨진다.

## 8. 알려진 문서 부채

- `daily/2026-08-04-ui-units-codex-reward.md` 14장의 소환 레벨 수치가 코드와 **20배**
  다르다. 문서는 "5N회 / 만렙 275회", 코드는 `LEVEL_BASE 100` → 만렙 누적 **4,500회**.
  `GachaDefs.gd` 주석도 63줄("만렙 10 / 200회")과 66줄("10레벨 4500")이 서로 다르다.
  **코드 공식이 정답이다.**
- `DESIGN.md` 9-1 의 "스킬 아이콘 72 / 사용 0" 은 옛 기성 자산 기준이다. 지금은
  PixelLab 으로 만든 20종을 쓴다.
