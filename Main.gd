extends Node2D

# 방치형 자동 전투. 화면 고정 · 배경 1장 · 몹이 오른쪽에서 걸어오고 알아서 싸운다.
#
# arrow-rpg(액션 RPG)와 나눈 이유: 거긴 조작·콤보·숙련이 값이라 방치형으로 바꾸면
# 그게 전부 안 쓰인다. 여기서 재사용하는 건 아트(캐릭터·몹·이펙트·아이콘)와
# 데이터 표(SkillDefs·FxMatrix)뿐이고 게임 루프는 새로 짠다.
#
# 방치형의 핵심은 "안 보고 있어도 는다"이므로 전투는 결정론적이다 — 회피도 조준도
# 없고, DPS와 적 체력의 나눗셈이 전부다. 그래서 오프라인 보상을 실제 전투 시뮬레이션
# 없이 같은 공식으로 계산할 수 있다.

const SAVE_PATH := "user://bloodlord.cfg"
# 세로 576x1024. 전투는 화면 중앙 띠(y=ground_y)에서만 벌어진다 —
# 위는 상태 표시, 아래는 성장 버튼이라 그 사이만 비워 둔다.
# 전투 화면은 상단 상태창과 하단 UI 사이의 "띠" 안에서만 보인다. 방치형은 화면 대부분이
# UI라, 전투가 배경째로 화면 전체에 깔리면 UI가 그 위에 떠 있는 것처럼 보인다.
# 위아래를 불투명한 UI 바탕으로 막아 전투를 액자 안에 가둔다.
# 화면 576x896 을 세 덩어리로 나눈다. 셋이 화면을 다 덮어 검은 자리가 안 남는다.
#   0  ~192   상단 상태창
#   192~480   전투 띠 (보이는 부분)
#   480~896   하단 UI (콘텐츠 + 탭바)
#
# 배경은 세로 320(원본 160 x2)이라 띠(288)보다 크다. **아래를 기준으로 붙이고**
# 넘치는 위쪽은 상단 패널 뒤로 숨긴다 — 위를 기준으로 붙이면 상단 패널을 키울 때마다
# 지면이 같이 내려가 바닥이 잘린다.
const VIEW_TOP := 192.0
const VIEW_BOTTOM := 480.0
# 발이 닿는 선. 배경마다 바닥 높이가 달라서 상수로 두면 캐릭터가 공중에 뜬다.
# 배경은 항상 전투 띠에 딱 맞게 깔고(y = VIEW_TOP), 대신 이 값을 막마다 옮긴다.
var ground_y := 442.0
# 영웅의 **대기** 자리. 전투 중에는 여기 서 있지 않고 적에게 달려간다.
# 좌우 양쪽에서 몹이 나오므로 한쪽에 치우쳐 두면 반대쪽으로 갈 때만 오래 뛴다.
const HERO_X := 288.0
const HERO_DRAW_SCALE := 2.0
# 타격 지점은 **프레임 번호가 아니라 모션 길이의 비율**이다. 고정 번호로 두면
# 프레임 수를 바꾸는 순간(8프레임 통일 예정) 타격이 그린 자세와 어긋난다.
# Foe.IMPACT_RATIO 와 같은 값을 쓴다 — 영웅과 몹의 타격 규칙이 갈리면 안 된다.
const IMPACT_RATIO := Foe.IMPACT_RATIO   # 원래 기준: 7프레임 중 네 번째
const SPAWN_X := 660.0        # 화면 밖 오른쪽에서 등장
const SPAWN_X_LEFT := -84.0   # 화면 밖 왼쪽에서 등장
# 칸이 좌우 3개씩 여섯인데 5가 상한이라 **왼쪽 마지막 칸을 한 번도 안 썼다.**
# 60마리/60초 구간에서는 동시 마릿수가 곧 처리량 상한이라(60 x 걷는시간 / n),
# 한 칸을 놀리면 그만큼 시간이 모자란다.
const MAX_FOES := 6
# 몹이 자리를 잡는 칸. 영웅 기준이 아니라 **화면 기준 고정 좌표**다 — 예전처럼
# 영웅 사거리 앞에 줄 세우면 영웅이 움직일 이유가 없어서 전투가 정지 화면이 된다.
# 간격 64 = 몹 한 마리 폭(32x2)이라 겹치지 않는 최소값이다. 예전 72 는 첫 칸이
# 영웅에서 92px 나 떨어져 **영웅 주변 184px 가 늘 비어 있었다** — 몹이 중앙으로
# 못 오는 게 아니라 올 자리가 없었다. 첫 칸을 당겨 공백을 112px 로 줄인다.
const LANES_RIGHT := [344.0, 408.0, 472.0]
const LANES_LEFT := [232.0, 168.0, 104.0]
# 대시. 520 으로 잡았더니 한 칸(92~236px)을 0.2~0.45초에 붙어서 **순간이동**으로
# 보였다 — 달리기 8프레임을 한 바퀴 돌리려면 최소 0.5초는 이동에 써야 한다.
# 걷기(120)의 2배면 가까운 칸도 0.4초, 먼 칸은 1초라 뛰는 게 눈에 남는다.
const DASH_SPEED := 240.0
# 영웅이 한 칸에 붙어 있을 때 사거리 안에 드는 몹 수. 칸 간격(64)과 몹 사거리
# (_size/2 + 80)에서 나오는 값이라 칸을 옮기면 CombatRulesTest "계측 A" 가 잡는다.
const FOES_IN_REACH := 3
# 전진 연출. 영웅은 화면 고정(카메라가 흔들리면 UI가 못 읽힌다)이고 대신 배경이 흐른다.
# 배경은 몹보다 느리게 흘린다(원경 시차). 같은 속도면 도트가 뭉개지고, 반대로
# 너무 느리면 걷는데 배경이 안 움직여 제자리걸음으로 보인다 — 0.5가 그 사이다.
# 배경 아래를 메우는 색 — 각 배경 맨 아랫줄에서 뽑았다 (tools/ 없이 눈으로 못 맞춘다).
const BACKDROP := [
	Color(0.147, 0.142, 0.121),   # 깨어난 무덤
	Color(0.183, 0.145, 0.118),   # 화형의 언덕
	Color(0.304, 0.387, 0.428),   # 서리 봉인지
	Color(0.083, 0.088, 0.090),   # 핏빛 성소
	Color(0.050, 0.049, 0.054),   # 빼앗긴 본성
]
const PARALLAX := 0.5
const SCROLL_SPEED := Foe.WALK_SPEED * PARALLAX

var stage := 1
var kills := 0
var gold := 0.0
var essence := 0.0
var gem := 0.0
var mileage := 0
var best_stage := 1
var play_time := 0.0

# 성장 스탯 (골드로 올린다). 방치형은 이 숫자가 오르는 것 자체가 보상이다.
# 스탯 레벨. 스탯이 7개로 늘어 변수를 따로 두면 저장·조회·구매가 전부 갈라진다.
# StatDefs.STATS 의 key 를 그대로 쓴다.
var lv := {}

# 영웅 레벨 — 처치로 자동으로 오른다(Balance 참고). 피를 안 쓰는 유일한 성장축이라
# 방치만 해도 뭔가 오르고 있다는 감각을 준다.
var hero_lv := 1
var hero_exp := 0.0

var _phase := "advance"     # "advance"(다음 무리로 걸어가는 중) | "fight"(교전)
var _scroll := 0.0
var _walk_only := false   # [개발 도구] --walk
var _shot_wait := 2.5     # [개발 도구] --wait=N
var _bg2: Sprite2D          # 옆에 이어 붙이는 사본 (좌우 끝 기둥이 만나 이음매를 가린다)
var _attack_t := 0.0
var _hero_hit_t := -1.0
var _pending_target: Foe
var _bg: Sprite2D
var _hero: Sprite2D
var _hero_frames: Array = []
var _hero_anim := 0.0
# 영웅 외형. 확장은 캐릭터 추가가 아니라 스킨이라, 이 값만 바꾸면 모션 전체가 갈린다.
var skin := "valentino_1"
var _motion := ""
var _motion_hold := 0.0   # 이 시간이 남아 있는 동안은 idle 로 안 돌아간다
var hero_hp := 100.0
var hero_x := HERO_X      # 영웅의 현재 x. 대시로 매 프레임 움직인다
var hero_face := 1        # +1 오른쪽, -1 왼쪽. 원본이 왼쪽을 보므로 flip_h = face > 0
var _dash_to := HERO_X    # 이번에 붙으려는 자리
var _hero_dead := false
var _revive_t := 0.0
var _hero_flash_t := 0.0
var _death_tween: Tween
# 쓰러진 뒤 재시작까지. 뒤에 암전 전환(0.8초)이 더 붙으므로 여기서 3초를 끌면
# 죽을 때마다 4초를 멍하니 본다 — 죽음 연출(0.55초)이 끝날 만큼만 준다.
const REVIVE_TIME := 1.2
const DEATH_FADE_TIME := 0.55
const SKILL_DUR := 0.70
# 스킬 표는 SkillDefs.gd 하나뿐이다. 예전엔 여기 6종이 하드코딩돼 있었는데,
# 자산·이름·쿨다운이 코드 세 군데에 흩어져서 하나만 고치면 나머지가 어긋났다.
#
# 처음 주는 스킬. 아무것도 없으면 전투가 기본 공격뿐이라 스킬 시스템이 안 보인다.
const STARTER_SKILLS := ["strike_common", "wave_common"]
var _boss_time := -1.0
var _fade_rect: ColorRect    # 전투 띠만 덮는 암전판
var _fade_t := 0.0           # 0보다 크면 전환 중 — 타이머·전진·재시작이 다 멈춘다
var _skill_cd := {}          # 스킬 키 -> 남은 쿨다운
var skill_owned := {}        # 스킬 키 -> 레벨 (있으면 보유)
var skill_equipped: Array[String] = []   # 장착 6칸. 순서가 곧 발동 우선순위다
# 켜 두면 새 스킬을 얻거나 레벨을 올릴 때마다 알아서 다시 낀다. 방치형에서
# "더 센 걸 뽑았는데 안 끼고 있었다"는 플레이어 잘못이 아니라 UI 잘못이다.
# 손으로 한 칸이라도 만지면 꺼진다 — 고른 걸 뒤에서 덮어쓰면 그게 더 나쁘다.
var skill_auto_equip := true
var _skill_action := ""
var _skill_action_t := 0.0
var _skill_hit_t := 0.0
var _skill_impact_sent := false
var _skill_target: Foe
var _summon_t := 0.0
var _summon_bonus := 0.0   # 시전 순간의 가호 배수. 버프 도중 장비를 바꿔도 유지된다
var _defer_stage_advance := false
var _hud: CanvasLayer
var _hud_root: Control   # 테마가 걸린 실제 부모
var _lbl_stage: Label
var _lbl_gold: Label
var _lbl_essence: Label
var _lbl_gem: Label
var _lbl_prog: Label
var _lbl_power: Label
var _lbl_hero: Label
var _lbl_life: Label
var equipped := {}          # slot -> 장비 dict (없으면 키 없음)
var gear_inventory := {}     # 뽑은 장비 icon -> 최고 등급 장비 + copies
var codex := {}             # 몹 key -> 누적 처치 수
# 발견한 종 수와 **지식 합계**(몹별 지식 레벨의 총합). damage()·gold_mult() 가 매
# 프레임 도는 자리라 그때마다 22칸을 세지 않고, 값이 바뀌는 순간에만 다시 센다.
var codex_found := 0
var codex_knowledge := 0
var _gear_slots := {}       # slot -> {frame, icon, label, btn} 표시 노드
var _gear_equipped_view: Control
var _gear_inventory_view: Control
var _gear_inventory_grid: GridContainer
var _gear_mode := "equipped"
var _gear_mode_buttons := {}
var _gear_filter := "weapon"   # 보관함 탭 = 슬롯
var _gear_filter_buttons := {}
var _gear_detail: Control
var _gear_selected_key := ""
var _bulk_view: Control
var _bulk_title: Label
var _bulk_body: Label
var _bulk_run: Button
var _bulk_mode := "salvage"
var _bulk_grid: GridContainer
var _bulk_selected := {}
var _panels := {}           # 탭 이름 -> 창 (한 번에 하나만 보인다)
var _tab_btns := {}
var _tab := "growth"
var _codex_cells := {}
var _codex_summary: Label
var _codex_detail := {}
var _codex_selected := ""
var _status_view: Control
var _status_head: Label
var _status_now: Label
var _status_rows: Array[Dictionary] = []
var gacha_pity := {"weapon": 0, "armor": 0, "trinket": 0, "skill": 0}
var gacha_pulls := {"weapon": 0, "armor": 0, "trinket": 0, "skill": 0}
var gacha_owned := {}
var gacha_shards := {}
var free_pull_date := ""
var _gacha_kind := "weapon"
# 소환 창 왼쪽 그림 자리. 창(y 68~246)의 세로 한가운데에 온다.
# 원본 64px 을 정확히 2배로 그린다 — 1.5배(96)로 놓으면 도트가 어긋나 혼자 흐려 보인다.
const GACHA_ART_BOX := 128.0
const GACHA_ART_X := 26.0    # 창 왼쪽(18) + 안쪽 여백 8
const GACHA_ART_Y := 78.0    # 아래에 확률표 버튼을 넣으려고 위로 붙였다
# 레벨별 확률표를 펼쳐 보는 창. 지금 레벨의 확률만 보이면 "올리면 뭐가 좋아지는지"가
# 숫자로 안 잡힌다 — 해금 레벨만 적혀 있고 그 뒤가 안 보인다.
# 0레벨부터 만렙까지 **전부** 보여 준다. 몇 개만 뽑아 보여 주면 그 사이가 어떻게
# 되는지 알 수 없다. 가로가 모자라니 옆으로 굴린다.
const RATE_ROW_H := 30.0
const RATE_NAME_W := 92.0
const RATE_COL_W := 86.0
var _gacha_icon: TextureRect
var _gacha_labels := {}
var _gacha_buttons := {}
var _gacha_reveal: Control
var _rates_view: Control
var _rates_head: Label
var _rates_scroll: ScrollContainer
var _rates_heads: Array[Label] = []
var _rates_cells: Array = []
var buy_step := 1          # 한 번에 올리는 단계 수 (x1 / x10 / x100)
var _stat_rows := {}
var _growth_mode := "stat"
var _growth_mode_buttons := {}
var _stat_view: Control
var _skill_view: Control
var _skill_slots: Array[Dictionary] = []
var _skill_grid: GridContainer
var _skill_info: Label
var _skill_bulk_btn: Button
var _skill_auto_btn: Button
var _skill_synth_btn: Button
var _step_btns: Array[Button] = []
var _stage_bar: ProgressBar
var _offline_banner: Label
var _power_toast: Label
var _confirm_view: Control
var _confirm_body: Label
var _confirm_action := Callable()
var _reward_view: Control
var _reward_title: Label
var _reward_row: HBoxContainer
var _offline_t := 0.0
var _visual_hitstop_t := 0.0
var _combat_shake: Tween
var _boss_pan_t := 0.0   # 보스 등장 연출이 도는 동안은 흔들림을 막는다
const HITSTOP_DUR := 0.035


# ── 스탯 ───────────────────────────────────────────────────────────────────
# 곱연산을 피하고 선형으로 둔다. 방치형에서 지수 성장은 곧 "몇 시간 방치"가 되고,
# 그때부터는 게임이 아니라 대기표가 된다.
func stat_lv(key: String) -> int:
	return int(lv.get(key, 1))


func damage() -> float:
	return Balance.hero_damage(stat_lv("damage"), _gear_stat("damage"), hero_lv) \
		* (1.0 + _collection_bonus("damage") + FoeTiers.codex_bonus(codex_knowledge,"damage"))


# 장착 중인 장비가 주는 해당 스탯 합. 없으면 0.
func _gear_stat(stat: String) -> float:
	var sum := 0.0
	for item in equipped.values():
		if str(item.get("stat", "")) == stat:
			sum += GearDefs.power(item)
	return sum


func _collection_bonus(stat: String) -> float:
	var sum := 0.0
	for item in gear_inventory.values():
		if str(item.get("stat", "")) == stat:
			sum += GearDefs.collection_rate(item)
	return sum


func attack_interval() -> float:
	return Balance.attack_interval(stat_lv("speed"))


func gold_mult() -> float:
	return (1.0 + 0.15 * float(stat_lv("gold") - 1) + _gear_stat("gold") * 0.02) \
		* Balance.hero_mult(hero_lv) \
		* (1.0 + _collection_bonus("gold") + FoeTiers.codex_bonus(codex_knowledge,"gold"))


func dps() -> float:
	# 버프 스킬은 장착돼 있을 때만 계산에 넣는다. 없으면 시전 손실도 지속 이득도 없다.
	var ward := _equipped_shape("ward")
	return Balance.auto_dps(_base_hit_damage() * (1.0 + _codex_act_bonus()),
		attack_interval(), SKILL_DUR,
		float(ward.get("cooldown", 999.0)), float(ward.get("duration", 0.0)),
		float(ward.get("bonus", 0.0)))


# 장착 중인 것 가운데 그 형태의 첫 스킬. 없으면 빈 사전.
func _equipped_shape(shape: String) -> Dictionary:
	for key in skill_equipped:
		if str(SkillDefs.split(str(key))[0]) == shape:
			return _skill_data(str(key))
	return {}


func _base_hit_damage() -> float:
	return damage() * Balance.crit_mult(stat_lv("crit"), stat_lv("critdmg"))


# 실제 타격 피해. 대상을 주면 그 몹의 **지식 레벨**만큼 더 아프게 때린다.
# 대상을 안 주면(광역 스킬·표시용) 지금 막의 평균을 쓴다 — 아래 _codex_act_bonus().
func _combat_damage(target: Foe = null) -> float:
	var known := _codex_act_bonus() if target == null \
		else FoeTiers.codex_kill_bonus(int(codex.get(target.key, 0)))
	# 버프 배수는 **시전할 때 잡아 둔 값**을 쓴다. 여기서 1.3 을 다시 적으면
	# SHAPES["ward"]["bonus"] 와 두 군데가 되어 한쪽만 고쳤을 때 화면 DPS(dps())와
	# 실제 피해가 갈린다. 들고 있으면 버프 도중에 장비를 바꿔도 안 사라진다.
	return _base_hit_damage() * (1.0 + _summon_bonus if _summon_t > 0.0 else 1.0) \
		* (1.0 + known)


# 지금 막 로스터의 지식 보너스 평균. 전투력 표시와 오프라인 판정이 쓴다 —
# 대상별로 다른 값을 그대로 두면 "전투력"이 화면마다 달라지고, 오프라인 계산에서는
# 아예 대상이 없다. 평균은 실제로 그 막에서 나오는 몹들의 기댓값이라 거짓말이 아니다.
func _codex_act_bonus() -> float:
	var roster: Array = StageDefs.act_data(stage)["roster"]
	if roster.is_empty():
		return 0.0
	var sum := 0.0
	for key in roster:
		sum += FoeTiers.codex_kill_bonus(int(codex.get(str(key), 0)))
	return sum / float(roster.size())


func max_hp() -> float:
	return Balance.hero_max_hp(stat_lv("tough"), _gear_stat("tough")) \
		* (1.0 + _collection_bonus("tough") + FoeTiers.codex_bonus(codex_knowledge, "tough"))


func regen_per_sec() -> float:
	return Balance.hero_regen_per_sec(max_hp(), stat_lv("regen"))


# 최대 체력이 늘 때 늘어난 몫만큼 현재 체력도 채운다. 강해졌는데 즉시 체력 비율이
# 떨어지는 역보상을 막되, 기존에 잃은 체력까지 공짜로 회복하지는 않는다.
func _apply_hp_growth(old_max: float) -> void:
	hero_hp = minf(max_hp(), hero_hp + maxf(0.0, max_hp() - old_max))


func upgrade_cost(key: String, level: int) -> float:
	var s := StatDefs.of(key)
	return Balance.upgrade_cost(level, s.get("base", 10.0), s.get("exp", 1.15))


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	var preview_stage := 0
	for arg in args:
		if arg.begins_with("--stage="):
			preview_stage = StageDefs.parse(arg.trim_prefix("--stage="))
	_build_scene()
	_load_game()
	if preview_stage > 0:
		stage = preview_stage
		kills = 0
		hero_hp = max_hp()
	_apply_stage_bg()
	_boss_time = StageDefs.time_limit(stage)
	_start_advance()
	_refresh_gear_slots()
	# 보관함도 여기서 한 번 새로 그린다. _build_scene() 은 _load_game() **앞**이라
	# 그때 센 칸 수는 항상 0이고, 그 뒤로는 소환·분해 때만 갱신돼서
	# 불러오기 직후에는 탭 숫자와 목록이 빈 저장본 기준으로 남아 있었다.
	_refresh_gear_inventory()
	_refresh_hud()
	for arg in args:
		# [개발 도구] --tab=gear 처럼 특정 창을 띄운 채로 캡처하려고 둔다.
		if arg.begins_with("--tab="):
			_select_tab(arg.trim_prefix("--tab="))
		# [개발 도구] --skills[=N] : 스킬 화면을 연다. N 을 주면 그만큼 무작위로 보유시킨다.
		if arg.begins_with("--skills"):
			var give := int(arg.trim_prefix("--skills=")) if "=" in arg else 0
			var pool := SkillDefs.all_keys()
			pool.shuffle()
			for i in mini(give, pool.size()):
				skill_owned[str(pool[i])] = randi() % 4
				gacha_shards["skill:" + str(pool[i])] = randi() % 12
			if give > 0:
				_auto_equip_skills()
			_select_tab("growth")
			_set_growth_mode("skill")
		# [개발 도구] --skillfx[=strike|wave|field|ward] : 그 형태의 **5등급을 나란히**
		# 실제 프로필(스타일·잔상·크기)로 얹는다. 크기와 가림 정도는 288px 띠에
		# 올려 봐야만 판단할 수 있다.
		#
		# 예전엔 `fx_sk_strike` 같은 **없는 폴더**를 참조해서 아무것도 안 그려졌다
		# (`_anim_fx` 는 프레임이 없으면 조용히 빠진다). 이펙트 이름은 등급까지 붙은
		# `SkillDefs.fx_of()` 가 단일 출처다 — 여기서 다시 적지 않는다.
		if arg.begins_with("--skillfx"):
			var fx_shape := arg.trim_prefix("--skillfx=") if "=" in arg else "strike"
			if not SkillDefs.SHAPES.has(fx_shape):
				fx_shape = "strike"
			# 이펙트는 0.6초면 끝나고 스스로 지워진다. 한 번만 띄우면 `--wait` 기본값
			# 2.5초 뒤의 캡처에는 이미 아무것도 없다 — 그래서 계속 다시 띄운다.
			#
			# 주기는 **가장 짧은 수명(격 0.56초)보다 짧아야** 한다. 0.8초로 뒀더니
			# 사이에 빈 구간이 생겨 캡처가 자꾸 아무것도 없는 순간에 걸렸다.
			var fx_timer := Timer.new()
			fx_timer.wait_time = 0.45
			fx_timer.autostart = true
			fx_timer.timeout.connect(func() -> void:
				for i in 5:
					var fx_key := SkillDefs.key_of(fx_shape,
						str(GachaDefs.RARITIES[i]["key"]))
					var fp := SkillDefs.fx_profile(fx_key)
					_anim_fx(str(fp["fx"]),
						Vector2(64.0 + float(i) * 112.0, ground_y + float(fp["y"])),
						float(fp["fps"]), float(fp["scale"]), str(fp["style"]),
						int(fp["echo"])))
			add_child(fx_timer)
		# [개발 도구] --equip=first : 첫 보관 장비를 장착해 "장착 중" 표시를 캡처한다.
		if arg == "--equip=first" and not gear_inventory.is_empty():
			_equip_inventory_item(str(gear_inventory.keys()[0]))
		# [개발 도구] --dialog=confirm|reward : 확인창/보상창을 연 채 캡처한다.
		if arg.begins_with("--dialog="):
			if arg.ends_with("confirm"):
				_ask("선택한 장비 12개를 분해합니다.\n정수 3.4k 을 얻습니다.\n\n되돌릴 수 없습니다.",
					func() -> void: pass)
			else:
				_show_reward("분해 완료", [{"icon": "res://assets/items/gem.png",
					"label": "정수 +3.4k"}])
		# [개발 도구] --rates : 소환 레벨별 확률표를 연 채 캡처한다.
		if arg == "--rates":
			_select_tab("summon")
			_rates_view.visible = true
			_refresh_rates_table()
		# [개발 도구] --bulk=salvage|fuse[:all] : 분해/조합 창을 연 채 캡처한다.
		if arg.begins_with("--bulk="):
			var bulk_args := arg.trim_prefix("--bulk=").split(":")
			_select_tab("gear")
			_set_gear_mode("inventory")
			_open_bulk(str(bulk_args[0]))
			if bulk_args.size() > 1 and str(bulk_args[1]) == "all":
				_bulk_select_all(true)
		# [개발 도구] --status : 도감의 능력치 창을 연 채로 캡처한다.
		if arg == "--status":
			_select_tab("codex")
			_status_view.visible = true
			_refresh_status()
		# [개발 도구] --gacha=armor : 해금된 소환 종류를 선택해 캡처한다.
		if arg.begins_with("--gacha="):
			_set_gacha_kind(arg.trim_prefix("--gacha="))
		# [개발 도구] --wait=8 : 캡처 전 대기 시간. 진행바처럼 값이 차야 보이는 것을
		# 확인할 때 쓴다.
		if arg.begins_with("--wait="):
			_shot_wait = float(arg.trim_prefix("--wait="))
		# [개발 도구] --pull=gear:10 : 비용을 채운 뒤 실제 뽑기/결과 연출까지 캡처한다.
		if arg.begins_with("--pull="):
			var pull_args := arg.trim_prefix("--pull=").split(":")
			var pull_kind := str(pull_args[0])
			if pull_kind == "gear":
				pull_kind = "weapon"
			var pull_count := int(pull_args[1]) if pull_args.size() > 1 else 1
			_set_gacha_kind(pull_kind)
			free_pull_date = Time.get_date_string_from_system()
			gem = maxf(gem, GachaDefs.COST * float(pull_count))
			_pull_gacha(pull_count)
		# [개발 도구] --gear-mode=inventory : 보관함을 연 채 캡처한다.
		if arg.begins_with("--gear-mode="):
			_set_gear_mode(arg.trim_prefix("--gear-mode="))
		# [개발 도구] --gear-detail=first : 첫 보관 장비 상세/합성 팝업을 연다.
		if arg == "--gear-detail=first" and not gear_inventory.is_empty():
			_open_gear_detail(str(gear_inventory.keys()[0]))
		# [개발 도구] --walk: 무리를 치우고 계속 걷게 해 스크롤 이음매를 확인한다.
		if arg == "--walk":
			_walk_only = true
			for f in get_tree().get_nodes_in_group("foes"):
				f.queue_free()
	if "--autoshot" in args:
		_autoshot()


# [개발 도구] --autoshot: 몇 초 굴린 뒤 화면을 저장하고 종료.
# 바탕화면 캡처는 다른 창이 앞으로 나오면 엉뚱한 그림이 찍혀서, 게임이 자기
# 뷰포트를 직접 저장하게 한다.
func _autoshot() -> void:
	await get_tree().create_timer(_shot_wait).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://autoshot.png")
	print("AUTOSHOT SAVED: ", ProjectSettings.globalize_path("user://autoshot.png"))
	get_tree().quit()


# ── 씬 구성 ────────────────────────────────────────────────────────────────
func _build_scene() -> void:
	_bg = Sprite2D.new()
	_bg.centered = false
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 배경 원본은 288x512이고 2배로 그려 576x1024를 채운다. 스프라이트(32px)도 2배라
	# 화면의 모든 도트가 같은 크기가 된다 — 배경만 뭉개져 보이는 일이 없다.
	_bg.scale = Vector2(2, 2)
	_bg.z_index = -20
	add_child(_bg)
	# 배경 한 장을 그대로 옆에 붙인다. 반전해 붙이면 픽셀은 완벽히 이어지지만
	# 이 배경이 좌우 대칭 구도(가운데 길)라 이음매가 나비처럼 보였다.
	# 그냥 붙이면 좌우 끝의 어두운 나무 기둥 둘이 만나 굵은 나무 하나로 읽힌다.
	_bg2 = Sprite2D.new()
	_bg2.centered = false
	_bg2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg2.scale = Vector2(2, 2)
	_bg2.z_index = -20
	add_child(_bg2)

	_hero = Sprite2D.new()
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.position = Vector2(HERO_X, ground_y - float(Grid.SPRITE))   # 발밑 = ground_y
	_hero.scale = Vector2(2, 2)   # 32px 원본 -> 64px. 배경도 2배라 도트 밀도가 같다.
	# 원본은 왼쪽을 보고 있는데 몹은 오른쪽에서 오므로 뒤집는다.
	_hero.flip_h = true
	_hero.z_index = 3
	add_child(_hero)
	_play("idle")

	_hud = CanvasLayer.new()
	add_child(_hud)
	# 폰트는 여기 한 번만 건다. 자식 컨트롤이 전부 상속받는다.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Type.theme()
	_hud.add_child(root)
	_hud_root = root
	_build_frame()
	# 상단 상태창 — 배경 위에 글씨만 얹으면 안 읽혀서 패널을 깐다.
	_hud_root.add_child(Ui.panel(Grid.uv(0, 0), Grid.uv(36, 12)))
	_build_topbar()
	_offline_banner = _mk_label(Vector2(TOP_PAD, VIEW_TOP + 6.0), Type.SIZE_SMALL,
		Color(0.95, 0.55, 0.55))
	_offline_banner.visible = false
	# 전투력 알림은 **전용 줄**이다. 오프라인·장비 알림과 같은 줄을 쓰면 그쪽이 떠 있는
	# 동안 상승이 통째로 안 보인다 — 전투력은 오를 때마다 무조건 보여야 한다.
	_power_toast = _mk_label(Vector2(TOP_PAD, VIEW_TOP + 30.0), Type.SIZE_SMALL,
		Color(1.0, 0.82, 0.42))
	_power_toast.size = Vector2(float(Grid.BG.x) - TOP_PAD * 2.0, 24.0)
	_power_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_toast.visible = false
	# 전투 띠 안에서 생존 상태를 바로 읽는다. 오른쪽 절반만 써 오프라인 알림과
	# 겹치지 않고, 별도 패널을 늘려 전투를 가리지 않는다.
	_lbl_life = _mk_label(Vector2(float(Grid.BG.x) * 0.52, VIEW_TOP + 4.0),
		Type.SIZE_SMALL, Color(0.72, 0.95, 0.78))
	_lbl_life.size = Vector2(float(Grid.BG.x) * 0.48 - TOP_PAD, 24.0)
	_lbl_life.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_life.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 콘텐츠 창 — 탭으로 하나만 띄운다. 세로 화면에서 전부 펼치면 전투가 안 보인다.
	_build_panels()
	_build_tabbar()
	_build_dialogs()
	_select_tab("growth")


# ── 영웅 모션 ──────────────────────────────────────────────────────────────
# idle / walk / attack / hurt 네 벌. 스킨을 갈아도 프레임 수와 타이밍이 같으므로
# 여기 말고 고칠 곳이 없다.
const MOTION_FPS := {"idle": 6.0, "walk": 10.0, "dash": 15.0, "hurt": 14.0}
const LOOPING := ["idle", "walk", "dash"]   # 나머지는 한 번 재생하고 idle 로 돌아간다


func _play(motion: String, hold := 0.0) -> void:
	# 루프 모션은 이미 재생 중이면 그대로 둔다. 공격·피격은 매번 처음부터 다시 튼다 —
	# 안 그러면 두 번째 공격부터 모션이 안 보인다.
	if motion == _motion and motion in LOOPING:
		return
	_motion = motion
	_motion_hold = hold
	_hero_anim = 0.0
	_hero_frames = Assets.frames("res://assets/anim/%s_%s" % [skin, motion])
	if _hero_frames.is_empty() and motion == "dash":
		# 달리기 그림이 아직 없으면 걷기를 빠르게 돌린다. 보폭은 덜해도
		# 멈춰 서서 순간이동하는 것보다 훨씬 낫다.
		_hero_frames = Assets.frames("res://assets/anim/%s_walk" % skin)
	if _hero_frames.is_empty():
		# 스킨에 그 모션이 없으면 idle 로 떨어진다 — 빈 화면보다 낫다.
		_hero_frames = Assets.frames("res://assets/anim/%s_idle" % skin)
	if _hero_frames.is_empty():
		_hero.texture = Assets.tex("res://assets/hero/%s.png" % skin)


# 공격 모션은 공격 주기에 맞춰 재생 속도를 바꾼다. 고정 fps로 두면 공격속도를
# 올려도 그림이 그대로라 업글한 느낌이 안 난다.
func _motion_fps() -> float:
	if _motion == "attack":
		return float(_hero_frames.size()) / maxf(0.08, attack_interval())
	if _motion == "heavy" or _motion == "cast":
		return float(_hero_frames.size()) / SKILL_DUR
	return float(MOTION_FPS.get(_motion, 6.0))


func _tick_motion(delta: float) -> void:
	if _hero_dead:
		return
	_hero_anim += delta
	if _hero_frames.size() > 0:
		var i := int(_hero_anim * _motion_fps())
		if _motion in LOOPING:
			_hero.texture = _hero_frames[i % _hero_frames.size()]
		else:
			# 한 번만 재생하고 마지막 프레임에서 멈춘다 — 공격이 루프로 돌면 광란이 된다.
			_hero.texture = _hero_frames[mini(i, _hero_frames.size() - 1)]
	if _motion_hold > 0.0:
		_motion_hold -= delta
	elif not (_motion in LOOPING) and _hero_anim >= float(_hero_frames.size()) / _motion_fps():
		_play("idle")


# 전투 띠 위아래를 불투명하게 덮어 "게임 화면"과 "UI"를 갈라놓는다.
# 스프라이트를 실제로 잘라내는 게 아니라 위아래를 가리는 것이다 — 전투는 이 띠를
# 벗어나지 않으므로(ground_y 기준) 잘라내기와 결과가 같고 코드는 훨씬 적다.
const UI_BACK := Color(0.093, 0.084, 0.103)
const VIEW_EDGE := Color(0.32, 0.10, 0.12)


func _build_frame() -> void:
	# 전투 띠 밖은 상단·하단 패널이 통째로 덮으므로 따로 칠할 게 없다.
	# 경계선만 그어 "여기까지가 게임 화면"을 알린다.
	for y in [VIEW_TOP - 2.0, VIEW_BOTTOM]:
		var line := ColorRect.new()
		line.color = VIEW_EDGE
		line.position = Vector2(0, y)
		line.size = Vector2(Grid.BG.x, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(line)
	# 암전판. 경계선 뒤에 만들어 선 위로 올라가고, 상단/하단 패널보다는 아래라
	# 전투 띠만 검어진다. 알림 라벨은 이 뒤에 만들어지므로 암전 위에 남는다.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.position = Vector2(0, VIEW_TOP)
	_fade_rect.size = Vector2(Grid.BG.x, VIEW_BOTTOM - VIEW_TOP)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_hud_root.add_child(_fade_rect)


# 큰 수는 줄여 쓴다. 방치형은 재화가 금방 억을 넘는데 그대로 찍으면 패널을 넘는다.
# 만/억/조가 아니라 k/m/b 인 이유: 방치형 표준 표기라 눈에 익다(사장님 지시).
# **대문자가 아니라 소문자인 이유**: 이 폰트(블랙레터)의 대문자 K 는 획이 꺾여
# "Ж" 처럼 읽힌다 — 실제로 폰트를 렌더해서 확인했다. 소문자 k·m·b·t 는 획이 단순해
# 그대로 읽힌다. 단위 글자를 바꿀 때는 반드시 같은 방법으로 렌더해서 확인할 것.
static func _n(v: float) -> String:
	if v < 1000.0:
		return str(int(v))
	var units := ["k", "m", "b", "t"]
	var i := -1
	while v >= 1000.0 and i < units.size() - 1:
		v /= 1000.0
		i += 1
	return ("%.1f" % v).trim_suffix(".0") + units[i]


# 발밑 접지 그림자. 이게 없으면 몹이 바닥에 선 게 아니라 떠 있는 것처럼 보인다.
# Main 은 z=0 이라 배경(-20) 위, 몹(1~2)·영웅(3) 아래에 깔린다.
func _draw() -> void:
	_shadow(Vector2(hero_x, ground_y), 22.0)
	# 영웅 머리 위의 작은 체력 바. 상단 숫자를 읽지 않아도 위험 상태가 보인다.
	var hp_at := Vector2(hero_x - 32.0, ground_y - 112.0)
	draw_rect(Rect2(hp_at, Vector2(64.0, 5.0)), Color(0.03, 0.03, 0.04, 0.85))
	draw_rect(Rect2(hp_at + Vector2(1.0, 1.0), Vector2(62.0
		* clampf(hero_hp / maxf(1.0, max_hp()), 0.0, 1.0), 3.0)),
		Color(0.78, 0.14, 0.18))
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f) and not f.dying:
			_shadow(Vector2(f.position.x, ground_y), f.shadow_r())


func _shadow(at: Vector2, r: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 상단 상태창. 왼쪽에 "어디까지 왔나", 오른쪽에 "얼마나 세졌나".
# 방치형은 이 두 줄이 곧 게임의 전부라 화면에서 제일 위에 온다.
const TOP_PAD := 30.0        # 패널 테두리에서 띄우는 여백 (좌·우 공통)
const TOP_ROW := 40.0        # 아이콘·글자 한 줄 높이
const TOP_ICON := 32.0


func _build_topbar() -> void:
	var w := float(Grid.BG.x)
	var right := w - TOP_PAD
	# 1줄: 막 이름과 단계 (왼쪽) / 전투력 (오른쪽)
	_lbl_hero = _mk_label(Vector2(TOP_PAD, 14.0), Type.SIZE_SMALL, Color(0.72, 0.92, 0.72))
	_lbl_hero.size = Vector2(76.0, 40.0)
	_lbl_hero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_stage = _mk_label(Vector2(TOP_PAD + 82.0, 14.0), Type.SIZE_BODY,
		Color(1.0, 0.9, 0.55))
	_lbl_stage.size = Vector2(w - TOP_PAD * 2.0 - 82.0, 40.0)
	_lbl_stage.clip_text = true
	_lbl_stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 전투력은 2줄로 내린다. 1줄에 같이 두면 막 이름이 길 때 글자가 겹친다.
	_lbl_power = _mk_label(Vector2(w * 0.4, 58.0), Type.SIZE_SMALL, Color(1.0, 0.78, 0.38))
	_lbl_power.size = Vector2(w * 0.6 - TOP_PAD, 24.0)
	_lbl_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 2줄: 진행 숫자 + 진행바. 숫자만으로는 "얼마나 남았나"가 곁눈질로 안 읽힌다.
	_lbl_prog = _mk_label(Vector2(TOP_PAD, 58.0), Type.SIZE_SMALL, Color(0.8, 0.85, 0.95))
	_lbl_prog.size.y = 24.0
	_lbl_prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_bar = Ui.bar(Vector2(TOP_PAD, 86.0), right - TOP_PAD, Color(0.78, 0.18, 0.22))
	_hud_root.add_child(_stage_bar)
	# 3줄: 성장에 쓰는 재화는 어디서든 한 번에 읽히도록 한 줄에 모은다.
	_hud_root.add_child(Ui.panel(Vector2(18.0, 132.0), Vector2(540.0, 48.0)))
	var currencies := [
		["res://assets/ui/res_blood.png", Color(1.0, 0.4, 0.4)],
		["res://assets/items/gem.png", Color(0.72, 0.82, 1.0)],
		["res://assets/ui/res_gem.png", Color(0.86, 0.72, 1.0)],
	]
	var labels: Array[Label] = []
	var icons: Array[TextureRect] = []
	# 아이콘 36px = 원본 32px 보다 크지만 NEAREST 라 도트가 뭉개지지 않는다.
	# 24px 은 32px 원본을 줄이는 쪽이라 오히려 도트가 깨져 뭉개져 보였다.
	for i in currencies.size():
		var x := 30.0 + float(i) * 176.0
		var ic := Ui.icon(currencies[i][0], Vector2(x, 138.0), 36.0)
		_hud_root.add_child(ic)
		icons.append(ic)
		var label := _mk_label(Vector2(x + 42.0, 140.0), Type.SIZE_SMALL, currencies[i][1])
		label.size = Vector2(126.0, 30.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		labels.append(label)
	_lbl_gold = labels[0]
	_lbl_essence = labels[1]
	_lbl_gem = labels[2]
	_currency_icons = icons


# ── 공용 확인창 / 보상창 ───────────────────────────────────────────────────
# 분해·조합 전용으로 만들지 않는다. "되돌릴 수 없으니 한 번 더 묻기"와 "뭘 얻었는지
# 보여 주기"는 앞으로 붙일 콘텐츠(업적·일일·탑) 전부가 쓴다 — 그때마다 새로 그리면
# 창마다 버튼 위치가 달라진다.
#
# 화면 전체를 덮으므로 탭 창이 아니라 _hud_root 바로 밑에 단다.
const DLG_W := 480.0
const DLG_AT := Vector2(48.0, 300.0)
const DLG_H := 248.0


func _build_dialogs() -> void:
	# 확인창
	_confirm_view = _overlay(60)
	_confirm_view.add_child(Ui.panel(DLG_AT, Vector2(DLG_W, DLG_H)))
	var title := _dlg_label(_confirm_view, Vector2(DLG_AT.x, DLG_AT.y + 20.0),
		Type.SIZE_BODY, Color(0.96, 0.90, 0.86), DLG_W, 32.0)
	title.text = "알림"
	_confirm_body = _dlg_label(_confirm_view, Vector2(DLG_AT.x + 28.0, DLG_AT.y + 72.0),
		Type.SIZE_SMALL, Color(0.90, 0.88, 0.92), DLG_W - 56.0, 92.0)
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bw := (DLG_W - 56.0 - 16.0) * 0.5
	var cancel := Ui.button("취소", Vector2(DLG_AT.x + 28.0, DLG_AT.y + DLG_H - 76.0),
		Vector2(bw, 48.0), Type.SIZE_SMALL)
	cancel.pressed.connect(func() -> void: _confirm_view.visible = false)
	_confirm_view.add_child(cancel)
	var ok := Ui.button("확인",
		Vector2(DLG_AT.x + 44.0 + bw, DLG_AT.y + DLG_H - 76.0),
		Vector2(bw, 48.0), Type.SIZE_SMALL)
	ok.pressed.connect(func() -> void:
		_confirm_view.visible = false
		if _confirm_action.is_valid():
			_confirm_action.call())
	_confirm_view.add_child(ok)

	# 보상창 — 빈 곳 아무 데나 눌러 닫는다. 읽고 나면 바로 없애고 싶은 창이라
	# 닫기 버튼을 찾게 하지 않는다.
	_reward_view = _overlay(61)
	var tap := Button.new()
	tap.flat = true
	tap.size = Vector2(Grid.BG)
	tap.focus_mode = Control.FOCUS_NONE
	tap.pressed.connect(func() -> void: _reward_view.visible = false)
	_reward_view.add_child(tap)
	_reward_view.add_child(Ui.panel(Vector2(48.0, 320.0), Vector2(DLG_W, 176.0)))
	# 창 위에 얹는 문장. 보상은 "알림"이 아니라 "받았다"라서 머리 장식이 하나 필요하다.
	# 크기를 적어 두지 않고 **원본에서 재서** 정확히 2배로 그린다 — 그림을 바꿔도
	# 도트 밀도가 유지되고 가운데도 저절로 맞는다(원본이 캔버스 가운데가 아닐 수 있다).
	# 아랫변을 창 윗변(320)에 딱 맞춰 제목(336~) 위로 절대 안 내려온다.
	var crest := Assets.tex("res://assets/ui/reward_crest.png")
	if crest != null:
		var cw := float(crest.get_width()) * 2.0
		var ch := float(crest.get_height()) * 2.0
		_reward_view.add_child(Ui.image("res://assets/ui/reward_crest.png",
			Vector2(48.0 + (DLG_W - cw) * 0.5, 320.0 - ch), Vector2(cw, ch)))
	_reward_title = _dlg_label(_reward_view, Vector2(48.0, 336.0), Type.SIZE_BODY,
		Color(1.0, 0.88, 0.55), DLG_W, 32.0)
	_reward_row = HBoxContainer.new()
	_reward_row.position = Vector2(48.0, 376.0)
	_reward_row.size = Vector2(DLG_W, 92.0)
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", 16)
	_reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_view.add_child(_reward_row)
	# 안내는 **창 밖**에 둔다. 안에 넣으면 보상과 같은 무게로 읽혀서 눈이 한 번 더 멈춘다.
	var hint := _dlg_label(_reward_view, Vector2(48.0, 508.0), Type.SIZE_SMALL,
		Color(0.68, 0.66, 0.72), DLG_W, 20.0)
	hint.text = "빈 곳을 눌러 닫기"


# 화면 전체를 덮는 반투명 판. 뒤 화면이 비쳐야 "어느 창 위에 떴는지"가 읽힌다.
func _overlay(z: int) -> Control:
	var c := Control.new()
	c.size = Vector2(Grid.BG)
	c.visible = false
	c.z_index = z
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.size = Vector2(Grid.BG)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	_hud_root.add_child(c)
	return c


func _dlg_label(parent: Control, pos: Vector2, size: int, col: Color,
		w: float, h: float) -> Label:
	var l := Ui.label("", pos, size, col)
	l.size = Vector2(w, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _ask(text: String, on_ok: Callable) -> void:
	_confirm_body.text = text
	_confirm_action = on_ok
	_confirm_view.visible = true


# entries: [{"icon": 경로, "label": "정수 +1.2k"}, ...]
func _show_reward(title: String, entries: Array) -> void:
	_reward_title.text = title
	for child in _reward_row.get_children():
		child.queue_free()
	for e in entries:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(88.0, 92.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 등급 틀을 두르면 무엇을 얻었는지가 **색으로 먼저** 읽힌다. 이름만 있으면
		# 커먼을 받았는지 레전더리를 받았는지 글자를 다 읽어야 안다.
		var col := Color(e["col"]) if e.has("col") else Color(1, 1, 1)
		if e.has("col"):
			var frame := Ui.image("res://assets/ui/slot_common.png",
				Vector2(12.0, 0.0), Vector2(64.0, 64.0))
			frame.modulate = col
			cell.add_child(frame)
			cell.add_child(Ui.icon(str(e.get("icon", "")), Vector2(20.0, 8.0), 48.0))
		else:
			cell.add_child(Ui.icon(str(e.get("icon", "")), Vector2(12.0, 0.0), 64.0))
		var lbl := _panel_label(cell, Vector2(0.0, 64.0), Type.SIZE_SMALL,
			Color(0.95, 0.92, 0.88), 88.0, 16.0)
		lbl.text = str(e.get("label", ""))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if e.has("sub"):
			var sub := _panel_label(cell, Vector2(0.0, 78.0), Type.SIZE_SMALL,
				col, 88.0, 16.0)
			sub.text = str(e["sub"])
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reward_row.add_child(cell)
	_reward_view.visible = true


func _mk_label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.95))
	_hud_root.add_child(l)
	return l


# 콘텐츠 창 3개. 창은 전부 같은 자리(rows 37..57)를 쓰고 탭이 하나만 켠다.
const PANEL_AT := Vector2(0, 30)
const PANEL_SIZE := Vector2(36, 20)
# 창 안쪽 여백. 창마다 다른 값을 쓰면 어느 창은 글자가 테두리에 닿는다 — 여기 하나만 본다.
const PAD := 26.0   # 패널 테두리(Ui.PANEL_MARGIN=12)보다 넉넉히 안쪽
const PANEL_W := 576.0
const PANEL_H := 320.0
const CONTENT_W := PANEL_W - PAD * 2.0    # 528
const CONTENT_BOTTOM := PANEL_H - PAD     # 296


func _build_panels() -> void:
	# 콘텐츠와 탭바는 별도 판이다. 한 장으로 덮으면 하단 메뉴가 콘텐츠에 붙어 보인다.
	_hud_root.add_child(Ui.panel(Grid.uv(0, 30), Grid.uv(36, 20)))
	for name in ["growth", "gear", "summon", "codex"]:
		var c := Control.new()
		c.position = Grid.pxv(Grid.uv(PANEL_AT.x, PANEL_AT.y))
		c.size = Grid.uv(PANEL_SIZE.x, PANEL_SIZE.y)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(c)
		_panels[name] = c
	_build_growth(_panels["growth"])
	_build_gear(_panels["gear"])
	_build_gacha(_panels["summon"])
	_build_codex(_panels["codex"])


# 창 안 라벨. _mk_label 은 HUD 루트에 붙지만 창 안 글씨는 창과 같이 숨어야 한다.
# width 를 주면 그 폭으로 묶고 넘치는 글자를 잘라낸다(옆 칸과 겹치는 걸 막는다).
# 0 이면 글자 길이대로 늘어난다 — clip_text 를 폭 없이 켜면 폭이 0으로 잡혀
# 글자가 통째로 안 보인다. 반드시 같이 준다.
func _panel_label(parent: Control, pos: Vector2, size: int, col: Color,
		width := 0.0, height := 0.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		l.size.x = width
		l.clip_text = true
	if height > 0.0:
		# 아이콘 옆 글자는 아이콘 한가운데에 와야 한다. 위에서부터 그리면
		# 글자 크기가 다를 때마다 줄이 어긋난다.
		l.size.y = height
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


# 성장 창. 스탯 7개를 스크롤 목록으로 세운다.
# 한 행에 아이콘 · 레벨 · 이름 · 실제 효과 · 훈련 버튼(비용)이 다 들어간다.
const BUY_STEPS := [1, 10, 100]
const ROW_H := 60.0
const STEP_H := 40.0


func _build_growth(root: Control) -> void:
	# 탭바가 4칸으로 꽉 차서 스킬을 새 탭으로 못 낸다. 성장 창 안에서 나눈다 —
	# 스탯도 스킬도 "무엇을 키울까"라서 자리가 맞는다.
	var mode_w := (CONTENT_W - 12.0) * 0.5
	for i in 2:
		var mode := "stat" if i == 0 else "skill"
		var mb := Ui.button("스탯" if i == 0 else "스킬",
			Vector2(PAD + float(i) * (mode_w + 12.0), PAD - 4.0),
			Vector2(mode_w, 34.0), Type.SIZE_SMALL)
		mb.toggle_mode = true
		mb.pressed.connect(func() -> void: _set_growth_mode(mode))
		root.add_child(mb)
		_growth_mode_buttons[mode] = mb

	_stat_view = Control.new()
	_stat_view.size = Vector2(PANEL_W, PANEL_H)
	_stat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stat_view)
	var top := PAD + 38.0
	var gap := 16.0
	var step_w := (CONTENT_W - gap * float(BUY_STEPS.size() - 1)) / float(BUY_STEPS.size())
	for i in BUY_STEPS.size():
		var n: int = BUY_STEPS[i]
		var b := Ui.button("x%d" % n, Vector2(PAD + i * (step_w + gap), top),
			Vector2(step_w, STEP_H))
		# 선택 표시는 toggle 로 한다. disabled 로 하면 글자가 흐려져 "선택됨"이 아니라
		# "못 누름"으로 읽힌다.
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _set_step(n))
		_stat_view.add_child(b)
		_step_btns.append(b)

	# 목록 영역: 배수탭 아래 ~ 창 바닥
	var list_y := top + STEP_H + 12.0
	var sc := Ui.scroll(Vector2(PAD, list_y), Vector2(CONTENT_W, CONTENT_BOTTOM - list_y))
	_stat_view.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	sc.add_child(col)

	for s in StatDefs.STATS:
		col.add_child(_stat_row(str(s["key"]), str(s["name"]), str(s["icon"])))

	_build_skill_view(root)
	_set_step(buy_step)   # 처음 열었을 때도 선택된 배수가 보이게
	_set_growth_mode("stat")


func _set_growth_mode(mode: String) -> void:
	_growth_mode = mode
	_stat_view.visible = mode == "stat"
	_skill_view.visible = mode == "skill"
	for key in _growth_mode_buttons:
		_growth_mode_buttons[key].set_pressed_no_signal(key == mode)
	if mode == "skill":
		_refresh_skills()
	else:
		_refresh_growth()


# ── 스킬 화면 ──────────────────────────────────────────────────────────────
# 위에서부터: 장착 6칸 / 안내 줄 / 보유 목록 / 버튼 2개.
# 칸을 누르면 장착·해제가 **바로** 된다 — 고르고 나서 "장착" 버튼을 또 누르게 하면
# 방치형에서 손이 두 배로 간다.
# 장착 칸. 아이콘이 틀 밖으로 삐져나와서 키웠다 — slot_common.png 는 40px 중
# 실제 창이 32px(80%)이라, 틀을 72로 그리면 안쪽은 57px 이고 아이콘 48이 들어간다.
# 레벨 숫자는 **틀 안 아래쪽에 겹쳐** 쓴다. 밖에 두면 칸이 22px 더 필요해서
# 그만큼 아래 목록이 줄어든다.
const SK_SLOT := 80.0
const SK_CARD := Vector2(120.0, 88.0)


func _build_skill_view(root: Control) -> void:
	_skill_view = Control.new()
	_skill_view.size = Vector2(PANEL_W, PANEL_H)
	_skill_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_skill_view)
	var top := PAD + 38.0
	var gap := (CONTENT_W - SK_SLOT * float(SkillDefs.SLOTS)) \
		/ float(SkillDefs.SLOTS - 1)
	for i in SkillDefs.SLOTS:
		var cell := Control.new()
		cell.position = Vector2(PAD + float(i) * (SK_SLOT + gap), top)
		cell.size = Vector2(SK_SLOT, 72.0)
		_skill_view.add_child(cell)
		var frame := Ui.image("res://assets/ui/slot_common.png", Vector2(4.0, 0.0),
			Vector2(72.0, 72.0))
		cell.add_child(frame)
		var ic := Ui.icon("", Vector2(16.0, 10.0), 48.0)
		cell.add_child(ic)
		# 쿨다운 그늘. **위에서 아래로 걷힌다** — 남은 양이 곧 남은 시간이라
		# 숫자를 안 읽어도 곁눈질로 잡힌다.
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.02, 0.04, 0.72)
		shade.position = Vector2(12.0, 8.0)
		shade.size = Vector2(56.0, 56.0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(shade)
		var cd := _panel_label(cell, Vector2(0.0, 20.0), Type.SIZE_SMALL,
			Color(1.0, 0.95, 0.85), SK_SLOT, 20.0)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lv := _panel_label(cell, Vector2(0.0, 50.0), Type.SIZE_SMALL,
			Color(1.0, 0.88, 0.55), SK_SLOT, 18.0)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hit := Button.new()
		hit.flat = true
		hit.size = Vector2(SK_SLOT, 72.0)
		hit.focus_mode = Control.FOCUS_NONE
		var idx := i
		hit.pressed.connect(func() -> void: _unequip_skill(idx))
		cell.add_child(hit)
		_skill_slots.append({"frame": frame, "icon": ic, "lv": lv,
			"shade": shade, "cd": cd})

	# 이 한 줄이 두 가지를 한다: 평소엔 조합 상태, 칸을 누르면 그 스킬 정보.
	# 칸이 좁아 이름을 넣을 자리가 없어서 여기로 몰았다.
	_skill_info = _panel_label(_skill_view, Vector2(PAD, top + 74.0), Type.SIZE_SMALL,
		Color(0.82, 0.88, 0.72), CONTENT_W, 20.0)
	_skill_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var list_y := top + 98.0
	var sc := Ui.scroll(Vector2(PAD, list_y),
		Vector2(CONTENT_W, CONTENT_BOTTOM - 44.0 - list_y))
	_skill_view.add_child(sc)
	_skill_grid = GridContainer.new()
	_skill_grid.columns = 4
	_skill_grid.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	_skill_grid.add_theme_constant_override("h_separation", 6)
	_skill_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_skill_grid)

	var bw := (CONTENT_W - 24.0) / 3.0
	var by := CONTENT_BOTTOM - 38.0
	# 토글이다. 켜 두면 새 스킬·레벨업·조합 때마다 알아서 다시 낀다 — 방치형에서
	# "더 센 걸 뽑았는데 안 끼고 있었다"는 플레이어 잘못이 아니라 UI 잘못이다.
	_skill_auto_btn = Ui.button("자동 장착", Vector2(PAD, by),
		Vector2(bw, 38.0), Type.SIZE_SMALL)
	_skill_auto_btn.toggle_mode = true
	_skill_auto_btn.pressed.connect(func() -> void:
		skill_auto_equip = not skill_auto_equip
		if skill_auto_equip:
			_auto_equip_skills()
		_refresh_skills()
		_save_game())
	_skill_view.add_child(_skill_auto_btn)
	_skill_bulk_btn = Ui.button("일괄 레벨업", Vector2(PAD + bw + 12.0, by),
		Vector2(bw, 38.0), Type.SIZE_SMALL)
	_skill_bulk_btn.pressed.connect(_ask_skill_bulk)
	_skill_view.add_child(_skill_bulk_btn)
	_skill_synth_btn = Ui.button("일괄 조합", Vector2(PAD + (bw + 12.0) * 2.0, by),
		Vector2(bw, 38.0), Type.SIZE_SMALL)
	_skill_synth_btn.pressed.connect(_ask_skill_synth)
	_skill_view.add_child(_skill_synth_btn)


# 한 행은 ROW_H 높이의 띠다. 그 안에서 아이콘·글자·버튼이 전부 세로 중앙에 온다.
func _stat_row(key: String, disp: String, icon: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(CONTENT_W - Ui.SCROLL_W, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CONTENT_W - Ui.SCROLL_W

	var ic := Ui.icon("res://assets/ui/%s.png" % icon, Vector2(0, (ROW_H - 56.0) * 0.5), 56.0)
	row.add_child(ic)
	# 폭은 전부 실측으로 잡았다(11px 기준):
	#   "레벨 999999" 108 · "치명타 피해"(22px) 144 · "+188.8k 피해" 120 · "혈액 999.9t" 108
	# 합이 504를 넘으면 어딘가 잘린다 — 잘린 숫자는 틀린 숫자보다 나쁘다(뭔지 모른다).
	var lv_lbl := _panel_label(row, Vector2(60.0, 0.0), Type.SIZE_SMALL,
		Color(0.62, 0.62, 0.68), 144.0, ROW_H * 0.5)
	var nm := _panel_label(row, Vector2(60.0, ROW_H * 0.5), Type.SIZE_BODY,
		Color(0.95, 0.90, 0.88), 144.0, ROW_H * 0.5)
	var eff := _panel_label(row, Vector2(208.0, ROW_H * 0.5), Type.SIZE_SMALL,
		Color(0.98, 0.72, 0.45), 120.0, ROW_H * 0.5)
	# SIZE_MID(16)로는 "혈액 999.9t"가 153px이라 124px 칸에서 "혈액 1."로 잘렸다.
	# 칸이 좁으면 글자 크기부터 내린다(UI_RULES 3장).
	var btn_w := 172.0
	var b := Ui.button("", Vector2(w - btn_w, (ROW_H - 48.0) * 0.5),
		Vector2(btn_w, 48.0), Type.SIZE_SMALL)
	Ui.cost_icon(b, "res://assets/ui/res_blood.png")
	b.pressed.connect(func() -> void: _buy(key))
	row.add_child(b)
	# 잠긴 행은 버튼 대신 조건을 보여 준다 — 감추면 목표가 안 되고, 보이면 이유가 된다.
	var lock := _panel_label(row, Vector2(w - btn_w, 0.0), Type.SIZE_SMALL,
		Color(0.58, 0.56, 0.62), btn_w, ROW_H)
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_rows[key] = {"icon": ic, "lv": lv_lbl, "name": nm, "eff": eff,
		"btn": b, "lock": lock}
	return row


# 손으로 한 칸이라도 만지면 자동 장착을 끈다. 고른 걸 뒤에서 덮어쓰면
# "내가 뭘 했는지 모르겠다"가 되고, 그게 안 끼워 주는 것보다 나쁘다.
func _unequip_skill(slot: int) -> void:
	if slot >= skill_equipped.size():
		return
	var key := str(skill_equipped[slot])
	_skill_info.text = "%s  해제" % SkillDefs.name_of(key)
	skill_equipped.remove_at(slot)
	skill_auto_equip = false
	_refresh_skills()
	_save_game()


func _toggle_skill(key: String) -> void:
	skill_auto_equip = false
	if skill_equipped.has(key):
		skill_equipped.erase(key)
	elif skill_equipped.size() < SkillDefs.SLOTS:
		skill_equipped.append(key)
	else:
		# 칸이 다 찼으면 **맨 뒤를 밀어낸다.** 순서가 발동 우선순위라 뒤가 제일 덜 급하다.
		skill_equipped[SkillDefs.SLOTS - 1] = key
	var lv := int(skill_owned.get(key, 0))
	_skill_info.text = "%s  ·  %s  ·  %d레벨" % [SkillDefs.name_of(key),
		str(SkillDefs.shape_of(key)["role"]), lv]
	_refresh_skills(false)
	_save_game()


func _skill_card(key: String) -> Control:
	var lv := int(skill_owned.get(key, 0))
	var rarity := SkillDefs.rarity_of(key)
	var cell := Control.new()
	cell.custom_minimum_size = SK_CARD
	var hit := Button.new()
	hit.flat = true
	hit.size = SK_CARD
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(func() -> void: _toggle_skill(key))
	cell.add_child(hit)
	var frame := Ui.image("res://assets/ui/slot_common.png",
		Vector2((SK_CARD.x - 56.0) * 0.5, 0.0), Vector2(56.0, 56.0))
	frame.modulate = Color(rarity["col"])
	cell.add_child(frame)
	cell.add_child(Ui.icon(SkillDefs.icon_path(key),
		Vector2((SK_CARD.x - 40.0) * 0.5, 8.0), 40.0))
	var info := _panel_label(cell, Vector2(0.0, 58.0), Type.SIZE_SMALL,
		Color(rarity["col"]), SK_CARD.x, 16.0)
	info.text = "%d레벨" % lv
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owned_key := "skill:" + key
	var shards := int(gacha_shards.get(owned_key, 0))
	var cost := SkillDefs.shard_cost(lv)
	var sh := _panel_label(cell, Vector2(0.0, 72.0), Type.SIZE_SMALL,
		Color(0.98, 0.82, 0.42) if shards >= cost else Color(0.62, 0.62, 0.68),
		SK_CARD.x, 16.0)
	sh.text = "조각 %d / %d" % [shards, cost]
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 장착 중인 건 어둡게. 목록에서 "이미 낀 것"이 곧바로 걸러져야 한다.
	if skill_equipped.has(key):
		frame.modulate = Color(rarity["col"]) * Color(0.5, 0.5, 0.5)
		info.text = "장착 · %d레벨" % lv
	return cell


func _refresh_skills(rebuild_info := true) -> void:
	if not _skill_grid:
		return
	for i in _skill_slots.size():
		var slot: Dictionary = _skill_slots[i]
		if i >= skill_equipped.size():
			slot["icon"].texture = null
			slot["frame"].modulate = Color(0.34, 0.32, 0.38)
			slot["lv"].text = "빈 칸"
			continue
		var key := str(skill_equipped[i])
		slot["icon"].texture = Assets.tex(SkillDefs.icon_path(key))
		slot["frame"].modulate = Color(SkillDefs.rarity_of(key)["col"])
		slot["lv"].text = "%d레벨" % int(skill_owned.get(key, 0))
	for child in _skill_grid.get_children():
		child.queue_free()
	# 목록은 **등급 낮은 순**이다(보관함과 같은 규칙). 센 것부터 놓으면 새로 뽑은
	# 낮은 등급이 맨 뒤로 밀려서 조합 재료를 찾을 때마다 끝까지 스크롤해야 한다.
	# 같은 등급 안에서는 형태 순 → 레벨 높은 순.
	var keys := skill_owned.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ra := GachaDefs.rarity_index(str(SkillDefs.split(str(a))[1]))
		var rb := GachaDefs.rarity_index(str(SkillDefs.split(str(b))[1]))
		if ra != rb:
			return ra < rb
		var sa := SkillDefs.SHAPE_ORDER.find(str(SkillDefs.split(str(a))[0]))
		var sb := SkillDefs.SHAPE_ORDER.find(str(SkillDefs.split(str(b))[0]))
		if sa != sb:
			return sa < sb
		return int(skill_owned[a]) > int(skill_owned[b]))
	for key in keys:
		_skill_grid.add_child(_skill_card(str(key)))
	_skill_bulk_btn.disabled = _skill_levelable().is_empty()
	_skill_synth_btn.disabled = _skill_synthesizable().is_empty()
	_skill_auto_btn.set_pressed_no_signal(skill_auto_equip)
	_skill_auto_btn.text = "자동 장착 켬" if skill_auto_equip else "자동 장착"
	if rebuild_info:
		_skill_info.text = _combo_text()


# 지금 조합이 무엇을 주는지 한 줄로. 없으면 무엇을 하면 되는지 적는다 —
# "없음"만 뜨면 조합이 있다는 사실 자체를 모른다.
# 쿨다운만 매 프레임 갱신한다. 카드를 다시 만드는 _refresh_skills 와 달리
# 여기는 라벨 글자와 사각형 높이만 건드려서 비용이 없다.
func _tick_skill_slots() -> void:
	for i in _skill_slots.size():
		var slot: Dictionary = _skill_slots[i]
		if i >= skill_equipped.size():
			slot["shade"].visible = false
			slot["cd"].text = ""
			continue
		var key := str(skill_equipped[i])
		var left := float(_skill_cd.get(key, 0.0))
		var total := SkillDefs.cooldown(key, int(skill_owned.get(key, 0)))
		slot["shade"].visible = left > 0.0
		if left <= 0.0:
			slot["cd"].text = ""
			continue
		# 위에서부터 걷히도록 높이를 줄이고 그만큼 아래로 민다.
		var h := 56.0 * clampf(left / maxf(0.001, total), 0.0, 1.0)
		slot["shade"].size.y = h
		slot["shade"].position.y = 4.0 + (56.0 - h)
		slot["cd"].text = "%.1f" % left if left < 10.0 else "%d" % int(left)


func _combo_text() -> String:
	var parts := PackedStringArray()
	var same: Dictionary = SkillDefs.combo_power(skill_equipped)
	for shape in SkillDefs.SHAPE_ORDER:
		var rate := float(same.get(shape, 0.0))
		if rate > 0.0:
			parts.append("%s +%d%%" % [str(SkillDefs.SHAPES[shape]["name"]),
				int(rate * 100.0)])
	var spread := SkillDefs.combo_spread(skill_equipped)
	if spread > 0.0:
		parts.append("전 스탯 +%d%%" % int(spread * 100.0))
	if parts.is_empty():
		return "조합 없음 — 같은 형태를 모으거나 네 형태를 다 갖추면 보너스"
	return "조합  " + "  ·  ".join(parts)


func _skill_levelable() -> Array[String]:
	var out: Array[String] = []
	for key in skill_owned:
		var lv := int(skill_owned[key])
		if int(gacha_shards.get("skill:" + str(key), 0)) >= SkillDefs.shard_cost(lv):
			out.append(str(key))
	return out


func _ask_skill_bulk() -> void:
	var keys := _skill_levelable()
	if keys.is_empty():
		return
	_ask("조각이 모인 스킬 %d종을 한 단계씩 올립니다." % keys.size(), func() -> void:
		var got: Array = []
		for key in keys:
			if _level_up_skill(key):
				var r := SkillDefs.rarity_of(key)
				got.append({"icon": SkillDefs.icon_path(key),
					"label": SkillDefs.name_of(key),
					"sub": "%d레벨" % int(skill_owned[key]), "col": r["col"]})
		# 레벨이 오르면 순위가 바뀐다 — 자동 장착이 켜져 있으면 다시 낀다.
		if skill_auto_equip:
			_auto_equip_skills()
		_refresh_skills()
		_save_game()
		if not got.is_empty():
			_show_reward("스킬 강화", got.slice(0, mini(got.size(), 5))))


func _set_step(n: int) -> void:
	buy_step = n
	for i in _step_btns.size():
		_step_btns[i].set_pressed_no_signal(BUY_STEPS[i] == n)
	_refresh_hud()


func _refresh_growth() -> void:
	for s in StatDefs.STATS:
		var key := str(s["key"])
		var row: Dictionary = _stat_rows[key]
		var reason := StatDefs.lock_reason(key, StageDefs.major_stage(stage))
		var open := reason == ""
		row["lv"].text = "레벨 %d" % stat_lv(key)
		row["name"].text = str(s["name"])
		row["eff"].text = _stat_effect(key) if open else ""
		row["btn"].visible = open
		row["lock"].visible = not open
		row["lock"].text = reason
		# 잠긴 행은 아이콘까지 어둡게. 글자만 회색이면 아직 켜진 줄 안다.
		row["icon"].modulate = Color(1, 1, 1) if open else Color(0.42, 0.42, 0.46)
		row["name"].add_theme_color_override("font_color",
			Color(0.95, 0.90, 0.88) if open else Color(0.55, 0.53, 0.58))
		row["lv"].visible = open
		if not open:
			continue
		if StatDefs.at_cap(key, stat_lv(key)):
			row["btn"].text = "만렙"
			row["btn"].icon = null
			row["btn"].disabled = true
			continue
		var cost := _buy_cost(key, buy_step)
		row["btn"].text = "혈액  %s" % _n(cost)
		row["btn"].disabled = gold < cost


# 레벨이 아니라 "그래서 뭐가 되는데"를 보여 준다.
func _stat_effect(key: String) -> String:
	match key:
		"damage": return "+%s 피해" % _n(damage())
		"speed": return "%.2f초 간격" % attack_interval()
		# "x1.01 흡혈"이라고만 쓰면 체력을 빨아먹는 능력으로 읽힌다. 실제로는
		# **처치 시 얻는 혈액(재화)의 배수**다 — 회복과 아무 상관이 없다.
		"gold": return "혈액 x%.2f" % gold_mult()
		"tough": return "체력 %s" % _n(max_hp())
		"regen": return "초당 %s 회복" % _n(regen_per_sec())
		"crit": return "%d%%" % int(minf(1.0, 0.01 * float(stat_lv("crit") - 1)) * 100.0)
		"critdmg": return "x%.2f 피해" % (1.5 + 0.05 * float(stat_lv("critdmg") - 1))
	return ""


# 여러 단계를 한 번에 살 때의 총액. 비용이 지수라 배수만 곱하면 실제보다 싸진다.
func _buy_cost(key: String, n: int) -> float:
	var s := StatDefs.of(key)
	return Balance.buy_cost(stat_lv(key), n, s.get("base", 10.0), s.get("exp", 1.15))


const SLOT_BOX := 80.0    # 등급 틀 크기
const SLOT_ICON := 48.0   # 그 안에 들어가는 아이콘 (틀 테두리 16px씩을 뺀 값)
const SLOT_GAP := 168.0   # 칸 사이 간격
# 칸 3개를 창 폭 한가운데에 놓는다. 왼쪽부터 쌓으면 오른쪽만 넓게 비어 치우쳐 보인다.
const SLOT_X0 := (576.0 - (SLOT_GAP * 2.0 + SLOT_BOX)) * 0.5


# 소환 결과에서만 희귀 이상 등급색을 강하게 맥동시킨다.
func _add_summon_rarity_fx(parent: Control, rarity: Dictionary, frame_path: String,
		pos: Vector2, size: Vector2) -> void:
	var rarity_index := GachaDefs.rarity_index(str(rarity["key"]))
	if rarity_index < GachaDefs.RARE_INDEX:
		return
	var aura := Ui.image(frame_path, pos, size)
	var strength := 0.46 + float(rarity_index - GachaDefs.RARE_INDEX) * 0.14
	var scale_peak := 1.02 + float(rarity_index - GachaDefs.RARE_INDEX) * 0.02
	aura.modulate = Color(Color(rarity["col"]), strength)
	aura.pivot_offset = size * 0.5
	parent.add_child(aura)
	if aura.is_inside_tree():
		var aura_tween := aura.create_tween().set_loops()
		aura_tween.tween_property(aura, "modulate:a", strength * 0.35, 0.55)
		aura_tween.parallel().tween_property(aura, "scale", Vector2.ONE, 0.55)
		aura_tween.tween_property(aura, "modulate:a", strength, 0.55)
		aura_tween.parallel().tween_property(aura, "scale", Vector2.ONE * scale_peak, 0.55)


# 장착 슬롯 3칸. 등급 테두리 색으로 지금 뭘 끼고 있는지 곁눈질에도 읽히게 한다.
func _build_gear(root: Control) -> void:
	for i in 2:
		var mode := "equipped" if i == 0 else "inventory"
		var mode_button := Ui.button("장착 장비" if i == 0 else "보관함",
			Vector2(PAD + i * 268.0, 18.0), Vector2(252.0, 36.0), Type.SIZE_SMALL)
		mode_button.toggle_mode = true
		mode_button.pressed.connect(func() -> void: _set_gear_mode(mode))
		mode_button.z_index = 2
		root.add_child(mode_button)
		_gear_mode_buttons[mode] = mode_button
	_gear_equipped_view = Control.new()
	_gear_equipped_view.size = Vector2(PANEL_W, PANEL_H)
	_gear_equipped_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gear_equipped_view)
	for i in GearDefs.SLOTS.size():
		var slot: String = GearDefs.SLOTS[i]
		var at := Vector2(SLOT_X0 + i * SLOT_GAP, 62.0)
		var frame := Ui.icon("res://assets/ui/slot_common.png", at, SLOT_BOX)
		_gear_equipped_view.add_child(frame)
		# 틀(80px)의 안쪽 구멍은 그보다 훨씬 작다. 아이콘 상자를 64로 두면
		# 원본이 큰 무기(96px짜리도 있다)가 틀 밖으로 삐져나온다.
		var ic := Ui.icon("", at + Vector2((SLOT_BOX - SLOT_ICON) * 0.5,
			(SLOT_BOX - SLOT_ICON) * 0.5), SLOT_ICON)
		_gear_equipped_view.add_child(ic)
		# 이름은 틀 바로 아래 가운데. 왼쪽 정렬로 두면 틀과 어긋나 보인다.
		# 틀 아래로 한 줄 띄운다 — 붙어 있으면 어느 칸의 이름인지 안 읽힌다.
		var name_lbl := _panel_label(_gear_equipped_view,
			Vector2(at.x + SLOT_BOX * 0.5 - SLOT_GAP * 0.5,
			154.0), Type.SIZE_SMALL, Color(0.75, 0.75, 0.8), SLOT_GAP, 20.0)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# 이 폰트는 한글 글자 폭이 크기보다 넓다 — 칸이 좁으면 크기부터 내린다.
		# 160px: 여백 24 + 아이콘 20 + 간격 4 를 빼면 112px, "정수 999.9t"(108)가 들어간다.
		var b := Ui.button("", Vector2(at.x + SLOT_BOX * 0.5 - 80.0, 186.0),
			Vector2(160.0, 48.0), Type.SIZE_SMALL)
		Ui.cost_icon(b, "res://assets/items/gem.png")
		b.pressed.connect(func() -> void: _enhance(slot))
		_gear_equipped_view.add_child(b)
		_gear_slots[slot] = {"frame": frame, "icon": ic, "label": name_lbl, "btn": b}
	_gear_inventory_view = Control.new()
	_gear_inventory_view.size = Vector2(PANEL_W, PANEL_H)
	_gear_inventory_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gear_inventory_view)
	# 보관함은 **슬롯**으로 나눈다. 등급 필터(7칸)를 쓰다가 바꾼 이유:
	# 등급은 칸 테두리 색과 정렬 순서로 이미 읽히는데, 슬롯은 그 어디에도 안 나온다.
	# 무기 사이에서 방어구를 찾는 게 진짜 문제였다.
	var gap := 12.0
	var fw := (CONTENT_W - gap * float(GearDefs.SLOTS.size() - 1)) 		/ float(GearDefs.SLOTS.size())
	for i in GearDefs.SLOTS.size():
		var slot_key: String = GearDefs.SLOTS[i]
		var filter_button := Ui.button(str(GearDefs.SLOT_NAME[slot_key]),
			Vector2(PAD + i * (fw + gap), 62.0), Vector2(fw, 36.0), Type.SIZE_MID)
		filter_button.toggle_mode = true
		filter_button.pressed.connect(func() -> void: _set_gear_filter(slot_key))
		_gear_inventory_view.add_child(filter_button)
		_gear_filter_buttons[slot_key] = filter_button
	# 목록을 152로 줄여 아래에 일괄 버튼 두 개를 놓는다. 한 칸(112x128 + 간격 8)
	# 기준이라 어차피 한 줄 + 다음 줄 살짝이 보이는 높이였다.
	var scroll := Ui.scroll(Vector2(PAD, 102.0), Vector2(CONTENT_W, 152.0))
	_gear_inventory_view.add_child(scroll)
	var bulk_w := (CONTENT_W - 12.0) * 0.5
	for i in 2:
		var mode: String = "salvage" if i == 0 else "fuse"
		var b := Ui.button("분해" if i == 0 else "조합",
			Vector2(PAD + float(i) * (bulk_w + 12.0), 258.0), Vector2(bulk_w, 38.0),
			Type.SIZE_SMALL)
		b.pressed.connect(func() -> void: _open_bulk(mode))
		_gear_inventory_view.add_child(b)
	_gear_inventory_grid = GridContainer.new()
	_gear_inventory_grid.columns = 4
	_gear_inventory_grid.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	_gear_inventory_grid.add_theme_constant_override("h_separation", 6)
	_gear_inventory_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_gear_inventory_grid)
	_gear_detail = Control.new()
	_gear_detail.size = Vector2(PANEL_W, PANEL_H)
	_gear_detail.visible = false
	_gear_detail.z_index = 4
	root.add_child(_gear_detail)
	_build_bulk(root)
	_set_gear_filter(GearDefs.SLOTS[0])
	_set_gear_mode("equipped")


# ── 분해 창 / 조합 창 ──────────────────────────────────────────────────────
# 칸을 눌러 고르고, "전체 선택"이 곧 일괄이다. 일괄을 따로 만들지 않는 이유:
# 일괄 버튼이 밖에 있으면 무엇이 녹는지 모른 채 누르게 되고, 되돌릴 수 없다.
# 여기서는 고른 게 밝게 보이고 합계가 같이 뜬 다음에야 실행이 눌린다.
func _build_bulk(root: Control) -> void:
	_bulk_view = Control.new()
	_bulk_view.size = Vector2(PANEL_W, PANEL_H)
	_bulk_view.visible = false
	_bulk_view.z_index = 5
	root.add_child(_bulk_view)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.05, 0.065)
	back.position = Vector2(PAD * 0.5, PAD * 0.5)
	back.size = Vector2(PANEL_W - PAD, PANEL_H - PAD)
	_bulk_view.add_child(back)
	_bulk_title = _panel_label(_bulk_view, Vector2(PAD, PAD - 4.0), Type.SIZE_BODY,
		Color(0.96, 0.90, 0.86), 200.0, 30.0)
	var close := Ui.button("닫기", Vector2(CONTENT_W + PAD - 100.0, PAD - 6.0),
		Vector2(100.0, 36.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _bulk_view.visible = false)
	_bulk_view.add_child(close)
	var all_btn := Ui.button("전체 선택", Vector2(PAD, PAD + 36.0), Vector2(120.0, 34.0),
		Type.SIZE_SMALL)
	all_btn.pressed.connect(func() -> void: _bulk_select_all(true))
	_bulk_view.add_child(all_btn)
	var none_btn := Ui.button("전체 해제", Vector2(PAD + 128.0, PAD + 36.0),
		Vector2(120.0, 34.0), Type.SIZE_SMALL)
	none_btn.pressed.connect(func() -> void: _bulk_select_all(false))
	_bulk_view.add_child(none_btn)
	_bulk_run = Ui.button("실행", Vector2(CONTENT_W + PAD - 160.0, PAD + 36.0),
		Vector2(160.0, 34.0), Type.SIZE_SMALL)
	_bulk_run.pressed.connect(_run_bulk)
	_bulk_view.add_child(_bulk_run)
	_bulk_body = _panel_label(_bulk_view, Vector2(PAD, PAD + 74.0), Type.SIZE_SMALL,
		Color(0.90, 0.88, 0.92), CONTENT_W, 22.0)
	_bulk_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sc := Ui.scroll(Vector2(PAD, PAD + 100.0),
		Vector2(CONTENT_W, CONTENT_BOTTOM - PAD - 100.0))
	_bulk_view.add_child(sc)
	_bulk_grid = GridContainer.new()
	_bulk_grid.columns = 4
	_bulk_grid.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	_bulk_grid.add_theme_constant_override("h_separation", 6)
	_bulk_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_bulk_grid)


func _open_bulk(mode: String) -> void:
	_bulk_mode = mode
	_bulk_selected.clear()
	_bulk_view.visible = true
	_refresh_bulk()


# 분해 대상: 장착 중이 아닌 보관 장비 전부. 등급으로 미리 거르지 않는다 —
# 무엇을 남길지는 칸을 보고 고르는 게 확실하다.
# 조합 대상: 조각 5개 이상이면서 신화가 아닌 것.
func _bulk_candidates() -> Array[String]:
	var out: Array[String] = []
	var salvaging := _bulk_mode == "salvage"
	for key in gear_inventory:
		var item: Dictionary = gear_inventory[key]
		if salvaging:
			if _is_equipped_key(str(key)):
				continue
		else:
			if GachaDefs.rarity_index(str(item.get("rarity", "common"))) \
					>= GachaDefs.RARITIES.size() - 1:
				continue
			if int(gacha_shards.get("gear:" + str(key), 0)) < 5:
				continue
		out.append(str(key))
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GachaDefs.rarity_index(str(gear_inventory[a].get("rarity", "common"))) \
			< GachaDefs.rarity_index(str(gear_inventory[b].get("rarity", "common"))))
	return out


func _bulk_select_all(on: bool) -> void:
	_bulk_selected.clear()
	if on:
		for key in _bulk_candidates():
			_bulk_selected[key] = true
	_refresh_bulk()


func _refresh_bulk() -> void:
	if not _bulk_view or not _bulk_view.visible:
		return
	var salvaging := _bulk_mode == "salvage"
	_bulk_title.text = "분해" if salvaging else "조합"
	var keys := _bulk_candidates()
	for child in _bulk_grid.get_children():
		child.queue_free()
	var chosen := 0
	var total := 0.0
	var precious := 0
	for key in keys:
		if _bulk_selected.has(key):
			chosen += 1
			total += GearDefs.salvage_value(gear_inventory[key])
			if GachaDefs.rarity_index(str(gear_inventory[key].get("rarity", "common"))) \
					>= GachaDefs.RARITIES.size() - 2:
				precious += 1
		var card := _gear_card(key, func() -> void:
			if _bulk_selected.has(key):
				_bulk_selected.erase(key)
			else:
				_bulk_selected[key] = true
			_refresh_bulk())
		# 안 고른 칸은 어둡게. 테두리를 덧그리는 대신 밝기로 가르면 등급 색이 안 죽는다.
		card.modulate = Color(1, 1, 1) if _bulk_selected.has(key) else Color(0.42, 0.42, 0.46)
		_bulk_grid.add_child(card)
	if keys.is_empty():
		_bulk_body.text = "녹일 장비가 없습니다." if salvaging \
			else "조각이 5개 모인 장비가 없습니다."
	elif salvaging:
		_bulk_body.text = "선택 %d / %d개  ·  정수 +%s%s" % [chosen, keys.size(), _n(total),
			"    레전더리 이상 %d개 포함" % precious if precious > 0 else ""]
	else:
		_bulk_body.text = "선택 %d / %d종  ·  각각 다음 등급으로 한 단계" % [chosen, keys.size()]
	# 되돌릴 수 없으니 귀한 등급이 끼면 글자색으로 한 번 더 말한다.
	_bulk_body.add_theme_color_override("font_color",
		Color(1.0, 0.52, 0.45) if precious > 0 else Color(0.90, 0.88, 0.92))
	_bulk_run.disabled = chosen == 0


# 실행 버튼은 **묻기만 한다.** 되돌릴 수 없는 작업이라 손이 미끄러지면 끝이다.
func _run_bulk() -> void:
	var chosen := 0
	var total := 0.0
	for key in _bulk_candidates():
		if not _bulk_selected.has(key):
			continue
		chosen += 1
		total += GearDefs.salvage_value(gear_inventory[key])
	if chosen == 0:
		return
	if _bulk_mode == "salvage":
		_ask("선택한 장비 %d개를 분해합니다.\n정수 %s 을 얻습니다.\n\n되돌릴 수 없습니다."
			% [chosen, _n(total)], _do_bulk)
	else:
		_ask("선택한 장비 %d종을 다음 등급으로 올립니다.\n각각 조각 5개를 씁니다."
			% chosen, _do_bulk)


func _do_bulk() -> void:
	var old_max := max_hp()
	var got: Array = []
	var earned := 0.0
	# 후보 목록을 기준으로 돈다 — 선택 사전에는 그새 사라진 키가 남아 있을 수 있다.
	for key in _bulk_candidates():
		if not _bulk_selected.has(key):
			continue
		if _bulk_mode == "salvage":
			earned += _salvage(key)
		else:
			var new_key := _synthesize(key)
			if not new_key.is_empty() and gear_inventory.has(new_key):
				got.append({"icon": GearDefs.icon_path(gear_inventory[new_key]),
					"label": str(gear_inventory[new_key]["name"])})
	_apply_hp_growth(old_max)
	_bulk_selected.clear()
	if _bulk_mode == "salvage":
		_show_reward("분해 완료", [{"icon": "res://assets/items/gem.png",
			"label": "정수 +%s" % _n(earned)}])
	elif not got.is_empty():
		# 6개까지만 보여 준다 — 그 이상은 한 줄에 안 들어가고, 어차피 보관함에 다 있다.
		_show_reward("합성 완료", got.slice(0, mini(got.size(), 5)))
	# 지운 칸을 보고 있었을 수 있다.
	if not gear_inventory.has(_gear_selected_key):
		_gear_selected_key = ""
		_gear_detail.visible = false
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_bulk()
	_save_game()


func _set_gear_mode(mode: String) -> void:
	_gear_mode = mode
	_gear_equipped_view.visible = mode == "equipped"
	_gear_inventory_view.visible = mode == "inventory"
	if mode != "inventory" and _bulk_view:
		_bulk_view.visible = false
	for key in _gear_mode_buttons:
		_gear_mode_buttons[key].set_pressed_no_signal(key == mode)
	if mode == "inventory":
		_refresh_gear_inventory()


func _set_gear_filter(filter: String) -> void:
	_gear_filter = filter
	_refresh_gear_inventory()


# 탭 글자(이름 + 보유 수)를 다시 쓴다.
#
# **여기서 갱신하는 이유**: _set_gear_filter 는 창을 만들 때 한 번 불리는데
# 그때는 _load_game() 전이라 보관함이 비어 있다. 거기서 세면 영원히 0 이다.
func _refresh_gear_tabs() -> void:
	# 잠긴 탭은 스탯 목록과 **같은 방식**으로 보여 준다 — 감추지 않고 조건을 적는다.
	# 감추면 그런 게 있는 줄도 모르고, 보이면 스테이지를 미는 이유가 된다.
	for key in _gear_filter_buttons:
		var b: Button = _gear_filter_buttons[key]
		var reason := GearDefs.lock_reason(key, stage)
		b.set_pressed_no_signal(key == _gear_filter)
		b.disabled = reason != ""
		if reason != "":
			b.text = "%s %s" % [str(GearDefs.SLOT_NAME[key]), reason]
			continue
		var n := 0
		for item in gear_inventory.values():
			if str(item.get("slot", "")) == key:
				n += 1
		b.text = "%s %d" % [str(GearDefs.SLOT_NAME[key]), n]


func _refresh_gear_inventory() -> void:
	if not _gear_inventory_grid:
		return
	if GearDefs.lock_reason(_gear_filter, stage) != "":
		# 잠긴 탭이 골라져 있으면(해금 전 저장을 불러온 경우) 열린 첫 탭으로 옮긴다.
		for key in GearDefs.SLOTS:
			if GearDefs.lock_reason(key, stage) == "":
				_gear_filter = key
				break
	_refresh_gear_tabs()
	for child in _gear_inventory_grid.get_children():
		child.queue_free()
	var keys := gear_inventory.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GachaDefs.rarity_index(str(gear_inventory[a].get("rarity", "common"))) \
			< GachaDefs.rarity_index(str(gear_inventory[b].get("rarity", "common"))))
	for key in keys:
		var item: Dictionary = gear_inventory[key]
		if str(item.get("slot", "")) != _gear_filter:
			continue
		_gear_inventory_grid.add_child(_gear_card(str(key),
			func() -> void: _open_gear_detail(str(key))))


# 보관함 칸 하나. 보관함 목록과 분해·조합 창이 **같은 칸을 쓴다** — 따로 그리면
# 한쪽에만 등급 테두리가 빠지거나 조각 수가 안 붙는 식으로 갈린다.
func _gear_card(key: String, on_press: Callable) -> Control:
	var item: Dictionary = gear_inventory[key]
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(116.0, 136.0)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = cell.custom_minimum_size
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(on_press)
	cell.add_child(hit)
	# 그림은 body 안에 모은다. 장착 중이면 body 만 어둡게 하고 표시는 그 위에 얹는다 —
	# 통째로 어둡게 하면 "장착 중" 글자까지 같이 죽는다.
	var body := Control.new()
	body.size = cell.custom_minimum_size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(body)
	var rarity := GachaDefs.rarity(str(item.get("rarity", "common")))
	var owned_key := "gear:" + key
	var equipped_now := _is_equipped_key(key)
	var glow := ColorRect.new()
	glow.position = Vector2(30.0, 36.0)
	glow.size = Vector2(56.0, 54.0)
	glow.color = Color(Color(rarity["col"]), 0.28)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(glow)
	var frame := Ui.image("res://assets/ui/gear_card.png", Vector2(2.0, 0.0),
		Vector2(112.0, 128.0))
	frame.modulate = Color(rarity["col"])
	body.add_child(frame)
	_add_summon_rarity_fx(body, rarity, "res://assets/ui/gear_card.png",
		Vector2(2.0, 0.0), Vector2(112.0, 128.0))
	body.add_child(Ui.icon(GearDefs.icon_path(item), Vector2(30.0, 36.0), 56.0))
	var level := _panel_label(body, Vector2(8.0, 4.0), Type.SIZE_SMALL,
		Color.WHITE, 100.0, 20.0)
	level.text = "레벨 %d" % int(item.get("lv", 0))
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := _panel_label(body, Vector2(6.0, 102.0), Type.SIZE_SMALL,
		Color(rarity["col"]), 104.0, 20.0)
	detail.text = "%s · %d" % [rarity["name"], int(gacha_shards.get(owned_key, 0))]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if equipped_now:
		# 어둡게 + 가로 띠. 글자만으로는 목록에서 훑을 때 안 걸린다.
		body.modulate = Color(0.48, 0.48, 0.54)
		var band := ColorRect.new()
		band.color = Color(0.05, 0.04, 0.07, 0.88)
		band.position = Vector2(4.0, 52.0)
		band.size = Vector2(108.0, 24.0)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(band)
		var mark := _panel_label(cell, Vector2(4.0, 52.0), Type.SIZE_SMALL,
			Color(1.0, 0.86, 0.45), 108.0, 24.0)
		mark.text = "장착 중"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return cell


func _equip_inventory_item(key: String) -> void:
	var stored: Dictionary = gear_inventory.get(key, {})
	if stored.is_empty():
		return
	var old_max := max_hp()
	var item := stored.duplicate(true)
	item["inventory_key"] = key
	equipped[str(item["slot"])] = item
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_gear_detail.visible = false
	_save_game()


func _open_gear_detail(key: String) -> void:
	if not gear_inventory.has(key):
		return
	_gear_selected_key = key
	_refresh_gear_detail()


func _refresh_gear_detail() -> void:
	var item: Dictionary = gear_inventory.get(_gear_selected_key, {})
	if item.is_empty():
		_gear_detail.visible = false
		return
	for child in _gear_detail.get_children():
		child.queue_free()
	_gear_detail.visible = true
	var shade := ColorRect.new()
	shade.color = Color.TRANSPARENT
	shade.size = Vector2(PANEL_W, PANEL_H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_detail.add_child(shade)
	_gear_detail.add_child(Ui.panel(Vector2.ZERO, Vector2(PANEL_W, PANEL_H)))
	_gear_detail.add_child(Ui.panel(Vector2(18.0, 18.0), Vector2(190.0, 210.0)))
	_gear_detail.add_child(Ui.panel(Vector2(216.0, 18.0), Vector2(342.0, 210.0)))
	var rarity := GachaDefs.rarity(str(item.get("rarity", "common")))
	var frame_path := GearDefs.slot_frame(item)
	var frame := Ui.icon(frame_path, Vector2(49.0, 40.0), 128.0)
	frame.modulate = Color(rarity["col"])
	_gear_detail.add_child(frame)
	_add_summon_rarity_fx(_gear_detail, rarity, frame_path, Vector2(49.0, 40.0),
		Vector2(128.0, 128.0))
	_gear_detail.add_child(Ui.icon(GearDefs.icon_path(item), Vector2(75.0, 66.0), 76.0))
	var preview := _panel_label(_gear_detail, Vector2(30.0, 178.0), Type.SIZE_SMALL,
		Color(rarity["col"]), 166.0, 24.0)
	preview.text = "%s · 레벨 %d" % [rarity["name"], int(item.get("lv", 0))]
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name := _panel_label(_gear_detail, Vector2(234.0, 28.0), Type.SIZE_MID,
		Color(rarity["col"]), 306.0, 28.0)
	name.text = str(item["name"])
	var info := _panel_label(_gear_detail, Vector2(234.0, 58.0), Type.SIZE_SMALL,
		Color(0.82, 0.80, 0.86), 306.0, 20.0)
	info.text = "%s · 레벨 %d · 보유 %d개" % [rarity["name"], int(item.get("lv", 0)),
		int(item.get("copies", 1))]
	var stat := str(item.get("stat", "damage"))
	var effect := _panel_label(_gear_detail, Vector2(234.0, 86.0), Type.SIZE_MID,
		Color(0.96, 0.82, 0.56), 306.0, 24.0)
	effect.text = "장착  %s +%s" % [GearDefs.STAT_NAME[stat], _n(GearDefs.power(item))]
	var owned := _panel_label(_gear_detail, Vector2(234.0, 114.0), Type.SIZE_MID,
		Color(0.62, 0.88, 0.70), 306.0, 24.0)
	owned.text = "보유  %s +%.1f%%" % [GearDefs.STAT_NAME[stat],
		GearDefs.collection_rate(item) * 100.0]
	var owned_key := "gear:" + _gear_selected_key
	var shards := int(gacha_shards.get(owned_key, 0))
	var level_cost := GearDefs.upgrade_cost(item)
	var salvage := GearDefs.salvage_value(item)
	var highest := GachaDefs.rarity_index(str(item["rarity"])) >= GachaDefs.RARITIES.size() - 1
	var resource_values := [
		["정수 %s" % _n(essence), Color(0.68, 0.82, 1.0)],
		["레벨업 %s" % _n(level_cost), Color(0.82, 0.80, 0.86)],
		["분해 +%s" % _n(salvage), Color(0.82, 0.80, 0.86)],
		["조각 %d/5" % shards, Color(0.72, 0.72, 0.78)],
		["최고 등급" if highest else "합성 가능" if shards >= 5 \
			else "합성 대기", Color(rarity["col"])],
		["보유 %d개" % int(item.get("copies", 1)), Color(0.72, 0.72, 0.78)],
	]
	for i in resource_values.size():
		var row := i / 2
		var col := i % 2
		var resource := _panel_label(_gear_detail,
			Vector2(230.0 + float(col) * 158.0, 146.0 + float(row) * 26.0),
			Type.SIZE_SMALL, resource_values[i][1], 148.0, 22.0)
		resource.text = resource_values[i][0]
		resource.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var material := _panel_label(_gear_detail, Vector2(22.0, 232.0), Type.SIZE_SMALL,
		Color(0.72, 0.72, 0.78), 532.0, 24.0)
	material.text = "장착은 전투 효과 · 보관만 해도 보유 효과 적용"
	material.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var equipped_now := str(equipped.get(str(item["slot"]), {}).get("inventory_key", "")) \
		== _gear_selected_key
	var equip_button := Ui.button("장착 중" if equipped_now else "장착",
		Vector2(22.0, 264.0), Vector2(100.0, 44.0), Type.SIZE_SMALL)
	equip_button.disabled = equipped_now
	equip_button.pressed.connect(func() -> void: _equip_inventory_item(_gear_selected_key))
	_gear_detail.add_child(equip_button)
	# 비용을 버튼에 안 적는 이유: 100px 칸에 "레벨업 999.9t"(132px)는 절대 안 들어가고,
	# 바로 위 재화 줄에 이미 "레벨업 N"이 적혀 있다. 같은 값을 두 번 적을 자리가 없다.
	var level_button := Ui.button("레벨업", Vector2(130.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	level_button.disabled = essence < level_cost
	level_button.pressed.connect(_level_up_selected)
	_gear_detail.add_child(level_button)
	var synth_button := Ui.button("최고" if highest else "합성",
		Vector2(238.0, 264.0), Vector2(100.0, 44.0), Type.SIZE_SMALL)
	if not highest:
		synth_button.text = "합성 5"
		Ui.cost_icon(synth_button, GearDefs.icon_path(item), 16)
	synth_button.disabled = shards < 5 or highest
	synth_button.pressed.connect(_synthesize_selected)
	_gear_detail.add_child(synth_button)
	var dismantle := Ui.button("분해", Vector2(346.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	dismantle.disabled = equipped_now
	dismantle.pressed.connect(_dismantle_selected)
	_gear_detail.add_child(dismantle)
	var close := Ui.button("닫기", Vector2(454.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _gear_detail.visible = false)
	_gear_detail.add_child(close)


func _level_up_selected() -> void:
	var item: Dictionary = gear_inventory.get(_gear_selected_key, {})
	if item.is_empty():
		return
	var cost := GearDefs.upgrade_cost(item)
	if essence < cost:
		return
	var old_max := max_hp()
	essence -= cost
	item["lv"] = int(item.get("lv", 0)) + 1
	var slot := str(item["slot"])
	if str(equipped.get(slot, {}).get("inventory_key", "")) == _gear_selected_key:
		var equipped_item := item.duplicate(true)
		equipped_item["inventory_key"] = _gear_selected_key
		equipped[slot] = equipped_item
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gear_detail()
	_save_game()


# 낱개 분해도 **일괄과 같은 확인창**을 쓴다. 예전엔 버튼 글자가 "분해"→"확인"으로
# 바뀌는 두 번 누르기였는데, 같은 화면에서 두 가지 확인 방식이 돌아가면 어느 쪽이
# 진짜 실행인지 헷갈린다.
func _dismantle_selected() -> void:
	var key := _gear_selected_key
	var item: Dictionary = gear_inventory.get(key, {})
	if item.is_empty() or _is_equipped_key(key):
		return
	_ask("%s 을(를) 분해합니다.\n정수 %s 을 얻습니다.\n\n되돌릴 수 없습니다."
		% [str(item["name"]), _n(GearDefs.salvage_value(item))],
		func() -> void:
			var old_max := max_hp()
			var earned := _salvage(key)
			_apply_hp_growth(old_max)
			_gear_selected_key = ""
			_gear_detail.visible = false
			_refresh_gear_slots()
			_refresh_gear_inventory()
			_save_game()
			_show_reward("분해 완료", [{"icon": "res://assets/items/gem.png",
				"label": "정수 +%s" % _n(earned)}]))


# 한 칸 분해. 낱개 분해와 일괄 분해가 같은 코드를 지나야 한쪽만 조각을 남기거나
# 지갑을 다르게 채우는 일이 안 생긴다. 얻은 정수를 돌려준다.
# 조각(gacha_shards)은 일부러 남긴다 — 조각은 장비가 아니라 뽑기 이력이다.
func _salvage(key: String) -> float:
	var item: Dictionary = gear_inventory.get(key, {})
	if item.is_empty():
		return 0.0
	var got := GearDefs.salvage_value(item)
	essence += got
	gear_inventory.erase(key)
	gacha_owned.erase("gear:" + key)
	return got


# 장착 중인 장비는 분해하지 않는다 — 지금 입고 있는 걸 녹이면 전투력이 말없이 떨어진다.
func _is_equipped_key(key: String) -> bool:
	for item in equipped.values():
		if str(item.get("inventory_key", "")) == key:
			return true
	return false


func _synthesize_selected() -> void:
	var new_key := _synthesize(_gear_selected_key)
	if new_key.is_empty():
		return
	_gear_selected_key = new_key
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gear_detail()
	_save_game()


# 한 칸 승급. 성공하면 승급 후 키, 못 하면 "".
func _synthesize(old_key: String) -> String:
	var item: Dictionary = gear_inventory.get(old_key, {})
	var owned_key := "gear:" + old_key
	if item.is_empty() or int(gacha_shards.get(owned_key, 0)) < 5:
		return ""
	var old_max := max_hp()
	var slot := str(item["slot"])
	var was_equipped := str(equipped.get(slot, {}).get("inventory_key", "")) == old_key
	if not GearDefs.promote(item):
		return ""
	var result_key := old_key
	var remaining_shards := int(gacha_shards[owned_key]) - 5
	var new_key := str(item["icon"])
	if new_key != old_key:
		gear_inventory.erase(old_key)
		gacha_owned.erase(owned_key)
		gacha_shards.erase(owned_key)
		var new_owned_key := "gear:" + new_key
		if gear_inventory.has(new_key):
			var existing: Dictionary = gear_inventory[new_key]
			existing["copies"] = int(existing.get("copies", 1)) + int(item.get("copies", 1))
			gacha_shards[new_owned_key] = int(gacha_shards.get(new_owned_key, 0)) \
				+ remaining_shards + 1
			item = existing
		else:
			gear_inventory[new_key] = item
			gacha_shards[new_owned_key] = int(gacha_shards.get(new_owned_key, 0)) + remaining_shards
		gacha_owned[new_owned_key] = true
		result_key = new_key
	else:
		gacha_shards[owned_key] = remaining_shards
	if was_equipped:
		var equipped_item := item.duplicate(true)
		equipped_item["inventory_key"] = result_key
		equipped[slot] = equipped_item
	_apply_hp_growth(old_max)
	return result_key


func _refresh_gear_slots() -> void:
	if _lbl_essence:
		_lbl_essence.text = "정수  %s" % _n(essence)
	for slot in _gear_slots.keys():
		var item: Dictionary = equipped.get(slot, {})
		var nodes: Dictionary = _gear_slots[slot]
		var btn: Button = nodes["btn"]
		if item.is_empty():
			nodes["icon"].texture = null
			nodes["frame"].texture = Assets.tex("res://assets/ui/slot_common.png")
			nodes["frame"].modulate = Color(0.45, 0.45, 0.5)
			nodes["label"].text = GearDefs.SLOT_NAME[slot]
			nodes["label"].add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			btn.text = "비었음"
			btn.icon = null
			btn.disabled = true
			continue
		nodes["icon"].texture = Assets.tex(GearDefs.icon_path(item))
		nodes["frame"].texture = Assets.tex(GearDefs.slot_frame(item))
		nodes["frame"].modulate = Color(1, 1, 1)
		# 칸 폭이 168px뿐이라 강화 레벨까지 넣으면 옆 칸 글자와 겹친다.
		# 레벨은 강화 버튼을 누르면 오르는 수치로 이미 읽힌다.
		nodes["label"].text = "%s +%s" % [str(item["name"]), _n(GearDefs.power(item))]
		nodes["label"].add_theme_color_override("font_color", Color(item["col"]))
		var cost := GearDefs.upgrade_cost(item)
		Ui.cost_icon(btn, "res://assets/items/gem.png")
		# 한 줄로 둔다 — 두 줄이면 아랫줄이 버튼 테두리를 넘는다.
		btn.text = "정수 %s" % _n(cost)
		btn.disabled = essence < cost


func _enhance(slot: String) -> void:
	var item: Dictionary = equipped.get(slot, {})
	if item.is_empty():
		return
	var cost := GearDefs.upgrade_cost(item)
	if essence < cost:
		return
	var old_max := max_hp()
	essence -= cost
	item["lv"] = int(item.get("lv", 0)) + 1
	var inventory_key := str(item.get("inventory_key", ""))
	if gear_inventory.has(inventory_key):
		gear_inventory[inventory_key]["lv"] = item["lv"]
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_save_game()


func _build_gacha(root: Control) -> void:
	var kinds := ["weapon", "armor", "trinket", "skill"]
	var names := ["무기 소환", "방어구 소환", "장신구 소환", "스킬 소환"]
	for i in kinds.size():
		var kind: String = kinds[i]
		var button := Ui.button(names[i], Vector2(22.0 + i * 134.0, 18.0),
			Vector2(128.0, 40.0), Type.SIZE_SMALL)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _set_gacha_kind(kind))
		root.add_child(button)
		_gacha_buttons[kind] = button
	root.add_child(Ui.panel(Vector2(18.0, 68.0), Vector2(540.0, 178.0)))
	# 왼쪽에 제단 그림 한 장. 글자만 있으면 어느 소환인지 곁눈질로 안 읽히고 창이 허전하다.
	# 등급 틀은 안 두른다 — 소환 결과는 매번 등급이 다른데 틀이 한 등급을 주장한다.
	_gacha_icon = Ui.icon("", Vector2(GACHA_ART_X, GACHA_ART_Y), GACHA_ART_BOX)
	root.add_child(_gacha_icon)
	# 글자 칸 376px. 레벨이 오르면 확률에 소수점이 붙어 줄이 길어진다 —
	# 최악값 "커먼 38.5%  언커먼 23.1%  레어 26.9%" 가 348px 이라 이 폭이 필요하다.
	var text_x := GACHA_ART_X + GACHA_ART_BOX + 12.0
	var text_w := 550.0 - text_x
	_gacha_labels["pity"] = _panel_label(root, Vector2(text_x, 108.0), Type.SIZE_MID,
		Color(1.0, 0.86, 0.52), text_w, 28.0)
	_gacha_labels["pity"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 2줄: 다음 레벨까지 남은 횟수와 천장. 레벨과 천장은 역할이 달라 같이 보여야 한다.
	_gacha_labels["sub"] = _panel_label(root, Vector2(text_x, 138.0), Type.SIZE_SMALL,
		Color(0.72, 0.72, 0.80), text_w, 20.0)
	_gacha_labels["sub"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_labels["rates"] = _panel_label(root, Vector2(text_x, 160.0), Type.SIZE_SMALL,
		Color(0.62, 0.82, 0.68), text_w, 44.0)
	_gacha_labels["rates"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_labels["rates"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var one := Ui.button("", Vector2(22.0, 258.0), Vector2(260.0, 50.0), Type.SIZE_SMALL)
	one.pressed.connect(func() -> void: _pull_gacha(1))
	root.add_child(one)
	_gacha_buttons["one"] = one
	var ten := Ui.button("10연  보석 300", Vector2(294.0, 258.0),
		Vector2(260.0, 50.0), Type.SIZE_SMALL)
	Ui.cost_icon(ten, "res://assets/ui/res_gem.png")
	ten.pressed.connect(func() -> void: _pull_gacha(10))
	root.add_child(ten)
	_gacha_buttons["ten"] = ten
	# 창(y 68~246)의 9-slice 테두리가 12px이라 안쪽은 80~234뿐이다. 32px 버튼을
	# 212에 두면 테두리를 넘는다 — 버튼 원화 높이 그대로(24) 208에 놓는다.
	var table_btn := Ui.button("확률표",
		Vector2(GACHA_ART_X + (GACHA_ART_BOX - 100.0) * 0.5, 208.0),
		Vector2(100.0, 24.0), Type.SIZE_SMALL)
	table_btn.pressed.connect(func() -> void:
		_rates_view.visible = not _rates_view.visible
		if _rates_view.visible:
			_refresh_rates_table())
	root.add_child(table_btn)
	_build_rates_table(root)
	_gacha_reveal = Control.new()
	_gacha_reveal.size = Vector2(PANEL_W, PANEL_H)
	_gacha_reveal.visible = false
	root.add_child(_gacha_reveal)
	_refresh_gacha()


# 세로=등급, 가로=레벨. 반대로 놓으면 머리글에 "레전더리"(72px)가 여섯 번 들어가
# 칸이 안 나온다. 등급 이름은 왼쪽 한 열에만 있으면 된다.
func _rate_cols() -> int:
	return GachaDefs.LEVEL_MAX - GachaDefs.LEVEL_MIN + 1


func _build_rates_table(root: Control) -> void:
	_rates_view = Control.new()
	_rates_view.size = Vector2(PANEL_W, PANEL_H)
	_rates_view.visible = false
	_rates_view.z_index = 5
	root.add_child(_rates_view)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.05, 0.065)
	back.position = Vector2(PAD * 0.5, PAD * 0.5)
	back.size = Vector2(PANEL_W - PAD, PANEL_H - PAD)
	_rates_view.add_child(back)
	_rates_head = _panel_label(_rates_view, Vector2(PAD, PAD - 4.0), Type.SIZE_SMALL,
		Color(0.96, 0.90, 0.86), CONTENT_W - 108.0, 28.0)
	_rates_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := Ui.button("닫기", Vector2(CONTENT_W + PAD - 100.0, PAD - 6.0),
		Vector2(100.0, 36.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _rates_view.visible = false)
	_rates_view.add_child(close)
	var top := PAD + 34.0
	# 등급 이름은 **스크롤 밖**에 고정한다. 같이 굴리면 옆으로 민 순간 어느 줄의
	# 숫자인지 알 수 없다.
	for r in GachaDefs.RARITIES.size():
		var name_lbl := _panel_label(_rates_view,
			Vector2(PAD, top + RATE_ROW_H * float(r + 1)), Type.SIZE_SMALL,
			Color(GachaDefs.RARITIES[r]["col"]), RATE_NAME_W, RATE_ROW_H)
		name_lbl.text = str(GachaDefs.RARITIES[r]["name"])
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rows := float(GachaDefs.RARITIES.size() + 1)
	var sc := Ui.scroll(Vector2(PAD + RATE_NAME_W, top),
		Vector2(CONTENT_W - RATE_NAME_W, RATE_ROW_H * rows + Ui.SCROLL_W), true)
	_rates_view.add_child(sc)
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(RATE_COL_W * float(_rate_cols()),
		RATE_ROW_H * rows)
	sc.add_child(strip)
	for i in _rate_cols():
		var c := GachaDefs.LEVEL_MIN + i
		# 레벨마다 필요한 횟수가 다르니 누적 횟수를 같이 적는다 —
		# 레벨 숫자만 있으면 "2레벨과 5레벨 사이가 얼마나 먼지"가 안 보인다.
		var h := _panel_label(strip, Vector2(RATE_COL_W * float(i), 0.0), Type.SIZE_SMALL,
			Color(0.72, 0.72, 0.80), RATE_COL_W, RATE_ROW_H)
		h.text = "%d레벨\n%s회" % [c, _n(float(GachaDefs.level_total(c)))]
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rates_heads.append(h)
	for r in GachaDefs.RARITIES.size():
		var row: Array[Label] = []
		for i in _rate_cols():
			var cell := _panel_label(strip,
				Vector2(RATE_COL_W * float(i), RATE_ROW_H * float(r + 1)),
				Type.SIZE_SMALL, Color(0.88, 0.86, 0.90), RATE_COL_W, RATE_ROW_H)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.append(cell)
		_rates_cells.append(row)
	_rates_scroll = sc


func _refresh_rates_table() -> void:
	if not _rates_view or not _rates_view.visible:
		return
	var lv := GachaDefs.level(int(gacha_pulls.get(_gacha_kind, 0)))
	_rates_head.text = "레벨별 확률  ·  지금 %d레벨" % lv
	var skill_pool := _gacha_kind == "skill"
	for i in _rate_cols():
		var c := GachaDefs.LEVEL_MIN + i
		var col_rates := GachaDefs.rates(c, skill_pool)
		# 지금 레벨 열을 밝게 — 표만 있으면 내가 어디쯤인지 안 보인다.
		_rates_heads[i].add_theme_color_override("font_color",
			Color(1.0, 0.86, 0.52) if c == lv else Color(0.62, 0.62, 0.70))
		for r in GachaDefs.RARITIES.size():
			var cell: Label = _rates_cells[r][i]
			if col_rates[r] <= 0.0:
				cell.text = "-"      # 아직 안 열린 칸. 0% 로 적으면 "열렸는데 안 나온다"로 읽힌다
				cell.add_theme_color_override("font_color", Color(0.40, 0.39, 0.44))
				continue
			cell.text = ("%.1f" % col_rates[r]).trim_suffix(".0") + "%"
			cell.add_theme_color_override("font_color",
				Color(1.0, 0.92, 0.72) if c == lv else Color(0.80, 0.78, 0.84))
	# 열 때 지금 레벨이 보이는 자리로 굴려 둔다 — 매번 왼쪽 끝부터 밀게 하지 않는다.
	if _rates_scroll:
		_rates_scroll.scroll_horizontal = int(maxf(0.0,
			RATE_COL_W * float(lv - GachaDefs.LEVEL_MIN)
			- (CONTENT_W - RATE_NAME_W) * 0.5))


func _set_gacha_kind(kind: String) -> void:
	if kind in GearDefs.SLOTS and not GearDefs.lock_reason(
			kind, StageDefs.major_stage(stage)).is_empty():
		return
	_gacha_kind = kind
	_refresh_gacha()
	_refresh_rates_table()   # 종류마다 레벨이 다르다 — 표의 "지금" 표시도 따라가야 한다


func _grant_test_gems() -> void:
	gem += 3000.0
	_refresh_gacha()
	_save_game()


# [테스트용] F9 로 보석 1만. 버튼이 아니라 단축키인 이유: 버튼은 화면에 계속 남아
# 나중에 지우는 걸 잊는다. 단축키는 안 누르면 없는 것과 같다.
const CHEAT_GEMS := 10000.0


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_F9:
		return
	gem += CHEAT_GEMS
	_refresh_hud()
	_refresh_gacha()
	_save_game()
	_show_reward("테스트 지급", [{"icon": "res://assets/ui/res_gem.png",
		"label": "보석 +%s" % _n(CHEAT_GEMS)}])


func _pull_gacha(count: int) -> void:
	var free := count == 1 and free_pull_date != Time.get_date_string_from_system()
	var cost := 0.0 if free else GachaDefs.COST * float(count)
	if gem < cost:
		return
	gem -= cost
	if free:
		free_pull_date = Time.get_date_string_from_system()
	# 레벨은 **이번 뽑기 전** 값으로 굴린다 — 화면에 적힌 확률 그대로여야 한다.
	var result := GachaDefs.pull(count, int(gacha_pity.get(_gacha_kind, 0)),
		GachaDefs.level(int(gacha_pulls.get(_gacha_kind, 0))), _gacha_kind == "skill")
	gacha_pity[_gacha_kind] = int(result["pity"])
	gacha_pulls[_gacha_kind] = int(gacha_pulls.get(_gacha_kind, 0)) + count
	mileage += count
	var received_items: Array[Dictionary] = []
	for rarity_key in result["rarities"]:
		var received: Dictionary = _receive_gacha_gear(str(rarity_key)) if _gacha_kind in GearDefs.SLOTS \
			else _receive_gacha_skill(str(rarity_key))
		received_items.append(received)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gacha()
	_save_game()
	_show_gacha_results(received_items)


func _receive_gacha_gear(rarity_key: String) -> Dictionary:
	var slot := _gacha_kind
	var item := GearDefs.make(slot, StageDefs.major_stage(stage), GachaDefs.rarity(rarity_key))
	if item.is_empty():
		return {}
	item["kind"] = "gear"
	item["copies"] = 1
	var old_max := max_hp()
	var owned_key := "gear:" + str(item["icon"])
	var inventory_key := str(item["icon"])
	var stored: Dictionary = gear_inventory.get(inventory_key, {})
	if not stored.is_empty():
		gacha_shards[owned_key] = int(gacha_shards.get(owned_key, 0)) + 1
		var copies := int(stored.get("copies", 1)) + 1
		if GachaDefs.rarity_index(rarity_key) > GachaDefs.rarity_index(str(stored["rarity"])):
			var level := int(stored.get("lv", 0))
			stored = item.duplicate(true)
			stored["lv"] = level
		stored["copies"] = copies
	else:
		gacha_owned[owned_key] = true
		stored = item.duplicate(true)
	gear_inventory[inventory_key] = stored
	_apply_hp_growth(old_max)
	return item


# 굴린 등급 안에서 **형태만** 랜덤이다. 등급은 소환 확률이 이미 정했고, 그 안에서
# 무엇이 나오느냐까지 등급을 다시 굴리면 표시 확률이 거짓말이 된다.
func _receive_gacha_skill(rarity_key: String) -> Dictionary:
	var shape: String = SkillDefs.SHAPE_ORDER[randi() % SkillDefs.SHAPE_ORDER.size()]
	var key := SkillDefs.key_of(shape, rarity_key)
	var owned_key := "skill:" + key
	if skill_owned.has(key):
		# 중복은 조각. 장비와 같은 규칙이라 따로 배울 게 없다.
		gacha_shards[owned_key] = int(gacha_shards.get(owned_key, 0)) + 1
	else:
		skill_owned[key] = 0
		gacha_owned[owned_key] = true
		if skill_auto_equip:
			_auto_equip_skills()
	return {"kind": "skill", "key": key, "name": SkillDefs.name_of(key),
		"rarity": rarity_key, "icon": SkillDefs.icon_path(key)}


# 조각으로 스킬 레벨을 올린다. 장비 강화가 정수를 쓰듯 스킬은 조각을 쓴다 —
# 재화를 새로 만들지 않는다.
func _level_up_skill(key: String) -> bool:
	if not skill_owned.has(key):
		return false
	var owned_key := "skill:" + key
	var lv := int(skill_owned[key])
	var cost := SkillDefs.shard_cost(lv)
	if int(gacha_shards.get(owned_key, 0)) < cost:
		return false
	gacha_shards[owned_key] = int(gacha_shards[owned_key]) - cost
	skill_owned[key] = lv + 1
	return true


# 같은 스킬 조각 5개로 다음 등급 승급. 재료는 사라진다 — 사라지지 않으면
# 조각만 있으면 20종을 전부 모으게 돼서 소환할 이유가 없어진다.
#
# **레벨은 승계하지 않는다.** 등급이 오르면 위력이 통째로 뛰는데 레벨까지 넘기면
# 한 번에 두 배가 된다. 성공하면 새 키, 아니면 "".
func _synthesize_skill(key: String) -> String:
	var next := SkillDefs.promote_key(key)
	var owned_key := "skill:" + key
	if next.is_empty() or not skill_owned.has(key):
		return ""
	if int(gacha_shards.get(owned_key, 0)) < SkillDefs.SYNTH_SHARDS:
		return ""
	gacha_shards[owned_key] = int(gacha_shards[owned_key]) - SkillDefs.SYNTH_SHARDS
	skill_owned.erase(key)
	skill_equipped.erase(key)   # 사라진 걸 낀 채로 두면 전투에서 빈 스킬이 돈다
	if skill_owned.has(next):
		# 이미 있으면 조각으로 들어간다(장비 합성과 같은 규칙).
		gacha_shards["skill:" + next] = int(gacha_shards.get("skill:" + next, 0)) + 1
	else:
		skill_owned[next] = 0
		gacha_owned["skill:" + next] = true
	return next


func _skill_synthesizable() -> Array[String]:
	var out: Array[String] = []
	for key in skill_owned:
		if SkillDefs.promote_key(str(key)).is_empty():
			continue
		if int(gacha_shards.get("skill:" + str(key), 0)) >= SkillDefs.SYNTH_SHARDS:
			out.append(str(key))
	return out


func _ask_skill_synth() -> void:
	var keys := _skill_synthesizable()
	if keys.is_empty():
		return
	_ask("스킬 %d종을 다음 등급으로 올립니다.\n각각 조각 %d개를 쓰고 **원래 스킬은 사라집니다.**"
		% [keys.size(), SkillDefs.SYNTH_SHARDS], func() -> void:
		var got: Array = []
		for key in keys:
			var next := _synthesize_skill(key)
			if not next.is_empty():
				var r := SkillDefs.rarity_of(next)
				got.append({"icon": SkillDefs.icon_path(next),
					"label": SkillDefs.name_of(next),
					"sub": str(r["name"]), "col": r["col"]})
		if skill_auto_equip:
			_auto_equip_skills()
		_refresh_skills()
		_save_game()
		if not got.is_empty():
			_show_reward("스킬 조합", got.slice(0, mini(got.size(), 5))))


func _show_gacha_results(items: Array[Dictionary]) -> void:
	if not _gacha_reveal:
		return
	for child in _gacha_reveal.get_children():
		child.queue_free()
	_gacha_reveal.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.025, 0.94)
	shade.size = Vector2(PANEL_W, PANEL_H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_gacha_reveal.add_child(shade)
	_gacha_reveal.add_child(Ui.panel(Vector2.ZERO, Vector2(PANEL_W, PANEL_H)))
	var title := _panel_label(_gacha_reveal, Vector2(PAD, 16.0), Type.SIZE_MID,
		Color(0.96, 0.84, 0.58), CONTENT_W, 28.0)
	title.text = "%s 소환 결과" % (GearDefs.SLOT_NAME[_gacha_kind] \
		if _gacha_kind in GearDefs.SLOTS else "스킬")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cards: Array[Control] = []
	for i in items.size():
		var item: Dictionary = items[i]
		if item.is_empty():
			continue
		var one := items.size() == 1
		var card := Control.new()
		card.position = Vector2(232.0, 56.0) if one else \
			Vector2(48.0 + float(i % 5) * 100.0, 54.0 + float(i / 5) * 100.0)
		card.size = Vector2(112.0, 160.0) if one else Vector2(80.0, 96.0)
		_gacha_reveal.add_child(card)
		var rarity := GachaDefs.rarity(str(item.get("rarity", "common")))
		var icon_path := GearDefs.icon_path(item) if item.get("kind", "") == "gear" \
			else str(item["icon"])
		if one:
			var glow := ColorRect.new()
			glow.position = Vector2(30.0, 36.0)
			glow.size = Vector2(56.0, 54.0)
			glow.color = Color(rarity["col"], 0.28)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(glow)
			card.add_child(Ui.image("res://assets/ui/gear_card.png", Vector2.ZERO,
				Vector2(112.0, 128.0)))
			card.add_child(Ui.icon(icon_path, Vector2(30.0, 36.0), 56.0))
			_add_summon_rarity_fx(card, rarity, "res://assets/ui/gear_card.png", Vector2.ZERO,
				Vector2(112.0, 128.0))
			var grade := _panel_label(card, Vector2(6.0, 102.0), Type.SIZE_SMALL,
				Color(rarity["col"]), 100.0, 20.0)
			grade.text = str(rarity["name"])
			grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var label := _panel_label(card, Vector2(-24.0, 132.0), Type.SIZE_SMALL,
				Color(rarity["col"]), 160.0, 22.0)
			label.text = str(item["name"])
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var glow := ColorRect.new()
			glow.position = Vector2(16.0, 18.0)
			glow.size = Vector2(48.0, 56.0)
			glow.color = Color(rarity["col"], 0.28)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(glow)
			card.add_child(Ui.image("res://assets/ui/gear_card_small.png", Vector2.ZERO,
				Vector2(80.0, 96.0)))
			card.add_child(Ui.icon(icon_path, Vector2(16.0, 18.0), 48.0))
			_add_summon_rarity_fx(card, rarity, "res://assets/ui/gear_card_small.png", Vector2.ZERO,
				Vector2(80.0, 96.0))
			var label := _panel_label(card, Vector2.ZERO, Type.SIZE_SMALL,
				Color(rarity["col"]), 80.0, 20.0)
			label.text = str(rarity["name"])
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards.append(card)
	var close := Ui.button("보관함 확인" if _gacha_kind in GearDefs.SLOTS else "확인",
		Vector2(158.0, 258.0),
		Vector2(260.0, 50.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void:
		_gacha_reveal.visible = false
		if _gacha_kind in GearDefs.SLOTS:
			_select_tab("gear")
			_set_gear_mode("inventory"))
	_gacha_reveal.add_child(close)
	if is_inside_tree():
		var tween := create_tween()
		for card in cards:
			card.modulate.a = 0.0
			card.scale = Vector2(0.65, 0.65)
			card.pivot_offset = card.size * 0.5
			tween.tween_property(card, "modulate:a", 1.0, 0.08)
			tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_gacha() -> void:
	if _gacha_labels.is_empty():
		return
	# 종류마다 전용 제단 그림. 파일명이 곧 종류라 표를 따로 두지 않는다.
	_gacha_icon.texture = Assets.tex("res://assets/ui/summon_%s.png" % _gacha_kind)
	var kind_name: String = GearDefs.SLOT_NAME[_gacha_kind] \
		if _gacha_kind in GearDefs.SLOTS else "스킬"
	var pulls := int(gacha_pulls.get(_gacha_kind, 0))
	var lv := GachaDefs.level(pulls)
	var need := GachaDefs.level_next_need(pulls)
	_gacha_labels["pity"].text = "%s 소환  %d레벨" % [kind_name, lv]
	# 이 줄에는 **다음 레벨까지 남은 횟수**만 둔다. 천장은 화면에서 뺐다 —
	# 두 숫자가 나란히 있으면 어느 쪽을 보고 뽑아야 하는지가 흐려진다.
	# (천장 자체는 남아 있다. 운이 나쁜 사람을 받쳐 주는 장치라 없애지 않았다.)
	_gacha_labels["sub"].text = "만렙" if need == 0 \
		else "다음 소환 레벨까지 %s회" % _n(float(need))
	# 확률은 **레벨이 반영된 실제 값**을 적는다. 고정 표를 적어 두면 레벨을 올려도
	# 화면이 그대로라 올린 티가 안 나고, 무엇보다 거짓말이 된다.
	# **지금 나오는 등급만** 적는다. 못 나오는 등급의 해금 레벨까지 여기 적으면
	# "지금 이 소환의 확률"이라는 이 줄의 뜻이 흐려진다 — 앞으로 뭐가 열리는지는
	# 확률표(전 레벨)가 보여 준다.
	var skill_pool := _gacha_kind == "skill"
	var r := GachaDefs.rates(lv, skill_pool)
	var parts := PackedStringArray()
	for i in GachaDefs.RARITIES.size():
		# 확률이 0인 칸(안 열렸거나 그 소환에 없는 등급)은 줄에서 뺀다.
		if r[i] <= 0.0:
			continue
		parts.append("%s %s%%" % [str(GachaDefs.RARITIES[i]["name"]),
			("%.1f" % r[i]).trim_suffix(".0")])
	# 두 줄로 반씩 나눈다. 3개씩 고정으로 자르면 4개일 때 아랫줄에 하나만 남는다.
	# 가운뎃점 구분자는 만렙 확률(소수점 한 자리)에서 8px 넘친다 — 공백 두 칸으로 쓴다.
	var half := (parts.size() + 1) / 2
	_gacha_labels["rates"].text = "%s\n%s" % [
		"  ".join(parts.slice(0, half)), "  ".join(parts.slice(half))]
	for kind in ["weapon", "armor", "trinket", "skill"]:
		_gacha_buttons[kind].set_pressed_no_signal(_gacha_kind == kind)
		if kind in GearDefs.SLOTS:
			var reason := GearDefs.lock_reason(kind, StageDefs.major_stage(stage))
			_gacha_buttons[kind].disabled = not reason.is_empty()
			_gacha_buttons[kind].text = reason if not reason.is_empty() \
				else "%s 소환" % GearDefs.SLOT_NAME[kind]
	var free := free_pull_date != Time.get_date_string_from_system()
	_gacha_buttons["one"].text = "오늘 무료 1회" if free else "1회  30"
	if free:
		_gacha_buttons["one"].icon = null
	else:
		Ui.cost_icon(_gacha_buttons["one"], "res://assets/ui/res_gem.png")
	_gacha_buttons["ten"].text = "10연  300"
	_gacha_buttons["one"].disabled = not free and gem < GachaDefs.COST
	_gacha_buttons["ten"].disabled = gem < GachaDefs.COST * 10.0


const CODEX_COLS := 6   # 5칸이면 5줄이 되어 세로가 창을 넘는다
const CODEX_ROWS := 4
const CODEX_ICON := 44.0
# 목록 + 상세 2단. 6x4 격자는 22종을 한눈에 보여 줬지만 몹마다 붙은 지식 레벨·효과·
# 다음 단계를 넣을 자리가 없다. 목록은 "뭐가 남았나", 상세는 "이걸 더 잡으면 뭐가 되나".
const CODEX_HEAD_H := 24.0        # 맨 위 종수 보상 한 줄
const CODEX_LIST_W := 156.0       # 칸 글자폭 74px — "999.9t"(72) 가 들어가는 최소값
const CODEX_ROW_H := 62.0
const CODEX_BIG := 72.0           # 상세의 큰 그림


# 도감. 방치형에서 "언젠가 다 채운다"는 장기 목표는 공짜다 — 처치 수는 이미 세고 있다.
func _build_codex(root: Control) -> void:
	var keys := FoeTiers.all_keys()
	# 지식 합계는 몹 하나가 아니라 도감 전체에 걸린 값이라 맨 위 한 줄에 둔다.
	# 오른쪽 버튼은 그 합계가 실제로 무슨 능력치가 됐는지 펼쳐 본다.
	_codex_summary = _panel_label(root, Vector2(PAD, PAD), Type.SIZE_SMALL,
		Color(0.82, 0.88, 0.72), CONTENT_W - 108.0, CODEX_HEAD_H)
	_codex_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status_btn := Ui.button("능력치", Vector2(CONTENT_W + PAD - 100.0, PAD - 6.0),
		Vector2(100.0, 36.0), Type.SIZE_SMALL)
	status_btn.pressed.connect(func() -> void:
		_status_view.visible = not _status_view.visible
		if _status_view.visible:
			_refresh_status())
	root.add_child(status_btn)

	var body_y := PAD + CODEX_HEAD_H + 8.0
	var body_h := CONTENT_BOTTOM - body_y
	var sc := Ui.scroll(Vector2(PAD, body_y), Vector2(CODEX_LIST_W, body_h))
	root.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = CODEX_LIST_W - Ui.SCROLL_W
	sc.add_child(col)
	for key in keys:
		col.add_child(_codex_row(str(key)))

	# ── 상세 ──
	var dx := PAD + CODEX_LIST_W + 16.0
	var dw := CONTENT_W + PAD - dx
	_codex_detail = {}
	# 세로 배치는 아래에서부터 잡는다. 진행바(52px)가 제일 크고 자리가 고정이라
	# 위에서부터 쌓으면 마지막에 바가 글자를 덮는다 — 실제로 한 번 덮었다.
	var bar_y := CONTENT_BOTTOM - Ui.BAR_H - 12.0
	_codex_detail["name"] = _panel_label(root, Vector2(dx, body_y), Type.SIZE_BODY,
		Color(0.96, 0.90, 0.86), dw, 28.0)
	_codex_detail["big"] = Ui.icon("", Vector2(dx + (dw - CODEX_BIG) * 0.5,
		body_y + 30.0), CODEX_BIG)
	root.add_child(_codex_detail["big"])
	_codex_detail["lv"] = _panel_label(root, Vector2(dx, body_y + 104.0),
		Type.SIZE_SMALL, Color(1.0, 0.86, 0.52), dw, 22.0)
	_codex_detail["effect"] = _panel_label(root, Vector2(dx, body_y + 126.0),
		Type.SIZE_SMALL, Color(0.98, 0.72, 0.45), dw, 22.0)
	_codex_detail["next"] = _panel_label(root, Vector2(dx, bar_y - 22.0),
		Type.SIZE_SMALL, Color(0.72, 0.72, 0.78), dw, 20.0)
	for k in ["name", "lv", "effect", "next"]:
		_codex_detail[k].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_codex_detail[k].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bar := Ui.bar(Vector2(dx, bar_y), dw, Color(0.62, 0.32, 0.72))
	root.add_child(bar)
	_codex_detail["bar"] = bar
	_codex_selected = str(keys[0])
	_build_status(root)


# 지식 합계가 실제로 무슨 능력치가 됐는지 한 장에 편다.
# 도감 목록은 "몹 하나를 얼마나 잡았나"만 보여 줘서, 그게 합쳐져 뭐가 됐는지가 안 보였다.
# 7줄 x 28 = 196px. 머리글(30) + 현재값(22) + 여백까지 296 안에 들어간다 —
# 닫기 버튼을 목록 아래에 두면 마지막 줄을 덮는다(실제로 덮었다). 그래서 오른쪽 위,
# "능력치" 버튼이 있던 바로 그 자리에 둔다.
const STATUS_ROW_H := 28.0


func _build_status(root: Control) -> void:
	_status_view = Control.new()
	_status_view.position = Vector2.ZERO
	_status_view.size = Vector2(PANEL_W, PANEL_H)
	_status_view.visible = false
	root.add_child(_status_view)
	# 창 전체를 덮는다 — 뒤 목록이 비쳐 보이면 어느 쪽 숫자인지 헷갈린다.
	var back := ColorRect.new()
	# 완전 불투명이어야 한다. 0.97 로 뒀더니 뒤 목록 글자가 유령처럼 비쳐서
	# 어느 쪽 숫자인지 헷갈렸다.
	back.color = Color(0.055, 0.05, 0.065)
	back.position = Vector2(PAD * 0.5, PAD * 0.5)
	back.size = Vector2(PANEL_W - PAD, PANEL_H - PAD)
	_status_view.add_child(back)
	_status_head = _panel_label(_status_view, Vector2(PAD, PAD), Type.SIZE_BODY,
		Color(0.96, 0.90, 0.86), CONTENT_W - 108.0, 30.0)
	_status_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_now = _panel_label(_status_view, Vector2(PAD, PAD + 32.0), Type.SIZE_SMALL,
		Color(0.98, 0.78, 0.45), CONTENT_W - 108.0, 22.0)
	_status_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := PAD + 58.0
	for r in FoeTiers.CODEX_REWARDS:
		var need := _panel_label(_status_view, Vector2(PAD + 8.0, y), Type.SIZE_SMALL,
			Color(0.72, 0.72, 0.78), 110.0, STATUS_ROW_H)
		need.text = "합 %d" % int(r["need"])
		need.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var gain := _panel_label(_status_view, Vector2(PAD + 122.0, y), Type.SIZE_SMALL,
			Color(0.95, 0.90, 0.88), 190.0, STATUS_ROW_H)
		gain.text = "%s +%d%%%s" % [FoeTiers.codex_stat_name(str(r["stat"])),
			int(float(r["rate"]) * 100.0),
			"  보석 %d" % int(float(r["gem"])) if r.has("gem") else ""]
		gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var state := _panel_label(_status_view, Vector2(PAD + 320.0, y), Type.SIZE_SMALL,
			Color(0.62, 0.62, 0.68), CONTENT_W - 328.0, STATUS_ROW_H)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_status_rows.append({"need": int(r["need"]), "gain": gain, "state": state,
			"label": need})
		y += STATUS_ROW_H
	var close := Ui.button("닫기", Vector2(CONTENT_W + PAD - 100.0, PAD - 6.0),
		Vector2(100.0, 36.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _status_view.visible = false)
	_status_view.add_child(close)


func _refresh_status() -> void:
	if not _status_view or not _status_view.visible:
		return
	_status_head.text = "지식 합계  %d / %d" % [codex_knowledge,
		FoeTiers.codex_max_knowledge()]
	var now: Array[String] = []
	for stat in ["damage", "gold", "tough"]:
		var rate := FoeTiers.codex_bonus(codex_knowledge, stat)
		if rate > 0.0:
			now.append("%s +%d%%" % [FoeTiers.codex_stat_name(stat), int(rate * 100.0)])
	_status_now.text = "지금 받는 것 —  %s" % ("  ·  ".join(now) if not now.is_empty()
		else "아직 없음")
	for row in _status_rows:
		var done: bool = codex_knowledge >= int(row["need"])
		# 받은 줄은 밝게, 못 받은 줄은 어둡게. 남은 줄에는 **얼마나 남았는지**를 적는다 —
		# 조건만 있고 거리가 없으면 목표가 안 된다.
		var col := Color(0.95, 0.90, 0.88) if done else Color(0.52, 0.50, 0.56)
		row["gain"].add_theme_color_override("font_color", col)
		row["label"].add_theme_color_override("font_color",
			Color(0.82, 0.88, 0.72) if done else Color(0.45, 0.44, 0.50))
		row["state"].text = "받음" if done else "%d 남음" % (int(row["need"])
			- codex_knowledge)


# 목록 한 줄. 누르면 상세가 바뀐다. 선택 표시는 뒤에 깔린 판의 밝기로 한다 —
# 테두리를 그리면 도트 UI 안에서 혼자 매끈해 보인다.
func _codex_row(key: String) -> Control:
	var w := CODEX_LIST_W - Ui.SCROLL_W
	var row := Control.new()
	row.custom_minimum_size = Vector2(w, CODEX_ROW_H)
	var mark := ColorRect.new()
	mark.color = Color(0.85, 0.72, 0.45, 0.16)
	mark.size = Vector2(w, CODEX_ROW_H - 4.0)
	mark.position = Vector2(0, 2.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var ic := Ui.icon(FoeTiers.sprite_of(key), Vector2(6.0, 4.0 + _sprite_drop(key)),
		CODEX_ICON)
	row.add_child(ic)
	var lv := _panel_label(row, Vector2(CODEX_ICON + 10.0, 6.0), Type.SIZE_SMALL,
		Color(1.0, 0.86, 0.52), w - CODEX_ICON - 14.0, 24.0)
	var cnt := _panel_label(row, Vector2(CODEX_ICON + 10.0, 32.0), Type.SIZE_SMALL,
		Color(0.68, 0.68, 0.74), w - CODEX_ICON - 14.0, 24.0)
	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(w, CODEX_ROW_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _select_codex(key))
	row.add_child(btn)
	_codex_cells[key] = {"icon": ic, "label": cnt, "lv": lv, "mark": mark}
	return row


func _select_codex(key: String) -> void:
	_codex_selected = key
	_refresh_codex()


# 몹 그림은 32x32 안에서 차지하는 높이가 제각각이다(박쥐는 위쪽, 슬라임은 아래쪽).
# 그대로 가운데 정렬하면 글자와의 간격이 칸마다 달라 보인다. 실제 그림의 아래끝을
# 한 줄에 맞추려고 그만큼 내린다. 22장뿐이라 시작할 때 한 번 재면 된다.
func _sprite_drop(key: String) -> float:
	var tex := Assets.tex(FoeTiers.sprite_of(key))
	if tex == null:
		return 0.0
	var used := tex.get_image().get_used_rect()
	if used.size.y <= 0:
		return 0.0
	var scale := CODEX_ICON / float(maxi(tex.get_width(), tex.get_height()))
	# 그림 아래끝이 상자 아래끝에 오도록 내린다.
	return (float(tex.get_height()) - float(used.position.y + used.size.y)) * -scale \
		+ (CODEX_ICON - float(tex.get_height()) * scale) * 0.5


func _refresh_codex() -> void:
	for key in _codex_cells.keys():
		var n := int(codex.get(key, 0))
		var cell: Dictionary = _codex_cells[key]
		# 못 본 몹은 실루엣으로 남긴다 — 뭐가 남았는지는 보이되 정체는 안 보인다.
		cell["icon"].modulate = Color(1, 1, 1) if n > 0 else Color(0, 0, 0, 0.55)
		# "Lv." 를 쓰지 않는 이유: 이 블랙레터 폰트의 대문자 L·D 가 딴 글자로 읽힌다
		# (실제로 "Lv.1" 이 "ℒ𝔇.1" 로 보였다). 한글 단위는 이 폰트에서 항상 안전하다.
		cell["lv"].text = "지식 %d" % FoeTiers.codex_level(n) if n > 0 else "?"
		cell["label"].text = _n(float(n)) if n > 0 else ""
		cell["mark"].visible = key == _codex_selected
	if not _codex_summary:
		return
	# 지금 받고 있는 것과 **다음 칸까지 몇 종 남았나**를 같이 띄운다.
	# 진도만 보이면 더 모을 이유가 안 생긴다.
	var parts := ["도감 %d / %d" % [codex_found, FoeTiers.TIERS.size()],
		"지식 합 %d" % codex_knowledge]
	for r in FoeTiers.CODEX_REWARDS:
		if int(r["need"]) > codex_knowledge:
			parts.append("다음 보상까지 %d" % (int(r["need"]) - codex_knowledge))
			break
	_codex_summary.text = "  ·  ".join(parts)
	_refresh_codex_detail()
	_refresh_status()


func _refresh_codex_detail() -> void:
	if _codex_detail.is_empty():
		return
	var key := _codex_selected
	var n := int(codex.get(key, 0))
	var seen := n > 0
	var tier := FoeTiers.get_tier(key)
	_codex_detail["name"].text = str(tier["name"]) if seen else "???"
	_codex_detail["big"].texture = Assets.tex(FoeTiers.sprite_of(key))
	_codex_detail["big"].modulate = Color(1, 1, 1) if seen else Color(0, 0, 0, 0.55)
	var level := FoeTiers.codex_level(n)
	_codex_detail["lv"].text = "지식 %d레벨" % level
	_codex_detail["effect"].text = "%s 상대 피해 +%d%%" % [
		str(tier["name"]) if seen else "???", int(FoeTiers.codex_kill_bonus(n) * 100.0)]
	var need := FoeTiers.codex_next_need(n)
	if need <= 0:
		_codex_detail["next"].text = "지식 만렙"
		_codex_detail["bar"].value = 1.0
		return
	var step := FoeTiers.codex_step_of(n)
	var prev := 0 if level == 0 else int(FoeTiers.CODEX_KILL_STEPS[level - 1])
	_codex_detail["next"].text = "%s / %s  (다음까지 %s)" % [_n(float(n)), _n(float(step)),
		_n(float(need))]
	_codex_detail["bar"].value = clampf(float(n - prev) / float(maxi(1, step - prev)),
		0.0, 1.0)


# 하단 탭바. "전투"는 창을 전부 닫는 탭이다 — 세로 화면에서 전투를 크게 보고 싶을 때
# 쓸 곳이 그것뿐이라 따로 창을 만들 이유가 없다.
# 탭 3개. 창을 닫는 "전투" 탭은 없앴다 — 레이아웃이 고정이라 닫아도 화면이 안 넓어지고
# 그 자리가 검게 비기만 한다.
const TABS := [["growth", "tab_growth", "성장"], ["gear", "tab_gear", "장비"],
	["summon", "tab_battle", "소환"], ["codex", "tab_codex", "도감"]]


func _build_tabbar() -> void:
	for i in TABS.size():
		var name: String = TABS[i][0]
		var b := Button.new()
		b.flat = true
		# 4칸을 화면 폭에 고르게 나눈다(칸 9유닛, 아이콘 4유닛짜리를 가운데에).
		b.position = Grid.uv(i * 9, 50.0)
		b.size = Grid.uv(9, 6)
		b.pressed.connect(func() -> void: _select_tab(name))
		_hud_root.add_child(b)
		var marker := Control.new()
		marker.position = Grid.uv(i * 9, 50.0)
		marker.size = Grid.uv(9, 6)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(marker)
		marker.add_child(Ui.image("res://assets/ui/tab_cell.png", Vector2.ZERO, Grid.uv(9, 6)))
		var ic := Ui.icon("res://assets/ui/%s.png" % TABS[i][1],
			Vector2(48.0, 6.0), 48.0)
		marker.add_child(ic)
		var label := _panel_label(marker, Vector2(0.0, 54.0), Type.SIZE_SMALL,
			Color(0.82, 0.78, 0.82), 144.0, 24.0)
		label.text = TABS[i][2]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tab_btns[name] = marker


func _select_tab(name: String) -> void:
	_tab = name
	for key in _panels.keys():
		_panels[key].visible = key == name
	for key in _tab_btns.keys():
		# 선택 안 된 탭은 어둡게. 아이콘이 4개뿐이라 밝기만으로 충분히 읽힌다.
		_tab_btns[key].modulate = Color(1, 1, 1) if key == name else Color(0.5, 0.5, 0.55)
	if name == "codex":
		_refresh_codex()
	elif name == "summon":
		_refresh_gacha()


func _buy(key: String) -> void:
	if not StatDefs.is_open(key, StageDefs.major_stage(stage)) \
			or StatDefs.at_cap(key, stat_lv(key)):
		return
	var cost := _buy_cost(key, buy_step)
	if gold < cost:
		return
	var old_max := max_hp()
	gold -= cost
	var s := StatDefs.of(key)
	var next := stat_lv(key) + buy_step
	if s.has("cap"):
		next = mini(next, int(s["cap"]))   # 상한을 넘겨 사도 레벨은 안 넘어간다
	lv[key] = next
	_apply_hp_growth(old_max)
	# 흡혈량은 전투력에 안 들어가므로(재화 획득량이지 전투 능력이 아니다) 그냥 사면
	# 화면에 아무 반응이 없다. 올린 값을 직접 띄운다 — **뭘 사든 반응은 있어야 한다.**
	if key == "gold":
		_notify_stat("혈액 획득 x%.2f" % gold_mult())
	_save_game()
	_refresh_hud()


# 전투력으로 안 잡히는 스탯이 올랐을 때의 알림. 전투력 알림과 **같은 줄**을 쓴다 —
# 둘이 동시에 뜰 일이 없고(한 번에 한 스탯만 산다), 줄을 늘리면 전투를 가린다.
func _notify_stat(text: String) -> void:
	_power_gain = 0.0
	_power_toast_t = POWER_TOAST_TIME
	_power_toast.text = text
	_power_toast.visible = true


# ── 루프 ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	play_time += delta
	_tick_hero_state(delta)
	var visual_frozen := _visual_hitstop_t > 0.0
	_visual_hitstop_t = maxf(0.0, _visual_hitstop_t - delta)
	_hitstop_cd = maxf(0.0, _hitstop_cd - delta)
	_tick_motion(0.0 if visual_frozen else delta)
	queue_redraw()   # 그림자는 몹이 움직일 때마다 다시 그려야 한다
	if _offline_t > 0.0:
		_offline_t -= delta
		if _offline_t <= 0.0:
			_offline_banner.visible = false
	_boss_pan_t = maxf(0.0, _boss_pan_t - delta)
	_fade_t = maxf(0.0, _fade_t - delta)
	if _power_toast_t > 0.0:
		_power_toast_t -= delta
		if _power_toast_t <= 0.0:
			_power_toast.visible = false
			_power_gain = 0.0   # 다음 상승은 처음부터 다시 센다

	var foes := get_tree().get_nodes_in_group("foes")
	if _tick_boss_timer(delta):
		_refresh_hud()
		return
	_tick_advance(delta, foes)
	for f in foes:
		if is_instance_valid(f):
			f.set_visual_frozen(visual_frozen)
			f.set_combat_active(_phase == "fight" and not _hero_dead)
			# 영웅 위치를 넘겨 **닿을 때만 휘두르게** 한다. 예전엔 사거리와 무관하게
			# 스윙을 시작하고 임팩트 때 빗나갔다 — 6칸 중 절반 이상이 매번 그랬고,
			# 화면에서는 "몹이 때리는데 아무 일도 안 일어난다"로 보인다.
			f.hero_x = hero_x
	_tick_skills(delta, foes)
	_tick_hero_attack(delta, foes)
	_tick_dash(delta)
	_refresh_hud()


# 자동 공격은 모션 시작이 아니라 7프레임 중 네 번째에 피해가 들어간다. 예약한 대상이
# 그 전에 사라졌으면 피해도 이펙트도 만들지 않는다.
func _tick_hero_attack(delta: float, foes: Array) -> void:
	if _hero_hit_t >= 0.0:
		_hero_hit_t -= delta
		if _hero_hit_t <= 0.0:
			_hero_hit_t = -1.0
			if _can_hit_foe(_pending_target):
				_pending_target.take_damage(_combat_damage(_pending_target))
				_anim_fx("fx_cleave", _pending_target.position + Vector2(0, -28), 18.0, 2.0)
			_pending_target = null
	if _hero_dead or _phase != "fight":
		return
	# 쿨다운은 **스킬 중에도 돈다.** 예전엔 여기서 통째로 빠져나가서, 스킬이 끝난 뒤
	# 남은 쿨다운을 처음부터 다시 기다렸다 — 네 형태를 다 끼면 시간의 22%가 스킬인데
	# 그만큼 기본공격이 두 번 지연됐다(계측: CombatRulesTest "계측 C").
	_attack_t -= delta
	if _skill_action != "":
		return
	# **가장 가까운** 적을 고른다. 예전엔 "제일 왼쪽"이었는데, 좌우 양쪽에서 나오는
	# 지금은 그러면 등 뒤 적만 계속 쫓아 화면 밖으로 걸어 나간다.
	var target: Foe = null
	var best := INF
	for f in foes:
		if not _foe_arrived(f):
			continue
		var d := absf(f.position.x - hero_x)
		if d < best:
			best = d
			target = f
	if target == null:
		return
	hero_face = 1 if target.position.x >= hero_x else -1
	# 사거리 밖이면 먼저 달려간다. 이게 "대시해서 달려가 팬다"의 전부다 —
	# 붙는 동안 공격 쿨다운은 계속 돌아서 도착하면 바로 첫 대를 친다.
	if not _in_front_reach(target):
		_dash_to = _strike_spot(target)
		_play("dash")
		return
	_dash_to = hero_x   # 붙었으면 멈춰서 팬다
	if _attack_t > 0.0:
		return
	var interval := attack_interval()
	_attack_t = interval
	_hero_hit_t = interval * IMPACT_RATIO
	_pending_target = target
	_play("attack")


# 대시. 모션·공격과 무관하게 매 프레임 자리로 민다 — 공격 중에도 조금씩 파고들어야
# 몹이 죽으면서 밀려나도 계속 닿는다.
func _tick_dash(delta: float) -> void:
	if _hero_dead:
		return
	if _phase != "fight":
		_dash_to = HERO_X   # 무리를 치웠으면 걷던 자리로 돌아온다
	hero_x = move_toward(hero_x, clampf(_dash_to, 24.0, Grid.BG.x - 24.0),
		DASH_SPEED * delta)
	_hero.position.x = hero_x
	_hero.flip_h = hero_face > 0


# 모션의 실제 임팩트 프레임에서 불투명 픽셀 끝을 읽는다. **길이**만 돌려준다 —
# 영웅이 좌우로 움직이므로 절대 좌표로 두면 뒤돌아섰을 때 값이 틀린다.
#
# 프레임 번호는 실제 프레임 수에서 비율로 뽑는다. 7프레임이면 3(지금과 동일),
# 8프레임이면 3, 9프레임이면 4 — 모션을 다시 뽑아도 사거리 측정이 따라간다.
func _motion_reach(motion: String) -> float:
	var dir := "res://assets/anim/%s_%s" % [skin, motion]
	var n := maxi(1, Assets.frames(dir).size())
	return Assets.frame_reach(dir, int(round(float(n) * IMPACT_RATIO)),
		HERO_DRAW_SCALE, true)


# 근접 사거리는 **쓰는 근접 모션 중 가장 짧은 것**에 맞춘다. 긴 쪽에 맞추면
# 짧은 모션이 허공을 벤다. 근접은 격(strike) 하나뿐이라 그 모션만 보면 된다.
func _front_reach() -> float:
	return minf(_motion_reach("attack"),
		_motion_reach(str(SkillDefs.SHAPES["strike"]["motion"])))


func _foe_arrived(foe: Foe) -> bool:
	return _phase == "fight" and is_instance_valid(foe) and not foe.dying 		and absf(foe.position.x - foe.stop_x) <= 1.0


# 칼끝과 적 외곽 사이의 빈 거리. 좌우 어느 쪽에 있든 같은 식이 되도록 **거리**로만 잰다.
func _foe_gap(foe: Foe) -> float:
	return absf(foe.position.x - hero_x) - foe._size() * 0.5


# 피해 순간에 해당 모션의 실제 픽셀 사거리와 적 외곽을 다시 비교한다.
func _can_hit_foe(foe: Foe, motion: String = "attack") -> bool:
	return _foe_arrived(foe) and _foe_gap(foe) <= _motion_reach(motion) + 1.0


# **쓰는 근접 모션이 전부 닿는가.** 대시는 이 기준으로 붙어야 한다 —
# 기본공격(30)만 보고 멈추면 더 짧은 스킬 모션(heavy 24)이 안 닿아서
# 격 스킬이 영영 사거리 밖이 되고, 그러면 쿨다운도 안 돌아 뒤 스킬까지 막힌다.
func _in_front_reach(foe: Foe) -> bool:
	return _foe_arrived(foe) and _foe_gap(foe) <= _front_reach() + 1.0


# 그 몹을 치려면 서야 할 자리 — 몹 몸통 바로 바깥이다.
func _strike_spot(foe: Foe) -> float:
	var gap := foe._size() * 0.5 + _front_reach() - 8.0
	return foe.position.x + (-gap if foe.position.x > hero_x else gap)


# 몹이 설 자리. 영웅 기준이 아니라 **화면 기준 고정 칸**이다 — 예전처럼 영웅
# 사거리 앞에 줄 세우면 영웅이 움직일 이유가 없어 전투가 정지 화면이 된다.
func _lane_x(side: int, line: int) -> float:
	var lanes: Array = LANES_RIGHT if side > 0 else LANES_LEFT
	return float(lanes[mini(line, lanes.size() - 1)])


func _tick_hero_state(delta: float) -> void:
	if _hero_dead:
		_revive_t -= delta
		if _revive_t <= 0.0:
			# 그 자리에서 되살아나지 않는다. 쓰러졌으면 그 구간을 못 넘은 것이라
			# 시간 초과와 같은 길로 보내 구간을 처음부터 다시 한다.
			_restart_stage("쓰러짐")
		return
	if _hero_flash_t > 0.0:
		_hero_flash_t -= delta
		if _hero_flash_t <= 0.0:
			_hero.self_modulate = Color.WHITE
	_summon_t = maxf(0.0, _summon_t - delta)
	hero_hp = minf(max_hp(), hero_hp + regen_per_sec() * delta)


# 쿨다운이 찬 스킬을 **장착 순서대로 전부**. 순서가 곧 발동 우선순위다.
func _ready_skills() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in skill_equipped:
		if float(_skill_cd.get(key, 0.0)) > 0.0:
			continue
		var data := _skill_data(str(key))
		if not data.is_empty():
			out.append(data)
	return out


# 먼저 적힌 스킬이 우선이다.
func _next_ready_skill() -> Dictionary:
	var ready := _ready_skills()
	return ready[0] if not ready.is_empty() else {}


# 표(SkillDefs)에서 형태 정보를 꺼내고 **보유 레벨을 반영한** 실제 값으로 만든다.
func _skill_data(key: String) -> Dictionary:
	if not SkillDefs.NAMES.has(SkillDefs.split(key)[0]):
		return {}
	var lv := int(skill_owned.get(key, 0))
	var shape: Dictionary = SkillDefs.shape_of(key)
	var data := shape.duplicate()
	data["key"] = key
	data["name"] = SkillDefs.name_of(key)
	data["shape"] = SkillDefs.split(key)[0]
	data["cooldown"] = SkillDefs.cooldown(key, lv)
	data["power"] = SkillDefs.power(key, lv) * (1.0 + _skill_combo_bonus(key))
	data["fx"] = SkillDefs.fx_of(key)
	data["hit_fx"] = SkillDefs.hit_fx_of(key)
	# 가호는 피해가 0이라 위 power 로는 등급이 안 갈린다. 배수·지속을 따로 얹는다 —
	# 안 하면 레전더리 가호와 커먼 가호가 글자만 다른 같은 스킬이 된다.
	if str(data["shape"]) == "ward":
		data["bonus"] = SkillDefs.ward_bonus(key)
		data["duration"] = SkillDefs.ward_duration(key, lv)
	# 형태가 곧 대상 규칙이다. 표에 target 을 또 적으면 둘이 어긋난다.
	data["target"] = {"strike": "melee", "wave": "area", "field": "area",
		"ward": "self"}[str(data["shape"])]
	return data


# 조합 버프. 같은 형태를 모으거나 네 형태를 다 펼치거나 — 둘 다 이득이다.
func _skill_combo_bonus(key: String) -> float:
	var same: Dictionary = SkillDefs.combo_power(skill_equipped)
	return float(same.get(SkillDefs.split(key)[0], 0.0)) \
		+ SkillDefs.combo_spread(skill_equipped)


# 슬롯을 비워 두면 그만큼 손해다. 방치형에서 매번 고르게 하면 방치가 아니라서
# 자동으로 채운다 — 형태를 골고루 먼저 채우고 남은 칸을 센 것부터 메운다.
func _auto_equip_skills() -> void:
	var owned := skill_owned.keys()
	# **센 것부터**. 등급만이 아니라 등급 x 레벨을 곱한 값이라, 올려 둔 커먼이
	# 갓 뽑은 레어를 이기기도 한다(SkillDefs.rank).
	owned.sort_custom(func(a: Variant, b: Variant) -> bool:
		return SkillDefs.rank(str(a), int(skill_owned[a])) \
			> SkillDefs.rank(str(b), int(skill_owned[b])))
	var picked: Array[String] = []
	var used_shape := {}
	# 1순위: 형태마다 가장 센 것 하나씩. 버프만 여섯 개 끼면 몹이 안 죽는다.
	for key in owned:
		var shape := str(SkillDefs.split(str(key))[0])
		if used_shape.has(shape):
			continue
		used_shape[shape] = true
		picked.append(str(key))
	# 2순위: 남은 칸은 그냥 센 것부터.
	for key in owned:
		if picked.size() >= SkillDefs.SLOTS:
			break
		if not picked.has(str(key)):
			picked.append(str(key))
	skill_equipped = picked.slice(0, mini(picked.size(), SkillDefs.SLOTS))


func _tick_skills(delta: float, foes: Array) -> void:
	if not _hero_dead:
		for key in _skill_cd:
			_skill_cd[key] = maxf(0.0, float(_skill_cd[key]) - delta)
	if _skill_action != "":
		_skill_action_t -= delta
		_skill_hit_t -= delta
		if not _skill_impact_sent and _skill_hit_t <= 0.0:
			_skill_impact_sent = true
			_resolve_skill(_skill_action)
		if _skill_action_t <= 0.0:
			_skill_action = ""
			_skill_target = null
		return
	# **_hero_hit_t 게이트를 뺐다.** 기본공격 임팩트를 기다리는 동안 스킬을 통째로
	# 막고 있었는데, 그 대기가 주기의 3/7 이라 발동 창이 4/7 밖에 안 됐다. 공속이
	# 만렙(0.10초)이면 창이 **3.4프레임**까지 줄어서 스킬이 운으로만 나갔다
	# (계측: CombatRulesTest "계측 B"). 막을 이유도 없다 — 예약된 기본공격 피해는
	# _tick_hero_attack 맨 위에서 _skill_action 과 무관하게 그대로 들어간다.
	if _hero_dead or _phase != "fight" or foes.is_empty():
		return
	# **대상이 없으면 다음 스킬을 본다.** 예전엔 1순위 하나만 보고 그게 사거리 밖이면
	# 통째로 포기했다 — 격이 안 나가면 쿨다운도 안 돌아서 파·진·가호까지 영영 막혔다.
	var skill := {}
	var target: Foe = null
	for candidate in _ready_skills():
		var targeting := str(candidate["target"])
		if targeting == "self":
			skill = candidate
			break
		var found: Foe = null
		for f in foes:
			var in_range := _foe_arrived(f) if targeting == "area" \
				else _can_hit_foe(f, str(candidate["motion"]))
			if in_range and (found == null or f.position.x < found.position.x):
				found = f
		if found != null:
			skill = candidate
			target = found
			break
	if skill.is_empty():
		return
	_skill_action = str(skill["key"])
	_skill_action_t = SKILL_DUR
	_skill_hit_t = SKILL_DUR * IMPACT_RATIO
	_skill_impact_sent = false
	_skill_cd[_skill_action] = float(skill["cooldown"])
	_skill_target = target
	_play(str(skill["motion"]), SKILL_DUR)


func _resolve_skill(key: String) -> void:
	if _hero_dead or _phase != "fight":
		return
	var skill := _skill_data(key)
	if skill.is_empty():
		return
	# 이펙트는 원본 64px 을 **1배**로 그린다. 2배로 그렸더니 캐릭터보다 커서
	# 그 뒤 몹이 통째로 가려졌다(2026-08-04 화면에서 확인).
	var p: Dictionary = SkillDefs.fx_profile(key)
	var fx := str(p["fx"])
	var fx_y := float(p["y"])
	var fx_fps := float(p["fps"])
	var fx_style := str(p["style"])
	var fx_scale := float(p["scale"])
	var fx_echo := int(p["echo"])
	var fx_skew := float(p["skew"])
	# 등급이 높을수록 화면이 더 흔들린다. 레전더리가 커먼과 같은 무게로 터지면 안 된다.
	if float(p["shake"]) > 0.0:
		_shake_combat(float(p["shake"]))
	var hit := _combat_damage() * Balance.skill_hit_mult(attack_interval(), SKILL_DUR) \
		* float(skill["power"]) / 2.2
	match str(skill["shape"]):
		"strike":
			if _can_hit_foe(_skill_target, str(skill["motion"])):
				var dealt := minf(_skill_target.hp, hit)
				_skill_target.take_damage(hit)
				gold += dealt * 0.20
				_anim_fx(fx, _skill_target.position + Vector2(0, fx_y),
					fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew)
				_skill_hit_fx(skill, _skill_target)
		"wave", "field":
			_defer_stage_advance = true
			var struck: Array[Foe] = []
			for f in get_tree().get_nodes_in_group("foes"):
				if _foe_arrived(f):
					f.take_damage(hit)
					_skill_hit_fx(skill, f)
					struck.append(f)
			_defer_stage_advance = false
			# **떨어지는 것은 맞는 놈들 머리 위마다 뜬다.** 광역인데 영웅 앞 한 자리에서만
			# 쏟아지면 "저기만 비가 온다"로 보인다. 쓸고 지나가는 것(sweep)과 바닥에
			# 깔리는 것(hold·rise)은 하나여야 맞으므로 fall 만 나눈다.
			#
			# 나눠 뜰 때는 잔상을 끈다 — 잔상은 **하나짜리 이펙트를 크게 보이게** 하는
			# 장치라, 이미 여러 개가 떠 있으면 화면만 두꺼워지고 등급은 크기로 읽힌다.
			if fx_style == "fall" and not struck.is_empty():
				for f in struck:
					_anim_fx(fx, Vector2(f.position.x, ground_y + fx_y),
						fx_fps, fx_scale, fx_style, 0, 1.0, hero_face, fx_skew)
			else:
				_anim_fx(fx, Vector2(hero_x + float(hero_face) * (_motion_reach("attack") + 48.0),
					ground_y + fx_y),
					fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew)
			if kills >= StageDefs.kills_needed(stage):
				_advance_stage()
		"ward":
			_summon_t = float(skill["duration"])
			_summon_bonus = float(skill.get("bonus", 0.0))
			_anim_fx(fx, Vector2(hero_x, ground_y + fx_y),
				fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew)


# 맞은 쪽 표시. 때린 이펙트만 있고 이게 없으면 피해가 들어갔는지 화면에서 안 읽힌다.
# 32px 라 몹을 안 가린다.
func _skill_hit_fx(skill: Dictionary, foe: Foe) -> void:
	var hit_fx := str(skill.get("hit_fx", ""))
	if hit_fx.is_empty() or not is_instance_valid(foe):
		return
	_anim_fx(hit_fx, foe.position + Vector2(0, -30.0), 18.0, 1.5)


# 히트스톱은 **띄엄띄엄 걸려야 효과가 있다.**
#
# 예전엔 맞은 몹마다 이 함수가 불려서 두 가지가 겹쳤다:
#   1. 피의 파도가 5마리를 때리면 흔들림이 **5겹**으로 쌓였다
#   2. 공속이 오르면 0.035초 정지가 끊임없이 들어가 화면이 계속 얼어붙었다
# 둘 다 "타격감"이 아니라 **뚝뚝 끊김**으로 보인다. 한 프레임에 한 번, 그리고
# 최소 간격을 두고만 건다.
const HITSTOP_MIN_GAP := 0.14
var _hitstop_cd := 0.0
var _hitstop_frame := -1


func on_foe_hit(_foe: Foe, _damage: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _hitstop_frame:
		return          # 같은 프레임의 광역 타격은 한 번으로 친다
	_hitstop_frame = frame
	if _hitstop_cd > 0.0:
		return          # 너무 잦으면 건너뛴다
	_hitstop_cd = HITSTOP_MIN_GAP
	_visual_hitstop_t = maxf(_visual_hitstop_t, HITSTOP_DUR)
	if is_inside_tree():
		for f in get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f):
				f.set_visual_frozen(true)
	_shake_combat(2.0)


# Foe가 자기 attack 애니의 네 번째 프레임에 호출한다.
# 몹은 **영웅이 뭘 하든** 제 쿨다운으로 친다. 영웅이 때리는 중이어도, 다른 몹이
# 이미 때리는 중이어도 막지 않는다 — 그래야 좌우에서 동시에 얻어맞는 난전이 된다.
# 대신 닿는지는 **임팩트 순간에** 본다. 대시로 빠져나갔으면 헛친다.
func on_foe_attack(_foe: Foe) -> void:
	if _hero_dead or _phase != "fight":
		return
	if absf(_foe.position.x - hero_x) > _foe.reach():
		return
	var incoming := Balance.foe_damage(StageDefs.enemy_power(stage))
	hero_hp = maxf(0.0, hero_hp - incoming)
	_hero_flash_t = 0.10
	_hero.self_modulate = Color(7, 7, 8)
	_play("hurt", 0.10)
	if hero_hp <= 0.0:
		_kill_hero()


func _kill_hero() -> void:
	if _hero_dead:
		return
	_hero_dead = true
	_revive_t = REVIVE_TIME
	hero_hp = 0.0
	kills = 0
	_attack_t = 0.0
	_hero_hit_t = -1.0
	_pending_target = null
	_skill_action = ""
	_skill_target = null
	_hero_flash_t = 0.0
	_hero.self_modulate = Color.WHITE
	_anim_fx("fx_death_blood", Vector2(hero_x, ground_y - 42.0), 18.0, 2.0)
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(_hero, "position:y", _hero.position.y - 32.0, DEATH_FADE_TIME)
	_death_tween.tween_property(_hero, "modulate:a", 0.0, DEATH_FADE_TIME)
	_death_tween.finished.connect(func() -> void:
		if _hero_dead:
			_hero.visible = false)
	_save_game()


func _revive_hero() -> void:
	_hero_dead = false
	hero_hp = max_hp()
	hero_x = HERO_X
	_dash_to = HERO_X
	hero_face = 1
	_hero.visible = true
	_hero.position = Vector2(HERO_X, ground_y - float(Grid.SPRITE))
	_hero.modulate = Color.WHITE
	_hero.self_modulate = Color.WHITE
	_attack_t = 0.0
	_play("idle")
	_save_game()


# 걷다가 무리를 만나고, 치우면 또 걷는다. 이 리듬이 "군주가 사냥터를 넓힌다"를
# 숫자가 아니라 그림으로 만든다 — 서서 기다리면 몹이 찾아오는 그림의 반대다.
func _tick_advance(delta: float, foes: Array) -> void:
	if _phase == "fight":
		# 칸이 비면 **바로** 채운다. 예전엔 무리를 다 치워야 다음 무리가 나와서,
		# 60마리를 잡는 동안 걸어 들어오기만 60마리 x 2.3초가 걸렸다 —
		# 제한 시간 안에 애초에 못 넘는다. 이제 죽은 자리로 다음 놈이 걸어온다.
		if _refill_lanes(foes):
			return
		if foes.is_empty():
			_start_advance()
		return

	_play("walk")
	_scroll += SCROLL_SPEED * delta
	_apply_scroll()
	# 선두가 전열에 닿으면 다 같이 멈춰 선다. 시간이 아니라 위치로 판정하는 이유:
	# 시간으로 재면 스폰 위치를 바꿀 때마다 시간도 같이 고쳐야 한다.
	for f in foes:
		if is_instance_valid(f) and absf(f.position.x - f.stop_x) > 1.0:
			return
	if not foes.is_empty():
		_phase = "fight"


# 다음 무리를 부르고 그쪽으로 걷기 시작한다. 무리를 미리 내보내야 배경과 같은
# 속도로 밀려 들어와 "다가간다"로 읽힌다 — 다 걷고 나서 부르면 허공에 튀어나온다.
func _start_advance() -> void:
	_phase = "advance"
	_spawn_wave()


# 동시에 화면에 서 있는 몹 수. **스폰·보충·오프라인 판정이 같은 값을 봐야 한다** —
# 세 군데에 같은 식을 적어 두면 하나만 고쳤을 때 화면과 계산이 조용히 갈린다.
#
# 하한이 4인 이유: 이 값이 곧 처치 처리량의 상한이다. 몹은 화면 밖에서 제 칸까지
# 걸어오므로(약 2.2초) 동시 n마리면 초당 n/2.2 마리가 한계다. 하한이 2이던 동안
# 큰 단계 1~7은 60초에 최대 51마리라 60마리 조건을 **DPS와 무관하게** 못 넘었다.
func _wave_size(at_stage: int) -> int:
	return clampi(2 + StageDefs.major_stage(at_stage) / 8, 4, MAX_FOES)


# 한 마리가 화면 밖에서 제 칸까지 걸어오는 평균 시간. 처리량 상한의 분모다.
func _lane_walk_seconds(at_stage: int) -> float:
	var n := _wave_size(at_stage)
	var right := (n + 1) / 2
	var total := 0.0
	for i in n:
		var side := 1 if i < right else -1
		var line := i if i < right else i - right
		var out := float(line) * Grid.u(3)
		var from := SPAWN_X + out if side > 0 else SPAWN_X_LEFT - out
		total += absf(from - _lane_x(side, line))
	return total / float(maxi(1, n)) / Foe.WALK_SPEED


# 빈 칸 하나를 채운다. 한 프레임에 한 마리씩만 — 몰아 내보내면 다 겹쳐 걸어온다.
# 보스·중간보스 구간은 한 마리로 끝나므로 보충하지 않는다.
func _refill_lanes(foes: Array) -> bool:
	if _walk_only or StageDefs.is_boss_stage(stage) or StageDefs.is_midboss_stage(stage):
		return false
	var want := _wave_size(stage)
	if foes.size() >= want:
		return false
	var taken := {}
	for f in foes:
		if is_instance_valid(f):
			taken[int(f.stop_x)] = true
	var right := (want + 1) / 2
	for i in want:
		var side := 1 if i < right else -1
		var line := i if i < right else i - right
		if taken.has(int(_lane_x(side, line))):
			continue
		_spawn_foe(side, line)
		return true
	return false


func _apply_scroll() -> void:
	# 되돌아오는 주기는 화면 폭이 아니라 배경 폭(1536 = 화면의 2.6배)이다.
	# 화면 폭으로 감으면 몇 초마다 같은 나무가 지나가 걷는 느낌이 죽는다.
	var w := float(Grid.BG_SRC.x * 2)
	var off := fmod(_scroll, w)
	_bg.position.x = -off
	_bg2.position.x = w - off


# 무리 단위로 한 번에 내보낸다. 예전처럼 한 마리씩 흘려보내면 몹이 끊이지 않아
# 영웅이 걸을 틈이 없다 — 리듬이 사라진다.
func _spawn_wave() -> void:
	if _walk_only:
		return
	# 제한 시간은 구간에 걸리지 무리에 걸리지 않는다 — 여기서 다시 채우면
	# 무리를 치울 때마다 시계가 되감겨 제한이 사라진다.
	if StageDefs.is_boss_stage(stage):
		_spawn_foe()
		return
	if StageDefs.is_midboss_stage(stage):
		_spawn_foe()
		return
	# 단계가 오를수록 한 무리가 두꺼워진다. 화면 폭 때문에 MAX_FOES 가 상한이다.
	var n := _wave_size(stage)
	# **좌우 양쪽에서** 나온다. 시간을 버티는 구조가 되면서 한쪽만 보면 되는 전투는
	# 서서 기다리기가 정답이 되어 버렸다 — 뒤에서도 오면 자리를 지킬 수가 없다.
	# 오른쪽을 먼저 채운다: 전진 방향이라 "다가간다"가 계속 읽힌다.
	var right := (n + 1) / 2
	for i in n:
		_spawn_foe(1 if i < right else -1, i if i < right else i - right)


func _spawn_foe(side := 1, line := 0) -> void:
	var act: Dictionary = StageDefs.act_data(stage)
	var boss := StageDefs.is_boss_stage(stage)
	var midboss := StageDefs.is_midboss_stage(stage)
	var key: String = str(act["boss"]) if boss else \
		str((act["roster"] as Array)[randi() % (act["roster"] as Array).size()])
	var tier := FoeTiers.get_tier(key)
	if boss:
		tier["name"] = str(act["boss_name"])
		tier["anim_key"] = str(act["boss_anim"])
	elif midboss:
		tier["midboss"] = true
		tier["name_prefix"] = StageDefs.midboss_prefix(stage) + " "
	var f := Foe.new()
	f.setup(tier, StageDefs.enemy_power(stage),
		StageDefs.gold_per_kill(stage) * gold_mult(), boss)
	f.face = -1 if side > 0 else 1
	# 같은 프레임에 여러 마리가 나가므로 등장 위치도 벌린다. 안 그러면 겹쳐서 걸어온다.
	var out := float(line) * Grid.u(3)
	f.position = Vector2(SPAWN_X + out if side > 0 else SPAWN_X_LEFT - out, ground_y)
	f.stop_x = _lane_x(side, line)
	add_child(f)
	if boss or midboss:
		_announce_elite(f.display_name)
	if boss:
		_boss_pan(f)


func _announce_elite(name: String) -> void:
	_offline_banner.text = name
	_offline_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	_offline_banner.visible = true
	_offline_t = 1.2
	_shake_combat(4.0)


# 보스가 나오면 화면을 보스 쪽으로 밀었다가 영웅에게 돌아온다.
# 몹은 화면 밖(SPAWN_X=640)에서 걸어오므로 그대로면 보스가 처음 몇 초간 안 보인다.
#
# 흔들림과 **같은 position.x 를 쓴다.** 둘이 동시에 돌면 서로 값을 덮어써서
# 화면이 튀므로, 미는 동안에는 흔들림을 막는다.
const BOSS_PAN_HOLD := 0.8


func _boss_pan(boss: Foe) -> void:
	if not is_inside_tree():
		return
	if _combat_shake and _combat_shake.is_valid():
		_combat_shake.kill()
	# 보스를 화면 가운데로. 왼쪽(양수)으로는 안 민다 — 영웅 뒤엔 볼 게 없다.
	var dx := clampf(float(Grid.BG.x) * 0.5 - boss.position.x, -260.0, 0.0)
	_boss_pan_t = 0.45 + BOSS_PAN_HOLD + 0.5
	var t := create_tween()
	t.tween_property(self, "position:x", dx, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_interval(BOSS_PAN_HOLD)
	t.tween_property(self, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_combat_shake = t


func _shake_combat(amount: float) -> void:
	if not is_inside_tree() or _boss_pan_t > 0.0:
		return
	if _combat_shake and _combat_shake.is_valid():
		_combat_shake.kill()
	position.x = 0.0
	_combat_shake = create_tween()
	_combat_shake.tween_property(self, "position:x", -amount, 0.03)
	_combat_shake.tween_property(self, "position:x", amount, 0.05)
	_combat_shake.tween_property(self, "position:x", 0.0, 0.03)


func on_foe_killed(f: Foe) -> void:
	gold += f.gold
	if f.is_boss:
		essence += StageDefs.boss_essence(stage)
	kills += 1
	var prev_kills := int(codex.get(f.key, 0))
	codex[f.key] = prev_kills + 1
	if prev_kills == 0:
		codex_found += 1
	# 지식 레벨이 오른 순간에만 합계를 갱신하고 보상을 확인한다.
	var gained := FoeTiers.codex_level(prev_kills + 1) - FoeTiers.codex_level(prev_kills)
	if gained > 0:
		codex_knowledge += gained
		_claim_codex_reward()
	_gain_exp(Balance.exp_per_kill(StageDefs.major_stage(stage)))
	if _tab == "codex":
		_refresh_codex()
	# 전투 드랍은 없앴다(2026-08-04). 장비가 나오는 곳은 **소환 하나**다 —
	# 드랍이 알아서 장착까지 해 주면 소환으로 뽑은 장비를 고를 이유가 사라지고,
	# 보관함에서 하는 선택이 전부 무의미해진다.
	if not _defer_stage_advance and kills >= StageDefs.kills_needed(stage):
		_advance_stage()
	_save_game()


# 장비 드랍. 더 센 것만 자동 장착한다 — 방치형에서 인벤토리 정리를 시키면
# "잠깐 보고 끄는" 게임이 "관리해야 하는" 게임이 돼 방치의 뜻이 사라진다.
# 경험치는 넘칠 수 있다(한 번에 여러 레벨). while 로 돌려야 보상이 안 새어 나간다.
# 도감 보상 수령. 발견 수는 한 번에 1씩만 오르므로 같은 칸을 두 번 밟을 수 없다 —
# 그래서 수령 플래그를 저장하지 않는다.
# (이 기능 이전 저장본은 능력치 보정만 소급된다. 보석은 22종을 이미 채운 저장본만
#  못 받는데 아직 그런 저장본이 없어 마이그레이션은 넣지 않았다.)
func _claim_codex_reward() -> void:
	var r := FoeTiers.codex_reward_at(codex_knowledge)
	if r.is_empty():
		return
	gem += float(r.get("gem", 0.0))
	_offline_banner.text = "지식 합 %d · %s +%d%%" % [codex_knowledge,
		FoeTiers.codex_stat_name(str(r["stat"])), int(float(r["rate"]) * 100.0)]
	_offline_banner.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	_offline_banner.visible = true
	_offline_t = 3.0


func _gain_exp(amount: float) -> void:
	hero_exp += amount
	while hero_exp >= Balance.exp_need(hero_lv):
		hero_exp -= Balance.exp_need(hero_lv)
		hero_lv += 1


func _advance_stage() -> void:
	if _fade_t > 0.0:
		return
	_clear_foes()
	_phase = "advance"
	# 배경과 몹이 **암전 뒤에서** 바뀐다. 그냥 갈아 끼우면 화면이 휙 튄다.
	_fade(func() -> void:
		kills = 0
		var next_stage := mini(stage + 1, StageDefs.total_stages())
		if next_stage > best_stage:
			if StageDefs.is_boss_stage(stage):
				gem += GachaDefs.COST
			best_stage = next_stage
		stage = next_stage
		_boss_time = StageDefs.time_limit(stage)
		_start_advance()
		_apply_stage_bg())


# 제한 시간은 **모든 구간**에 돈다. 시간을 넘기면 그 구간을 처음부터 다시 한다.
# 전환 중(_fade_t > 0)에는 세지 않는다 — 화면이 검은데 시계가 도는 건 손해다.
func _tick_boss_timer(delta: float) -> bool:
	if _fade_t > 0.0 or _hero_dead:
		return false
	_boss_time -= delta
	if _boss_time > 0.0:
		return false
	_restart_stage("시간 초과")
	return true


# 구간을 처음부터. 죽었을 때와 시간을 넘겼을 때 **같은 길**을 지난다 —
# 둘 다 "이 구간을 못 넘었다"라서 결과가 달라야 할 이유가 없다.
func _restart_stage(reason: String) -> void:
	if _fade_t > 0.0:
		return
	_clear_foes()
	_skill_action = ""
	_skill_target = null
	_phase = "advance"
	_fade(func() -> void:
		kills = 0
		_boss_time = StageDefs.time_limit(stage)
		hero_hp = max_hp()
		_hero_dead = false
		_revive_t = 0.0
		_revive_hero()
		_start_advance())
	_offline_banner.text = "%s — %s 다시" % [reason, StageDefs.label(stage)]
	_offline_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_offline_banner.visible = true
	_offline_t = 2.2


func _clear_foes() -> void:
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f):
			f.remove_from_group("foes")
			f.queue_free()


# 전투 띠만 덮는 암전. 화면 전체를 덮으면 20킬마다 UI 까지 깜빡여서 성가시다.
# 바뀌는 건 전투 띠뿐이라 거기만 가린다.
const FADE_OUT := 0.28
const FADE_HOLD := 0.14
const FADE_IN := 0.4


func _fade(action: Callable) -> void:
	_fade_t = FADE_OUT + FADE_HOLD + FADE_IN
	_fade_rect.visible = true
	_fade_rect.color.a = 0.0
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_callback(action)
	t.tween_interval(FADE_HOLD)
	t.tween_property(_fade_rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: _fade_rect.visible = false)


func _apply_stage_bg() -> void:
	var act: Dictionary = StageDefs.act_data(stage)
	var t := Assets.tex(str(act["bg"]))
	_bg.texture = t
	_bg2.texture = t
	_bg2.visible = t != null
	# 배경 아래끝을 띠 아래끝에 맞춘다. 위로 넘치는 만큼은 상단 패널이 가린다.
	var bg_top := VIEW_BOTTOM - float(Grid.BG_SRC.y) * 2.0
	_bg.position.y = bg_top
	_bg2.position.y = bg_top
	ground_y = bg_top + float(act.get("ground", 141)) * 2.0
	_hero.position.y = ground_y - float(Grid.SPRITE)
	for f in get_tree().get_nodes_in_group("foes"):
		f.position.y = ground_y
	# 위아래로 1~2px 틈이 생길 수 있어 화면 바탕을 막 색으로 깔아 둔다.
	RenderingServer.set_default_clear_color(BACKDROP[StageDefs.act_of(stage) % BACKDROP.size()])
	_bg.visible = t != null


# style: "burst" 터졌다 사라짐 · "hold" 떠올랐다 머물다 걷힘 · "" 곡선 없음
#
# **프레임만 넘기면 "떴다 없어졌다"로 보인다.** PixelLab 이 만든 8프레임은 서로
# 비슷한 변주라 그 안에 커졌다 작아지는 흐름이 없다. 크기·투명도 곡선을 코드로
# 씌우면 자산을 다시 뽑지 않고 20종 전부가 한 번에 살아난다.
# 때리는 이펙트는 **살짝 기울인다.** 수평·수직으로 딱 서 있으면 도장을 찍은 것처럼
# 보이고, 비스듬하면 휘두른 궤적으로 읽힌다(피의 송곳니·핏빛 창이 그림부터 대각선이다).
#
# **회전(rotation)이 아니라 전단(skew)이다.** 회전은 그림을 통째로 돌려서 그냥 비뚤어진
# 그림이 되고, 전단은 위아래를 서로 어긋나게 밀어 **깊이로 누운 것처럼** 보인다.
# 세로를 조금 눌러 주면(원근 단축) 3차원으로 기운 느낌이 더 산다.
#
# **기울이는 건 때리는 것뿐이다.** 떨어지는 비(fall)는 수직이어야 비이고, 바닥 문양
# (hold·rise)과 몸에 두르는 것(pulse·orbit)은 기울면 어긋난 것으로 보인다.
const SKEW_BURST := 20.0    # 격 — 내려치는 각
const SKEW_SWEEP := 15.0    # 파 — 쓸고 가는 각
const SQUASH_TILT := 0.88   # 기운 만큼 세로를 눌러 원근을 만든다


# face: +1 오른쪽, -1 왼쪽. **영웅이 보는 쪽으로 나간다.** 좌우 양쪽에서 몹이 나오므로
# 고정해 두면 절반은 등 뒤로 날아간다 — 창이 반대를 겨누고 파가 뒤로 쓸린다.
func _anim_fx(name: String, at: Vector2, fps: float, draw_scale: float,
		style := "burst", echo := 0, alpha := 1.0, face := 1, skew_mul := 1.0) -> void:
	# 잔상: 같은 이펙트를 조금 늦게·작게·흐리게 다시 띄운다. 앞의 것이 아직 남아
	# 있는 동안 뒤엣것이 뜨므로 "빠르게 지나갔다"가 된다. 새 자산이 필요 없다.
	for i in echo:
		var delay := 0.045 * float(i + 1)
		var shrink := 1.0 - 0.13 * float(i + 1)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_inside_tree():
				_anim_fx(name, at, fps, draw_scale * shrink, style, 0,
					alpha * (0.55 - 0.1 * float(i)), face, skew_mul))
	# 정지 아이콘이 아니라 보유한 프레임 전체를 재생한다. 기본공격과 사망 모두
	# 같은 작은 도우미를 써서 프레임 수가 달라도 마지막에 정확히 정리된다.
	var textures := Assets.frames("res://assets/anim/%s" % name)
	if textures.is_empty():
		return
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("play")
	sprite_frames.set_animation_loop("play", false)
	sprite_frames.set_animation_speed("play", fps)
	for texture in textures:
		sprite_frames.add_frame("play", texture)
	var fx := AnimatedSprite2D.new()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite_frames = sprite_frames
	fx.position = at
	# **좌우 반전은 scale.x 부호 하나로 끝낸다.** 아래 스타일들이 전부 `full` 에서
	# 크기를 뽑으므로, 여기서 부호를 넣어 두면 모든 연출이 저절로 따라 뒤집힌다.
	fx.scale = Vector2(draw_scale * float(signi(face)), draw_scale)
	fx.modulate.a = alpha
	# 잔상은 본체 뒤에 깔린다. 위에 오면 본체가 흐려 보인다.
	#
	# **몸에 두르는 것(pulse·orbit)은 영웅 뒤에 깔린다.** 앞에 오면 방패·성배·심장처럼
	# 꽉 찬 그림이 영웅을 통째로 가려서 "버프가 걸렸다"가 아니라 "캐릭터가 사라졌다"로
	# 보인다. 뒤에 두면 영웅이 그 앞에 선 것이 되어 후광으로 읽힌다. (영웅은 z=3)
	var wraps_hero := style == "pulse" or style == "orbit"
	if wraps_hero:
		fx.z_index = 2 if alpha >= 1.0 else 1
	else:
		fx.z_index = 5 if alpha >= 1.0 else 4
	add_child(fx)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("play")
	if style.is_empty() or not fx.is_inside_tree():
		return
	var life := float(textures.size()) / maxf(1.0, fps)
	var full := Vector2(draw_scale * float(signi(face)), draw_scale)
	# 사라지는 꼬리는 어느 방식이든 공통이다. 마지막 프레임에서 뚝 끊기면
	# "끝났다"가 아니라 "버그"로 보인다.
	var fade := fx.create_tween()
	fade.tween_interval(life * 0.6)
	fade.tween_property(fx, "modulate:a", 0.0, life * 0.4)
	var keep_a := alpha
	var t := fx.create_tween()
	match style:
		"burst":
			# 아주 작게 시작해 **크게 넘겼다가** 제자리로. 넘기는 폭이 작으면
			# 곡선이 있어도 그냥 뜬 것처럼 보인다 — 과할 만큼 키워야 타격으로 읽힌다.
			fx.skew = deg_to_rad(SKEW_BURST * skew_mul * float(signi(face)))
			full.y *= lerpf(1.0, SQUASH_TILT, clampf(skew_mul, 0.0, 1.0))
			fx.scale = full * 0.30
			t.tween_property(fx, "scale", full * 1.55, life * 0.20) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(fx, "scale", full, life * 0.22) \
				.set_trans(Tween.TRANS_QUAD)
		"sweep":
			# 앞으로 날아가며 늘어난다. 제자리에서 터지면 "쓸었다"가 안 읽힌다.
			# **나아가는 쪽도 영웅이 보는 쪽이다.** 예전엔 +190 고정이라 왼쪽을 볼 때
			# 등 뒤로 쓸고 갔다.
			var dir := float(signi(face))
			fx.skew = deg_to_rad(SKEW_SWEEP * skew_mul * dir)
			full.y *= lerpf(1.0, SQUASH_TILT, clampf(skew_mul, 0.0, 1.0))
			fx.scale = Vector2(full.x * 0.45, full.y * 0.85)
			fx.position.x -= 66.0 * dir
			t.tween_property(fx, "position:x", fx.position.x + 190.0 * dir, life * 0.7) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(fx, "scale",
				Vector2(full.x * 1.6, full.y * 1.15), life * 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"hold":
			# **바닥에서 열린다.** 지면에 눌린 한 줄에서 시작해 타원으로 벌어진다 —
			# 처음부터 세로가 반쯤 서 있으면 "바닥이 갈라졌다"가 아니라 "그림이 떴다"로
			# 보인다. 그래서 y 를 거의 0에서 시작한다.
			#
			# **안 돌린다.** 예전엔 55° 회전을 걸었는데, 얼굴(비명의 흔적)과
			# 눈(감시의 눈)이 기울어 보였다. 바닥 문양은 정면으로 읽혀야 한다.
			fx.scale = Vector2(full.x * 0.45, full.y * 0.10)
			fx.modulate.a = 0.0
			t.tween_property(fx, "scale", full * 1.12, life * 0.38) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(fx, "modulate:a", keep_a, life * 0.22)
			t.tween_property(fx, "scale", full, life * 0.3)
		"orbit":
			# 가호는 감싸는 것이라 돈다. 한 바퀴로는 느려 보여서 한 바퀴 반.
			fx.scale = full * 0.25
			t.tween_property(fx, "scale", full * 1.35, life * 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(fx, "rotation", TAU * 1.5, life) \
				.set_trans(Tween.TRANS_LINEAR)
			t.tween_property(fx, "scale", full, life * 0.3)
		"rise":
			# **땅에서 밀고 올라온다**(제단·왕좌). 원점이 가운데라 그냥 키우면 아래로도
			# 같이 자라서 바닥을 뚫고 내려간다 — **커지는 만큼 위치를 올려** 아래끝을
			# 지면에 붙여 둔다. 그래야 "솟았다"로 읽힌다.
			var half := 32.0 * absf(draw_scale)      # 64px 스프라이트의 절반
			fx.position.y += half * 0.8
			fx.scale = Vector2(full.x * 0.75, full.y * 0.2)
			t.tween_property(fx, "scale", full, life * 0.42) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(fx, "position:y",
				fx.position.y - half * 0.8 - 16.0, life * 0.42) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"fall":
			# 위에서 내려온다. 비(혈우)처럼 **하늘에서 떨어지는** 것에 쓴다.
			# 시작 위치를 위로 올려 두고 내린다 — 제자리에서 커지면 비가 아니다.
			#
			# 낙하 거리는 **몹 몸통 높이 안**이어야 한다. 86px 로 뒀더니 전투 띠
			# 꼭대기(나무 높이)에서 시작해 몹과 무관한 데서 떨어지는 것으로 보였다.
			const FALL_DROP := 54.0
			fx.position.y -= FALL_DROP
			fx.scale = Vector2(full.x * 0.9, full.y * 0.6)
			t.tween_property(fx, "position:y", fx.position.y + FALL_DROP, life * 0.75) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(fx, "scale", full, life * 0.4) \
				.set_trans(Tween.TRANS_QUAD)
		"pulse":
			# 제자리에서 커졌다 작아진다. **안 돌린다** — 방패·성배·심장처럼
			# 서 있는 물건은 돌리면 뒤집혀서 무엇인지 안 읽힌다.
			fx.scale = full * 0.55
			t.tween_property(fx, "scale", full * 1.18, life * 0.32) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(fx, "scale", full * 0.98, life * 0.34) \
				.set_trans(Tween.TRANS_SINE)
			t.tween_property(fx, "scale", full, life * 0.3) \
				.set_trans(Tween.TRANS_SINE)


# 전투력이 오른 순간을 띄운다. 스탯 훈련·장비 장착·강화·레벨업이 전부 이 한 곳을
# 지나므로 여기 하나만 두면 된다 — 구매 함수마다 알림을 붙이면 성장 수단이 늘 때
# 반드시 하나를 빠뜨린다.
var _last_power := -1.0
var _power_gain := 0.0
var _power_toast_t := 0.0
const POWER_TOAST_TIME := 1.8


# 문구 만들기는 순수 함수로 뺀다 — 화면 없이 검사할 수 있다.
# 불러오기 직후 첫 계산(before < 0)은 "0 -> 전부"라 알릴 게 아니다.
static func power_toast(now: float, gain: float) -> String:
	if gain <= 0.0:
		return ""
	return "전투력 %s  ▲%s" % [_n(now), _n(gain)]


# **전투력이 오르면 무조건 뜬다.** 예전엔 오프라인·장비 알림과 같은 줄을 써서
# 그쪽이 떠 있는 동안 오른 만큼이 통째로 삼켜졌다(그 알림이 3~6초라 대부분 삼켜졌다).
# 지금은 전용 줄을 쓰고, 표시 중에 더 오르면 **더한다** — 연속으로 오를 때
# 숫자가 실시간으로 불어나는 게 보인다.
func _notify_power(now: float) -> void:
	var before := _last_power
	_last_power = now
	if before < 0.0 or now <= before:
		return
	_power_gain += now - before
	_power_toast_t = POWER_TOAST_TIME
	_power_toast.text = power_toast(now, _power_gain)
	_power_toast.visible = true


# 재화 해금 (DESIGN 13-1). 첫 화면에 재화가 3개 있으면 뭐가 중요한지 모른다 —
# 1단계에서 쓸 수 있는 건 피뿐인데 정수 0 · 보석 0 이 나란히 놓여 있으면
# "저건 언제 쓰나"가 계속 걸린다. **한 번이라도 얻으면 그때부터 계속 보인다** —
# 다 쓰고 0이 됐다고 다시 사라지면 그게 더 이상하다.
var _currency_seen := {"essence": false, "gem": false}
var _currency_icons: Array[TextureRect] = []


func _refresh_currency_visibility() -> void:
	if _currency_icons.size() < 3:
		return
	_currency_seen["essence"] = _currency_seen["essence"] or essence > 0.0
	_currency_seen["gem"] = _currency_seen["gem"] or gem > 0.0
	for i in [1, 2]:
		var open: bool = _currency_seen["essence" if i == 1 else "gem"]
		_currency_icons[i].visible = open
		(_lbl_essence if i == 1 else _lbl_gem).visible = open


# 진행 문구. 폰트 칸 폭 검사(GearTest)가 실제 문자열을 재려고 부르므로 static 이다.
static func stage_progress_text(at_stage: int, done: int, need: int) -> String:
	if StageDefs.is_boss_stage(at_stage):
		return "보스"
	if StageDefs.is_midboss_stage(at_stage):
		return "중간보스"
	return "처치 %d / %d" % [done, need]


func _refresh_hud() -> void:
	var act: Dictionary = StageDefs.act_data(stage)
	_lbl_stage.text = "%s  %s" % [act["name"], StageDefs.label(stage)]
	var need := StageDefs.kills_needed(stage)
	_lbl_prog.text = "%s · %d초" % [stage_progress_text(stage, kills, need),
		int(ceil(maxf(0.0, _boss_time)))]
	# 남은 시간이 얼마 없으면 붉게. 숫자를 안 보고 있어도 색이 먼저 눈에 들어온다.
	_lbl_prog.add_theme_color_override("font_color",
		Color(1.0, 0.45, 0.42) if _boss_time <= 5.0 else Color(0.8, 0.85, 0.95))
	if _stage_bar:
		_stage_bar.value = clampf(float(kills) / maxf(1.0, float(need)), 0.0, 1.0)
	_lbl_hero.text = "레벨 %d" % hero_lv
	_lbl_gold.text = "혈액 %s" % _n(gold)
	_lbl_essence.text = "정수 %s" % _n(essence)
	_lbl_gem.text = "보석 %s" % _n(gem)
	_refresh_currency_visibility()
	var power := Balance.combat_power(dps(), max_hp(), regen_per_sec())
	_lbl_power.text = "전투력 %s · 초당 %s" % [_n(power), _n(dps())]
	_notify_power(power)
	if _hero_dead:
		_lbl_life.text = "부활 %.1f초" % maxf(0.0, _revive_t)
		_lbl_life.add_theme_color_override("font_color", Color(0.95, 0.48, 0.48))
	else:
		_lbl_life.text = "HP %s / %s" % [_n(hero_hp), _n(max_hp())]
		_lbl_life.add_theme_color_override("font_color", Color(0.72, 0.95, 0.78))
	if _tab == "gear":
		_refresh_gear_slots()
	elif _tab == "growth":
		# 스킬 화면은 매 프레임 다시 그리지 않는다 — 카드를 통째로 다시 만드는 일이라
		# 값이 바뀔 때만(장착·레벨업·소환) 부른다. 쿨다운만 따로 돌린다.
		if _growth_mode == "stat":
			_refresh_growth()
		else:
			_tick_skill_slots()
	elif _tab == "summon":
		_refresh_gacha()


# ── 저장 / 오프라인 보상 ───────────────────────────────────────────────────
func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "stage", stage)
	cfg.set_value("run", "kills", kills)
	cfg.set_value("run", "gold", gold)
	cfg.set_value("wallet", "essence", essence)
	cfg.set_value("wallet", "gem", gem)
	cfg.set_value("wallet", "mileage", mileage)
	cfg.set_value("wallet", "seen", _currency_seen)
	cfg.set_value("run", "best_stage", best_stage)
	cfg.set_value("run", "hero_lv", hero_lv)
	cfg.set_value("run", "hero_exp", hero_exp)
	cfg.set_value("run", "hero_hp", hero_hp)
	cfg.set_value("up", "lv", lv)
	cfg.set_value("gear", "equipped", equipped)
	cfg.set_value("gear", "inventory", gear_inventory)
	cfg.set_value("gacha", "pity", gacha_pity)
	cfg.set_value("gacha", "pulls", gacha_pulls)
	cfg.set_value("gacha", "owned", gacha_owned)
	cfg.set_value("gacha", "shards", gacha_shards)
	cfg.set_value("gacha", "free_date", free_pull_date)
	cfg.set_value("skill", "owned", skill_owned)
	cfg.set_value("skill", "equipped", skill_equipped)
	cfg.set_value("skill", "auto", skill_auto_equip)
	cfg.set_value("codex", "kills", codex)
	cfg.set_value("meta", "left_at", Time.get_unix_time_from_system())
	cfg.save(SAVE_PATH)


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stage = clampi(int(cfg.get_value("run", "stage", 1)), 1, StageDefs.total_stages())
	kills = int(cfg.get_value("run", "kills", 0))
	gold = float(cfg.get_value("run", "gold", 0.0))
	essence = maxf(0.0, float(cfg.get_value("wallet", "essence", 0.0)))
	gem = maxf(0.0, float(cfg.get_value("wallet", "gem", 0.0)))
	mileage = maxi(0, int(cfg.get_value("wallet", "mileage", 0)))
	# 키가 없는 옛 저장본은 잔액으로 되살린다 — 이미 쓰던 재화가 갑자기 사라지면 안 된다.
	var seen: Dictionary = cfg.get_value("wallet", "seen", {})
	_currency_seen["essence"] = bool(seen.get("essence", essence > 0.0))
	_currency_seen["gem"] = bool(seen.get("gem", gem > 0.0))
	best_stage = clampi(int(cfg.get_value("run", "best_stage", stage)), stage,
		StageDefs.total_stages())
	hero_lv = int(cfg.get_value("run", "hero_lv", 1))
	hero_exp = float(cfg.get_value("run", "hero_exp", 0.0))
	lv = cfg.get_value("up", "lv", {})
	equipped = cfg.get_value("gear", "equipped", {})
	gear_inventory = cfg.get_value("gear", "inventory", {})
	if gear_inventory.is_empty():
		for equipped_item in equipped.values():
			var old_item: Dictionary = equipped_item
			if not old_item.is_empty() and old_item.has("icon"):
				var inventory_item := old_item.duplicate(true)
				inventory_item["copies"] = 1
				inventory_item.erase("inventory_key")
				gear_inventory[str(inventory_item["icon"])] = inventory_item
	var gear_key_map := {}
	var normalized_inventory := {}
	for old_key in gear_inventory.keys():
		var normalized: Dictionary = gear_inventory[old_key].duplicate(true)
		GearDefs.normalize_catalog_item(normalized)
		var new_key := str(normalized["icon"])
		gear_key_map[str(old_key)] = new_key
		if normalized_inventory.has(new_key):
			var existing: Dictionary = normalized_inventory[new_key]
			var copies := int(existing.get("copies", 1)) + int(normalized.get("copies", 1))
			if GearDefs.power(normalized) > GearDefs.power(existing):
				normalized["copies"] = copies
				normalized_inventory[new_key] = normalized
			else:
				existing["copies"] = copies
		else:
			normalized_inventory[new_key] = normalized
	gear_inventory = normalized_inventory
	for slot in equipped.keys():
		var equipped_item: Dictionary = equipped[slot]
		var old_inventory_key := str(equipped_item.get("inventory_key", equipped_item.get("icon", "")))
		GearDefs.normalize_catalog_item(equipped_item)
		equipped_item["inventory_key"] = str(gear_key_map.get(old_inventory_key,
			equipped_item.get("icon", "")))
	gacha_pity = cfg.get_value("gacha", "pity", {})
	gacha_pulls = cfg.get_value("gacha", "pulls", {})
	for kind in ["weapon", "armor", "trinket", "skill"]:
		if not gacha_pity.has(kind):
			gacha_pity[kind] = int(gacha_pity.get("gear", 0)) if kind == "weapon" else 0
		if not gacha_pulls.has(kind):
			gacha_pulls[kind] = int(gacha_pulls.get("gear", 0)) if kind == "weapon" else 0
	gacha_pity.erase("gear")
	gacha_pulls.erase("gear")
	gacha_owned = cfg.get_value("gacha", "owned", {})
	gacha_shards = cfg.get_value("gacha", "shards", {})
	for old_key in gear_key_map:
		var new_key: String = str(gear_key_map[old_key])
		if new_key == old_key:
			continue
		var old_owned_key := "gear:" + str(old_key)
		var new_owned_key := "gear:" + new_key
		if gacha_owned.has(old_owned_key):
			gacha_owned[new_owned_key] = true
			gacha_owned.erase(old_owned_key)
		if gacha_shards.has(old_owned_key):
			gacha_shards[new_owned_key] = int(gacha_shards.get(new_owned_key, 0)) \
				+ int(gacha_shards[old_owned_key])
			gacha_shards.erase(old_owned_key)
	free_pull_date = str(cfg.get_value("gacha", "free_date", ""))
	# 옛 저장본(스킬 6종·역할 3칸)에는 owned 가 없다. 그때는 기본 스킬만 주고
	# 새로 시작한다 — 없어진 키를 억지로 옮기면 표에 없는 스킬이 장착된다.
	skill_owned = cfg.get_value("skill", "owned", {})
	for key in STARTER_SKILLS:
		if not skill_owned.has(key):
			skill_owned[key] = 0
	# **옛 저장본은 equipped 가 사전({역할: 키})이다.** 배열로 그냥 넣으면 터진다.
	# 타입을 확인하고 아니면 버린다 — 어차피 그 시절 스킬 키는 지금 표에 없다.
	var saved_equipped: Variant = cfg.get_value("skill", "equipped", [])
	skill_equipped.assign(saved_equipped if saved_equipped is Array else [])
	# 표에서 사라진 키는 버린다(스킬 표를 고쳤을 때 조용히 깨지는 걸 막는다).
	var valid: Array[String] = []
	for key in skill_equipped:
		if skill_owned.has(str(key)):
			valid.append(str(key))
	skill_equipped = valid
	skill_auto_equip = bool(cfg.get_value("skill", "auto", true))
	if skill_equipped.is_empty():
		_auto_equip_skills()
	codex = cfg.get_value("codex", "kills", {})
	codex_found = 0
	codex_knowledge = 0
	for k in codex:
		if int(codex[k]) > 0:
			codex_found += 1
		codex_knowledge += FoeTiers.codex_level(int(codex[k]))
	hero_hp = clampf(float(cfg.get_value("run", "hero_hp", max_hp())), 0.0, max_hp())
	if hero_hp <= 0.0:
		hero_hp = max_hp()
	_refresh_gear_slots()
	_grant_offline(float(cfg.get_value("meta", "left_at", 0.0)))


# 오프라인 적 무리는 실제 스폰의 무작위 몹 대신 로스터 평균을 쓴다. 같은 저장본과
# 같은 경과 시간이면 언제나 같은 결과가 나와야 하므로 난수는 한 번도 굴리지 않는다.
func _offline_profile(at_stage: int) -> Dictionary:
	var act := StageDefs.act_data(at_stage)
	var boss := StageDefs.is_boss_stage(at_stage)
	var midboss := StageDefs.is_midboss_stage(at_stage)
	var hp_mult := 0.0
	if boss:
		hp_mult = float(FoeTiers.get_tier(str(act["boss"]))["hp_mult"])
	else:
		var roster: Array = act["roster"]
		for key in roster:
			hp_mult += float(FoeTiers.get_tier(str(key))["hp_mult"])
		hp_mult /= maxf(1.0, float(roster.size()))
	# **무리 크기가 곧 동시 타격 수가 아니다.** 몹은 고정 칸에 서고 영웅은 한 칸에
	# 붙어 있으므로, 사거리 안에 드는 건 그중 일부다(계측: 6칸 중 평균 2.8).
	# 무리 크기를 그대로 쓰면 오프라인이 받는 피해를 과대평가해 실시간과 갈린다.
	var count := 1 if boss or midboss else mini(_wave_size(at_stage), FOES_IN_REACH)
	return {
		"hp": FoeTiers.foe_hp(hp_mult, StageDefs.enemy_power(at_stage), boss, midboss),
		"count": count,
		"damage": Balance.foe_damage(StageDefs.enemy_power(at_stage)),
		"interval": Balance.foe_attack_interval(hp_mult),
	}


func _offline_can_clear(at_stage: int, remaining_kills: int) -> bool:
	var p := _offline_profile(at_stage)
	# 무리가 걸어 들어오는 시간은 싸우는 시간이 아니라서 예산에서 먼저 뺀다 —
	# 실시간에서는 그 시간에도 시계가 돌기 때문이다.
	var budget := StageDefs.time_limit(at_stage) - StageDefs.WAVE_WALK_SECONDS
	if budget <= 0.0:
		return false
	# 보스·중간보스는 한 마리라 걸어오는 시간이 예산에서 이미 빠졌다. 일반 구간만
	# 실시간과 같은 처리량 상한(동시 몹 수 / 걷는 시간)을 건다.
	var lanes := 0
	var walk := 0.0
	if not (StageDefs.is_boss_stage(at_stage) or StageDefs.is_midboss_stage(at_stage)):
		lanes = _wave_size(at_stage)
		walk = _lane_walk_seconds(at_stage)
	return Balance.can_clear_stage(max_hp(), regen_per_sec(), dps(), remaining_kills,
		float(p["hp"]), int(p["count"]), float(p["damage"]), float(p["interval"]),
		budget, lanes, walk)


# 껐던 시간만큼 보상을 준다. 먼저 생존 공식으로 밀 수 있는 최고 단계까지 올리고,
# 그 자리에서 남은 시간 동안 피를 모은 것으로 계산한다. 난수 없는 실시간 수치와
# 같은 HP/DPS/공격주기를 쓰므로 껐다 켜도 결과가 뒤집히지 않는다.
func _grant_offline(left_at: float) -> void:
	if left_at <= 0.0:
		return
	var away := Time.get_unix_time_from_system() - left_at
	if away < 60.0:
		return
	away = minf(away, 8.0 * 3600.0)   # 8시간 상한: 그 이상은 접속할 이유가 사라진다
	var climbed := 0
	while stage < StageDefs.total_stages():
		var need := maxi(0, StageDefs.kills_needed(stage) - kills) if climbed == 0 \
			else StageDefs.kills_needed(stage)
		if not _offline_can_clear(stage, need):
			break
		stage += 1
		kills = 0
		climbed += 1
	var profile := _offline_profile(stage)
	var kill_time := maxf(0.2, float(profile["hp"]) / maxf(0.001, dps()))
	# 자리를 비운 동안은 절반 효율. 방치가 접속보다 이득이면 게임을 안 켜게 된다.
	var earned := (away / kill_time) * StageDefs.gold_per_kill(stage) * gold_mult() * 0.5
	gold += earned
	hero_hp = max_hp()
	_offline_banner.text = "관에서 %d분 · 피 +%s%s" % [int(away / 60.0), _n(earned),
		(" · %d단계 전진" % climbed) if climbed > 0 else ""]
	_offline_banner.visible = true
	_offline_t = 6.0
