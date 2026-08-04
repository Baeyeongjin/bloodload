# 2026-08-04 · 스테이지 제한시간 · 대시 전투 · 양방향 스폰

퇴근 인수인계. **여기부터 이어서 하면 된다.**

---

## 1. 이번에 끝난 것

### 스테이지 제한시간 / 사망 재시작 / 페이드 전환
사장님 요청: *"스테이지 별로 클리어 시간이 나오고 그 클리어 시간에 맞게 몬스터를 다
잡아야 넘어갈 수 있게 … 죽으면 스테이지를 처음부터 다시 시작하는 듯한 화면 전환 …
스테이지 넘어갈 때 검은 화면에서 서서히"*

| 파일 | 내용 |
|---|---|
| `StageDefs.gd` | `TIME_NORMAL 60` / `TIME_MIDBOSS 45` / `TIME_BOSS 60`, `time_limit(stage)`, `WAVE_WALK_SECONDS 2.3` |
| `Main.gd` | `_tick_boss_timer()` 를 **모든 구간**에 적용 (예전엔 보스만). 시간 초과 → `_restart_stage("시간 초과")` |
| `Main.gd` | `_restart_stage(reason)` 신규 — 몹 정리 → 암전 → kills·타이머·HP 초기화 → `_start_advance()` |
| `Main.gd` | `_fade(action)` 신규. `FADE_OUT .28 / HOLD .14 / IN .4`. 콜백이 **암전 정점**에서 돈다 |
| `Main.gd` | `_fade_rect` — 전투 띠(192~480)만 덮는다. 화면 전체를 덮으면 UI까지 깜빡인다 |
| `Main.gd` | `_advance_stage()` 를 `_fade()` 안으로 감쌈 → 배경·스테이지가 암전 뒤에서 바뀐다 |
| `Main.gd` | 사망 시 그 자리 부활 폐지. `REVIVE_TIME 3.0 → 1.2` 뒤 `_restart_stage("쓰러짐")` |
| `Main.gd` | `_lbl_prog` = `"처치 N / M · X초"`, 5초 이하면 붉게 |
| `Balance.gd` | `can_clear_stage(..., time_limit := 0.0)` — 오프라인도 같은 벽 앞에서 멈춘다 |

**핵심 결정**: 시계는 전진(걷는) 구간에도 돈다. 멈추면 화면 숫자가 얼어붙어 고장으로
보이고, 무리를 잘게 쪼개 시간을 버는 구멍이 생긴다.

### 전투 박진감 개편
사장님 요청: *"캐릭터가 대시해서 달려가서 뚜드려패는 느낌 … 맞고 있는 와중에도 몬스터가
동시에 공격 … 달리는 모션 … 몬스터가 양방향으로"*

- **영웅이 움직인다.** `hero_x` / `hero_face` / `_dash_to` 신규, `_tick_dash()` 가 매 프레임 민다.
  `HERO_X 150 → 288` (화면 가운데. 양쪽에서 나오므로 한쪽에 치우치면 반대쪽만 오래 뛴다)
- **몹은 화면 기준 고정 칸에 선다.** `LANES_RIGHT [380,452,524]` / `LANES_LEFT [196,124,52]`.
  예전 `_foe_stop_x`(영웅 사거리 앞 줄 세우기)는 제거 — 그러면 영웅이 움직일 이유가 없다.
- **양방향 스폰**: `_spawn_foe(side, line)`, `SPAWN_X_LEFT -84`. 오른쪽부터 채운다.
  `Foe.face` 로 좌우 반전(`draw_set_transform` 스케일). 넉백도 온 길 쪽으로 뒤집힌다.
- **사거리 판정을 거리로**: `_motion_reach_x()`(절대 좌표) → `_motion_reach()`(길이).
  `_can_hit_foe()` 는 `absf(foe.x - hero_x)` 로 잰다.
- **동시 피격**: `on_foe_attack()` 은 영웅이 뭘 하든 막지 않는다. 대신 **임팩트 순간에**
  `absf(foe.x - hero_x) > foe.reach()` 면 헛친다 → 대시로 피하는 여지가 생긴다.
- **달리기 모션** `valentino_1_dash` 9프레임 생성·다운로드 완료
  (job `de9e6b5a-8605-4585-af67-423dac0ec4f2`). `_play()` 에 dash→walk 폴백 있음.

### 처치 수 / 보충 스폰 (사장님 마지막 지시)
*"처치 20명은 스테이지가 너무 금방 끝나 1분 기준 60명"* / *"대시가 순간이동 느낌"*

- `KILLS_PER_STAGE 20 → 60`
- `DASH_SPEED 520 → 240` (걷기 120의 2배. 520은 한 칸을 0.2초에 붙어 순간이동으로 보였다)
- **`_refill_lanes()` 신규** — 칸이 비면 그 프레임에 한 마리 보충. 이게 없으면
  60마리 × 2.3초 = 걸어 들어오기만 138초라 60초 제한을 애초에 못 넘는다.
  → 일반 구간은 첫 진입 뒤로 `advance` 로 안 돌아간다(계속 난전). 배경 스크롤도 멈춘다.
- 오프라인 예산도 "첫 무리 한 번"만 빼도록 수정

### 스킬 VFX 20/20 완료
남아 있던 6종 전부 다운로드 완료:
`fx_sk_legend_field`, `fx_sk_common_ward`, `fx_sk_uncommon_ward`, `fx_sk_rare_ward`,
`fx_sk_epic_ward`(`d211038a-…`), `fx_sk_legend_ward`(`6b94c492-…`)

---

## 2. 검증 상태 — **여기가 미완이다**

| 검사 | 결과 |
|---|---|
| `Main.gd` / `Foe.gd` 파싱 | ✅ 통과 |
| `BalanceTest` | ✅ (60마리·`_refill_lanes` 반영 **전**에 통과. 다시 돌려야 함) |
| `GearTest` | ✅ (동일) |
| `SkillTest` | ⚠️ VFX 6종 넣은 뒤 **아직 안 돌렸다**. 통과할 것으로 보이나 확인 필요 |
| 렌더 확인 | 1-2 단계에서 양방향 스폰·대시·"처치 1/20 · 55초" 확인 ✅ |

집에 가서 **제일 먼저** 돌릴 것:
```bash
godot --headless --path . --import
godot --headless --path . --script tests/BalanceTest.gd
godot --headless --path . --script tests/GearTest.gd
godot --headless --path . --script tests/SkillTest.gd
```
(렌더는 반드시 `$env:APPDATA` 를 임시 폴더로 격리할 것 — 사장님 저장본으로 돌리면
창이 떠 있는 동안 버튼이 눌린다. 예전에 장비가 분해된 사고가 있었다.)

---

## 3. 남은 할 일 (사장님이 요청한 순서)

### (1) 8프레임 통일 — 대시가 아직 순간이동 느낌
> *"프레임을 8프레임으로 가능한가 대시가 순간이동느낌이야 … 전체적으로 8프레임이 필요"*

`DASH_SPEED` 는 240으로 낮춰 뒀지만 **그림 프레임 수는 아직 안 맞췄다.**

| 모션 | 현재 프레임 | 필요 |
|---|---|---|
| `valentino_1_idle` | 4~5 | 8 |
| `valentino_1_walk` | 5 | 8 |
| `valentino_1_dash` | 9 (입력1+생성8) | 그대로 OK |
| `valentino_1_attack` | 7 | 8 |
| `valentino_1_heavy` / `cast` / `sweep` / `ward` / `hurt` | 7 | 8 |

- PixelLab `animate_image(frame_count=8)` 로 재생성. 32×32라 16프레임까지 가능.
- **주의**: `IMPACT_FRAME = 3` 은 "7프레임 중 네 번째" 기준이다. 8프레임으로 가면
  임팩트 지점을 다시 재야 한다(`_hero_hit_t = interval * 3.0 / 7.0` 도 같이).
- 몹 attack 애니도 `Foe.IMPACT_FRAME = 3`, `_attack_frames.size()` 기준이라 같이 봐야 함.

### (2) 스킬 상세보기 창
> *"스킬 눌렀을 때 상세보기도 필요할것같은데"* (레퍼런스 스크린샷 첨부됨)

레퍼런스 구성: 왼쪽에 큰 아이콘 + 등급 배지 + `Lv.N` + 보유 수량,
오른쪽에 이름 / 쿨타임 / 설명 / 보유 효과, 아래에 `해제` · `레벨업(진행바)` 버튼.

- 붙일 자리: 스킬 탭의 카드 클릭 → 기존 `--gear-detail` 상세창과 같은 틀 재사용
- 필요한 값은 이미 `_skill_data(key)` 에 다 있다 (`name/cooldown/power/role/target`)
- **폰트 함정**: `Lv.` 는 이 블랙레터에서 `ℒ𝔇` 로 읽힌다. `레벨 N` 으로 쓸 것.
  칸 폭은 `GearTest` 의 폰트 실측 검사에 항목을 추가해서 잡을 것.

### (3) 업적 / 스테이지 보상
> *"업적 보상 및 보석을 수급할 수 있어야 … 스테이지 보상부터 시작해서 화면에 작은 버튼"*

레퍼런스(주점 화면) 구성: 진행 중 / 종료됨 탭, 두루마리 행마다 [아이콘][제목][보상 3칸],
아래에 일일 임무 / 주간 임무 진행바.

- 1단계(작게): 상단에 작은 버튼 → `스테이지 보상` 창. `best_stage` 마일스톤마다 보석.
  `FoeTiers.CODEX_REWARDS` 와 같은 틀(`{"need":…, "gem":…}`)을 쓰면 코드가 거의 안 는다.
- 2단계: 일일/주간. 이건 시간 기준이라 저장 형식에 `last_daily_reset` 이 필요하다.

### (4) 스킬바 상시 노출 검토
전투 화면 아래에 6칸을 늘 띄울지. VFX 20종이 다 찼으니 이제 판단 가능.

---

## 4. 밸런스 재확인 필요 (60마리로 바뀌어서)

- `Balance.can_clear_stage` 예산 = `60초 - 2.3초`. 60마리를 57.7초에 = 마리당 0.96초.
  `BalanceTest` 의 TTK 출력(일반 0.21s ~ 1.52s)과 비교하면 후반이 빠듯하다 —
  **일부러 그렇게 뒀다**(제한 시간은 벽이어야 한다). 첫 플레이에서 못 넘으면 완화할 것.
- `MAX_FOES 5` 에 칸은 6개(좌3+우3). 6으로 올릴지 검토.
