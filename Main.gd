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
const HERO_X := 150.0         # 영웅은 왼쪽 1/4 지점
const HERO_DRAW_SCALE := 2.0
const IMPACT_FRAME := 3       # 0부터 세므로 7프레임 중 네 번째
const SPAWN_X := 640.0        # 화면 밖 오른쪽에서 등장
const MAX_FOES := 5           # 세로 화면은 가로가 좁아 5마리가 한계
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
var _hero_dead := false
var _revive_t := 0.0
var _hero_flash_t := 0.0
var _death_tween: Tween
const REVIVE_TIME := 3.0
const DEATH_FADE_TIME := 0.55
const BOSS_TIME := 60.0
const SKILL_DUR := 0.70
const SKILLS := [
	{"key": "drain", "name": "흡혈 강타", "effect": "drain", "cooldown": 8.0,
		"motion": "heavy", "target": "melee", "icon": "vfx_dark_slash"},
	{"key": "wave", "name": "피의 파도", "effect": "area", "cooldown": 14.0,
		"motion": "heavy", "target": "area", "icon": "vfx_water_wave"},
	{"key": "summon", "name": "망령 소환", "effect": "buff", "cooldown": 20.0,
		"motion": "cast", "target": "self", "duration": 6.0, "bonus": 0.3,
		"icon": "vfx_dark_portal"},
	{"key": "blood_fang", "name": "밤의 송곳니", "effect": "drain", "cooldown": 8.0,
		"motion": "heavy", "target": "melee", "icon": "vfx_dark_ball"},
	{"key": "grave_storm", "name": "무덤 폭풍", "effect": "area", "cooldown": 14.0,
		"motion": "cast", "target": "area", "icon": "vfx_dark_blackhole"},
	{"key": "night_pact", "name": "밤의 계약", "effect": "buff", "cooldown": 20.0,
		"motion": "cast", "target": "self", "duration": 6.0, "bonus": 0.3,
		"icon": "vfx_dark_shield"},
]
const BASE_SKILL := {"drain": "drain", "area": "wave", "buff": "summon"}
const GACHA_SKILLS := ["blood_fang", "grave_storm", "night_pact"]
var _boss_time := -1.0
var _skill_cd := {"drain": 0.0, "wave": 0.0, "summon": 0.0,
	"blood_fang": 0.0, "grave_storm": 0.0, "night_pact": 0.0}
var skill_quality := {}
var skill_equipped := BASE_SKILL.duplicate()
var _skill_action := ""
var _skill_action_t := 0.0
var _skill_hit_t := 0.0
var _skill_impact_sent := false
var _skill_target: Foe
var _summon_t := 0.0
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
var _gear_slots := {}       # slot -> {frame, icon, label, btn} 표시 노드
var _gear_equipped_view: Control
var _gear_inventory_view: Control
var _gear_inventory_grid: GridContainer
var _gear_mode := "equipped"
var _gear_mode_buttons := {}
var _gear_filter := "all"
var _gear_filter_buttons := {}
var _gear_detail: Control
var _gear_selected_key := ""
var _gear_dismantle_confirm_key := ""
var _panels := {}           # 탭 이름 -> 창 (한 번에 하나만 보인다)
var _tab_btns := {}
var _tab := "growth"
var _codex_cells := {}
var gacha_pity := {"weapon": 0, "armor": 0, "trinket": 0, "skill": 0}
var gacha_pulls := {"weapon": 0, "armor": 0, "trinket": 0, "skill": 0}
var gacha_owned := {}
var gacha_shards := {}
var free_pull_date := ""
var _gacha_kind := "weapon"
var _gacha_labels := {}
var _gacha_buttons := {}
var _gacha_reveal: Control
var buy_step := 1          # 한 번에 올리는 단계 수 (x1 / x10 / x100)
var _stat_rows := {}
var _step_btns: Array[Button] = []
var _stage_bar: ProgressBar
var _offline_banner: Label
var _offline_t := 0.0
var _visual_hitstop_t := 0.0
var _combat_shake: Tween
const HITSTOP_DUR := 0.035


# ── 스탯 ───────────────────────────────────────────────────────────────────
# 곱연산을 피하고 선형으로 둔다. 방치형에서 지수 성장은 곧 "몇 시간 방치"가 되고,
# 그때부터는 게임이 아니라 대기표가 된다.
func stat_lv(key: String) -> int:
	return int(lv.get(key, 1))


func damage() -> float:
	return Balance.hero_damage(stat_lv("damage"), _gear_stat("damage"), hero_lv) \
		* (1.0 + _collection_bonus("damage"))


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
		* Balance.hero_mult(hero_lv) * (1.0 + _collection_bonus("gold"))


func dps() -> float:
	var summon := _skill_data(str(skill_equipped.get("buff", "summon")))
	return Balance.auto_dps(_base_hit_damage(), attack_interval(), SKILL_DUR,
		float(summon["cooldown"]), float(summon["duration"]), float(summon["bonus"]))


func _base_hit_damage() -> float:
	return damage() * Balance.crit_mult(stat_lv("crit"), stat_lv("critdmg"))


func _combat_damage() -> float:
	return _base_hit_damage() * (1.3 if _summon_t > 0.0 else 1.0)


func max_hp() -> float:
	return Balance.hero_max_hp(stat_lv("tough"), _gear_stat("tough")) \
		* (1.0 + _collection_bonus("tough"))


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
	_start_advance()
	_refresh_gear_slots()
	_refresh_hud()
	for arg in args:
		# [개발 도구] --tab=gear 처럼 특정 창을 띄운 채로 캡처하려고 둔다.
		if arg.begins_with("--tab="):
			_select_tab(arg.trim_prefix("--tab="))
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
	_select_tab("growth")


# ── 영웅 모션 ──────────────────────────────────────────────────────────────
# idle / walk / attack / hurt 네 벌. 스킨을 갈아도 프레임 수와 타이밍이 같으므로
# 여기 말고 고칠 곳이 없다.
const MOTION_FPS := {"idle": 6.0, "walk": 10.0, "hurt": 14.0}
const LOOPING := ["idle", "walk"]   # 나머지는 한 번 재생하고 idle 로 돌아간다


func _play(motion: String, hold := 0.0) -> void:
	# 루프 모션은 이미 재생 중이면 그대로 둔다. 공격·피격은 매번 처음부터 다시 튼다 —
	# 안 그러면 두 번째 공격부터 모션이 안 보인다.
	if motion == _motion and motion in LOOPING:
		return
	_motion = motion
	_motion_hold = hold
	_hero_anim = 0.0
	_hero_frames = Assets.frames("res://assets/anim/%s_%s" % [skin, motion])
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


# 큰 수는 줄여 쓴다. 방치형은 재화가 금방 억을 넘는데 그대로 찍으면 패널을 넘는다.
# K/M/B 가 아니라 만/억/조인 이유: 이 폰트가 블랙레터라 라틴 대문자가 딴 글자로 읽힌다.
# (18.8K 가 "18.8Ж" 처럼 보였다.) 한글 단위는 폰트도 안정적이고 읽기도 낫다.
func _n(v: float) -> String:
	if v < 10000.0:
		return str(int(v))
	var units := ["만", "억", "조", "경"]
	var i := -1
	while v >= 10000.0 and i < units.size() - 1:
		v /= 10000.0
		i += 1
	return ("%.1f" % v).trim_suffix(".0") + units[i]


# 발밑 접지 그림자. 이게 없으면 몹이 바닥에 선 게 아니라 떠 있는 것처럼 보인다.
# Main 은 z=0 이라 배경(-20) 위, 몹(1~2)·영웅(3) 아래에 깔린다.
func _draw() -> void:
	_shadow(Vector2(HERO_X, ground_y), 22.0)
	# 영웅 머리 위의 작은 체력 바. 상단 숫자를 읽지 않아도 위험 상태가 보인다.
	var hp_at := Vector2(HERO_X - 32.0, ground_y - 112.0)
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
	for i in currencies.size():
		var x := 34.0 + float(i) * 176.0
		_hud_root.add_child(Ui.icon(currencies[i][0], Vector2(x, 143.0), 24.0))
		var label := _mk_label(Vector2(x + 32.0, 140.0), Type.SIZE_SMALL, currencies[i][1])
		label.size = Vector2(132.0, 30.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		labels.append(label)
	_lbl_gold = labels[0]
	_lbl_essence = labels[1]
	_lbl_gem = labels[2]


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
	var gap := 16.0
	var step_w := (CONTENT_W - gap * float(BUY_STEPS.size() - 1)) / float(BUY_STEPS.size())
	for i in BUY_STEPS.size():
		var n: int = BUY_STEPS[i]
		var b := Ui.button("x%d" % n, Vector2(PAD + i * (step_w + gap), PAD),
			Vector2(step_w, STEP_H))
		# 선택 표시는 toggle 로 한다. disabled 로 하면 글자가 흐려져 "선택됨"이 아니라
		# "못 누름"으로 읽힌다.
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _set_step(n))
		root.add_child(b)
		_step_btns.append(b)

	# 목록 영역: 배수탭 아래 ~ 요약 줄 위
	var list_y := PAD + STEP_H + 16.0
	var list_h := CONTENT_BOTTOM - list_y
	var sc := Ui.scroll(Vector2(PAD, list_y), Vector2(CONTENT_W, list_h))
	root.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	sc.add_child(col)

	for s in StatDefs.STATS:
		col.add_child(_stat_row(str(s["key"]), str(s["name"]), str(s["icon"])))

	_set_step(buy_step)   # 처음 열었을 때도 선택된 배수가 보이게


# 한 행은 ROW_H 높이의 띠다. 그 안에서 아이콘·글자·버튼이 전부 세로 중앙에 온다.
func _stat_row(key: String, disp: String, icon: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(CONTENT_W - Ui.SCROLL_W, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CONTENT_W - Ui.SCROLL_W

	var ic := Ui.icon("res://assets/ui/%s.png" % icon, Vector2(0, (ROW_H - 56.0) * 0.5), 56.0)
	row.add_child(ic)
	var lv_lbl := _panel_label(row, Vector2(64.0, 0.0), Type.SIZE_SMALL,
		Color(0.62, 0.62, 0.68), 120.0, ROW_H * 0.5)
	var nm := _panel_label(row, Vector2(64.0, ROW_H * 0.5), Type.SIZE_BODY,
		Color(0.95, 0.90, 0.88), 150.0, ROW_H * 0.5)
	var eff := _panel_label(row, Vector2(224.0, ROW_H * 0.5), Type.SIZE_SMALL,
		Color(0.98, 0.72, 0.45), 124.0, ROW_H * 0.5)
	var btn_w := 160.0
	var b := Ui.button("", Vector2(w - btn_w, (ROW_H - 48.0) * 0.5),
		Vector2(btn_w, 48.0), Type.SIZE_MID)
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
		row["btn"].text = "훈련  %s" % _n(cost)
		row["btn"].disabled = gold < cost


# 레벨이 아니라 "그래서 뭐가 되는데"를 보여 준다.
func _stat_effect(key: String) -> String:
	match key:
		"damage": return "+%s 피해" % _n(damage())
		"speed": return "%.2f초 간격" % attack_interval()
		"gold": return "x%.2f 흡혈" % gold_mult()
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
		# 152px 칸에 "강화 1.5만"(한글 6자)을 넣으려면 SIZE_MID(16)로는 잘린다.
		# 이 폰트는 한글 글자 폭이 크기보다 넓다 — 칸이 좁으면 크기부터 내린다.
		var b := Ui.button("", Vector2(at.x + SLOT_BOX * 0.5 - 76.0, 186.0),
			Vector2(152.0, 48.0), Type.SIZE_SMALL)
		Ui.cost_icon(b, "res://assets/items/gem.png")
		b.pressed.connect(func() -> void: _enhance(slot))
		_gear_equipped_view.add_child(b)
		_gear_slots[slot] = {"frame": frame, "icon": ic, "label": name_lbl, "btn": b}
	_panel_label(_gear_equipped_view, Vector2(PAD, CONTENT_BOTTOM - 20.0), Type.SIZE_SMALL,
		Color(0.6, 0.6, 0.66), CONTENT_W, 20.0).text = "드랍은 자동 장착. 소환 장비는 보관함에서 선택."
	_gear_inventory_view = Control.new()
	_gear_inventory_view.size = Vector2(PANEL_W, PANEL_H)
	_gear_inventory_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gear_inventory_view)
	var filter_names := ["전체", "커먼", "언커먼", "레어", "에픽", "레전더리", "신화"]
	var filter_keys := ["all", "common", "uncommon", "rare", "epic", "legend", "mythic"]
	for i in filter_keys.size():
		var filter_button := Ui.button(filter_names[i], Vector2(PAD + i * 76.0, 62.0),
			Vector2(70.0, 32.0), Type.SIZE_SMALL)
		filter_button.toggle_mode = true
		var filter_key: String = filter_keys[i]
		filter_button.pressed.connect(func() -> void: _set_gear_filter(filter_key))
		_gear_inventory_view.add_child(filter_button)
		_gear_filter_buttons[filter_key] = filter_button
	var scroll := Ui.scroll(Vector2(PAD, 102.0), Vector2(CONTENT_W, 184.0))
	_gear_inventory_view.add_child(scroll)
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
	_set_gear_filter("all")
	_set_gear_mode("equipped")


func _set_gear_mode(mode: String) -> void:
	_gear_mode = mode
	_gear_equipped_view.visible = mode == "equipped"
	_gear_inventory_view.visible = mode == "inventory"
	for key in _gear_mode_buttons:
		_gear_mode_buttons[key].set_pressed_no_signal(key == mode)
	if mode == "inventory":
		_refresh_gear_inventory()


func _set_gear_filter(filter: String) -> void:
	_gear_filter = filter
	for key in _gear_filter_buttons:
		_gear_filter_buttons[key].set_pressed_no_signal(key == filter)
	_refresh_gear_inventory()


func _refresh_gear_inventory() -> void:
	if not _gear_inventory_grid:
		return
	for child in _gear_inventory_grid.get_children():
		child.queue_free()
	var keys := gear_inventory.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GachaDefs.rarity_index(str(gear_inventory[a].get("rarity", "common"))) \
			< GachaDefs.rarity_index(str(gear_inventory[b].get("rarity", "common"))))
	for key in keys:
		var item: Dictionary = gear_inventory[key]
		if _gear_filter != "all" and str(item.get("rarity", "common")) != _gear_filter:
			continue
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(116.0, 136.0)
		var hit := Button.new()
		hit.flat = true
		hit.position = Vector2.ZERO
		hit.size = cell.custom_minimum_size
		hit.focus_mode = Control.FOCUS_NONE
		hit.pressed.connect(func() -> void: _open_gear_detail(str(key)))
		cell.add_child(hit)
		var rarity := GachaDefs.rarity(str(item.get("rarity", "common")))
		var owned_key := "gear:" + str(key)
		var equipped_now := str(equipped.get(str(item["slot"]), {}).get("inventory_key", "")) == str(key)
		var glow := ColorRect.new()
		glow.position = Vector2(30.0, 36.0)
		glow.size = Vector2(56.0, 54.0)
		glow.color = Color(Color(rarity["col"]), 0.28)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(glow)
		var frame := Ui.image("res://assets/ui/gear_card.png", Vector2(2.0, 0.0),
			Vector2(112.0, 128.0))
		frame.modulate = Color(rarity["col"])
		cell.add_child(frame)
		_add_summon_rarity_fx(cell, rarity, "res://assets/ui/gear_card.png",
			Vector2(2.0, 0.0), Vector2(112.0, 128.0))
		cell.add_child(Ui.icon(GearDefs.icon_path(item), Vector2(30.0, 36.0), 56.0))
		var level := _panel_label(cell, Vector2(8.0, 4.0), Type.SIZE_SMALL,
			Color.WHITE, 100.0, 20.0)
		level.text = "%s레벨 %d" % ["장착  " if equipped_now else "", int(item.get("lv", 0))]
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var detail := _panel_label(cell, Vector2(6.0, 102.0), Type.SIZE_SMALL,
			Color(rarity["col"]), 104.0, 20.0)
		detail.text = "%s · %d" % [rarity["name"], int(gacha_shards.get(owned_key, 0))]
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gear_inventory_grid.add_child(cell)


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
	_gear_dismantle_confirm_key = ""
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
	material.text = "다시 누르면 영구 분해 · 보유 효과도 사라짐" \
		if _gear_dismantle_confirm_key == _gear_selected_key \
		else "장착은 전투 효과 · 보관만 해도 보유 효과 적용"
	if _gear_dismantle_confirm_key == _gear_selected_key:
		material.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	material.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var equipped_now := str(equipped.get(str(item["slot"]), {}).get("inventory_key", "")) \
		== _gear_selected_key
	var equip_button := Ui.button("장착 중" if equipped_now else "장착",
		Vector2(22.0, 264.0), Vector2(100.0, 44.0), Type.SIZE_SMALL)
	equip_button.disabled = equipped_now
	equip_button.pressed.connect(func() -> void: _equip_inventory_item(_gear_selected_key))
	_gear_detail.add_child(equip_button)
	var level_button := Ui.button("레벨업 %s" % _n(level_cost), Vector2(130.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	Ui.cost_icon(level_button, "res://assets/items/gem.png", 16)
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
	var dismantle := Ui.button("확인" if _gear_dismantle_confirm_key == _gear_selected_key \
		else "분해", Vector2(346.0, 264.0), Vector2(100.0, 44.0), Type.SIZE_SMALL)
	dismantle.disabled = equipped_now
	dismantle.pressed.connect(_dismantle_selected)
	_gear_detail.add_child(dismantle)
	var close := Ui.button("닫기", Vector2(454.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void:
		_gear_dismantle_confirm_key = ""
		_gear_detail.visible = false)
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


func _dismantle_selected() -> void:
	var item: Dictionary = gear_inventory.get(_gear_selected_key, {})
	if item.is_empty():
		return
	var slot := str(item["slot"])
	if str(equipped.get(slot, {}).get("inventory_key", "")) == _gear_selected_key:
		return
	if _gear_dismantle_confirm_key != _gear_selected_key:
		_gear_dismantle_confirm_key = _gear_selected_key
		_refresh_gear_detail()
		return
	var old_max := max_hp()
	essence += GearDefs.salvage_value(item)
	gear_inventory.erase(_gear_selected_key)
	gacha_owned.erase("gear:" + _gear_selected_key)
	_apply_hp_growth(old_max)
	_gear_dismantle_confirm_key = ""
	_gear_selected_key = ""
	_gear_detail.visible = false
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_save_game()


func _synthesize_selected() -> void:
	var item: Dictionary = gear_inventory.get(_gear_selected_key, {})
	var old_key := _gear_selected_key
	var owned_key := "gear:" + old_key
	if item.is_empty() or int(gacha_shards.get(owned_key, 0)) < 5:
		return
	var old_max := max_hp()
	var slot := str(item["slot"])
	var was_equipped := str(equipped.get(slot, {}).get("inventory_key", "")) == old_key
	if not GearDefs.promote(item):
		return
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
		_gear_selected_key = new_key
	else:
		gacha_shards[owned_key] = remaining_shards
	if was_equipped:
		var equipped_item := item.duplicate(true)
		equipped_item["inventory_key"] = _gear_selected_key
		equipped[slot] = equipped_item
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gear_detail()
	_save_game()


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
	_gacha_labels["pity"] = _panel_label(root, Vector2(34.0, 112.0), Type.SIZE_MID,
		Color(0.82, 0.80, 0.86), 508.0, 28.0)
	_gacha_labels["pity"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_labels["rates"] = _panel_label(root, Vector2(34.0, 150.0), Type.SIZE_SMALL,
		Color(0.62, 0.82, 0.68), 508.0, 48.0)
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
	_gacha_reveal = Control.new()
	_gacha_reveal.size = Vector2(PANEL_W, PANEL_H)
	_gacha_reveal.visible = false
	root.add_child(_gacha_reveal)
	_refresh_gacha()


func _set_gacha_kind(kind: String) -> void:
	if kind in GearDefs.SLOTS and not GearDefs.lock_reason(
			kind, StageDefs.major_stage(stage)).is_empty():
		return
	_gacha_kind = kind
	_refresh_gacha()


func _grant_test_gems() -> void:
	gem += 3000.0
	_refresh_gacha()
	_save_game()


func _pull_gacha(count: int) -> void:
	var free := count == 1 and free_pull_date != Time.get_date_string_from_system()
	var cost := 0.0 if free else GachaDefs.COST * float(count)
	if gem < cost:
		return
	gem -= cost
	if free:
		free_pull_date = Time.get_date_string_from_system()
	var result := GachaDefs.pull(count, int(gacha_pity.get(_gacha_kind, 0)))
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


func _receive_gacha_skill(rarity_key: String) -> Dictionary:
	var key: String = GACHA_SKILLS[randi() % GACHA_SKILLS.size()]
	var owned_key := "skill:" + key
	if gacha_owned.has(owned_key):
		gacha_shards[owned_key] = int(gacha_shards.get(owned_key, 0)) + 1
	else:
		gacha_owned[owned_key] = true
	var quality := GachaDefs.rarity_index(rarity_key)
	skill_quality[key] = maxi(quality, int(skill_quality.get(key, -1)))
	var skill := _skill_data(key)
	var effect := str(skill["effect"])
	var current_key := str(skill_equipped.get(effect, BASE_SKILL[effect]))
	if quality > int(skill_quality.get(current_key, -1)):
		skill_equipped[effect] = key
	return {"kind": "skill", "key": key, "name": skill["name"], "rarity": rarity_key,
		"icon": "res://assets/skill_icons/%s.png" % str(skill["icon"])}


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
	_gacha_labels["pity"].text = "%s 천장  %d / 100" % [
		GearDefs.SLOT_NAME[_gacha_kind] if _gacha_kind in GearDefs.SLOTS else "스킬",
		int(gacha_pity.get(_gacha_kind, 0))]
	_gacha_labels["rates"].text = "커먼 50% · 언커먼 30% · 레어 14%\n" \
		+ "에픽 5% · 레전더리 0.9% · 신화 0.1%"
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


# 도감. 방치형에서 "언젠가 다 채운다"는 장기 목표는 공짜다 — 처치 수는 이미 세고 있다.
func _build_codex(root: Control) -> void:
	# 창 안쪽 여백을 빼고 남은 폭을 5칸으로 고르게 나눈다. 유닛으로 눈대중하면
	# 마지막 칸이 테두리에 붙는다 — 픽셀로 계산한다.
	var keys := FoeTiers.all_keys()
	var cell_w := CONTENT_W / float(CODEX_COLS)
	# 4줄이 여백 안에 들어가게 나누는다. 눈대중으로 70 을 넣었더니 마지막 줄이 넘쳤다.
	var cell_h := (CONTENT_BOTTOM - PAD) / float(CODEX_ROWS)
	for i in keys.size():
		var key: String = keys[i]
		var cx := PAD + cell_w * (float(i % CODEX_COLS) + 0.5)
		var cy := PAD + cell_h * float(i / CODEX_COLS)
		var ic := Ui.icon(FoeTiers.sprite_of(key),
			Vector2(cx - CODEX_ICON * 0.5, cy + _sprite_drop(key)), CODEX_ICON)
		root.add_child(ic)
		var lbl := _panel_label(root, Vector2(cx - cell_w * 0.5, cy + CODEX_ICON),
			Type.SIZE_SMALL, Color(0.7, 0.7, 0.75), cell_w, 18.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_codex_cells[key] = {"icon": ic, "label": lbl}


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
		cell["label"].text = str(n) if n > 0 else "?"


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
	_save_game()
	_refresh_hud()


# ── 루프 ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	play_time += delta
	_tick_hero_state(delta)
	var visual_frozen := _visual_hitstop_t > 0.0
	_visual_hitstop_t = maxf(0.0, _visual_hitstop_t - delta)
	_tick_motion(0.0 if visual_frozen else delta)
	queue_redraw()   # 그림자는 몹이 움직일 때마다 다시 그려야 한다
	if _offline_t > 0.0:
		_offline_t -= delta
		if _offline_t <= 0.0:
			_offline_banner.visible = false

	var foes := get_tree().get_nodes_in_group("foes")
	if _tick_boss_timer(delta):
		_refresh_hud()
		return
	_tick_advance(delta, foes)
	for f in foes:
		if is_instance_valid(f):
			f.set_visual_frozen(visual_frozen)
			f.set_combat_active(_phase == "fight" and not _hero_dead)
	_tick_skills(delta, foes)
	_tick_hero_attack(delta, foes)
	_refresh_hud()


# 자동 공격은 모션 시작이 아니라 7프레임 중 네 번째에 피해가 들어간다. 예약한 대상이
# 그 전에 사라졌으면 피해도 이펙트도 만들지 않는다.
func _tick_hero_attack(delta: float, foes: Array) -> void:
	if _hero_hit_t >= 0.0:
		_hero_hit_t -= delta
		if _hero_hit_t <= 0.0:
			_hero_hit_t = -1.0
			if _can_hit_foe(_pending_target):
				_pending_target.take_damage(_combat_damage())
				_anim_fx("fx_cleave", _pending_target.position + Vector2(0, -28), 18.0, 2.0)
			_pending_target = null
	if _hero_dead or _phase != "fight" or _skill_action != "":
		return
	_attack_t -= delta
	if _attack_t > 0.0:
		return
	var target: Foe = null
	for f in foes:
		if _can_hit_foe(f) \
				and (target == null or f.position.x < target.position.x):
			target = f
	if target:
		var interval := attack_interval()
		_attack_t = interval
		_hero_hit_t = interval * 3.0 / 7.0
		_pending_target = target
		_play("attack")


# 모션의 실제 임팩트 프레임에서 불투명 픽셀 끝을 읽는다.
func _motion_reach_x(motion: String) -> float:
	return HERO_X + Assets.frame_reach(
		"res://assets/anim/%s_%s" % [skin, motion], IMPACT_FRAME, HERO_DRAW_SCALE, true)


func _front_reach_x() -> float:
	var reach := _motion_reach_x("attack")
	for skill in SKILLS:
		if str(skill["target"]) == "melee":
			reach = minf(reach, _motion_reach_x(str(skill["motion"])))
	return reach


func _foe_arrived(foe: Foe) -> bool:
	return _phase == "fight" and is_instance_valid(foe) and not foe.dying \
		and foe.position.x <= foe.stop_x + 1.0


# 피해 순간에 해당 모션의 실제 픽셀 사거리와 적 외곽을 다시 비교한다.
func _can_hit_foe(foe: Foe, motion: String = "attack") -> bool:
	return _foe_arrived(foe) \
		and foe.position.x - foe._size() * 0.5 <= _motion_reach_x(motion) + 1.0


# 가장 짧은 근접 모션과 적 그림의 왼쪽 외곽이 맞닿는 중심 좌표.
func _foe_stop_x(foe: Foe, line: int) -> float:
	return _front_reach_x() + foe._size() * 0.5 + float(line) * Grid.u(3)


func _compact_foe_line(foes: Array) -> void:
	foes.sort_custom(func(a, b) -> bool: return a.position.x < b.position.x)
	for i in foes.size():
		foes[i].stop_x = _foe_stop_x(foes[i], i)


func _tick_hero_state(delta: float) -> void:
	if _hero_dead:
		_revive_t -= delta
		if _revive_t <= 0.0:
			_revive_hero()
		return
	if _hero_flash_t > 0.0:
		_hero_flash_t -= delta
		if _hero_flash_t <= 0.0:
			_hero.self_modulate = Color.WHITE
	_summon_t = maxf(0.0, _summon_t - delta)
	hero_hp = minf(max_hp(), hero_hp + regen_per_sec() * delta)


# 먼저 적힌 스킬이 우선이다. 별도 스킬 시스템 없이 세 개의 쿨다운만 돈다.
func _next_ready_skill() -> Dictionary:
	for skill in _active_skills():
		if float(_skill_cd[skill["key"]]) <= 0.0:
			return skill
	return {}


func _skill_data(key: String) -> Dictionary:
	for skill in SKILLS:
		if str(skill["key"]) == key:
			var data: Dictionary = skill.duplicate()
			var quality := int(skill_quality.get(key, -1))
			if quality >= 0:
				data["cooldown"] = float(data["cooldown"]) * (0.95 - quality * 0.05)
			return data
	return {}


func _active_skills() -> Array:
	var out := []
	for effect in ["drain", "area", "buff"]:
		out.append(_skill_data(str(skill_equipped.get(effect, BASE_SKILL[effect]))))
	return out


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
	if _hero_dead or _phase != "fight" or _hero_hit_t >= 0.0 or foes.is_empty():
		return
	var skill := _next_ready_skill()
	if skill.is_empty():
		return
	var targeting := str(skill["target"])
	var target: Foe = null
	if targeting != "self":
		for f in foes:
			var in_range := _foe_arrived(f) if targeting == "area" \
				else _can_hit_foe(f, str(skill["motion"]))
			if in_range and (target == null or f.position.x < target.position.x):
				target = f
	if targeting != "self" and target == null:
		return
	_skill_action = str(skill["key"])
	_skill_action_t = SKILL_DUR
	_skill_hit_t = SKILL_DUR * 3.0 / 7.0
	_skill_impact_sent = false
	_skill_cd[_skill_action] = float(skill["cooldown"])
	_skill_target = target
	_play(str(skill["motion"]), SKILL_DUR)


func _resolve_skill(key: String) -> void:
	if _hero_dead or _phase != "fight":
		return
	var skill := _skill_data(key)
	var hit := _combat_damage() * Balance.skill_hit_mult(attack_interval(), SKILL_DUR)
	match str(skill["effect"]):
		"drain":
			if _can_hit_foe(_skill_target, str(skill["motion"])):
				var dealt := minf(_skill_target.hp, hit)
				_skill_target.take_damage(hit)
				gold += dealt * 0.20
				_anim_fx("fx_cleave", _skill_target.position + Vector2(0, -28), 18.0, 2.4)
		"area":
			_defer_stage_advance = true
			for f in get_tree().get_nodes_in_group("foes"):
				if _foe_arrived(f):
					f.take_damage(hit)
			_defer_stage_advance = false
			_anim_fx("fx_explosion", Vector2(_motion_reach_x("attack") + 48.0,
				ground_y - 38.0), 18.0, 2.6)
			if kills >= StageDefs.kills_needed(stage):
				_advance_stage()
		"buff":
			_summon_t = float(skill["duration"])
			_anim_fx("fx_death_soul", Vector2(HERO_X + 32.0, ground_y - 46.0), 16.0, 2.2)


func on_foe_hit(_foe: Foe, _damage: float) -> void:
	_visual_hitstop_t = maxf(_visual_hitstop_t, HITSTOP_DUR)
	if is_inside_tree():
		for f in get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f):
				f.set_visual_frozen(true)
	_shake_combat(2.0)


# Foe가 자기 attack 애니의 네 번째 프레임에 호출한다.
func on_foe_attack(_foe: Foe) -> void:
	if _hero_dead or _phase != "fight":
		return
	var incoming := StageDefs.enemy_power(stage) * 4.0
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
	_anim_fx("fx_death_blood", Vector2(HERO_X, ground_y - 42.0), 18.0, 2.0)
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
		if foes.is_empty():
			_start_advance()
		return

	_play("walk")
	_scroll += SCROLL_SPEED * delta
	_apply_scroll()
	# 선두가 전열에 닿으면 다 같이 멈춰 선다. 시간이 아니라 위치로 판정하는 이유:
	# 시간으로 재면 스폰 위치를 바꿀 때마다 시간도 같이 고쳐야 한다.
	for f in foes:
		if is_instance_valid(f) and f.position.x > f.stop_x + 1.0:
			return
	if not foes.is_empty():
		_phase = "fight"


# 다음 무리를 부르고 그쪽으로 걷기 시작한다. 무리를 미리 내보내야 배경과 같은
# 속도로 밀려 들어와 "다가간다"로 읽힌다 — 다 걷고 나서 부르면 허공에 튀어나온다.
func _start_advance() -> void:
	_phase = "advance"
	_spawn_wave()


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
	if StageDefs.is_boss_stage(stage):
		_boss_time = BOSS_TIME
		_spawn_foe()
		return
	_boss_time = -1.0
	if StageDefs.is_midboss_stage(stage):
		_spawn_foe()
		return
	# 단계가 오를수록 한 무리가 두꺼워진다. 화면 폭 때문에 MAX_FOES 가 상한이다.
	var n := clampi(2 + StageDefs.major_stage(stage) / 8, 2, MAX_FOES)
	for i in n:
		_spawn_foe()


func _spawn_foe() -> void:
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
	var n := get_tree().get_nodes_in_group("foes").size()
	# 같은 프레임에 여러 마리가 나가므로 등장 위치도 벌린다. 안 그러면 겹쳐서 걸어온다.
	f.position = Vector2(SPAWN_X + float(n) * Grid.u(3), ground_y)
	f.stop_x = _foe_stop_x(f, n)
	add_child(f)
	if boss or midboss:
		_announce_elite(f.display_name)


func _announce_elite(name: String) -> void:
	_offline_banner.text = name
	_offline_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	_offline_banner.visible = true
	_offline_t = 1.2
	_shake_combat(4.0)


func _shake_combat(amount: float) -> void:
	if not is_inside_tree():
		return
	if _combat_shake and _combat_shake.is_valid():
		_combat_shake.kill()
	position.x = 0.0
	_combat_shake = create_tween()
	_combat_shake.tween_property(self, "position:x", -amount, 0.03)
	_combat_shake.tween_property(self, "position:x", amount, 0.05)
	_combat_shake.tween_property(self, "position:x", 0.0, 0.03)


func on_foe_killed(f: Foe) -> void:
	_compact_foe_line(get_tree().get_nodes_in_group("foes"))
	gold += f.gold
	if f.is_boss:
		essence += StageDefs.boss_essence(stage)
	kills += 1
	codex[f.key] = int(codex.get(f.key, 0)) + 1
	_gain_exp(Balance.exp_per_kill(StageDefs.major_stage(stage)))
	if _tab == "codex":
		_refresh_codex()
	# 보스는 확정, 잡몹은 낮은 확률. 방치형이라 "가끔 좋은 게 뜬다"가 접속 이유가 된다.
	if f.is_boss or randf() < 0.04:
		_drop_gear(f.is_boss)
	if not _defer_stage_advance and kills >= StageDefs.kills_needed(stage):
		_advance_stage()
	_save_game()


# 장비 드랍. 더 센 것만 자동 장착한다 — 방치형에서 인벤토리 정리를 시키면
# "잠깐 보고 끄는" 게임이 "관리해야 하는" 게임이 돼 방치의 뜻이 사라진다.
# 경험치는 넘칠 수 있다(한 번에 여러 레벨). while 로 돌려야 보상이 안 새어 나간다.
func _gain_exp(amount: float) -> void:
	hero_exp += amount
	while hero_exp >= Balance.exp_need(hero_lv):
		hero_exp -= Balance.exp_need(hero_lv)
		hero_lv += 1


func _drop_gear(boss: bool) -> void:
	var slot: String = GearDefs.SLOTS[randi() % GearDefs.SLOTS.size()]
	var item := GearDefs.roll(slot, StageDefs.major_stage(stage), 2.0 if boss else 0.0)
	if item.is_empty():
		return
	var cur: Dictionary = equipped.get(slot, {})
	if not cur.is_empty() and GearDefs.power(cur) >= GearDefs.power(item):
		essence += GearDefs.salvage_value(item)
		_refresh_gear_slots()
		return
	var old_max := max_hp()
	equipped[slot] = item
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_event_gear(item)


func _event_gear(item: Dictionary) -> void:
	_offline_banner.text = "[%s] %s 장착" % [
		GearDefs.SLOT_NAME[str(item["slot"])], str(item["name"])]
	_offline_banner.add_theme_color_override("font_color", Color(item["col"]))
	_offline_banner.visible = true
	_offline_t = 3.0


func _advance_stage() -> void:
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f):
			f.remove_from_group("foes")
			f.queue_free()
	kills = 0
	var next_stage := mini(stage + 1, StageDefs.total_stages())
	if next_stage > best_stage:
		if StageDefs.is_boss_stage(stage):
			gem += GachaDefs.COST
		best_stage = next_stage
	stage = next_stage
	_start_advance()
	_apply_stage_bg()


func _tick_boss_timer(delta: float) -> bool:
	if not StageDefs.is_boss_stage(stage) or _phase != "fight":
		return false
	_boss_time -= delta
	if _boss_time > 0.0:
		return false
	kills = 0
	_skill_action = ""
	_skill_target = null
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f):
			f.remove_from_group("foes")
			f.queue_free()
	_phase = "advance"
	call_deferred("_start_advance")
	return true


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


func _anim_fx(name: String, at: Vector2, fps: float, draw_scale: float) -> void:
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
	fx.scale = Vector2.ONE * draw_scale
	fx.z_index = 5
	add_child(fx)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("play")


func _refresh_hud() -> void:
	var act: Dictionary = StageDefs.act_data(stage)
	_lbl_stage.text = "%s  %s" % [act["name"], StageDefs.label(stage)]
	var need := StageDefs.kills_needed(stage)
	_lbl_prog.text = ("보스 %.1f초" % maxf(0.0, _boss_time) if StageDefs.is_boss_stage(stage)
		else ("중간보스" if StageDefs.is_midboss_stage(stage)
		else "처치 %d / %d" % [kills, need]))
	if _stage_bar:
		_stage_bar.value = clampf(float(kills) / maxf(1.0, float(need)), 0.0, 1.0)
	_lbl_hero.text = "레벨 %d" % hero_lv
	_lbl_gold.text = "혈액 %s" % _n(gold)
	_lbl_essence.text = "정수 %s" % _n(essence)
	_lbl_gem.text = "보석 %s" % _n(gem)
	_lbl_power.text = "전투력 %s · 초당 %s" % [
		_n(Balance.combat_power(dps(), _gear_stat("tough"))), _n(dps())]
	if _hero_dead:
		_lbl_life.text = "부활 %.1f초" % maxf(0.0, _revive_t)
		_lbl_life.add_theme_color_override("font_color", Color(0.95, 0.48, 0.48))
	else:
		_lbl_life.text = "HP %s / %s" % [_n(hero_hp), _n(max_hp())]
		_lbl_life.add_theme_color_override("font_color", Color(0.72, 0.95, 0.78))
	if _tab == "gear":
		_refresh_gear_slots()
	elif _tab == "growth":
		_refresh_growth()
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
	cfg.set_value("skill", "quality", skill_quality)
	cfg.set_value("skill", "equipped", skill_equipped)
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
	skill_quality = cfg.get_value("skill", "quality", {})
	skill_equipped = cfg.get_value("skill", "equipped", BASE_SKILL.duplicate())
	codex = cfg.get_value("codex", "kills", {})
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
	var count := 1 if boss or midboss else clampi(
		2 + StageDefs.major_stage(at_stage) / 8, 2, MAX_FOES)
	return {
		"hp": 10.0 * hp_mult * StageDefs.enemy_power(at_stage) \
			* (12.0 if boss else (3.5 if midboss else 1.0)),
		"count": count,
		"damage": StageDefs.enemy_power(at_stage) * 4.0,
		"interval": Balance.foe_attack_interval(hp_mult),
	}


func _offline_can_clear(at_stage: int, remaining_kills: int) -> bool:
	var p := _offline_profile(at_stage)
	return Balance.can_clear_stage(max_hp(), regen_per_sec(), dps(), remaining_kills,
		float(p["hp"]), int(p["count"]), float(p["damage"]), float(p["interval"]))


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
