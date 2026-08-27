# 검사 대장

`tests/` 아래 61개. **깨진 것을 기록해 두는 자리다** (사장님 2026-08-26:
"실패난 거는 기록했다가 고칠 수 있도록 해라").

## 돌리는 법

한 개:

```bash
APPDATA=/c/Users/kpo02/AppData/Local/Temp/claude/godot_iso \
  "C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe" \
  --headless --rendering-method gl_compatibility --path . --script tests/이름.gd
```

**`APPDATA` 격리는 예외 없다.** 안 하면 사장님 저장본으로 돌아간다 — 창이 뜬
사이 버튼이 눌려 실제로 장비가 분해된 사고가 있었다(`godot-verify` 스킬).

전부 한 번에 돌리는 스크립트는 `tools/run_checks.sh` 다. 넷씩 병렬로 돌리고
`ok / FAIL / TIMEOUT / PARSE / ERROR` 로 한 줄씩 찍는다.

---

## 실패는 왜 "타임아웃"으로 둔갑하는가

**assert 가 깨져도 SceneTree 는 안 죽는다.** 그래서 타임아웃 가드가 없는
검사는 실패한 뒤 영원히 매달려 있고, 밖에서 보면 그냥 안 끝나는 검사다.

`TicketCheck` 를 그렇게 오진했다 — 인수인계에 "60초 타임아웃(기존 버그,
게임 영향 없음)"이라고 몇 주 적혀 있었는데, 실제로는 **소환권 지불 규칙이
바뀐 걸 안 따라온 assert 실패**였다.

그래서 모든 검사는 머리에 가드를 둔다:

```gdscript
func _init() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
```

2026-08-26 에 없던 12개(`AxisLiveCheck` `HoldKeepCheck` `CurveSweep`
`SplitCheck` `PopAllCheck` `PullCostCheck` `CurveCheck` `RaidPaceCheck`
`AchieveCheck` `MigCheck` `RageGritCheck` `SpecialKindCheck`)에 붙였다.
**새 검사를 만들면 이 가드부터 쓴다.**

---

## 2026-08-26 전수 점검 — 깨져 있던 것 여섯

전부 **게임이 아니라 검사가 낡은 것**이었다. 축을 옮기거나 기능을 지우면서
검사를 안 따라가게 둔 자국이다. 하나도 게임 버그가 아니었다는 게 이 표의
요점이다 — 그런데 그동안 **빨간 줄이 일상이라 진짜 실패가 묻혔다.**

| 검사 | 증상 | 뿌리 |
|---|---|---|
| `TicketCheck` | `모자란 권이 부분 지불됐다` | d6cf82c 가 "권을 있는 만큼 먼저 쓴다"로 바꾸면서 `PullCostCheck` 를 새로 만들었는데 이쪽을 안 고쳤다. 두 검사가 같은 걸 두고 서로 다른 말을 하고 있었다 |
| `AttendCheck` | `모르는 훅 종류: critdmg` | 은총 종류 목록에 `gold`·`essence`(사라진 축)가 남고 `critdmg`(새 축)가 없었다 |
| `AxisLiveCheck` | `도감 수집이 혈액에 안 붙는다` | 혈액 배수 축을 통째로 걷어냈는데(2026-08-25) 검사는 아직 붙기를 기대했다. **이제는 안 붙는 것을 못 박는다** |
| `StageResetCheck` | `미궁 다음 층에서 체력이 안 찼다` | 클리어 여운(`CLEAR_HOLD` 1.8초)이 회복을 타이머 뒤로 미뤘다. 검사는 `_fade_t > 0` 을 기다렸는데 여운 중엔 그게 0 이라 바로 빠져나왔다. **회복 자체를 기다리게** 고쳤다 — 무엇이 몇 초 걸리든 안 흔들린다 |
| `SplitCheck` | `수입과 비용의 비가 눈금 때문에 바뀌었다` | `gold_per_kill` 에 `KILL_WORTH`(3.0)가 들어갔는데 검사식이 안 따라와 정확히 3배 어긋났다. 이제 상수를 읽는다 |
| `PaceProbe` | 런타임 에러 (`game.essence`) | **가장 아팠던 것.** 정수(essence)를 삭제(2026-08-25)하면서 이 프로브를 안 고쳤다. 없는 키 `"essence"` 로 `open_stage` 는 기본값 25 를, `reward` 는 0.0 을 받고, `game.essence` 에 쓰다 죽었다 — **밸런스 실측 도구가 통째로 못 돌고 있었다.** 재화가 연마석(`whet`)으로 바뀐 것을 반영했다 |

### 여기서 배울 것

**재화나 축을 지울 때 `tests/` 를 같이 grep 한다.** 위 여섯 중 넷이 그걸
안 해서 생겼다. 특히 프로브(`PaceProbe`·`CurveSweep`)는 assert 가 아니라
표를 찍는 물건이라 **아무도 안 볼 때 조용히 죽어 있는다.**

---

## 성격별 분류

### 규칙을 못 박는 검사 (빠르다, 매번 돌린다)

`BalanceTest` `CombatRulesTest` `GearTest` `SkillTest` `GoalTest`
`TicketCheck` `PullCostCheck` `TraitCheck` `PetCheck` `TripCheck`
`NameCheck` `BossNeedCheck` `TitleCheck` `TitleUi` `MileCheck`
`PullUiCheck` `QuestCheck` `AttendCheck` `PassCheck` `ShopCheck`
`IapCheck` `OathCheck` `PactCheck` `RelicCheck` `MasteryCheck`
`TraitCheck` `AchieveCheck` `LoreCheck` `DropCheck` `UnlockCheck`
`SplitCheck` `MigCheck` `ResetCheck` `PromoCheck`

### 판을 실제로 돌리는 씬 검사 (느리다)

`DungeonCheck` `RaidCheck` `TrialCheck` `EventCheck` `ForgeFightCheck`
`StageResetCheck` `EngageCheck` `FirstHitCheck` `AoeCheck` `SplitCheck`
`RageGritCheck` `StartPosCheck` `NoAttackProbe` `HoldKeepCheck`
`AxisLiveCheck` `SpecialKindCheck` `PopupCheck` `PopAllCheck`
`FxPlaceCheck` `MotionCheck` `SkinCheck` `BootProbe` `OathReplay`

### 밸런스 실측 프로브 (매우 느리다, 값을 정할 때만)

`PaceProbe` — 무과금/멤버십 N일치를 굴려 구간·미궁·재화·전투력 표를 찍는다.
`CurveSweep` — 곡선 상수를 훑는다.
`CurveCheck` `RaidPaceCheck` — 곡선·던전 페이스의 경계값.

**이 넷이 밸런스의 자다.** 상수를 바꾸면 여기부터 다시 잰다.


---

## 2026-08-26 마감 상태

전수 재점검 결과 **59 / 61 통과**. 나머지 둘은 고장이 아니다:

| 검사 | 왜 안 끝나나 |
|---|---|
| `CurveSweep` | 곡선 상수를 훑는 시뮬이라 원래 길다. 단독으로 돌리면 끝난다 |
| `HoldKeepCheck` | 넷씩 병렬로 돌릴 때만 150초를 넘긴다. 단독은 통과 |

병렬로 돌리면 Godot 인스턴스가 서로 CPU를 뺏어 느려진다. 프로브가 섞이면
`JOBS=2` 나 `LIMIT=300` 을 주는 게 낫다:

```bash
JOBS=2 LIMIT=300 bash tools/run_checks.sh
```

### 새로 생긴 검사

| 검사 | 무엇을 지키나 |
|---|---|
| `BossNeedCheck` | 이정표 요구치의 분모(화력) — 회귀·재시작에 안 흔들린다 |
| `TripCheck` | 펫 원정 — 시간이 **나올 조각의 등급**을 따르는가 |
| `NameCheck` | 이름 입력 — 사람이 친 글자도 저장본도 안 믿는다 |
| `DotCheck` | 알림 점 — 켜지는 조건과 **꺼지는 조건을 같이** |
| `BuyStepCheck` | 배수 버튼 — **화면에 눌린 것과 실제로 사는 양이 같은가** |

### PaceProbe 는 사장님이 직접 돌린다

밸런스 상수를 바꾸면 여기부터 다시 잰다. 하루 루프(방치 8시간 + 접속 60분 +
던전 + 소환 + 펫 + 조합)를 실제로 굴리므로 **1~2분** 걸린다.

```bash
bash tools/run_checks.sh PaceProbe
```

찍는 표: 구간·미궁층·훈련상한·공격렙·혈흔·전투력 · **재화 유입(연마석/일 ·
먹이/일 · 착용 장비렙)** · 축별 기여 · 소환 횟수.

재화 유입 줄은 2026-08-26 에 붙였다 — 장비 만렙 일수가 "하루 연마석 12,700"
을 전제로 잡혀서, 그 전제가 실제로 서는지 봐야 한다.

## `FirstHitCheck` — 재는 것을 바꿨다 (2026-08-27, 닫힘)

옛 문턱 `대기 < 주기 x 0.8` 은 밸런스 개편(주기 0.60 -> 0.22) 뒤로
**어떤 코드로도 통과할 수 없었다.** `_attack_swing()` 이 `min(0.34, 주기)` 라
스윙만 0.22초이고, 임팩트는 그림이 제일 뻗는 프레임(9장 중 5·6·8번 =
스윙의 0.61~0.94)에서 난다 — 하한 0.195초 > 문턱 0.176초.

문턱만 옮기면 공속이 또 오를 때 다시 빨개진다. **축이 틀린 것이라 재는 것을
바꿨다**: "사거리가 열린 프레임(+1)에 스윙이 나가는가" 하나만 본다. 스윙
길이·임팩트 프레임·스킬 점유가 자동으로 빠지고 주기에도 안 묶인다.

**후보 셋을 다 찍어서 골랐다** — 읽어서는 못 골랐다:

| 신호 | 고쳐진 상태 | 버그 되돌림 |
|---|---|---|
| 사거리 열린 프레임에 스윙 | 0.89 | 0.14 |
| **+1프레임까지 스윙** | **1.00** | **0.19 / 0.23** |
| 사거리 열릴 때 쿨다운 끝남 | 0.11 | 0.05 |

쿨다운 잔량(`_attack_t`)은 **안 갈라진다.** 가드가 `_attack_t > 0` 이라 0 이
되는 순간 스윙이 나가고 같은 프레임에 주기로 되돌려져서, 프레임 끝에서 재면
고쳐진 상태에서도 늘 양수다. 코드만 읽고 이 신호를 골랐으면 조용히 늘 초록인
검사를 만들 뻔했다.

되돌림 검증: `_attack_t -= delta` 를 phase 가드 **뒤로** 옮기면 0.23 으로
떨어져 빨개진다. 45초를 실시간으로 굴려서 **한 번에 5~9분** 걸린다 —
타임아웃 560초를 준다.
