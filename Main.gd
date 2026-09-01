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
# 상단 UI 를 12유닛(192px) -> 8유닛(128px)으로 줄이고 그만큼을 **하단 콘텐츠 창에**
# 줬다. 전투 띠 높이(288px)는 그대로다 — 줄어든 건 전투가 아니라 위쪽 판이다.
# **상단 판을 없앴다**(사장님 레퍼런스). 전투 띠가 배경 원본 높이(320px)에 딱 맞게
# 96 에서 시작하고, 위 96px 는 막 배경색 하늘이다 — 거기에 소형 위젯(재화 알약,
# 막 이름, 진행)이 떠 있다. 판이 없어서 게임 화면이 화면의 절반을 넘는다.
#   0..96    떠 있는 위젯 (막 배경색 위)
#   96..416  전투 띠 (배경 원본 320px 그대로)
#   416..800 콘텐츠 창
#   800..896 탭바
const VIEW_TOP := 96.0
const VIEW_BOTTOM := 416.0
# 발이 닿는 선. 배경마다 바닥 높이가 달라서 상수로 두면 캐릭터가 공중에 뜬다.
# 배경은 항상 전투 띠에 딱 맞게 깔고(y = VIEW_TOP), 대신 이 값을 막마다 옮긴다.
var ground_y := 442.0
# 영웅의 앵커. **화면 가운데가 아니라 40% 자리다**(2026-08-06).
#
# 양방향 스폰이던 동안은 정중앙(288)이어야 했다 — 한쪽에 치우치면 반대쪽으로 갈 때만
# 오래 뛰었다. 방향이 하나가 된 뒤로는 **앞쪽(오른쪽)을 넓게 쓰는 게 맞다**: 다가오는
# 놈들이 보여야 "찾아간다"가 읽힌다. 레퍼런스 영상도 영웅이 화면 42% 자리다(실측).
const HERO_X := 230.0
const HERO_DRAW_SCALE := 2.0
# 타격 지점은 **프레임 번호가 아니라 모션 길이의 비율**이다. 고정 번호로 두면
# 프레임 수를 바꾸는 순간(8프레임 통일 예정) 타격이 그린 자세와 어긋난다.
# Foe.IMPACT_RATIO 와 같은 값을 쓴다 — 영웅과 몹의 타격 규칙이 갈리면 안 된다.
const IMPACT_RATIO := Foe.IMPACT_RATIO   # 원래 기준: 7프레임 중 네 번째
const SPAWN_X := 660.0        # 화면 밖 오른쪽. 몹은 여기(또는 그 뒤)에 서서 기다린다
const MAX_FOES := 6
# 교전 자리. **영웅 앵커에서 몸통 두 개 폭(55)만 떨어뜨린다** — 몹이 여기 서면 이미
# 영웅의 칼끝이라 영웅은 자리를 안 옮긴다.
#
# 120 으로 벌려 뒀었다(영웅이 65px 마주 걸어 나가게). 웨이브 모델에서는 그게 유일한
# 영웅 움직임이라 필요했는데, 찾아가는 모델에서는 **달리는 것이 이미 움직임**이라
# 그 65px 이 남는 동작이 됐다 — 잡을 때 나가고 잡은 뒤 되돌아오는 왕복이 되어
# 사장님이 "왜 몬스터를 잡고 다시 중앙으로 돌아오는지" 묻게 됐다. 붙여 두면 왕복이
# 사라지고 영웅이 화면 40% 자리를 지킨다(레퍼런스와 같은 배치).
#
# 큰 몹(잉크 절반 48)은 몸이 더 넓어 영웅이 23px 물러서 자리를 만든다 — 그건 남는
# 동작이 아니라 필요한 조정이다.
#
# **칸 배열(LANES_RIGHT/LEFT)을 지웠다**(2026-08-06). 몹이 여러 칸에 줄 서서 앞칸으로
# 당겨지던 구조는 "웨이브가 몰려온다"의 장치였다. 지금은 몹이 사냥터에 **서 있고**
# 영웅이 찾아가므로(사장님), 줄 간격은 `FOE_GAP` 으로 스폰 때 정해지고 그 뒤로는
# `_advance_world` 가 통째로 밀 뿐 서로 당기지 않는다. 남는 것은 이 한 자리다.
const FRONT_X := 285.0
# 서 있는 몹끼리의 간격. 이 값이 **한 마리당 영웅이 달리는 거리**이고, 곧 처리량의
# 고정비다(`Balance.APPROACH_SECONDS`). 몸통이 겹치지 않는 하한은 50 남짓(잉크 25 x 2,
# 큰 몹은 96)인데, 그보다 넉넉히 벌려 **달려가는 구간이 눈에 보이게** 한다.
const FOE_GAP := 160.0
# 전진 속도. 영웅은 화면 고정이므로 이 값으로 **세상이 왼쪽으로 흐른다**.
# FOE_GAP / TRAVEL_SPEED = 0.8초가 한 마리당 달리는 시간이다.
const TRAVEL_SPEED := 200.0
# 대시. 520 으로 잡았더니 0.2~0.45초에 붙어서 **순간이동**으로 보였다 —
# 달리기 8프레임을 한 바퀴 돌리려면 최소 0.5초는 이동에 써야 한다.
const DASH_SPEED := 240.0
# 전투 밖(보스 등장 · 앵커 복귀)에서 걷는 속도. 대시로 움직이면 걷기 모션을 재생하며
# 달리는 속도로 미끄러진다. 몹 걷기(55)보다 빠르되 같은 세계로 읽히는 값이다.
const ENTER_SPEED := 90.0
# 넉백. 대시(240)보다 빨라야 밀리는 게 보이고, 감쇠가 빨라야 곧 되돌아온다 —
# 느리게 감쇠하면 몹에서 멀어진 채로 굳어 공격이 끊긴다.
const KNOCK_SPEED := 380.0
const KNOCK_DECAY := 1600.0
# 전진 연출. 영웅은 화면 고정(카메라가 흔들리면 UI가 못 읽힌다)이고 대신 배경이 흐른다.
# 배경은 몹보다 느리게 흘린다(원경 시차). 같은 속도면 도트가 뭉개지고, 반대로
# 너무 느리면 걷는데 배경이 안 움직여 제자리걸음으로 보인다 — 0.5가 그 사이다.
# 틈 메우기용 바탕색 — 각 배경 맨 아랫줄의 최빈색이다(눈으로는 못 맞춘다).
# 배경이 띠를 다 덮게 된 뒤로는 반올림 때문에 1~2px 틈이 생길 때만 보인다.
const BACKDROP := [
	Color(0.447, 0.420, 0.318),   # 깨어난 무덤
	Color(0.196, 0.098, 0.043),   # 화형의 언덕
	Color(0.125, 0.208, 0.282),   # 서리 봉인지
	Color(0.224, 0.200, 0.184),   # 핏빛 성소
	Color(0.153, 0.149, 0.165),   # 빼앗긴 본성
	Color(0.284, 0.318, 0.314),   # 봉인된 심연 (실측 — 배경 맨 윗줄 평균)
	Color(0.323, 0.388, 0.331),   # 달빛 유적 (실측)
	Color(0.337, 0.156, 0.149),   # 혈월 제단 (실측)
	Color(0.168, 0.284, 0.273),   # 잠긴 습지 (실측)
	Color(0.152, 0.120, 0.114),   # 핏빛 왕좌 (실측)
]
# 지면 아래 위젯이 앉는 띠의 높이 = 가장 위에 오는 위젯(가이드, 106+여백 6)이
# 시작하는 자리. 지면이 이보다 아래로 내려간 배경을 쓰면 위젯이 몹 몸통을 덮는다.
# 배경마다 지면 행이 다르니 눈으로는 못 지킨다 — CombatRulesTest 가 막마다 잰다.
const WIDGET_BAND := GOAL_WIDGET_H + 6.0


# 원경 시차. 배경은 영웅이 움직인 거리의 이 비율만큼 흐른다.
#
# **고정 속도 스크롤을 지웠다**(2026-08-06, 사장님: "배경을 고정시키고 캐릭터 움직임에
# 따라 움직이게 하면 되잖아"). 예전엔 `SCROLL_SPEED` 로 초당 45px 씩 흘렸는데, 영웅은
# 중앙 고정이라 **화면에는 제자리 걷기만 남았다**(실측: walk 프레임의 95%가 제자리).
# 게다가 `hero_face` 는 직전 전투의 방향을 들고 있어서, 왼쪽 몹을 마지막에 잡으면
# 왼쪽을 본 채로 배경이 흘러 뒤로 달리는 그림이 됐다("문워크").
#
# 이동량에 묶으면 **둘이 어긋날 수가 없다.** 영웅이 서 있으면 배경도 선다.
# 전투 중에는 안 흘린다(`_tick_dash`) — 결투 중 앞뒤 발놀림까지 따라가면 배경이
# 좌우로 흔들린다. 그건 전진이 아니라 제자리 스텝이다.
const PARALLAX := 0.5

var stage := 1
var kills := 0
var gold := 0.0
# 조합 천장 — "gear:<보관키>" -> 실패 누적. 성공하면 지운다(사장님 2026-08-25).
# 조합 천장 — **등급 하나당 카운터 하나**다(사장님 2026-08-25). 무기·방어구·
# 장신구·스킬이 같은 등급이면 같은 통에 쌓인다: "언커먼 조합 10회째는 확정".
# 아이템별로 두면 종이 수십 개라 천장에 영영 못 닿는다.
# 키는 등급 키("common"·"uncommon"…). 조각 곳간(gacha_shards)은 아이템별 그대로.
var fuse_pity := {}
var gem := 0.0
# 혈정 — 쓰는 곳은 혈맥뿐이다(Main.gd 의 `crystal -=` 는 _buy_trait 한 줄).
# **획득은 미궁뿐이 아니다.** 설계 초안(EXPANSION 6장)은 그렇게 적었지만 실제
# 공급처는 여덟이다: 미궁 첫 돌파·소탕 · 펫 둥지 · 상점(보석 45/회, 하루 2회) ·
# 임무 · 출석 · 패스 · 업적 · 주간 보스 이정표.
# **그중 펫 둥지가 나머지를 다 합친 것의 8~10배다**(중반 기준 3,123/일 대 327/일).
# 즉 "미궁을 올라야 혈맥이 큰다"는 교차 잠금은 실제로는 "펫을 뽑아야 큰다"다.
# 수급을 다시 잴 일이 있으면 이 여덟을 다 세라 — 미궁만 보면 5~100배 과소평가한다.
var crystal := 0.0
# 인장 — 혈맹 전용 재화(PactDefs). 획득은 계약의 제단(재화 던전 3호)뿐이고
# 쓰는 곳은 혈맹 레벨업뿐이다. 혈정과 같은 격리 규칙.
var sigil := 0.0
# 소환권 — 소환 전용(TicketDefs). 장수라 정수다. 보석과 달리 **다른 데 못 쓴다**:
# 임무·도감이 준 소환권은 반드시 소환이 된다.
# 종류별 소환권 (TicketDefs). kind -> 장수. **천장이 종류별로 쌓이므로** 권도
# 나뉜다 — 범용 한 종이면 한 종류에 몰아넣게 되고 나머지 천장이 안 찬다.
var tickets := {}
# 유물 — id -> 레벨(0..5). 조각은 gacha_shards 에 "relic:<id>" 로 같이 쌓는다
# (소환 장비와 같은 그릇이라 새 저장 칸을 안 만든다).
var relics := {}
# 받은 이정표 — 칭호 수집(번호), 승급 단계(번호). 한 번만 준다.
var title_ms_got := {}
var promo_got := {}
var pact_lv := 0
var mileage := 0
# 천장 상자 — mileage 는 평생 누적이고, mile_fill 은 지금 상자의 몫이다.
var mile_fill := 0
var mile_lv := 0
var _mile_pending: Array = []   # 공개 연출을 닫을 때 보여 줄 상자 보상
var _mile_ui: Array = []
# 군주의 기록 (참고작 캐릭터 정보 판) — 플레이 시간은 여기서만 쓴다.
var play_sec := 0.0
var _info_view: Control
var _info_body: Control
var _info_power: Label
var _info_note: Label
var _outfit_view: Control
var _name_view: Control
var _name_edit: LineEdit
var _name_note: Label
var _outfit_cells: Array[Dictionary] = []
var _outfit_note: Label
var best_stage := 1
# ── 핏빛 미궁 (DungeonDefs, EXPANSION 7장) ────────────────────────────────
# 미궁에 있는 동안에도 `stage` 는 본편 위치 그대로다 — 나가면 그 자리로 돌아온다.
# 미궁 "진행 중" 상태는 저장하지 않는다: 다시 켜면 본편에서 시작하고, 남는 것은
# 기록(dungeon_best)뿐이다. 그 기록이 3단계 혈맥의 열쇠가 된다.
var dungeon_on := false
var dungeon_floor := 1
var dungeon_best := 0
# 혈맥(TraitDefs) — 산 노드의 집합 {id: true}. 곱연산 %는 게임 전체에서 여기뿐이다.
var traits := {}


func _trait_mult(kind: String) -> float:
	return TraitDefs.mult(kind, traits)


# 유물 곱배수. **혈맥과 곱연산 예산을 나눠 갖는다**(EXPANSION 8장 갱신) —
# 혈맥은 혈정으로 꾸준히 크고 유물은 뽑기로 띄엄띄엄 커서 성격이 안 겹친다.
func _relic_mult(kind: String) -> float:
	return RelicDefs.mult(kind, relics)


func _trait_add(kind: String) -> float:
	return TraitDefs.add(kind, traits)


# ── 군림(MasteryDefs) 훅 — 기능 해금이 걸리는 자리를 헬퍼로 모은다 ──────────
# 흩어 놓으면 하나를 빠뜨린 자리가 조용히 옛 규칙으로 돈다(래퍼 _c_* 와 같은 이유).
func _equip_cap() -> int:
	return SkillDefs.SLOTS + (1 if MasteryDefs.has("slot", best_stage) else 0)


# 처형 문턱 가산(군림 II). 처형이 있는 스킬에만 얹는다.
func _exec_bonus() -> float:
	return 0.05 if MasteryDefs.has("execute", best_stage) else 0.0


# 소탕 시급 — 기록 x 혈맥(탐욕) x 군림 V. 접속 중·오프라인 둘 다 이걸 쓴다.
func _sweep_per_hour() -> float:
	return DungeonDefs.sweep_per_hour(dungeon_best) * _trait_mult("sweep") 		* _relic_mult("sweep") \
		* (2.0 if MasteryDefs.has("sweep2", best_stage) else 1.0) 		* (1.0 + _boon("sweep"))


# 방치 상한(시간) — 기본 8 + 혈맥 긴 잠 + 군림 IV + 혈세.
# **합산하되 16시간에서 끊는다** (설계서 미결 항목, 추천안). max 로 겹치기를
# 막으면 군림 IV 를 딴 사람에게 혈세의 그 줄이 통째로 거짓말이 된다 — 대신
# 상한을 두어 "하루 두 번 접속"이 무의미해지는 지점을 막는다.
const IDLE_CAP_MAX := 16.0
func _offline_cap_hours() -> float:
	return minf(IDLE_CAP_MAX, 8.0 + _trait_add("hours") + RelicDefs.add("hours", relics) \
		+ (4.0 if MasteryDefs.has("hours", best_stage) else 0.0) \
		+ IapDefs.idle_bonus_hours(iap_subs) + _boon("hours"))


# ── 칭호(TitleDefs) ────────────────────────────────────────────────────────
# 딴 칭호의 집합. 조건은 기록의 순수 함수지만, "새로 땄다" 배너를 위해 저장한다.
var titles_got := {}
# 획득했지만 아직 안 본 칭호. 텍스트 배너 대신 도감 버튼의 알림점이 알린다
# (사장님 2026-08-21: "알림 뜨는 거 없애고 점만 달아줘 — 받을 게 있구나
# 생각이 드니까"). 칭호 소탭을 여는 순간 비운다.
var titles_new := {}
var _title_check_t := 0.0


# 조건이 보는 기록 스냅샷 — TitleDefs.cond_met 이 이것만 본다.
func _title_state() -> Dictionary:
	var kill_sum := 0
	for k in codex:
		kill_sum += int(codex[k])
	return {"stage": best_stage, "floor": dungeon_best, "hero": hero_lv,
		"kills": kill_sum, "species": codex_found, "knowledge": codex_knowledge,
		"skills": skill_owned.size(), "traits": traits.size(),
		"trial": trial_stage, "pets": pets_got.size(), "chest": mile_lv,
		"nights": int(play_sec / 3600.0), "prestige": prestige_count}


# 스탯의 **효과 레벨** = 산 레벨 + 칭호 공짜 레벨. 효과 계산(피해·체력·회복·수입·
# 치명·속도)만 이걸 쓰고, **비용·화면의 레벨 표시는 stat_lv 그대로다** — 공짜
# 레벨이 비용에 붙으면 칭호를 딸수록 다음 강화가 비싸지는 벌이 된다.
# 15분할 경계 — **여기 한 곳에서만 나눈다**(2026-08-20). 구매 레벨은 15배지만
# 효과는 옛 단위(유효 레벨)로 환산해서 Balance 상수를 그대로 쓴다.
# 칭호 공짜 레벨은 옛 단위 그대로라 TitleDefs 106행을 안 건드린다.
func _stat_eff(key: String) -> float:
	return 1.0 + float(stat_lv(key) - 1) / float(Balance.SPLIT) \
		+ float(TitleDefs.bonus(key, titles_got))


# 1초에 한 번 새 칭호를 확인한다. 조건 12종 x 2 비교라 매 프레임도 싸지만,
# 처치 합계 합산(도감 순회)이 있어 굳이 60fps 로 돌 이유가 없다.
func _tick_titles(delta: float) -> void:
	_title_check_t -= delta
	if _title_check_t > 0.0:
		return
	_title_check_t = 1.0
	play_sec += 1.0   # 켜 둔 시간 전부 — 방치형에서는 방치도 플레이다
	var _q1 := Time.get_ticks_usec()
	_oath_tick()
	_perf_mark("틱:계약", _q1)
	var _q2 := Time.get_ticks_usec()
	_refresh_board()
	_perf_mark("틱:보드", _q2)
	# 임무도 이 1초 틱을 탄다 — 자정 넘김과 알림점(처치가 50에 닿는 순간 등)을
	# 여기서 갱신한다. 줄 6개 글자 갱신이라 1초에 한 번은 공짜다.
	var _q3 := Time.get_ticks_usec()
	_refresh_quests()
	_perf_mark("틱:임무", _q3)
	var _q4 := Time.get_ticks_usec()
	_tick_income()
	_perf_mark("틱:수입", _q4)
	# 장착 칭호 — 레벨 배지 아래. 여기서 갱신하면 로드 직후·장착 직후를 다 잡는다.
	if _lbl_worn:
		_lbl_worn.visible = title_worn != ""
		if title_worn != "":
			_lbl_worn.text = str(TitleDefs.title(title_worn).get("name", ""))
	var _q5 := Time.get_ticks_usec()
	var state := _title_state()
	_perf_mark("틱:칭호상태", _q5)
	var _q6 := Time.get_ticks_usec()
	for t in TitleDefs.TITLES:
		var id := str(t["id"])
		if titles_got.has(id) or not TitleDefs.earned(id, state):
			continue
		titles_got[id] = true
		titles_new[id] = true
		_claim_title_milestones()
		_save_game()
	_perf_mark("틱:칭호루프", _q6)
	# 로드 직후의 남은 알림도 이 1초 틱이 다시 켠다 — 갱신 경로가 하나다.
	if _codex_dot:
		_codex_dot.visible = not titles_new.is_empty()
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
var _bg2: Sprite2D
var _attack_t := 0.0
var _hero_hit_t := -1.0
var _pending_target: Foe
# **순차 교전.** 영웅과 서로 때리는 몹은 언제나 이 한 마리다. 나머지는 제 칸에서
# 기다리고(공격 금지), 죽는 동안은 다음을 안 부른다 — 사망 처리가 끝나야 다음이
# 걸어 나온다. 레퍼런스 방치형의 리듬이고, HANDOFF 3장의 잔여 겹침(-8.5, 표적
# 아닌 몹)도 구조적으로 사라진다: 표적 아닌 몹이 영웅 곁에 설 일 자체가 없다.
var _engaged: Foe
# 보스 구간 등장 중. 영웅이 화면 왼쪽 밖에서 앵커까지 걸어 들어오며, 그동안 전투가
# 열리지 않는다(`_tick_advance`). 잡몹 구간은 서서 맞이하므로 늘 false 다.
var _boss_entry := false
var _bg: Sprite2D
var _hero: Sprite2D
var _pet_sprite: Sprite2D
var _pet_anim_t := 0.0
var _hero_frames: Array = []
var _hero_anim := 0.0
# 영웅 외형. 확장은 캐릭터 추가가 아니라 스킨이라, 이 값만 바꾸면 모션 전체가 갈린다.
var skin := "valentino_1"
# 산 스킨들 (id -> true). 기본 의상은 늘 보유다 — 표에 안 적는다.
var skins_owned := {}
# 군주의 이름. **빈 문자열이 기본값이다** — 저장본에 "핏빛 군주"를 박아 두면
# 나중에 기본값을 바꿔도 옛 저장본이 안 따라온다.
var hero_name := ""
const NAME_MAX := 8
const NAME_DEFAULT := "핏빛 군주"
var _motion := ""
var _motion_hold := 0.0   # 이 시간이 남아 있는 동안은 idle 로 안 돌아간다
var hero_hp := 100.0
var hero_x := HERO_X      # 영웅의 현재 x. 대시로 매 프레임 움직인다
var _knock_vx := 0.0      # 맞아서 밀리는 속도. 대시가 곧 되돌린다
var _gap_probe := false   # [개발 도구] --gaps
# [개발 도구] --perf — 프레임 시간을 재서 2초마다 찍는다. 무엇이 느린지는
# 재기 전엔 모른다. 평균만 보면 안 된다 — **랙은 최악 프레임이 만든다**.
var _perf_probe := false
var _perf_t := 0.0
var _perf_ms: Array[float] = []
# 의심 지점별 누적 시간(ms). 어느 함수가 그 프레임을 만들었는지 좁힌다.
var _perf_spent := {}
# 미리 데울 애니 폴더 줄. **한꺼번에 안 데운다** — 막 시작에 몰아 하면
# 끊김이 전투 중에서 막 전환으로 옮겨갈 뿐이다. 매 프레임 한 칸씩 소화한다.
var _warm_queue: Array[String] = []
var _gap_t := 0.0
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
var _fade_full_rect: ColorRect   # 던전 입장·퇴장 전용 — 화면 전체 암전
var _fade_t := 0.0           # 0보다 크면 전환 중 — 타이머·전진·재시작이 다 멈춘다
var _skill_cd := {}          # 스킬 키 -> 남은 쿨다운
var skill_owned := {}        # 스킬 키 -> 레벨 (있으면 보유)
var skill_equipped: Array[String] = []   # 장착 6칸. 순서가 곧 발동 우선순위다
# 프리셋 — 스킬과 장비를 **따로** 담는다(사장님 2026-08-27: "스킬 장비
# 프리셋 각각 따로"). 한 벌로 묶으면 무기만 바꾸고 싶을 때도 스킬이 딸려
# 간다. 스킬은 키 목록, 장비는 slot -> inventory_key 다 — 장비 dict 를
# 통째로 담으면 레벨을 올렸을 때 프리셋만 옛 수치로 굳는다.
const PRESETS := 3
var skill_presets: Array = []
# 화면 쪽 — 저장 모드일 때 번호를 누르면 담고, 아니면 꺼낸다. 버튼을
# 여섯 개(저장 3 + 불러오기 3) 두는 것보다 줄이 반으로 준다.
var _preset_write := {"skill": false, "gear": false}
var _preset_btns := {"skill": [], "gear": []}
var _preset_write_btns := {}
var gear_presets: Array = []
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
var _summon_tint := 0.0    # 버프 도중 영웅을 붉게 물들이는 정도(RULES.tint)
var _summon_cleave := ""   # 버프 도중 평타가 광역이 될 때 쓰는 이펙트(RULES.cleave)
var _defer_stage_advance := false
var _hud: CanvasLayer
var _hud_root: Control   # 테마가 걸린 실제 부모
var _lbl_stage: Label
var _lbl_gold: Label
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
# 장비 도감 — **본 적 있는 종류**(icon -> true). gear_inventory 로는 못 센다:
# 분해하면 사라져서 도감이 거꾸로 줄어든다. 스킬은 skill_owned 가 안 사라지므로
# 따로 안 둔다(LoreDefs).
var gear_seen := {}

# ── 펫 (PetDefs) ───────────────────────────────────────────────────────────
# 물어온 것은 **지갑이 아니라 그릇에 담긴다** — 눌러서 받는 게 보상이다
# (방치 상자와 같은 문법). pet_at 은 마지막 정산 시각(유닉스 초)이다.
var pets_got := {}           # id -> 승급 별(1~MAX_STAR). 뽑기 중복이 올린다
var pet_lv := {}             # id -> 먹이 레벨(1~lv_cap(별))
var pet_gear_got := {}       # 장비 id -> 별
var pet_gear_worn := {}      # 펫 id -> 장비 id (펫당 1슬롯)
var feed := 0.0              # 먹이 — 펫 전용 재화. 야수 우리가 준다
var whet := 0.0              # 연마석 — 장비 레벨업. 제련의 성소가 준다
var pet_bank := {}           # id -> 쌓인 양
var pet_worn := ""           # 지금 데리고 다니는 하나
var pet_at := 0.0
# 원정 — 펫id -> [완료 유닉스 시각, 파 올 조각 키]. 조각 키를 **보낼 때 박아
# 둔다**: 나간 사이에 그 펫이 승급하면 파 올 물건이 바뀌는데, 돌아올 때 다시
# 계산하면 보낼 때 약속한 것과 달라진다.
var pet_trip := {}
var _codex_view: Control
var _codex_gain: Label
var _codex_roots := {}
var _codex_tab_art := {}
var _codex_mode := "foe"
var _lore_cells := {}         # "gear"/"skill" -> [{"ico","dim"}...]
var _act_rows: Array[Dictionary] = []
# 트랙 kind -> 지금까지 깬 단계 수. 가이드는 여기서 "다음 목표"를 계산한다.
# 지금까지 깬 가이드 수 = 지금 도전 중인 가이드의 번호(0부터). 가이드가 한 줄로
# 이어지므로 상태가 이 숫자 하나뿐이다.
var goal_index := 0
var _goal_widget: Button
var _chest_btn: Button
var chest_gold := 0.0      # 방치 보상. 눌러서 받을 때까지 지갑에 안 들어간다
var chest_minutes := 0.0
var _goal_widget_icon: TextureRect
var _goal_widget_name: Label
var _goal_widget_prog: Label
var _goal_widget_gem: Label
var _goal_widget_cta: Label
var _goal_widget_fill: ColorRect
var _goal_widget_bar_label: Label
var _goal_dot: TextureRect
var _goal_bar_width := 0.0
var _last_goal_gem := 0.0
var _gear_slots := {}       # slot -> {frame, icon, label, btn} 표시 노드
var _gear_equipped_view: Control
var _gear_inventory_view: Control
var _gear_hold_lbl: Label      # 보관 중인 장비가 주는 보유 효과 합계
var _gear_inventory_grid: GridContainer
var _gear_mode := "equipped"
var _gear_mode_buttons := {}
var _gear_filter := "weapon"   # 보관함 탭 = 슬롯
var _gear_filter_buttons := {}
var _gear_detail: Control
var _skill_detail: Control      # 스킬 상세보기 (장비 상세창과 같은 틀)
var _skill_selected_key := ""
var _gear_selected_key := ""
var _bulk_view: Control
var _bulk_title: Label
var _bulk_body: Label
var _bulk_run: Button
var _bulk_mode := "salvage"
var _bulk_kind := "gear"        # 무엇을 조합하는가 — "gear" | "skill"
var _bulk_tab := "all"          # 등급 탭 — "all" 이면 전 등급
var _bulk_tabs := {}
var _bulk_preview: Control
var _bulk_hint: Label
var _bulk_pity_lbl: Label
var _bulk_pity_bar: ColorRect
var _bulk_pity_num: Label
var _bulk_grid: GridContainer
var _bulk_selected := {}
var _panels := {}           # 탭 이름 -> 창 (한 번에 하나만 보인다)
var _panel_bg: Control      # 반판 배경 — 전투가 보이는 탭들
var _panel_bg_full: Control # 전면 판 배경 — FULL_TABS 가 쓴다
var _tab_btns := {}
var _nav_root: Control          # 하단 탭 바 전체 — 던전 전투 중엔 걷는다
var _gate_exit_btn: Button      # 던전 전투의 유일한 문(중단)
# 전장 게시판(사장님 승인: 안 C + 스킬 줄) — 홈·던전 하단이 같은 판을 쓴다.
var _board: Control
var _board_cells: Array = []     # 스킬 칸 7: {frame, icon, shade, num}
var _board_pills: Array = []     # 알약 라벨 3
var _board_btn: Button
var _board_prev_cd := {}         # 시전 감지(쿨다운이 0에서 만땅으로 튀는 순간)
var _income_per_min := 0.0
var _tab_dots := {}         # 탭 이름 -> 붉은 알림 점 (도감은 없다)
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
# 종류별 전용 제단 그림(sets/altar_*.png, 80px) — 64px 공용 제단은 세트 액자
# 안에서 작고 결이 안 맞았다(사장님: "아이콘도 그렇고 어색해").
# 자리는 세트마다 액자가 달라서 _refresh_gacha 가 장소에 맞춰 옮긴다.
# 좌표는 담백한 2차 몸판(카드 528x288 고정)의 액자 실측 중심이다.
const GACHA_ART_BOX := 80.0
const GACHA_ART_X := 94.0    # 대장간 철판 액자 창 실측
const GACHA_ART_Y := 363.0
# 레벨별 확률표를 펼쳐 보는 창. 지금 레벨의 확률만 보이면 "올리면 뭐가 좋아지는지"가
# 숫자로 안 잡힌다 — 해금 레벨만 적혀 있고 그 뒤가 안 보인다.
# 0레벨부터 만렙까지 **전부** 보여 준다. 몇 개만 뽑아 보여 주면 그 사이가 어떻게
# 되는지 알 수 없다. 가로가 모자라니 옆으로 굴린다.
const RATE_ROW_H := 30.0
const RATE_NAME_W := 92.0
const RATE_COL_W := 86.0
var _gacha_icon: TextureRect
var _gacha_head_tex: TextureRect   # 대장간/점성소 — 종류를 고르면 장소가 바뀐다
var _gacha_place: Label
var _gacha_line: Label
var _gacha_bubble: TextureRect     # 말풍선 틀 — 세트 알약, 장소 따라 바뀐다
var _gacha_card_tex: TextureRect   # 소환 카드 몸판 — 철판/별판
var _gacha_kind_labels := {}       # 종류 탭이 그림 버튼이라 글자는 따로 얹는다
var _gacha_btn_tex := {}           # 1회·10연 — 그림/아이콘/글자가 셋으로 나뉜다
var _gacha_btn_icon := {}
var _gacha_btn_lbl := {}
var _gacha_table_tex: TextureRect  # 확률표 알약
var _gacha_table_lbl: Label
var _gacha_table_btn: Button
# 확률표 알약의 세로 자리 — 몸판마다 아랫띠 높이가 달라 세트별로 잰 값이다.
const TABLE_Y := {"forge": 498.0, "astro": 506.0}
var _gacha_tk_texs: Array[TextureRect] = []   # 소환권 알약 그림 넷
var _gacha_labels := {}
var _gacha_ticket_labels: Array[Label] = []
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
var _growth_mode_labels := {}   # 그림 탭이라 글자는 따로 얹는다
var _stat_view: Control
var _skill_view: Control
var _skill_slots: Array[Dictionary] = []
var _skill_grid: GridContainer
var _skill_info: Label
var _skill_bulk_btn: Button
var _skill_auto_btn: Button
var _skill_synth_btn: Button
var _step_btns: Array[Button] = []
var _stage_bar: ColorRect
var _stage_bar_width := 0.0
var _stage_icon: TextureRect      # 보스 구간에만 뜨는 마크
var _timer_bar: ColorRect
var _timer_frame: NinePatchRect
var _timer_bar_width := 0.0
var _lbl_time: Label
var _power_toast: Label
var _confirm_view: Control
var _confirm_body: Label
var _confirm_action := Callable()
var _reward_view: Control
var _reward_title: Label
var _reward_row: Control
var _reward_panel: NinePatchRect
var _reward_hint: Label
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
	return Balance.hero_damage(_stat_eff("damage"), _gear_stat("damage"), hero_lv) \
		* (1.0 + _collection_bonus("damage") + FoeTiers.codex_bonus(codex_knowledge,"damage") \
		+ PactDefs.bonus(pact_lv) + _lore_bonus("damage") \
		+ SkinDefs.bonus("attack", skins_owned) \
		+ 0.01 * (_stat_eff("rage") - 1.0)) \
		* _relic_mult("damage")


# 도감 이정표(장비·스킬 수집) + 연대기(막 도달) 가 주는 몫. 합연산 괄호 A 에
# 들어간다 — 화면(_refresh_lore)이 이미 이 숫자를 "받는 중"으로 적고 있었는데
# 전투 계산에는 안 붙어 있었다.
func _lore_bonus(stat: String) -> float:
	var key := "hp" if stat == "tough" else stat
	return LoreDefs.total_bonus(_lore_got("gear"), _lore_got("skill"), key) \
		+ LoreDefs.act_bonus(StageDefs.act_of(best_stage), key)


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
	# 유물 공격속도는 **간격을 줄인다** — 배수를 그냥 곱하면 느려진다. 계약도 같다.
	# 펫 speed 6종도 여기 붙는다(2026-08-20까지 안 읽히고 있었다).
	return Balance.attack_interval(_stat_eff("speed")) / _relic_mult("speed") \
		/ (1.0 + _pet_mult("speed")) \
		/ (1.0 + _oath_val("speed"))


# 장신구 전투력 1점이 치명 피해 배수에 더하는 몫. **작게 잡는다** — 치명은
# 확률과 곱해져 자라는 축이라(확률 100%면 그대로 dps 배수), 옛 혈액 계수
# 0.02 를 그대로 옮기면 후반에 배수가 열 배로 튄다(2026-08-25 환산).
const GEAR_CRITDMG := 0.01

# 사라진 혈액 배수를 메우는 기본 계수(2026-08-25). 옵션에 붙던 배수를
# 전투 축으로 옮기면서 수급이 통째로 빠졌다 — 총량이 비슷하게 남도록
# 기본 곡선을 올린다. 곡선을 손대면 이 값도 다시 재야 한다.
const BLOOD_MAKEUP := 6.0


func gold_mult() -> float:
	# **혈액 획득 배수는 옵션에서 사라졌다**(사장님 2026-08-25:
	# "피획득 흡혈량 증가 같은 건 없애줘"). 칭호·장비·도감·펫·유물·
	# 혈맥·은총·계약에 붙던 몫은 전투 축(공격력·치명)으로 옮겼고,
	# 사라진 수급은 BLOOD_MAKEUP 이 기본 곡선에서 메운다.
	return BLOOD_MAKEUP * Balance.hero_mult(hero_lv)


func dps() -> float:
	# 버프 스킬은 장착돼 있을 때만 계산에 넣는다. 없으면 시전 손실도 지속 이득도 없다.
	# **패시브 가호는 여기 안 넣는다** — 시전이 없으니 `auto_dps` 의 가동률 회계가
	# 안 맞는다. 상시 배수라 밖에서 한 번 곱하는 게 맞고, 실제 피해(_combat_damage)와
	# 같은 식이라 화면 DPS 와 전투 결과가 안 갈린다.
	var ward := _equipped_shape("ward", true)
	var base := Balance.auto_dps(_base_hit_damage() * (1.0 + _codex_act_bonus()),
		attack_interval(), SKILL_DUR,
		float(ward.get("cooldown", 999.0)), float(ward.get("duration", 0.0)),
		float(ward.get("bonus", 0.0)))
	return (base + _skill_dps()) * (1.0 + _passive_ward_bonus())


# 몇 마리에게 닿는가 — DPS 계산용. 화면 안에 실제로 서 있는 수를 셀 수 없으므로
# (계산할 때는 전투 중이 아니다) 광역은 **2마리로 잡는다.** 전투 띠에 보통 2~3이
# 서고(`tests/AoeCheck` 실측 2), 적게 잡아야 잠금이 헐거워지지 않는다.
# ponytail: 막마다 평균 동시 등장 수가 생기면 그 값을 쓴다.
const DPS_AOE_FOES := 2.0


func _skill_targets(key: String) -> float:
	var r := SkillDefs.rule_of(key)
	var bounce := int(r.get("bounce", 0))
	if bounce > 0:
		return float(bounce)
	var cap := int(r.get("max_targets", 0))
	if cap > 0:
		return minf(float(cap), DPS_AOE_FOES)
	return 1.0 if SkillDefs.behavior_of(key) == "strike" else DPS_AOE_FOES


# **장착한 공격 스킬이 얹는 초당 피해.**
#
# 2026-08-11 까지 `dps()` 는 스킬을 아예 안 셌다 — `auto_dps` 주석의 "피해 스킬은
# 기본공격을 대체한다"가 전제였는데, 그건 **스킬 한 방이 평타 한 방과 같다**는 뜻이다.
# 지금은 아니다: 피의 왕좌가 평타의 272% 를 한 명당 넣고, 여럿을 동시에 때린다.
# 그래서 화면의 전투력·오프라인 수입·해금 문턱이 전부 실제보다 낮은 DPS 를 보고
# 있었다(사장님: "공격력을 하나도 안 찍어도 엄청 진행이 많이 됨").
#
# 모델은 **교대**다: 시전하는 동안 평타를 못 치므로, 스킬이 버는 것은
# "제 피해 - 밀려난 평타"다. 그래서 격 커먼(평타의 100%, 1명)은 정확히 0을 더한다 —
# 그게 맞다. 평타와 똑같은 스킬은 DPS 를 안 올린다.
#
#     한 번 시전 = 평타 `mult` 번어치 시간
#     버는 것    = 평타피해 x mult x (위력배수 x 대상수 - 1) / 쿨타임
func _skill_dps() -> float:
	var hit := _base_hit_damage() * (1.0 + _codex_act_bonus())
	var mult := Balance.skill_hit_mult(attack_interval(), SKILL_DUR)
	var out := 0.0
	for key in skill_equipped:
		var k := str(key)
		if SkillDefs.behavior_of(k) == "ward":
			continue      # 버프는 위 auto_dps 가 이미 센다
		if bool(SkillDefs.rule_of(k).get("passive", false)):
			continue      # 패시브는 배수라 밖에서 곱한다
		var lv := int(skill_owned.get(k, 0))
		var power := SkillDefs.power(k, lv) * (1.0 + _skill_combo_bonus(k)) \
			* _trait_mult("skill")
		var cd := maxf(0.001, SkillDefs.cooldown(k, lv))
		var gain := power / SkillDefs.POWER_NORM * _skill_targets(k) - 1.0
		out += hit * mult * maxf(0.0, gain) / cd
	return out


# 장착 중인 것 가운데 그 형태의 첫 스킬. 없으면 빈 사전.
func _equipped_shape(shape: String, active_only := false) -> Dictionary:
	for key in skill_equipped:
		if str(SkillDefs.split(str(key))[0]) != shape:
			continue
		if active_only and bool(SkillDefs.rule_of(str(key)).get("passive", false)):
			continue
		return _skill_data(str(key))
	return {}


func _base_hit_damage() -> float:
	# 혈맥: 공격 배수(살육 I~III)와 치명 피해 가산(사혈)이 여기서 붙는다 —
	# 화면 DPS(dps())와 실제 피해(_combat_damage)가 같은 함수를 지나므로 안 갈린다.
	# 회귀 배율도 여기 붙는다 — 화면 DPS 와 실제 피해가 같은 함수를 지나므로
	# 한 곳만 곱하면 둘이 안 갈린다(혈맥·유물과 같은 자리).
	return damage() * _trait_mult("attack") * _prestige_mult() \
		* TrialDefs.mult(trial_stage) \
		* (1.0 + _pet_mult("damage")) \
		* (1.0 + _oath_val("attack")) \
		* Balance.crit_mult(_stat_eff("crit") + int(_oath_val("crit")),
			_stat_eff("critdmg"),
			_trait_add("critdmg") + RelicDefs.add("critdmg", relics)
			+ _gear_stat("critdmg") * GEAR_CRITDMG
			+ _collection_bonus("critdmg") + _boon("critdmg")
			+ SkinDefs.bonus("critdmg", skins_owned))


# 실제 타격 피해. 대상을 주면 그 몹의 **지식 레벨**만큼 더 아프게 때린다.
# 대상을 안 주면(광역 스킬·표시용) 지금 막의 평균을 쓴다 — 아래 _codex_act_bonus().
func _combat_damage(target: Foe = null) -> float:
	var known := _codex_act_bonus() if target == null \
		else FoeTiers.codex_kill_bonus(int(codex.get(target.key, 0)))
	# 버프 배수는 **시전할 때 잡아 둔 값**을 쓴다. 여기서 1.3 을 다시 적으면
	# SHAPES["ward"]["bonus"] 와 두 군데가 되어 한쪽만 고쳤을 때 화면 DPS(dps())와
	# 실제 피해가 갈린다. 들고 있으면 버프 도중에 장비를 바꿔도 안 사라진다.
	return _base_hit_damage() * (1.0 + _summon_bonus if _summon_t > 0.0 else 1.0) \
		* (1.0 + _passive_ward_bonus()) * (1.0 + known) * _dev_weak


# 패시브 가호(RULES.passive)가 상시로 주는 피해 배수.
#
# 2026-08-10 사장님: "진홍 방패는 패시브로 돌리자 / 붉은 성배도 패시브처리 / 혈월은
# 패시브 처리". 시전을 없애면 **가동률이 곧 100%** 가 되므로, 표에 적힌 `bonus` 를
# 그대로 상시로 주면 같은 스킬이 3배 세진다(가동률 duration/cooldown = 6/20 = 30%).
# 그래서 **효과값을 가동률로 환산**해서 준다 — 세기는 그대로고 시전만 사라진다.
# 세기를 올릴 거면 `bonus` 를 올리는 게 맞지, 여기서 슬쩍 올릴 일이 아니다.
func _passive_ward_bonus() -> float:
	var sum := 0.0
	for key in skill_equipped:
		if not bool(SkillDefs.rule_of(str(key)).get("passive", false)):
			continue
		var d := _skill_data(str(key))
		if d.is_empty():
			continue
		var cd := maxf(0.001, float(d["cooldown"]))
		sum += float(d.get("bonus", 0.0)) * clampf(float(d["duration"]) / cd, 0.0, 1.0)
	return sum


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
	return Balance.hero_max_hp(_stat_eff("tough"), _gear_stat("tough")) \
		* (1.0 + _collection_bonus("tough") + FoeTiers.codex_bonus(codex_knowledge, "tough") \
		+ PactDefs.bonus(pact_lv) + _lore_bonus("tough") \
		+ SkinDefs.bonus("tough", skins_owned) \
		+ 0.01 * (_stat_eff("grit") - 1.0)) \
		* _trait_mult("hp") * _relic_mult("hp") * TrialDefs.mult(trial_stage) \
		* (1.0 + _pet_mult("tough"))


func regen_per_sec() -> float:
	return Balance.hero_regen_per_sec(max_hp(), _stat_eff("regen")) \
		* _trait_mult("regen") * (1.0 + _oath_val("regen")) \
		+ max_hp() * _oath_val("regen_max")


# 최대 체력이 늘 때 늘어난 몫만큼 현재 체력도 채운다. 강해졌는데 즉시 체력 비율이
# 떨어지는 역보상을 막되, 기존에 잃은 체력까지 공짜로 회복하지는 않는다.
func _apply_hp_growth(old_max: float) -> void:
	hero_hp = minf(max_hp(), hero_hp + maxf(0.0, max_hp() - old_max))


func upgrade_cost(key: String, level: int) -> float:
	var s := StatDefs.of(key)
	return Balance.upgrade_cost(level, s.get("base", 10.0), StatDefs.cost_exp(key))


# ── 로딩 화면 ─────────────────────────────────────────────────────────────
# 씬 조립(판 28개)을 프레임에 쪼개는 동안 진행 바를 보여 준다. 전면 어둠이
# 입력도 같이 먹으므로(mouse_filter 기본 STOP) 반쯤 지어진 버튼은 못 누른다.
# 헤드리스(검사)에서는 아예 안 짓는다 — 검사는 "두 프레임이면 _ready 가
# 끝난다"를 전제하는데, 레이어가 없으면 _load_tick 이 await 없이 돌아와
# _ready 가 예전처럼 한 번에 완주한다.
var _load_layer: CanvasLayer = null
var _load_fill: ColorRect = null


func _build_loading() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_load_layer = CanvasLayer.new()
	_load_layer.layer = 100
	add_child(_load_layer)
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_layer.add_child(box)
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.01, 0.03)
	dark.size = Vector2(Grid.BG)
	box.add_child(dark)
	var lbl := Label.new()
	lbl.theme = Type.theme()
	lbl.text = "피를 깨우는 중..."
	lbl.add_theme_color_override("font_color", Color(0.78, 0.62, 0.66))
	lbl.size = Vector2(float(Grid.BG.x), 30.0)
	lbl.position = Vector2(0.0, float(Grid.BG.y) * 0.56)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var frame := ColorRect.new()
	frame.color = Color(0.13, 0.05, 0.08)
	frame.size = Vector2(240.0, 10.0)
	frame.position = Vector2(float(Grid.BG.x) * 0.5 - 120.0,
		float(Grid.BG.y) * 0.56 + 44.0)
	box.add_child(frame)
	_load_fill = ColorRect.new()
	_load_fill.color = Color(0.66, 0.14, 0.18)
	_load_fill.position = frame.position + Vector2(2.0, 2.0)
	_load_fill.size = Vector2(0.0, 6.0)
	box.add_child(_load_fill)


# 진행 바를 p 까지 채우고 한 프레임 쉰다 — 이 쉼이 로딩 화면을 그리게 한다.
func _load_tick(p: float) -> void:
	if _load_layer == null:
		return
	_load_fill.size.x = 236.0 * clampf(p, 0.0, 1.0)
	await get_tree().process_frame


func _load_done() -> void:
	if _load_layer == null:
		return
	_load_fill.size.x = 236.0
	var layer := _load_layer
	var box: Control = layer.get_child(0)
	_load_layer = null          # 치트키 가드도 여기서 풀린다
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 0.0, 0.25).set_delay(0.05)
	tw.tween_callback(layer.queue_free)


func _ready() -> void:
	randomize()
	set_process(false)      # 조립 중 _process 는 아직 없는 노드를 만진다
	_build_loading()
	await _load_tick(0.05)
	var args := OS.get_cmdline_user_args()
	var preview_stage := 0
	for arg in args:
		if arg == "--weak":
			_dev_weak = DEV_WEAK_MULT
		if arg.begins_with("--stage="):
			preview_stage = StageDefs.parse(arg.trim_prefix("--stage="))
	await _build_scene()
	_load_game()
	if preview_stage > 0:
		stage = preview_stage
		kills = 0
		hero_hp = max_hp()
	_apply_stage_bg()
	_boss_time = StageDefs.time_limit(stage)
	# 불러온 자리가 보스 구간이면 켤 때도 왼쪽에서 걸어 들어온다 — 구간 전환과 같은 길.
	_begin_stage_pose()
	_start_advance()
	_refresh_gear_slots()
	# 보관함도 여기서 한 번 새로 그린다. _build_scene() 은 _load_game() **앞**이라
	# 그때 센 칸 수는 항상 0이고, 그 뒤로는 소환·분해 때만 갱신돼서
	# 불러오기 직후에는 탭 숫자와 목록이 빈 저장본 기준으로 남아 있었다.
	_refresh_gear_inventory()
	# 배수 버튼도 같은 이유로 여기서 다시 맞춘다. _build_growth() 는 _load_game()
	# **앞**이라 그때는 buy_step 이 늘 기본값 1 이다 — 저장본에 100 이 들어 있으면
	# 화면은 x1 을 누른 채인데 실제로는 100 씩 올라갔다(사장님 2026-08-27).
	# _set_step 은 빌드 때 한 번과 버튼 누를 때만 돌아서 스스로 못 고친다
	# (_refresh_skills 안의 자동장착 토글은 탭 열 때마다 다시 맞춰져서 무사했다).
	_set_step(buy_step)
	_refresh_goal_widget()
	_refresh_chest()
	_refresh_hud()
	for arg in args:
		# [개발 도구] --tab=gear 처럼 특정 창을 띄운 채로 캡처하려고 둔다.
		if arg.begins_with("--tab="):
			_select_tab(arg.trim_prefix("--tab="))
		# [개발 도구] --name : 이름 변경 판을 연 채로 캡처한다.
		if arg == "--name":
			hero_name = "어둠의공작"
			_show_info()
			_name_edit.text = _hero_name()
			_name_note.text = "%d글자까지" % NAME_MAX
			_name_view.visible = true
		# [개발 도구] --titles : 도감 탭의 칭호 목록을 연 채로 캡처한다.
		# [개발 도구] --codex=gear|skill|act : 도감 소탭을 연 채로 캡처한다.
		if arg.begins_with("--codex="):
			_codex_view.visible = true
			_codex_set_mode(arg.trim_prefix("--codex="))
		if arg == "--titles":
			_codex_view.visible = true
			_codex_set_mode("title")
		# [개발 도구] --petroll[=N] : 펫권을 채우고 N연 공개 연출을 캡처한다.
		if arg.begins_with("--petroll"):
			best_stage = maxi(best_stage, PetDefs.PET_OPEN)
			tickets["pet"] = 99
			_select_tab("pet")
			_pet_set_mode("roll")
			var n := int(arg.trim_prefix("--petroll=")) if "=" in arg else 1
			if n > 1:
				_pet_roll_many(n)
			else:
				_pet_roll()
		# [개발 도구] --dying=N : 몹을 죽는 도중 N(0~1) 지점에 얼려 디졸브를 캡처한다.
		# 사망이 0.62초라 그냥 찍으면 원하는 순간이 안 걸린다.
		# [개발 도구] --shatter : 보스 하나를 그 자리에서 터뜨려 캡처한다.
		if arg == "--shatter":
			_dev_shatter = true
		if arg.begins_with("--dying="):
			_dev_dying = clampf(float(arg.trim_prefix("--dying=")), 0.0, 1.0)
		# [개발 도구] --flash : 화면의 몹을 전부 피격 상태로 고정해 번쩍임을 캡처한다.
		# 번쩍임은 0.1초라 그냥 찍으면 절대 안 잡힌다 — 값을 눈으로 고르려면 고정이 필요하다.
		if arg.begins_with("--flash"):
			_dev_flash = float(arg.trim_prefix("--flash=")) if "=" in arg else -1.0
		# [개발 도구] --trip : 펫 열둘을 쥐여 주고 둘을 내보낸 채로 원정 판을 연다.
		# 원정은 시간이 지나야 그림이 생기므로 하나는 도착시켜 둔다 — 안 그러면
		# 캡처가 늘 "보내기" 한 가지 상태밖에 못 잡는다.
		if arg == "--trip":
			best_stage = maxi(best_stage, PetDefs.TRIP_OPEN)
			tickets["pet"] = 99
			tickets["petgear"] = 99
			for _i in 12:
				_pet_roll(false)
			var ids: Array = pets_got.keys()
			if ids.size() >= 2:
				_trip_send(str(ids[0]))
				_trip_send(str(ids[1]))
				if pet_trip.has(str(ids[0])):
					pet_trip[str(ids[0])][0] = 0.0
				_trip_sel = str(ids[1])
			_select_tab("pet")
			_pet_set_mode("trip")
		# [개발 도구] --petmode=own|gear|feed|trip|roll|rollgear : 펫 소탭 캡처.
		if arg.begins_with("--petmode="):
			_select_tab("pet")
			_pet_set_mode(arg.trim_prefix("--petmode="))
		# [개발 도구] --quest[=day|week|attend|boon] : 그 소탭을 연 채로 캡처한다.
		if arg == "--quest" or arg.begins_with("--quest="):
			_quest_view.visible = true
			_quest_bump("kills", 30)
			quest_wprog = {"kills": 380, "train": 30, "daily": 11, "raid": 2}
			# 출석은 몇 칸 받아 둔 모습이라야 받은 칸/오늘 칸이 같이 보인다.
			attend_got = 11
			attend_date = ""
			_quest_set_mode(arg.trim_prefix("--quest=") if "=" in arg else "day")
		# [개발 도구] --maze : 던전 탭의 미궁 소탭을 연 채로 캡처한다.
		if arg == "--maze":
			_select_tab("raid")
			_raid_set_mode("maze")
		# [개발 도구] --relic : 유물 화면을 연 채로 캡처한다(가진 것·못 가진 것 섞어).
		if arg == "--relic":
			best_stage = maxi(best_stage, RelicDefs.OPEN_STAGE)
			for i in RelicDefs.RELICS.size():
				if i % 3 != 2:
					relics[str(RelicDefs.RELICS[i]["id"])] = 1 + i % RelicDefs.MAX_LV
			gacha_shards["relic:" + str(RelicDefs.RELICS[0]["id"])] = 3
			_select_tab("growth")
			_set_growth_mode("relic")
		# [개발 도구] --buy=blood_tax : 결제 SDK 없이 구매 훅을 태운다.
		# 지급·만료·상시 효과가 실제로 들어오는지 보려면 이 길밖에 없다.
		if arg.begins_with("--buy="):
			_iap_buy(arg.trim_prefix("--buy="))
			_select_tab("shop")
		# [개발 도구] --gacha=skill : 그 종류의 소환을 연 채로 캡처한다 —
		# 점성소(스킬·유물) 판은 종류를 골라야 보이는데 그건 검수 방법이 아니다.
		if arg.begins_with("--gacha="):
			_select_tab("summon")
			_set_gacha_kind(arg.trim_prefix("--gacha="))
		# [개발 도구] --shop : 상점을 연 채로 캡처한다(해금 계단이 다 보이게).
		if arg == "--shop" or arg.begins_with("--shop="):
			best_stage = maxi(best_stage, 50)
			dungeon_best = maxi(dungeon_best, 20)
			gem = maxf(gem, 500.0)
			shop_used = {}          # 캡처는 오늘 아무것도 안 산 상태로
			_select_tab("shop")
			for a2 in args:
				if a2.begins_with("--shop="):
					_shop_set_mode(a2.trim_prefix("--shop="))
		# [개발 도구] --boss[=in] : 주간 보스 판(=in 이면 도전 중)으로 캡처한다.
		if arg.begins_with("--boss=") and arg.trim_prefix("--boss=").is_valid_int():
			_dev_boss = int(arg.trim_prefix("--boss="))
			# 캡처마다 도전 횟수가 깎여서 넷째 판부터 진입이 막힌다(실측) —
			# 검수용 플래그는 표를 되돌려 넣는다(--raid= 와 같은 규칙).
			_boss_roll()
			boss_tries = EventDefs.TRIES_PER_DAY
			_select_tab("raid")
			_raid_set_mode("boss")
			boss_dps = dps()
			boss_dmg = boss_dps * 120.0
			_refresh_dungeon()
		elif arg == "--boss" or arg == "--boss=in":
			_select_tab("raid")
			_raid_set_mode("boss")
			boss_dps = dps()
			boss_dmg = boss_dps * 120.0
			if arg.ends_with("in"):
				_boss_enter()
			_refresh_dungeon()
		# [개발 도구] --pact : 혈맹 화면을 연 채로 캡처한다(별 3개 · 인장 넉넉히).
		if arg == "--pact":
			pact_lv = 168
			sigil = 5000.0
			_select_tab("growth")
			_set_growth_mode("pact")
		# [개발 도구] --book : 계약의 서(미니 패스) 판을 연 채로 캡처한다.
		if arg.begins_with("--book"):
			oath_used = int(arg.trim_prefix("--book=")) if "=" in arg else 24
			_select_tab("shop")
			_shop_set_mode("book")
		# [개발 도구] --oath10 : 10회 뽑기 선택 화면을 캡처한다.
		if arg.begins_with("--oath10"):
			var gten := arg == "--oath10=gold"
			oath_cards = 10
			oath_gold = 10
			oath_first = true
			_oath_view.visible = true
			_refresh_oath()
			_oath_play10(gten)
		# [개발 도구] --powerband : 전투력 띠를 띄운 채 캡처한다.
		if arg == "--powerband":
			_select_tab("home")
			_power_toast_t = 999.0
			_power_band_show(318_900_000.0, 29_400_000.0)
		# [개발 도구] --oathbuff : 계약을 걸고 전투 화면 카드 위젯을 캡처한다.
		if arg.begins_with("--oathbuff"):
			oath_cards = 3
			oath_first = true
			var one := _oath_roll(false, false)
			if not one.is_empty():
				_oath_use(one)
			_select_tab("home")
			if "=" in arg and arg.trim_prefix("--oathbuff=") == "tip":
				_oath_hud_toggle()
		# [개발 도구] --oathpick : 10연차 확인 판(교체 여부)을 바로 캡처한다.
		if arg == "--oathpick":
			oath_cards = 10
			oath_first = true
			_oath_view.visible = true
			var pk: Array = []
			for i in 10:
				var one := _oath_roll(false, false)
				if not one.is_empty():
					pk.append(one)
			if not pk.is_empty():
				_oath_use(pk[0])          # 먼저 하나 걸어 "지금 것" 을 만든다
				_oath_reveal.visible = true
				_oath_show_pick(pk)
				_oath_confirm_pick(pk[pk.size() - 1], pk)
			_refresh_oath()
		# [개발 도구] --oathroll[=등급] : 그 등급이 뜨도록 굴려 연출을 캡처한다.
		# 확률을 못 기다리므로 결과를 **심어** 두고 연출만 재생한다.
		if arg.begins_with("--oathroll"):
			var want := arg.trim_prefix("--oathroll=") if "=" in arg else "legend"
			oath_cards = 9
			gem = maxf(gem, 500.0)
			_oath_view.visible = true
			_refresh_oath()
			_dev_oath_force = want
			_oath_play(false)
		# [개발 도구] --oath[=N] : 핏빛 계약 판(카드 N장)을 연 채로 캡처한다.
		if arg == "--oath" or arg.begins_with("--oath="):
			oath_cards = int(arg.trim_prefix("--oath=")) if "=" in arg else 3
			gem = maxf(gem, 500.0)
			_oath_view.visible = true
			if arg == "--oath=col":     # 수집 탭을 연 채로(표본 몇 장 심어서)
				oath_lv = {"thirst": 2, "hide": 1, "frenzy": 3, "clot": 1,
					"redthirst": 1, "lord": 1}
				_oath_set_tab("col")
			_refresh_oath()
		# [개발 도구] --rdpop=<kind> : 던전 입장 팝업을 연 채로 캡처한다.
		if arg.begins_with("--rdpop"):
			_select_tab("raid")
			_raid_detail_open(arg.trim_prefix("--rdpop=") if "=" in arg
				else "blood")
		# [개발 도구] --slam=<key> : 그 보스의 착지 파동을 1초마다 반복 재생.
		# 임팩트가 0.45초라 실전 캡처는 타이밍이 운이다.
		if arg.begins_with("--slam="):
			_slam_demo = arg.trim_prefix("--slam=")
		# [개발 도구] --bosscut : 보스 등장 암전 연출을 튼 채로 캡처한다.
		if arg == "--bosscut":
			_select_tab("home")
			_boss_cut("가고일 군주")
		# [개발 도구] --home : 홈(사냥) 탭을 연 채로 캡처한다.
		if arg == "--home":
			_select_tab("home")
		# [개발 도구] --info : 군주의 기록 판을 연 채로 캡처한다.
		if arg == "--info":
			_show_info()
		# [개발 도구] --outfit : 외형 변경 판을 연 채로 캡처한다(몇 벌 보유 상태).
		if arg == "--outfit":
			skins_owned = {"demon_king": true, "dragon": true, "pink": true}
			_refresh_outfit()
			_outfit_view.visible = true
		# [개발 도구] --trial[=N|=in] : 시련 판(N단계 격파)으로, =in 이면 전투까지.
		if arg.begins_with("--trial"):
			if "=" in arg and arg.trim_prefix("--trial=").is_valid_int():
				trial_stage = int(arg.trim_prefix("--trial="))
			dungeon_best = maxi(dungeon_best, TrialDefs.floor_need(trial_stage + 1))
			_select_tab("raid")
			_raid_set_mode("trial")
			if arg.ends_with("=in"):
				_trial_enter()
		# [개발 도구] --raid=blood|pact|hunt : 재화 던전에 들어간 채로 캡처한다.
		# 오늘 표를 이미 썼어도 들어가야 하므로 표를 되돌려 넣는다 — 캡처 전용.
		if arg.begins_with("--raid="):
			var rk := arg.trim_prefix("--raid=")
			best_stage = maxi(best_stage, RaidDefs.open_stage(rk))   # 잠금 해제(검수)
			_raid_roll_day()
			raid_left[rk] = RaidDefs.TRIES_PER_DAY
			_raid_enter(rk)
		# [개발 도구] --traits : 혈맥 화면을 연 채로 캡처한다. 잠금 대부분을 풀고
		# 앞 노드 몇 개를 사 둔 상태 — 보유/구매 가능/잠김 세 상태가 다 보이게.
		if arg == "--traits":
			hero_lv = maxi(hero_lv, 60)
			dungeon_best = maxi(dungeon_best, 40)
			crystal = maxf(crystal, 5000.0)
			# 정수 레벨로 심는다 — bool 은 만렙으로 읽혀서 "사는 중" 상태가
			# 화면에 한 번도 안 잡혔다. 고른 노드는 **사는 중**인 것으로 둔다:
			# 구매 버튼이 몇 레벨을 사는지("x7") 보이는 자리가 거기뿐이다.
			traits["attack_1"] = TraitDefs.MAX_LV
			traits["attack_2"] = TraitDefs.MAX_LV
			traits["life_1"] = 3
			_trait_sel = "life_1"
			_select_tab("growth")
			_set_growth_mode("trait")
		# [개발 도구] --dungeon[=N] : 미궁 N층에 바로 들어간 채로 캡처한다.
		# 잠금(본편 30구간)과 개방 상한을 그 층에 맞게 같이 풀어 준다.
		if arg.begins_with("--dungeon"):
			var floor_want := maxi(1, int(arg.trim_prefix("--dungeon="))) \
				if "=" in arg else 1
			best_stage = maxi(best_stage,
				DungeonDefs.OPEN_STAGE + (floor_want / 5) * 10 + 10)
			dungeon_best = floor_want - 1
			_dungeon_enter()
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
		# [개발 도구] --god[=N] : **한 방에 N구간(기본 100) 검수 상태로 올린다.**
		# 던전 테마·보스 연출처럼 "해금 뒤에야 보이는 것"을 손으로 재려면 그
		# 자리까지 몇 시간을 밀어야 한다 — 그건 검수 방법이 아니다(사장님 요청).
		# 주는 것: 구간·미궁 기록 · 재화 뭉치 · 최고 등급 장비 한 벌 · 스킬 전종 ·
		# 소환권 · 유물 몇 · 스탯 상한. 세이브를 덮으므로 **검수 전용**이다.
		if arg.begins_with("--god"):
			_dev_god(int(arg.trim_prefix("--god=")) if "=" in arg else 100)
		# [개발 도구] --skin=grimble_1 : 그 외형으로 갈아입고 전투를 캡처한다.
		# 스킨 상품을 만들기 전에 **모션이 실제로 도는지** 눈으로 봐야 한다.
		if arg.begins_with("--skin="):
			skin = arg.trim_prefix("--skin=")
			_play("idle")
		# [개발 도구] --prestige[=N] : 회귀 판을 연다(N구간 도달 상태로).
		if arg.begins_with("--prestige"):
			var ps := int(arg.trim_prefix("--prestige=")) if "=" in arg else 250
			best_stage = maxi(best_stage, ps)
			stage = best_stage
			_select_tab("growth")
			_set_growth_mode("prestige")
		# [개발 도구] --pass[=N] : 성장 패스를 N단계까지 올린 채로 캡처한다.
		# 30단계 트랙은 임무를 며칠 채워야 보이는데 그건 검수 방법이 아니다.
		if arg.begins_with("--pass"):
			var pw := int(arg.trim_prefix("--pass=")) if "=" in arg else 8
			pass_points = pw * PassDefs.STEP_POINT
			# 받음·받을 수 있음·잠김이 한 판에 다 보이게(--traits 와 같은 규칙).
			for i2 in range(1, mini(4, pw + 1)):
				pass_free_got[i2] = true
			_select_tab("shop")
			_shop_set_mode("pass")
			_refresh_pass()
		# [개발 도구] --detail=blood : 던전 상세 판을 연 채로 캡처한다.
		if arg.begins_with("--detail="):
			_select_tab("raid")
			_raid_set_mode("raid")
			_raid_detail_open(arg.trim_prefix("--detail="))
		# [개발 도구] --cut : 보스 등장 컷신을 **띄운 채로** 잡는다. 연출은
		# 1.7초면 끝나서 --wait 로는 타이밍을 못 맞춘다(찍으면 이미 끝나 있다).
		if arg == "--cut":
			_boss_cut("뼈의 합창단")
		# [개발 도구] 영웅과 몹이 겹치는 순간만 골라 찍는다.
		if arg == "--perf":
			_perf_probe = true
			# **vsync 를 끈다.** 켜 두면 평균이 늘 16.7ms 로 붙어서 여유가
			# 얼마나 남았는지 안 보인다 — 튀는 것만 보이고 "왜 튀는지"는
			# 안 보인다. 끄면 진짜 한 프레임 원가가 나온다.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if arg == "--gaps":
			_gap_probe = true
		# [개발 도구] 보상 창을 띄운 채로 캡처한다. 실제로는 F9(치트)나 가이드 수령으로만
		# 뜨는데, 그 둘 다 헤드리스 캡처로는 못 눌러서 칸 크기를 눈으로 못 봤다.
		if arg == "--reward":
			_show_reward("보상 획득", [{"icon": "res://assets/ui/res_gem.png",
				"label": "보석 +1.2k", "sub": "가이드 3개"}])
		# [개발 도구] 방치 보상 상자를 띄운 채로 캡처한다.
		if arg == "--chest" or arg == "--chest=open":
			chest_gold = 12480.0
			chest_minutes = 143.0
			dungeon_best = 12          # 혈정 줄이 보이게
			_refresh_chest()
			if arg.ends_with("open"):
				_claim_chest()
		# [개발 도구] 스킬 상세보기를 띄운 채로 캡처한다.
		# `--skill-detail=field_epic` 처럼 **키를 지정할 수 있다.** 지정 안 하면 보유
		# 목록의 첫 칸인데, `--skills=N` 이 무작위로 채우므로 매번 다른 스킬이 열려
		# "이 스킬의 상세창"을 못 찍는다 — 아이콘이 이름과 맞는지 확인할 때 그게 걸림돌이다.
		if arg.begins_with("--skill-detail") and not skill_owned.is_empty():
			var want := arg.trim_prefix("--skill-detail=") if "=" in arg else ""
			if want != "" and not skill_owned.has(want):
				skill_owned[want] = 1     # 안 가진 것도 열어 볼 수 있게 준다
			_open_skill_detail(want if want != "" else str(skill_owned.keys()[0]))
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
					# **자리는 실제 시전과 같은 식으로 잡는다.** 예전엔 여기서
					# `ground_y + y` 를 직접 썼는데, 진짜 경로는 `_fx_anchor_y` 로
					# **몸통 가운데 기준**이라 둘이 갈렸다 — 개발 도구가 실제 화면과
					# 다른 자리를 보여 주면 그걸로 내린 판단이 전부 틀어진다
					# (2026-08-06: 가호 fx_y 를 0 으로 고치자 여기서만 지면에 반쯤 묻혔다).
					_anim_fx(str(fp["fx"]),
						Vector2(64.0 + float(i) * 112.0,
							_fx_anchor_y(str(fp["style"]), str(fp["fx"]),
								float(fp["scale"]), ground_y - float(Grid.SPRITE),
								float(fp["y"]))),
						float(fp["fps"]), float(fp["scale"]), str(fp["style"]),
						int(fp["echo"]), 1.0, 1, 1.0, false, int(signf(float(fp["flip"])))))
			add_child(fx_timer)
		# [개발 도구] --cast=field_common : 교전이 붙고 표적이 둘 이상 설 때까지 기다렸다가
		# 그 스킬을 **실제 시전 경로로** 한 번 쏜다.
		#
		# `--skillfx` 와 다르다. 저건 이펙트 5등급을 정해진 자리에 얹기만 해서 크기·가림만
		# 본다 — "맞는 놈마다 문양이 깔린다" 같은 **규칙**은 실제 경로로 쏴야 화면에 나온다.
		if arg.begins_with("--cast="):
			var cast_key := arg.trim_prefix("--cast=")
			var cast_timer := Timer.new()
			cast_timer.wait_time = 0.1
			cast_timer.autostart = true
			cast_timer.timeout.connect(func() -> void:
				if _phase != "fight" or _aoe_targets().size() < 2:
					return
				cast_timer.queue_free()
				# 시전 조건만 비운다. 쿨다운과 진행 중 동작이 남아 있으면 조용히 빠진다.
				_skill_action = ""
				_skill_cd.clear()
				# **격(strike)은 표적이 있어야 나간다.** `_can_hit_foe(null)` 이 false 라
				# 표적을 안 잡으면 아무 일도 안 일어나고 화면에는 "이펙트가 없다"로
				# 보인다 — 아가리·핏빛 창을 찍다가 그렇게 헛돌았다.
				_skill_target = _aoe_targets()[0]
				_resolve_skill(cast_key)
				# 시각을 찍는다. `--wait` 이 이보다 이르면 아직 안 쐈고, 늦으면 세상이
				# 전진한 뒤라 문양이 화면 왼쪽으로 밀려 있다 — 둘 다 화면만 보면
				# "안 깔렸다"로 보인다.
				print("CAST: %s  t=%.2fs  대상 %d" % [cast_key,
					float(Time.get_ticks_msec()) * 0.001, _aoe_targets().size()]))
			add_child(cast_timer)
		# [개발 도구] --equip=first : 첫 보관 장비를 장착해 "장착 중" 표시를 캡처한다.
		if arg == "--equip=first" and not gear_inventory.is_empty():
			_equip_inventory_item(str(gear_inventory.keys()[0]))
		# [개발 도구] --dialog=confirm|reward : 확인창/보상창을 연 채 캡처한다.
		if arg.begins_with("--dialog="):
			if arg.ends_with("confirm"):
				_ask("선택한 장비 12종을 조합합니다.\n각각 조각 3개를 씁니다.\n\n실패해도 조각은 소모됩니다.",
					func() -> void: pass)
			else:
				_show_reward("합성 완료", [{"icon": "res://assets/items/gem.png",
					"label": "장비 1종 승급"}])
		# [개발 도구] --rates : 소환 레벨별 확률표를 연 채 캡처한다.
		if arg == "--rates":
			_select_tab("summon")
			_rates_view.visible = true
			_refresh_rates_table()
		# [개발 도구] --bulk=fuse[:all] : 조합 창을 연 채 캡처한다.
		if arg.begins_with("--bulk="):
			var bulk_args := arg.trim_prefix("--bulk=").split(":")
			_select_tab("gear")
			_set_gear_mode("inventory")
			_open_bulk(str(bulk_args[0]))
			if bulk_args.size() > 1 and str(bulk_args[1]) == "all":
				_bulk_select_all(true)
		# [개발 도구] --status : 도감의 능력치 창을 연 채로 캡처한다.
		if arg == "--status":
			_codex_view.visible = true
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
			_select_tab("summon")   # 공개 층이 소환 판 안에 산다 — 탭을 안 열면 안 보인다
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
		# [개발 도구] --tell: 보스·중간보스가 **매 스윙 특수 패턴**을 쓰게 한다.
		# 예고(0.85초)가 세 스윙마다 오므로 그냥 찍으면 잡히지 않는다.
		if arg == "--tell":
			Foe.force_special = true
		# [개발 도구] --drop: 핏방울을 바로 떨어뜨려 자리·반짝임을 캡처한다.
		if arg == "--drop":
			_drop_t = 0.1
		# [개발 도구] --walk: 무리를 치우고 계속 걷게 해 스크롤 이음매를 확인한다.
		if arg == "--walk":
			_walk_only = true
			for f in get_tree().get_nodes_in_group("foes"):
				f.queue_free()
	set_process(true)
	_load_done()
	if "--autoshot" in args:
		_autoshot()


# [개발 도구] --autoshot: 몇 초 굴린 뒤 화면을 저장하고 종료.
# 바탕화면 캡처는 다른 창이 앞으로 나오면 엉뚱한 그림이 찍혀서, 게임이 자기
# 뷰포트를 직접 저장하게 한다.
func _autoshot() -> void:
	await get_tree().create_timer(_shot_wait).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://autoshot.png")
	print("AUTOSHOT SAVED (t=%.2fs): %s" % [float(Time.get_ticks_msec()) * 0.001,
		ProjectSettings.globalize_path("user://autoshot.png")])
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
	#
	# **띠를 메우는 보조 레이어가 셋 있었는데 전부 지웠다**(2026-08-05). 원본이
	# 160줄이라 전투 띠(416)를 못 덮어서 위는 하늘 그라데이션, 아래는 담을 뒤집어
	# 잇고 그 위에 흙 그늘을 깔았다. 배경을 208줄로 다시 뽑아 그림 하나가 띠를
	# 통째로 덮으니 셋 다 할 일이 없어졌다 — 가짜로 메우던 것을 그림이 대신한다.
	_bg2 = Sprite2D.new()
	_bg2.centered = false
	_bg2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg2.scale = Vector2(2, 2)
	_bg2.z_index = -20
	add_child(_bg2)

	_hero = Sprite2D.new()
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 피격 번쩍임 — self_modulate(곱셈)로는 어두운 스킨을 못 하얗게 만든다.
	# 버프 tint 는 `modulate` 라 셰이더의 MODULATE 로 그대로 살아 있다.
	var hero_mat := ShaderMaterial.new()
	hero_mat.shader = Foe.FX_SHADER
	_hero.material = hero_mat
	_hero.position = Vector2(HERO_X, ground_y - float(Grid.SPRITE))   # 발밑 = ground_y
	_hero.scale = Vector2(2, 2)   # 32px 원본 -> 64px. 배경도 2배라 도트 밀도가 같다.
	# 원본은 왼쪽을 보고 있는데 몹은 오른쪽에서 오므로 뒤집는다.
	_hero.flip_h = true
	_hero.z_index = 3
	add_child(_hero)
	# **데리고 다니는 펫이 화면에 보인다.** 이게 펫의 절반이다 — 수집만 하면
	# 창 안의 숫자로 끝나고, "성장이 눈에 안 보인다"는 문제가 그대로 남는다.
	# 영웅보다 뒤(z 2)에 두고 조금 위로 띄운다: 앞에 서면 전투를 가린다.
	_pet_sprite = Sprite2D.new()
	_pet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pet_sprite.scale = Vector2(1.0, 1.0)
	_pet_sprite.z_index = 2
	_pet_sprite.visible = false
	add_child(_pet_sprite)
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
	_build_topbar()
	_build_boss_cut()
	# 전투력 알림은 **전용 줄**이다. 오프라인·장비 알림과 같은 줄을 쓰면 그쪽이 떠 있는
	# 동안 상승이 통째로 안 보인다 — 전투력은 오를 때마다 무조건 보여야 한다.
	_build_power_band()
	# 전투 띠 안에서 생존 상태를 바로 읽는다. 오른쪽 절반만 써 오프라인 알림과
	# 겹치지 않고, 별도 패널을 늘려 전투를 가리지 않는다.
	_lbl_life = _mk_label(Vector2(float(Grid.BG.x) * 0.52, VIEW_TOP + 12.0),
		Type.SIZE_SMALL, Color(0.72, 0.95, 0.78))
	_lbl_life.size = Vector2(float(Grid.BG.x) * 0.48 - TOP_PAD, 24.0)
	_lbl_life.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_life.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 콘텐츠 창 — 탭으로 하나만 띄운다. 세로 화면에서 전부 펼치면 전투가 안 보인다.
	await _load_tick(0.15)
	await _build_panels()
	_build_goal_widget()
	_build_chest()
	_build_tabbar()
	# 임무판·도감판은 맨 나중 — 팝업이라 모든 창 위에 그려져야 한다.
	# 도감을 _build_panels 안에서 지었더니 탭바보다 먼저 붙어 어둠막이 하단
	# 탭을 못 덮었다(실측 캡처).
	await _load_tick(0.85)
	_build_quests()
	_build_codex_view()
	_build_oath_view()
	_build_dialogs()
	_build_clear_view()
	await _load_tick(0.95)
	# 창이 뜰 때의 반응을 **한 곳에서** 건다(사장님: "모든 창들 띄울 때 애니메이션").
	# `visible` 을 켜는 자리가 34곳이라 호출부마다 넣으면 하나씩 빠진다 — Ui.pop_in
	# 은 켜지는 순간을 시그널로 잡으므로 여기서 한 번만 걸면 된다.
	#
	# **손 목록을 버리고 이름으로 훑는다**(2026-08-20, 사장님 "모든 UI에 애니").
	# 목록에 7개가 올라 있는 동안 판은 28개였다 — 새 창을 만들 때 목록에 올리는
	# 걸 잊는 게 당연하다. `_..._view` / `_..._detail` 은 이미 이 파일의 약속이라
	# 그 약속을 읽으면 목록이 저절로 자란다. 다음 창은 아무것도 안 해도 붙는다.
	for prop in get_property_list():
		var pname := str(prop["name"])
		if not (pname.ends_with("_view") or pname.ends_with("_detail")):
			continue
		var node = get(pname)
		if node is Control:
			Ui.pop_in(node)
	# 사냥 탭 소탭 셋만 이름이 _panel 이다. _reward_panel 은 _reward_view **안**에
	# 있어서 부모가 이미 움직인다 — 같이 걸면 두 번 줄어든다.
	for v in [_trial_panel, _maze_panel, _boss_panel]:
		if v != null:
			Ui.pop_in(v)
	_select_tab("growth")


# ── 영웅 모션 ──────────────────────────────────────────────────────────────
# idle / walk / attack / hurt 네 벌. 스킨을 갈아도 프레임 수와 타이밍이 같으므로
# 여기 말고 고칠 곳이 없다.
# **초당 프레임이 아니라 한 바퀴에 걸리는 시간을 적는다.** fps 로 두면 그림을 다시
# 뽑아 장수가 바뀔 때마다 fps 도 같이 고쳐야 하고, 안 고치면 걷기가 슬로모션이 된다 —
# 5장을 9장으로 늘렸을 때 실제로 그랬다(10fps 면 0.5초 -> 0.9초).
# 시간으로 두면 그림이 몇 장이든 리듬이 같다. IMPACT_RATIO 를 프레임 번호에서
# 비율로 바꾼 것과 같은 이유다.
const MOTION_CYCLE := {"idle": 0.85, "walk": 0.50, "dash": 0.60, "hurt": 0.36}
# 휘두르는 데 걸리는 시간. **공격 주기(0.60)와 분리한다.**
#
# 주기 전체에 9프레임을 늘려 재생하면 영웅이 늘 휘두르는 중이고, 피해가 0.257초
# 뒤에야 들어와서 "붙었는데 반응이 없다"가 된다. 짧게 휘두르고 남는 시간은 idle 로
# 선다 — 몹이 맞닿는 순간 바로 들어가는 느낌이 여기서 나온다(사장님 요청).
#
# **초당 타수는 그대로다.** 바뀌는 건 스윙 시작에서 피해까지의 지연뿐이라 DPS 도
# 밸런스 표도 안 건드린다. 주기가 이보다 짧아지면(공격속도 만렙) 주기를 따른다.
const ATTACK_SWING := 0.34
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
# 한 번 휘두르는 데 실제로 쓰는 시간. 주기가 스윙보다 짧아지면 주기를 따른다.
func _attack_swing() -> float:
	return minf(ATTACK_SWING, maxf(0.08, attack_interval()))


# 평타는 **이어지는 연격**이다(2026-08-10 사장님: "기본공격 모션 하나가 아니라
# 액션성을 위해 이어지는 공격모션 2/3"). 한 그림만 반복하면 자동 전투가 정지 화면처럼
# 보인다 — 스윙마다 다음 모션으로 넘어간다.
#
# **있는 것만 쓴다.** `attack2`·`attack3` 자산이 없는 스킨은 자동으로 1연격이 된다
# (영웅 스킨이 11종인데 모션이 다 갖춰진 건 `valentino_1` 뿐이다).
const COMBO_MOTIONS := ["attack", "attack2", "attack3"]
var _combo := 0
var _combo_live: Array[String] = []   # 이 스킨에 실제로 있는 연격. 스킨이 바뀌면 비운다


func _attack_motion() -> String:
	if _combo_live.is_empty():
		for m in COMBO_MOTIONS:
			if not Assets.frames("res://assets/anim/%s_%s" % [skin, m]).is_empty():
				_combo_live.append(str(m))
		if _combo_live.is_empty():
			_combo_live.append("attack")
	return _combo_live[_combo % _combo_live.size()]


func _motion_fps() -> float:
	# 연격 전부가 평타 박자를 따른다 — `attack` 만 보면 2·3연격이 기본 주기(0.85초)로
	# 돌아서 공격속도를 올려도 그림만 느려진다.
	if _motion in COMBO_MOTIONS:
		return float(_hero_frames.size()) / _attack_swing()
	if _motion == "heavy" or _motion == "cast":
		return float(_hero_frames.size()) / SKILL_DUR
	var cycle := float(MOTION_CYCLE.get(_motion, 0.85))
	return float(_hero_frames.size()) / maxf(0.05, cycle)


func _tick_motion(delta: float) -> void:
	if _hero_dead:
		return
	# **달리기는 실제로 움직일 때만 돈다.** `dash` 는 루프 모션이라(LOOPING) 아무도
	# 안 끊으면 영원히 돌아간다 — 전진 구간에서 켜 둔 dash 가 전투로 넘어와도 그대로
	# 남아서, 공격 쿨다운 내내 제자리에서 달렸다(실측: 전투 중 1261 프레임 = 24%).
	#
	# 전투 중에는 세상이 안 흐르므로(`_advance_world` 는 전진 구간에서만 돈다) 영웅이
	# 제 자리에 있으면 화면에서 아무것도 안 움직인다. 모션을 켜는 자리가 여럿이라
	# **재생을 관리하는 이 한 곳**에서 끊는다.
	# (판정은 _tick_dash 로 옮겼다 — "목표점에 닿았나"가 아니라 **실제로 움직였나**를
	# 본다. 목표점이 흔들리면(_clear_idle·넉백) 닿음 검사가 영영 안 맞아서
	# 제자리 달리기가 남았다: 사장님 "만나면 가만히 있어야지".)
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
	# 위쪽 선은 없앴다. 배경이 화면 맨 위까지 이어지므로 선을 그으면 거기서 다시
	# 잘려 보인다 — 아래쪽만 콘텐츠 창과의 경계로 남긴다.
	for y in [VIEW_BOTTOM]:
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
	# 던전 입장·퇴장 전용 — **화면 전체** 암전(사장님, 레퍼런스). 평소 구간 전환은
	# 전투 띠만 가리는 위 판을 계속 쓴다(20킬마다 UI가 깜빡이면 성가시다).
	_fade_full_rect = ColorRect.new()
	_fade_full_rect.color = Color(0, 0, 0, 0)
	_fade_full_rect.size = Vector2(Grid.BG)
	_fade_full_rect.z_index = 90
	_fade_full_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_full_rect.visible = false
	_hud_root.add_child(_fade_full_rect)


# 큰 수는 줄여 쓴다. 방치형은 재화가 금방 억을 넘는데 그대로 찍으면 패널을 넘는다.
# 만/억/조가 아니라 k/m/b 인 이유: 방치형 표준 표기라 눈에 익다(사장님 지시).
# **대문자가 아니라 소문자인 이유**: 이 폰트(블랙레터)의 대문자 K 는 획이 꺾여
# "Ж" 처럼 읽힌다 — 실제로 폰트를 렌더해서 확인했다. 소문자 k·m·b·t 는 획이 단순해
# 그대로 읽힌다. 단위 글자를 바꿀 때는 반드시 같은 방법으로 렌더해서 확인할 것.
# up=true 는 **가격**이다: 반드시 올려 적는다.
#
# 내림으로 적으면 화면이 "혈액 9"인데 실제로는 9.36 이 필요해 버튼이 안 눌린다 —
# 살 수 있어 보이는데 안 되는 자리라 유저에겐 버그다(사장님 2026-08-20).
# 올려 적으면 그 반대(안 될 것 같은데 되는 쪽)라 막히는 일이 없다. 값 자체는
# 안 바꾼다 — 실제로 올려 받으면 누적 비용 항등이 깨진다(SplitCheck 1번).
#
# **지갑은 내림(기본), 가격은 올림.** 이 짝이 "화면이 살 수 있다고 하면 정말로
# 살 수 있다"를 보장한다: floor(지갑) >= ceil(가격) 이면 지갑 >= 가격이다.
static func _n(v: float, up := false) -> String:
	# **1 미만을 0 으로 찍지 않는다.** 15분할로 한 칸 값이 1 아래로 내려가면서
	# (눈금 15배 전, 공격력 첫 칸 0.62) 스탯 가격이 통째로 "혈액 0"으로 보였다 —
	# 공짜라는 거짓말이다. 0.1 로 바닥을 받쳐 0.04 도 "0.0"이 되지 않게 한다.
	if up:
		v = ceilf(v)
	elif v > 0.0 and v < 1.0:
		return "%.1f" % maxf(v, 0.1)
	if v < 1000.0:
		return str(int(v))
	var units := ["k", "m", "b", "t"]
	var i := -1
	while v >= 1000.0 and i < units.size() - 1:
		v /= 1000.0
		i += 1
	# 축약도 같은 이유로 올린다 — 1234 를 "1.2k" 로 적으면 또 모자라다.
	if up:
		v = ceilf(v * 10.0) / 10.0
	return ("%.1f" % v).trim_suffix(".0") + units[i]


# 소수점 없는 축약. 좁은 칸(가이드 보상 등)에서 쓴다.
static func _n_int(v: float) -> String:
	if v < 1000.0:
		return str(int(v))
	var units := ["k", "m", "b", "t"]
	var i := -1
	while v >= 1000.0 and i < units.size() - 1:
		v /= 1000.0
		i += 1
	return str(int(v)) + units[i]


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
# 재화 알약. 아이콘은 판보다 크고 **왼쪽 끝에 걸쳐 밖으로 나온다**(레퍼런스).
# 판 안에 얌전히 넣으면 아이콘이 작아져 무슨 재화인지 한눈에 안 갈린다.
# 폭은 아이콘이 먹는 자리 + 숫자 칸(최장 "999.9t" 72) + 오른쪽 여백.
const PILL_W := 118.0
const PILL_H := 26.0
const PILL_GAP := 6.0
const PILL_ICON := 40.0      # 판(26)보다 크다 — 위아래로 7px 씩 튀어나온다
const PILL_ICON_OUT := 14.0  # 왼쪽으로 나오는 양
const BOSS_FACE := 26.0      # 진행바 아래로 걸치는 보스 마크
# 두 바의 y. 캔버스는 32px 이지만 실제 그림은 타이머 y7~25 · 진행바 y11~21 이라
# **캔버스 간격과 보이는 간격이 다르다.** 셋을 고르게 벌리려면 보이는 자리로 재야 한다:
#   글자 34~58(속 38~54) · 타이머 그림 67~85 · 진행바 그림 99~109 -> 사이가 각각 13, 14.
const TIMER_BAR_Y := 60.0
const PROG_BAR_Y := 88.0
# 두 바는 **같은 길이**로 가운데 정렬한다. 최장 글자가 진행 144px / 보스 이름 156px 이라
# 홈통(260 - 좌우 캡 52 = 208)에 들어간다(GearTest 가 실제 폰트로 지킨다).
const BAR_W := 260.0        # 타이머·진행바 공통 길이
# 일반 구간은 **차오르고**(처치 진행도), 보스 구간은 **줄어든다**(남은 체력).
# 방향이 반대라 색까지 같으면 어느 쪽인지 헷갈린다.
const STAGE_BAR_COL := Color(0.72, 0.16, 0.20)
const BOSS_BAR_COL := Color(0.88, 0.22, 0.16)
const TIMER_BAR_COL := Color(0.30, 0.62, 0.88)
const TIMER_LOW_COL := Color(0.92, 0.35, 0.28)   # 5초 남으면
# 제한 시간이 없는 일반 구간에서 **같은 자리**가 교전 몹 체력이 된다. 시계와 색을
# 다르게 둔다 — 자리가 같으니 색이 유일한 구분이다. 몹 머리 위 바(0.78,0.14,0.18)와
# 같은 붉은 계열로 두어 "저 놈의 체력"이 위아래로 같이 읽히게 한다.
const FOE_BAR_COL := Color(0.80, 0.18, 0.20)


func _build_topbar() -> void:
	var w := float(Grid.BG.x)
	# **레퍼런스 확대본 그대로.**
	#   왼쪽 위 : 초상화 + (원 아래 겹치는) 레벨 배지
	#   그 오른쪽: 교차검 아이콘 + 전투력 / 그 아래 칭호·닉네임 판
	#   오른쪽 위: 재화 **바 하나**에 세 쌍 (알약 셋이 아니다)
	#   가운데   : 막이름+단계 -> 상태 태그 -> 진행바(숫자는 홈통 안)
	# 초상화 묶음은 **레이드에서 통째로 감춘다**(사장님 2026-08-14, 레퍼런스:
	# 보스전 화면에는 상단 소품이 없다). 노드가 여럿이라 이름을 다 들고 있느니
	# 만들어진 자리를 표시해 두고 그 뒤에 붙은 것을 담는다.
	var portrait_mark := _hud_root.get_child_count()
	_build_portrait()
	for i in range(portrait_mark, _hud_root.get_child_count()):
		var n := _hud_root.get_child(i)
		if n is CanvasItem:
			_hud_raid_hide.append(n)
	# ── 재화. **재화마다 검은 알약 하나씩**, 앞에 아이콘 뒤에 숫자(레퍼런스).
	# 예전엔 돌 바 하나에 세 쌍을 우겨넣었는데, 무늬 있는 바가 늘어나면서 뭉개지고
	# 숫자가 그 위에 얹혀 안 읽혔다. 판이 무늬 없는 검정이면 숫자가 그냥 읽힌다.
	#
	# 아이콘·숫자를 **알약의 자식으로** 둔다 — 그래야 잠긴 재화를 숨길 때 알약 하나만
	# 끄면 되고, 아이콘만 남거나 빈 판이 뜨는 일이 없다.
	# **아이콘 세 개가 헷갈리기 쉽다.** items/gem(흰 다이아)은 정수고, 보석은
	# ui/res_gem(보라)다. 가이드 보상과 보상 창이 보석에 흰 다이아를 쓰고 있었다.
	#
	# 상단에는 **핵심 2개만**(레퍼런스) — 혈액(상시 소비)과 보석(소환). 넷을 다
	# 올리면 알약이 초상화까지 밀고 들어가 끝이 잘렸다(사장님 캡처). 정수는 장비
	# 탭에서만 쓰니 그 탭에 두고, 혈정은 미궁 탭·혈맥 창이 이미 보여 준다 —
	# 재화는 **쓰는 곳에** 두는 게 레퍼런스 방식이다.
	var currencies := [
		["res://assets/ui/res_blood.png", Color(1.0, 0.45, 0.45)],   # 혈액
		["res://assets/ui/res_gem.png", Color(0.88, 0.74, 1.0)],     # 보석
	]
	var labels: Array[Label] = []
	_currency_pills.clear()
	for i in currencies.size():
		var pill := Ui.pill(Vector2(0.0, 4.0), Vector2(PILL_W, PILL_H))
		_hud_root.add_child(pill)
		_currency_pills.append(pill)
		pill.add_child(Ui.icon(str(currencies[i][0]),
			Vector2(-PILL_ICON_OUT, (PILL_H - PILL_ICON) * 0.5), PILL_ICON))
		# _mk_label 은 _hud_root 에 붙여서 돌려준다 — 알약 밑으로 옮겨 단다.
		# 숫자는 **오른쪽 정렬**. 왼쪽에 붙이면 자릿수가 바뀔 때마다 끝이 들쭉날쭉하다.
		var lx := PILL_ICON - PILL_ICON_OUT + 4.0
		var label := _mk_label(Vector2(lx, 0.0), Type.SIZE_SMALL, currencies[i][1])
		label.size = Vector2(PILL_W - lx - 10.0, PILL_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		_hud_root.remove_child(label)
		pill.add_child(label)
		labels.append(label)
	_lbl_gold = labels[0]
	_lbl_gem = labels[1]
	# ── 가운데: 막이름 + 단계 -> 진행바. 한 덩어리로 **화면 가운데에** 붙인다.
	# 예전엔 초상화 오른쪽(148)부터 남는 폭을 다 썼는데, 그러면 덩어리 가운데가
	# 352 라 화면 가운데(288)에서 64px 오른쪽으로 밀려 있었다(사장님 지적).
	# 폭 376 이면 좌우 100px 씩 남아 왼쪽 레벨 배지(4~100)에 정확히 안 닿는다.
	var mid_w := 376.0
	var mid_x := (w - mid_w) * 0.5
	# 막 이름은 뺐다 — 어느 막인지는 배경 그림이 이미 말하고, 글자는 **어디까지 왔나**
	# 하나만 남기는 게 레퍼런스다("스테이지 1-1"). 크기도 22 -> 16, 색은 흰색.
	_lbl_stage = _mk_label(Vector2(mid_x, 34.0), Type.SIZE_MID, Color(0.96, 0.96, 1.0))
	_lbl_stage.size = Vector2(mid_w, 24.0)
	_lbl_stage.clip_text = true
	_lbl_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 분당 수입 (참고작 "사냥 중 109.5 Pt/m") — "지금 벌고 있다"를 상시로 보여준다.
	# 최근 60초 처치 수입의 굴림 합이라 곧 분당 시세다. 벌이가 없으면 숨긴다.
	# 자리는 혈액 알약 **바로 아래 오른쪽 정렬** — 가운데(스테이지 글자)에 두면
	# 겹쳐서 둘 다 안 읽혔다(실측).
	_lbl_income = _mk_label(Vector2(w - 226.0, 32.0), Type.SIZE_SMALL,
		Color(0.98, 0.78, 0.45))
	_lbl_income.size = Vector2(218.0, 13.0)
	_lbl_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_income.visible = false
	# ── 제한 시간 바를 진행바 **위에** 올린다(레퍼런스 배치). 두 바 모두 32px 캔버스에
	# 그림은 그 일부(타이머 y7~25 · 진행바 y11~21)라, 캔버스끼리는 겹쳐도 그림은 안 겹친다.
	var timer_at := Vector2((w - BAR_W) * 0.5, TIMER_BAR_Y)
	# 홈통도 들고 있는다 — 제한 없는 구간에서는 채움만 감추면 빈 홈통이 남아서
	# 0초에 멈춘 시계로 보인다(_refresh_hud).
	_timer_frame = Ui.timer_bar(timer_at, BAR_W)
	_hud_root.add_child(_timer_frame)
	_timer_bar = ColorRect.new()
	_timer_bar.color = TIMER_BAR_COL
	_timer_bar.position = timer_at + Vector2(float(Ui.BAR_TIMER_L), Ui.BAR_TIMER_INNER_Y)
	_timer_bar.size = Vector2(0.0, Ui.BAR_TIMER_INNER_H)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_timer_bar)
	_timer_bar_width = BAR_W - float(Ui.BAR_TIMER_L + Ui.BAR_TIMER_R)
	_lbl_time = _mk_label(timer_at + Vector2(float(Ui.BAR_TIMER_L), 0.0),
		Type.SIZE_SMALL, Color(0.90, 0.95, 1.0))
	_lbl_time.size = Vector2(_timer_bar_width, Ui.BAR_TIMER_H)
	_lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_time.clip_text = true
	var bar2_at := Vector2((w - BAR_W) * 0.5, PROG_BAR_Y)
	_hud_root.add_child(Ui.slim_bar(bar2_at, BAR_W))
	# 채움은 **틀 위에**, 홈통 안(y13~18)에만. 밑에 깔면 홈통이 불투명이라 통째로
	# 가려진다 — 진행도가 안 채워지는 게 아니라 안 보이는 상태였다(가이드 바와 동일).
	_stage_bar = ColorRect.new()
	_stage_bar.color = STAGE_BAR_COL
	_stage_bar.position = bar2_at + Vector2(float(Ui.BAR_SLIM_SIDE), Ui.BAR_SLIM_INNER_Y)
	_stage_bar.size = Vector2(0.0, Ui.BAR_SLIM_INNER_H)
	_stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_stage_bar)
	_stage_bar_width = BAR_W - float(Ui.BAR_SLIM_SIDE) * 2.0
	# 글자는 **홈통 안에만.** 바 전체 폭을 주면 좌우 화살촉(26px) 위까지 뻗어 잘린다.
	_lbl_prog = _mk_label(bar2_at + Vector2(float(Ui.BAR_SLIM_SIDE), 0.0),
		Type.SIZE_SMALL, Color(0.98, 0.96, 0.98))
	_lbl_prog.size = Vector2(_stage_bar_width, Ui.BAR_SLIM_H)
	_lbl_prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_prog.clip_text = true
	# 보스 구간 표시. 바 아래끝에 걸쳐 얼굴이 튀어나온다(레퍼런스와 같은 자리) —
	# 바 색만 바꾸면 "지금이 보스 구간"이 화면을 훑는 눈에는 안 걸린다.
	# 바 **가운데보다 조금 아래**에 얹어 아래쪽으로 걸쳐 나간다. 완전히 밑으로 내리면
	# 바와 따로 노는 아이콘이 되고, 가운데에 맞추면 바 안 글자를 물어 문구가 안 읽힌다.
	_stage_icon = Ui.icon("res://assets/ui/icon_boss.png",
		Vector2(w * 0.5 - BOSS_FACE * 0.5,
			PROG_BAR_Y + Ui.BAR_SLIM_H * 0.5 + 4.0), BOSS_FACE)
	_stage_icon.visible = false
	_hud_root.add_child(_stage_icon)


# 왼쪽 위 초상화 블록. 레퍼런스에서 이 자리가 "누구인가"를 담당한다.
const PORTRAIT := 56.0
# 32px 원본의 **정확히 절반**. 1.2배(14~15)면 축소 배율이 정수가 아니라 어떤 도트 줄은
# 2px, 어떤 줄은 3px 이 되어 지저분해진다 — 16 이 가장 가까운 깨끗한 값이다.
const POWER_ICON := 16.0


# 레벨 배지가 초상화(56)보다 넓어서(96) 둘의 가운데를 맞추면 배지가 화면 밖으로
# 나간다. **초상화를 오른쪽으로 민다** — 배지를 왼쪽 끝(4)에 붙이고 그 가운데에
# 초상화를 얹으면 둘이 한 덩어리로 읽힌다.
const LV_BADGE_SIZE := Vector2(96.0, 22.0)
const LV_BADGE_AT := Vector2(4.0, 2.0 + PORTRAIT - 11.0)
const PORTRAIT_X := LV_BADGE_AT.x + (LV_BADGE_SIZE.x - PORTRAIT) * 0.5


func _build_portrait() -> void:
	var face := Ui.icon("res://assets/ui/portrait_hero.png",
		Vector2(PORTRAIT_X + PORTRAIT * 0.16, 2.0 + PORTRAIT * 0.14), PORTRAIT * 0.68)
	# 얼굴을 틀보다 먼저 붙여야 틀 테두리가 얼굴 위로 온다.
	_hud_root.add_child(face)
	_hud_root.add_child(Ui.icon("res://assets/ui/portrait_frame.png",
		Vector2(PORTRAIT_X, 2.0), PORTRAIT))
	# 레벨 배지 — 레퍼런스처럼 **초상화 원 아래에 걸쳐** 놓는다.
	# 배지 폭은 "레벨 9999"(84px) + 좌우 여백(6+6)에서 나온 값이다.
	_hud_root.add_child(Ui.lv_badge(LV_BADGE_AT, LV_BADGE_SIZE))
	_lbl_hero = _mk_label(LV_BADGE_AT, Type.SIZE_SMALL, Color(0.88, 0.98, 0.88))
	_lbl_hero.size = LV_BADGE_SIZE
	_lbl_hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_hero.clip_text = true
	# 장착 칭호 (참고작 "죽음의 신" 자리) — 레벨 배지 바로 아래 금빛 한 줄.
	_lbl_worn = _mk_label(LV_BADGE_AT + Vector2(-12.0, 24.0), Type.SIZE_SMALL,
		Color(0.92, 0.82, 0.62))
	_lbl_worn.size = Vector2(LV_BADGE_SIZE.x + 24.0, 14.0)
	_lbl_worn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_worn.clip_text = true
	_lbl_worn.visible = false
	# 전투력 — 레퍼런스의 **교차검 + 8M**. 초상화 오른쪽 위.
	# 아이콘은 **절반(24 -> 12)**. 원본 32px 짜리를 24로 그렸더니 초상화만큼 커서
	# 얼굴과 숫자 사이에서 저 혼자 튀었다.
	var pw_x := PORTRAIT_X + PORTRAIT + 6.0
	_hud_root.add_child(Ui.icon("res://assets/ui/icon_power.png",
		Vector2(pw_x, 8.0), POWER_ICON))
	# 색은 흰색. 금색은 재화(혈액·정수·보석)가 쓰는 색이라 전투력이 재화로 읽혔다.
	_lbl_power = _mk_label(Vector2(pw_x + POWER_ICON + 4.0, 4.0), Type.SIZE_SMALL,
		Color(1.0, 1.0, 1.0))
	_lbl_power.size = Vector2(96.0, 24.0)
	_lbl_power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_power.clip_text = true
	# 이름판 — 레퍼런스가 전투력 아래에 두는 그 자리다(_build_topbar 주석의
	# "그 아래 칭호·닉네임 판"). plate_name 과 Ui.name_plate 는 진작 만들어
	# 두고 쓰는 데가 없었다. 초상화 묶음 안이라 레이드에서 같이 숨는다.
	_hud_root.add_child(Ui.name_plate(Vector2(pw_x, 26.0), Vector2(124.0, 22.0)))
	_lbl_name = _mk_label(Vector2(pw_x, 26.0), Type.SIZE_SMALL,
		Color(0.94, 0.90, 0.96))
	_lbl_name.size = Vector2(124.0, 22.0)
	_lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_name.clip_text = true
	# 초상·전투력을 누르면 군주의 기록(참고작 캐릭터 정보) — 투명 판정 버튼.
	var info_btn := Button.new()
	info_btn.flat = true
	info_btn.modulate = Color(1, 1, 1, 0)
	info_btn.size = Vector2(210.0, 54.0)
	info_btn.focus_mode = Control.FOCUS_NONE
	info_btn.pressed.connect(_show_info)
	_hud_root.add_child(info_btn)


# 이름을 확정한다. 못 쓰는 이름이면 **판을 안 닫고** 이유를 적는다 — 닫고 나서
# 안 바뀐 걸 발견하면 무엇이 잘못됐는지 알 길이 없다.
func _name_apply() -> void:
	var want := _clean_name(_name_edit.text)
	if want == "":
		_name_note.text = "이름을 적어 주세요"
		return
	hero_name = want
	_name_edit.text = want          # 다듬은 결과를 보여 준다
	_name_view.visible = false
	_refresh_hud()
	_save_game()


# 군주의 기록 (참고작 캐릭터 정보 판) — 전투력 + 능력치 + 배수의 출처 + 기록.
# 항목은 전부 **이미 있는 숫자의 집계**다. 이 판은 새 기계가 아니라 거울이다.
# "배수" 부는 사장님 요청(상세한 설명): 어느 시스템이 얼마를 얹는지 이름을 단다.
func _show_info() -> void:
	if _info_view == null:
		return
	for c in _info_body.get_children():
		c.queue_free()
	_info_power.text = "전투력  %s" % _n(Balance.combat_power(dps(), max_hp(),
		regen_per_sec()))
	var kills := 0.0
	for k in codex:
		kills += float(codex[k])
	var mins := int(play_sec / 60.0)
	# 치명 두 축은 Balance.crit_mult 와 같은 눈금으로 읽는다(1레벨 = 0%).
	# 기본 확률(BASE_CRIT)이 깔려 있다 — Balance.crit_mult 와 같은 눈금.
	var crit_pct := int(minf(100.0, Balance.BASE_CRIT * 100.0
		+ maxf(0.0, float(_stat_eff("crit")) - 1.0)))
	var critdmg := 1.5 + 0.05 * (float(_stat_eff("critdmg")) - 1.0) \
		+ _trait_add("critdmg") + RelicDefs.add("critdmg", relics) \
		+ _gear_stat("critdmg") * GEAR_CRITDMG \
		+ _collection_bonus("critdmg") + _boon("critdmg") \
		+ SkinDefs.bonus("critdmg", skins_owned)
	var sections: Array = [
		["능력치", [
			["평타 한 방", _n(_base_hit_damage() * (1.0 + _codex_act_bonus()))],
			["초당 피해", _n(dps())],
			["공격 속도", "초당 %.2f회" % (1.0 / attack_interval())],
			["체력", _n(max_hp())],
			["회복 (초당)", _n(regen_per_sec())],
			["치명타 확률", "%d%%" % crit_pct],
			["치명타 피해", "x%.2f" % critdmg],
		]],
		["배수 — 어디서 오는 힘인가", [
			["혈맥 (공격)", "x%.2f" % _trait_mult("attack")],
			["핏빛 회귀", "x%.2f" % _prestige_mult()],
			["시련", "x%.2f" % TrialDefs.mult(trial_stage)],
			["펫 동행 (공격)", "+%d%%" % int(round(_pet_mult("damage") * 100.0))],
			["지식 (도감 평균)", "+%d%%" % int(round(_codex_act_bonus() * 100.0))],
			["혈맹 (체력)", "+%d%%" % int(round(PactDefs.bonus(pact_lv) * 100.0))],
			["혈액 획득", "x%.2f" % gold_mult()],
		]],
		["기록", [
			["최고 구간", StageDefs.label(best_stage)],
			["핏빛 미궁", "%d층" % dungeon_best],
			["시련", "%d단계 격파" % trial_stage],
			["주간 보스", "%d단계" % boss_tier],
			["핏빛 회귀", "%d회" % prestige_count],
			["펫 도감", "%d / %d" % [pets_got.size(), PetDefs.PETS.size()]],
			["총 출석", "%d일" % attend_got],
			["총 처치", _n(kills)],
			["누적 소환", "%d회" % mileage],
			["함께한 밤", "%d시간 %d분" % [mins / 60, mins % 60]],
		]],
	]
	var y := 8.0
	for sec in sections:
		var head := _dlg_label(_info_body, Vector2(6.0, y), Type.SIZE_SMALL,
			Color(0.92, 0.82, 0.62), 460.0, 20.0)
		head.text = str(sec[0])
		y += 28.0
		for row in sec[1]:
			var l := _dlg_label(_info_body, Vector2(18.0, y), Type.SIZE_SMALL,
				Color(0.78, 0.76, 0.80), 230.0, 18.0)
			l.text = str(row[0])
			var v := _dlg_label(_info_body, Vector2(226.0, y), Type.SIZE_SMALL,
				Color(0.95, 0.93, 0.90), 240.0, 18.0)
			v.text = str(row[1])
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			y += 28.0
		y += 12.0
	_info_body.custom_minimum_size = Vector2(504.0 - Ui.SCROLL_W, y)
	_info_view.visible = true


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
	_confirm_view = _overlay(70)
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
	_reward_view = _overlay(71)
	var tap := Button.new()
	tap.flat = true
	tap.size = Vector2(Grid.BG)
	tap.focus_mode = Control.FOCUS_NONE
	tap.pressed.connect(func() -> void: _reward_view.visible = false)
	_reward_view.add_child(tap)
	# **창 높이를 칸에서 뽑는다.** 176 으로 박아 뒀더니 아이콘을 키우는 순간 글자가
	# 창 밖으로 흘러 아래 성장 창 위에 찍혔다(사장님 지적).
	var reward_h := 56.0 + REWARD_CELL.y + 16.0
	_reward_panel = Ui.panel(Vector2(48.0, 320.0), Vector2(DLG_W, reward_h))
	_reward_view.add_child(_reward_panel)
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
	# HBox 였다가 맨손 배치로 — 줄바꿈이 필요해졌다(_show_reward 가 좌표를 잰다).
	_reward_row = Control.new()
	_reward_row.position = Vector2(48.0, 376.0)
	_reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_view.add_child(_reward_row)
	# 안내는 **창 밖**에 둔다. 안에 넣으면 보상과 같은 무게로 읽혀서 눈이 한 번 더 멈춘다.
	_reward_hint = _dlg_label(_reward_view, Vector2(48.0, 320.0 + reward_h + 12.0),
		Type.SIZE_SMALL, Color(0.68, 0.66, 0.72), DLG_W, 20.0)
	_reward_hint.text = "빈 곳을 눌러 닫기"

	# 군주의 기록 — 내용은 열 때마다 다시 그린다(_show_info). 전부 집계라 싸다.
	# 래퍼런스 캐릭터 정보 판 문법: 프로필 버튼 셋(이름·외형·칭호) 아래 집계 스크롤.
	_info_view = _overlay(62)
	var itap := Button.new()
	itap.flat = true
	itap.size = Vector2(Grid.BG)
	itap.focus_mode = Control.FOCUS_NONE
	itap.pressed.connect(func() -> void: _info_view.visible = false)
	_info_view.add_child(itap)
	_info_view.add_child(Ui.panel(Vector2(24.0, 96.0), Vector2(528.0, 648.0)))
	var ititle := _dlg_label(_info_view, Vector2(24.0, 112.0), Type.SIZE_BODY,
		Color(1.0, 0.88, 0.55), 528.0, 32.0)
	ititle.text = "군주의 기록"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 버튼 셋 — 이름·외형·칭호. 셋 다 실제로 연다.
	var bw2 := (528.0 - 36.0 * 2.0 - 12.0 * 2.0) / 3.0
	for b2 in [["이름 변경", 0], ["외형 변경", 1], ["칭호 설정", 2]]:
		var idx: int = b2[1]
		var bb := Ui.button(str(b2[0]),
			Vector2(24.0 + 36.0 + (bw2 + 12.0) * float(idx), 152.0),
			Vector2(bw2, 40.0), Type.SIZE_SMALL)
		bb.pressed.connect(func() -> void:
			if idx == 2:
				_info_view.visible = false
				_codex_view.visible = true
				_codex_set_mode("title")
			elif idx == 1:
				# 외형 변경 — 그 자리에서 갈아입는다(사장님 2026-08-24:
				# "상점에서는 그냥 구매만"). 산 스킨을 고르는 자체 판.
				_refresh_outfit()
				_outfit_view.visible = true
			else:
				# 이름 변경 — 지금 이름을 넣어 둔다. 빈 칸에서 시작하면
				# 무엇을 바꾸는지가 안 보인다.
				_name_edit.text = _hero_name()
				_name_note.text = "%d글자까지" % NAME_MAX
				_name_view.visible = true
				_name_edit.grab_focus()
				_name_edit.select_all())
		_info_view.add_child(bb)
	_info_power = _dlg_label(_info_view, Vector2(24.0, 206.0), Type.SIZE_BODY,
		Color(1.0, 1.0, 1.0), 528.0, 34.0)
	_info_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var isc := Ui.scroll(Vector2(36.0, 250.0), Vector2(504.0, 470.0))
	_info_view.add_child(isc)
	_info_body = Control.new()
	_info_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	isc.add_child(_info_body)
	_info_note = _dlg_label(_info_view, Vector2(24.0, 726.0), Type.SIZE_SMALL,
		Color(0.98, 0.80, 0.55), 528.0, 20.0)
	_info_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_note.modulate.a = 0.0
	var ihint := _dlg_label(_info_view, Vector2(24.0, 752.0), Type.SIZE_SMALL,
		Color(0.68, 0.66, 0.72), 528.0, 20.0)
	ihint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ihint.text = "빈 곳을 눌러 닫기"

	# ── 이름 변경 판 ──────────────────────────────────────────────────────
	# 군주의 기록(62) 위에 뜬다. 이 게임의 **첫 글자 입력**이라 LineEdit 은
	# 여기 하나뿐이다 — 검사는 _clean_name 한 곳이 다 한다.
	_name_view = _overlay(64)
	var ntap := Button.new()
	ntap.flat = true
	ntap.size = Vector2(Grid.BG)
	ntap.focus_mode = Control.FOCUS_NONE
	ntap.pressed.connect(func() -> void: _name_view.visible = false)
	_name_view.add_child(ntap)
	_name_view.add_child(Ui.panel(Vector2(64.0, 300.0), Vector2(448.0, 260.0)))
	var ntitle := _dlg_label(_name_view, Vector2(64.0, 320.0), Type.SIZE_BODY,
		Color(1.0, 0.88, 0.55), 448.0, 32.0)
	ntitle.text = "이름 변경"
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(112.0, 376.0)
	_name_edit.size = Vector2(352.0, 44.0)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 여기서 막아도 붙여넣기·IME 는 새어 들어온다 — 진짜 검사는 확정할 때 한다.
	_name_edit.max_length = NAME_MAX
	_name_edit.add_theme_font_size_override("font_size", Type.SIZE_BODY)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _name_apply())
	_name_view.add_child(_name_edit)
	_name_note = _dlg_label(_name_view, Vector2(64.0, 428.0), Type.SIZE_SMALL,
		Color(0.90, 0.66, 0.62), 448.0, 20.0)
	var nok := Ui.button("확인", Vector2(176.0, 470.0), Vector2(224.0, 44.0),
		Type.SIZE_MID)
	nok.pressed.connect(_name_apply)
	_name_view.add_child(nok)

	# ── 외형 변경 판 — 산 스킨을 그 자리에서 갈아입는다 ───────────────────
	# 상점 의상실은 구매 전용이다(사장님 2026-08-24). 군주의 기록(62) 위에
	# 뜨므로 z 는 한 층 위.
	_outfit_view = _overlay(63)
	var otap := Button.new()
	otap.flat = true
	otap.size = Vector2(Grid.BG)
	otap.focus_mode = Control.FOCUS_NONE
	otap.pressed.connect(func() -> void: _outfit_view.visible = false)
	_outfit_view.add_child(otap)
	_outfit_view.add_child(Ui.panel(Vector2(24.0, 120.0), Vector2(528.0, 610.0)))
	var otitle := _dlg_label(_outfit_view, Vector2(24.0, 136.0), Type.SIZE_BODY,
		Color(1.0, 0.88, 0.55), 528.0, 32.0)
	otitle.text = "외형 변경"
	otitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in SkinDefs.SKINS.size():
		var sk2: Dictionary = SkinDefs.SKINS[i]
		var id2 := str(sk2["id"])
		var col := i % 3
		var row := i / 3
		var cell := Control.new()
		cell.position = Vector2(40.0 + float(col) * 168.0,
			184.0 + float(row) * 158.0)
		cell.size = Vector2(160.0, 148.0)
		_outfit_view.add_child(cell)
		var icon := Ui.icon("res://assets/anim/%s_idle/0.png" % id2,
			Vector2(32.0, 4.0), 96.0)
		icon.flip_h = true      # 소스는 왼쪽 보기 — 화면 규칙은 오른쪽
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var nm := _dlg_label(cell, Vector2(0.0, 106.0), Type.SIZE_SMALL,
			Color(0.92, 0.88, 0.86), 160.0, 20.0)
		nm.text = str(sk2["name"])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var st := _dlg_label(cell, Vector2(0.0, 126.0), Type.SIZE_SMALL,
			Color(0.72, 0.68, 0.72), 160.0, 18.0)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ob := Button.new()
		ob.flat = true
		ob.size = cell.size
		ob.focus_mode = Control.FOCUS_NONE
		ob.pressed.connect(_outfit_pick.bind(id2))
		cell.add_child(ob)
		_outfit_cells.append({"root": cell, "icon": icon, "name": nm,
			"state": st, "btn": ob})
	_outfit_note = _dlg_label(_outfit_view, Vector2(24.0, 680.0),
		Type.SIZE_SMALL, Color(0.98, 0.80, 0.55), 528.0, 20.0)
	_outfit_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outfit_note.modulate.a = 0.0
	var ohint := _dlg_label(_outfit_view, Vector2(24.0, 704.0), Type.SIZE_SMALL,
		Color(0.68, 0.66, 0.72), 528.0, 20.0)
	ohint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ohint.text = "빈 곳을 눌러 닫기"



# 화면 전체를 덮는 반투명 판. 뒤 화면이 비쳐야 "어느 창 위에 떴는지"가 읽힌다.
# 전면 판을 **입력에서도 맨 위**로 올린다. z_index 는 그리기 순서만 바꾼다 —
# 클릭은 형제 중 **나중 자식**이 먼저 받으므로, 늦게 지어진 위젯(가이드 카드
# 등)이 판 위를 가로챈다(사장님 2026-08-25: 조합 창에서 가이드 보상이 눌렸다).
func _front(view: Control) -> void:
	if view and view.get_parent():
		view.get_parent().move_child(view, -1)


func _overlay(z: int) -> Control:
	var c := Control.new()
	c.size = Vector2(Grid.BG)
	c.visible = false
	c.z_index = z
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	# **화면보다 크게.** 팝인이 0.92 배로 줄였다 펴는데 딱 맞으면 그 사이
	# 가장자리 23px 가 안 덮인다 — 어두워지다 만 테두리가 번쩍인다.
	dim.size = Vector2(Grid.BG) * 1.25
	dim.position = -Vector2(Grid.BG) * 0.125
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	_hud_root.add_child(c)
	Ui.pop_in(c)   # 공장에서 건다 — 늦게 만드는 판도 빠지지 않는다
	return c


# 사람이 친 글자다 — **믿지 않는다.** 라벨이 Label(RichTextLabel 이 아니다)이라
# 태그 주입은 없지만, 줄바꿈 하나면 판이 밀리고 공백만 친 이름은 화면에서
# 사라진 것처럼 보인다. 제어문자를 걷고 앞뒤 공백을 자르고 길이를 끊는다.
static func _clean_name(raw: String) -> String:
	var out := ""
	for ch in raw:
		var c := ch.unicode_at(0)
		if c < 32 or c == 127:
			continue
		out += ch
	# 자르고 나서 한 번 더 다듬는다 — 여덟 글자째가 공백이면 꼬리가 남는다.
	return out.strip_edges().substr(0, NAME_MAX).strip_edges()


# 화면에 쓸 이름. 빈 값이면 기본값 — 판이 비어 있으면 고장으로 읽힌다.
func _hero_name() -> String:
	return hero_name if hero_name != "" else NAME_DEFAULT


func _dlg_label(parent: Control, pos: Vector2, size: int, col: Color,
		w: float, h: float) -> Label:
	var l := Ui.label("", pos, size, col)
	l.size = Vector2(w, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


# ── 클리어 연출 ────────────────────────────────────────────────────────────
# 던전이 끝나면 전투 띠 왼쪽 위 알림 한 줄만 떴는데, 그건 판이 끝났다는 신호로
# 너무 약했다 — 화면이 뜬금없이 넘어가는 것으로 읽혔다(사장님 2026-08-25:
# "걍 모든 던전들 클리어하면 클리어했다 나와야할듯"). 가운데에 크게 띄운다.
# 그 알림 줄은 2026-08-27 에 통째로 걷어냈다(사장님: "저 위치에 뜨는 텍스트 싹 다").
# 이제 판이 끝났다는 것을 말하는 건 이 클리어 연출 하나다.
var _clear_view: Control
var _clear_title: Label
var _clear_sub: Label


func _build_clear_view() -> void:
	_clear_view = Control.new()
	_clear_view.size = Vector2(Grid.BG)
	_clear_view.visible = false
	_clear_view.z_index = 80
	_clear_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_clear_view)
	_clear_title = _dlg_label(_clear_view, Vector2(0.0, 330.0), Type.SIZE_TITLE,
		Color(1.0, 0.90, 0.55), float(Grid.BG.x), 48.0)
	_shop_outline(_clear_title, 10)
	_clear_sub = _dlg_label(_clear_view, Vector2(0.0, 386.0), Type.SIZE_BODY,
		Color(0.94, 0.90, 0.94), float(Grid.BG.x), 30.0)
	_shop_outline(_clear_sub, 6)


func _show_clear(title: String, sub: String) -> void:
	if _clear_view == null or not is_inside_tree():
		return
	_clear_title.text = title
	_clear_sub.text = sub
	_front(_clear_view)
	_clear_view.visible = true
	_clear_view.modulate.a = 0.0
	_clear_view.pivot_offset = Vector2(Grid.BG) * 0.5
	_clear_view.scale = Vector2(0.82, 0.82)
	var tw := create_tween()
	tw.tween_property(_clear_view, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_clear_view, "scale", Vector2.ONE, 0.26) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(CLEAR_HOLD - 0.62)
	tw.tween_property(_clear_view, "modulate:a", 0.0, 0.24)
	tw.tween_callback(func() -> void: _clear_view.visible = false)


func _ask(text: String, on_ok: Callable) -> void:
	_confirm_body.text = text
	_confirm_action = on_ok
	_front(_confirm_view)      # 어떤 판 위에서든 확인은 맨 위다
	_confirm_view.visible = true


# 보상 칸. 아이콘이 64px 이라 **뭘 받았는지 한눈에 안 들어왔다**(사장님 지적) —
# 96 으로 키운다. 창(DLG_W 480)엔 한 줄 3칸(3x116+틈32=380)이 한계라
# 넷째 재화부터 _show_reward 가 줄을 바꾼다(사장님: 둥지 정산 4칸이 잘렸다).
const REWARD_BOX := 96.0
const REWARD_CELL := Vector2(116.0, 140.0)


# entries: [{"icon": 경로, "label": "정수 +1.2k"}, ...]
func _show_reward(title: String, entries: Array) -> void:
	if _reward_title == null:
		return   # 화면 없이 도는 계측기 — 받기는 이미 끝났고 그릴 창만 없다
	_reward_title.text = title
	for child in _reward_row.get_children():
		child.queue_free()
	# 한 줄 3칸 — 4칸(4x116+틈48=512)은 창(480)을 넘쳐 끝 재화가 잘렸다(사장님).
	# 넷째부터 **한 칸 내려** 놓고 창 높이·안내 위치도 줄 수에 맞춘다.
	var per := 3
	var rows := int(ceil(float(entries.size()) / float(per)))
	var reward_h := 56.0 + float(rows) * REWARD_CELL.y + float(rows - 1) * 8.0 + 16.0
	_reward_panel.size = Vector2(DLG_W, reward_h)
	_reward_hint.position.y = 320.0 + reward_h + 12.0
	for i in entries.size():
		var e: Dictionary = entries[i]
		var r := floori(float(i) / float(per))
		var in_row := mini(per, entries.size() - r * per)
		var row_w := float(in_row) * REWARD_CELL.x + float(in_row - 1) * 16.0
		var cell := Control.new()
		cell.position = Vector2(
			(DLG_W - row_w) * 0.5 + float(i % per) * (REWARD_CELL.x + 16.0),
			float(r) * (REWARD_CELL.y + 8.0))
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 등급 틀을 두르면 무엇을 얻었는지가 **색으로 먼저** 읽힌다. 이름만 있으면
		# 커먼을 받았는지 레전더리를 받았는지 글자를 다 읽어야 안다.
		var col := Color(e["col"]) if e.has("col") else Color(1, 1, 1)
		var pad := (REWARD_CELL.x - REWARD_BOX) * 0.5
		if e.has("col"):
			var frame := Ui.image("res://assets/ui/slot_common.png",
				Vector2(pad, 0.0), Vector2(REWARD_BOX, REWARD_BOX))
			frame.modulate = col
			cell.add_child(frame)
			# 틀 안쪽 구멍(slot_common 은 40x40 에 테두리 4)에 맞춰 넣는다.
			cell.add_child(Ui.icon(str(e.get("icon", "")),
				Vector2(pad + REWARD_BOX * 0.1, REWARD_BOX * 0.1), REWARD_BOX * 0.8))
		else:
			cell.add_child(Ui.icon(str(e.get("icon", "")),
				Vector2(pad, 0.0), REWARD_BOX))
		var lbl := _panel_label(cell, Vector2(0.0, REWARD_BOX + 4.0), Type.SIZE_SMALL,
			Color(0.95, 0.92, 0.88), REWARD_CELL.x, 18.0)
		lbl.text = str(e.get("label", ""))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if e.has("sub"):
			var sub := _panel_label(cell, Vector2(0.0, REWARD_BOX + 22.0), Type.SIZE_SMALL,
				col, REWARD_CELL.x, 18.0)
			sub.text = str(e["sub"])
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reward_row.add_child(cell)
	_front(_reward_view)
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
const PANEL_AT := Vector2(0, 26)
const PANEL_SIZE := Vector2(36, 24)
# 창 안쪽 여백. 창마다 다른 값을 쓰면 어느 창은 글자가 테두리에 닿는다 — 여기 하나만 본다.
const PAD := 26.0   # 패널 테두리(Ui.PANEL_MARGIN=12)보다 넉넉히 안쪽
const PANEL_W := 576.0
const PANEL_H := 384.0
const CONTENT_W := PANEL_W - PAD * 2.0    # 528
const CONTENT_BOTTOM := PANEL_H - PAD     # 358
# 전면 판 — **화면 꼭대기부터** 하단 네비까지(사장님: 상단 HUD·사이드 아이콘도
# 다 가리고 완전 전체 화면). 레퍼런스처럼 장소 헤더 + 큰 카드 진열이 들어가는
# 탭들이 쓴다. 나머지 탭은 반판(전투가 보인다) 유지.
const FULL_TABS := ["shop", "summon", "raid", "pet"]
const PANEL_FULL_H := 800.0               # Grid.uv 50칸 — 네비(96) 위 전부
const FULL_BOTTOM := PANEL_FULL_H - PAD   # 774


func _build_panels() -> void:
	# 콘텐츠와 탭바는 별도 판이다. 한 장으로 덮으면 하단 메뉴가 콘텐츠에 붙어 보인다.
	# 배경 판이 둘이다: 반판(전투가 보인다)과 전면 판(레퍼런스 문법 — 상점·도전·
	# 소환은 진열이 커서 반판 384 에 안 담긴다. 사장님 2026-08-13). 방치형에서
	# 전투는 배경 소음이라 가려도 잃는 게 없다.
	_panel_bg = Ui.panel(Grid.uv(0, 26), Grid.uv(36, 24))
	_hud_root.add_child(_panel_bg)
	_panel_bg_full = Ui.panel(Grid.uv(0, 0), Grid.uv(36, 50))
	_panel_bg_full.visible = false
	_hud_root.add_child(_panel_bg_full)
	for name in ["growth", "gear", "summon", "raid", "shop", "pet"]:
		var full: bool = name in FULL_TABS
		var c := Control.new()
		c.position = Grid.pxv(Grid.uv(PANEL_AT.x, 0 if full else PANEL_AT.y))
		c.size = Grid.uv(PANEL_SIZE.x, 50 if full else PANEL_SIZE.y)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(c)
		_panels[name] = c
	_build_growth(_panels["growth"])
	await _load_tick(0.27)
	_build_gear(_panels["gear"])
	await _load_tick(0.38)
	_build_gacha(_panels["summon"])
	await _load_tick(0.48)
	_build_shop(_panels["shop"])
	await _load_tick(0.58)
	_build_raids(_panels["raid"])
	await _load_tick(0.68)
	_build_pet(_panels["pet"])
	await _load_tick(0.76)


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
# -1 = MAX(지금 혈액으로 살 수 있는 만큼). 레벨이 네 자리가 되면서 x100 으로도
# 손이 아프다 — 참고작·업계 표준(AdVenture Capitalist)이 이 네 칸이다.
const BUY_STEPS := [1, 10, 100, -1]
const ROW_H := 60.0
const STEP_H := 40.0


func _build_growth(root: Control) -> void:
	# 탭바가 꽉 차서 새 탭으로 못 낸다. 성장 창 안에서 나눈다 —
	# 스탯도 스킬도 혈맥도 "무엇을 키울까"라서 자리가 맞다.
	var modes := [["stat", "스탯"], ["skill", "스킬"], ["trait", "혈맥"],
		["pact", "혈맹"], ["relic", "유물"], ["prestige", "회귀"]]
	var mode_w := (CONTENT_W - 12.0 * float(modes.size() - 1)) / float(modes.size())
	# 성장은 **내 피를 다루는 곳**이라 전용 세트를 뽑았다(sets/blood_*).
	# 켬/끔 그림이 따로 없어 밝기로 가른다 — 켠 쪽만 제 색이고 나머지는 눌린다.
	for i in modes.size():
		var mode: String = modes[i][0]
		var mb := TextureButton.new()
		mb.texture_normal = Assets.tex("res://assets/ui/sets/blood_tab.png")
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_SCALE
		mb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mb.toggle_mode = true
		mb.position = Vector2(PAD + float(i) * (mode_w + 12.0), PAD - 4.0)
		mb.size = Vector2(mode_w, 34.0)
		Ui.hover_pop(mb)
		mb.pressed.connect(func() -> void: _set_growth_mode(mode))
		root.add_child(mb)
		var ml := _panel_label(root, Vector2(mb.position.x, PAD + 3.0),
			Type.SIZE_SMALL, Color(1.0, 0.96, 0.92), mode_w, 20.0)
		ml.text = str(modes[i][1])
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(ml, 6)
		_growth_mode_buttons[mode] = mb
		_growth_mode_labels[mode] = ml

	_stat_view = Control.new()
	_stat_view.size = Vector2(PANEL_W, PANEL_H)
	_stat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stat_view)
	var top := PAD + 38.0
	var gap := 16.0
	# 배수 넷 + [초기화] 다섯 칸. 초기화는 자주 누를 것이 아니라 폭을 절반만 준다.
	var reset_w := 62.0
	var step_w := (CONTENT_W - reset_w - gap * float(BUY_STEPS.size())) \
		/ float(BUY_STEPS.size())
	for i in BUY_STEPS.size():
		var n: int = BUY_STEPS[i]
		var b := Ui.button("MAX" if n < 0 else "x%d" % n,
			Vector2(PAD + i * (step_w + gap), top), Vector2(step_w, STEP_H),
			Type.SIZE_SMALL)
		# 선택 표시는 toggle 로 한다. disabled 로 하면 글자가 흐려져 "선택됨"이 아니라
		# "못 누름"으로 읽힌다.
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _set_step(n))
		_stat_view.add_child(b)
		_step_btns.append(b)
	var rb := Ui.button("초기화",
		Vector2(PAD + CONTENT_W - reset_w, top), Vector2(reset_w, STEP_H),
		Type.SIZE_SMALL)
	rb.pressed.connect(_ask_full_reset)
	_stat_view.add_child(rb)

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
	_build_trait_view(root)
	_build_pact_view(root)
	_build_relic_view(root)
	_build_prestige_view(root)
	_set_step(buy_step)   # 처음 열었을 때도 선택된 배수가 보이게
	_set_growth_mode("stat")


func _set_growth_mode(mode: String) -> void:
	_growth_mode = mode
	_stat_view.visible = mode == "stat"
	_skill_view.visible = mode == "skill"
	_trait_view.visible = mode == "trait"
	_pact_view.visible = mode == "pact"
	_relic_view.visible = mode == "relic"
	_prestige_view.visible = mode == "prestige"
	for key in _growth_mode_buttons:
		var on: bool = key == mode
		_growth_mode_buttons[key].set_pressed_no_signal(on)
		# 켬/끔 그림이 따로 없으니 **밝기가 선택 표시**다.
		_growth_mode_buttons[key].modulate = Color(1, 1, 1) if on \
			else Color(0.52, 0.46, 0.50)
		if _growth_mode_labels.has(key):
			_growth_mode_labels[key].modulate = Color(1, 1, 1) if on \
				else Color(0.72, 0.68, 0.70)
	if mode == "skill":
		_refresh_skills()
	elif mode == "trait":
		_refresh_traits()
	elif mode == "prestige":
		_refresh_prestige()
	elif mode == "pact":
		_refresh_pact()
	elif mode == "relic":
		_refresh_relics()
	else:
		_refresh_growth()


# ── 유물 화면 (RelicDefs) ───────────────────────────────────────────────────
# 12칸 격자 하나. 유물은 **고르는 축이 아니라 모으는 축**이라(장착도 구매도 없다)
# 화면이 할 일은 "무엇을 가졌고 다음은 무엇인가"를 보여 주는 것뿐이다.
var _relic_view: Control
var _relic_icons: Array[TextureRect] = []
var _relic_names: Array[Label] = []
var _relic_effs: Array[Label] = []
var _relic_head: Label
# 4열은 글자 칸이 66px 뿐이라 효과가 통째로 잘렸다(실측). 3열이면 100px 넘는다.
# 18종이라 6줄이고 창을 넘으므로 스크롤 안에 담는다.
const RELIC_COLS := 3
const RELIC_CELL := Vector2(168.0, 72.0)


# 회귀 판 — 지금 혈흔·배율, 이번에 받을 몫, 그리고 무엇이 남는지.
# **무엇이 사라지는지를 반드시 적는다**: 되돌릴 수 없는 버튼이라 누르기 전에
# 알아야 한다(임무판·상점과 달리 여기는 한 번 누르면 끝이다).
var _prestige_view: Control
var _pr_now: Label
var _pr_gain: Label
var _pr_keep: Label
var _pr_btn: Button
var _pr_btn_tex: TextureRect
var _pr_btn_lbl: Label


func _build_prestige_view(root: Control) -> void:
	_prestige_view = Control.new()
	_prestige_view.size = Vector2(PANEL_W, PANEL_H)
	_prestige_view.visible = false
	_prestige_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prestige_view)
	var top := PAD + 46.0
	var title := _panel_label(_prestige_view, Vector2(0.0, top), Type.SIZE_MID,
		Color(0.98, 0.72, 0.72), PANEL_W, 26.0)
	title.text = "핏빛 회귀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(title, 6)
	_pr_now = _panel_label(_prestige_view, Vector2(0.0, top + 36.0), Type.SIZE_MID,
		Color(0.98, 0.90, 0.70), PANEL_W, 24.0)
	_pr_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_pr_now, 6)
	_pr_gain = _panel_label(_prestige_view, Vector2(0.0, top + 72.0), Type.SIZE_SMALL,
		Color(0.86, 0.90, 0.98), PANEL_W, 20.0)
	_pr_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_pr_gain, 5)
	_pr_keep = _panel_label(_prestige_view, Vector2(PAD, top + 100.0),
		Type.SIZE_SMALL, Color(0.80, 0.78, 0.82), CONTENT_W, 66.0)
	_pr_keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 세 줄로 나눈다 — "남는 것"을 한 줄에 이으면 폭을 넘어 잘린다(실측).
	# 무엇이 사라지는지는 이 판에서 가장 중요한 글이라 잘리면 안 된다.
	_pr_keep.text = "잃는 것 — 구간 · 스탯 레벨 · 혈액\n" \
		+ "남는 것 — 장비 · 스킬 · 유물 · 미궁 기록\n" \
		+ "도감 · 칭호 · 혈맹 · 혈맥 · 혈정 · 인장"
	_shop_outline(_pr_keep, 5)
	# 되돌릴 수 없는 버튼 — 혈액 세트의 붉은 판이 이 자리에 맞는다.
	var bx := Vector2((PANEL_W - 220.0) * 0.5, top + 184.0)
	_pr_btn_tex = _shop_tex(_prestige_view, "res://assets/ui/sets/blood_button.png",
		bx, Vector2(220.0, 52.0))
	_pr_btn_lbl = _panel_label(_prestige_view, Vector2(bx.x, bx.y + 15.0),
		Type.SIZE_MID, Color(1.0, 0.95, 0.92), 220.0, 24.0)
	_pr_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_pr_btn_lbl, 8)
	_pr_btn = _shop_ghost(_prestige_view, Vector2(220.0, 52.0), _pr_btn_tex)
	_pr_btn.position = bx
	# **한 번 더 묻는다.** 되돌릴 수 없는 일은 확인 창을 지난다(공용 _confirm).
	_pr_btn.pressed.connect(func() -> void:
		_ask("%d구간을 접고 혈흔 %d 을 받습니다.\n구간·스탯·혈액이 처음으로 돌아갑니다.\n\n되돌릴 수 없습니다."
			% [best_stage, PrestigeDefs.marks_for(best_stage, prestige_peak)],
			_prestige_do))
	_refresh_prestige()


func _refresh_prestige() -> void:
	if _pr_now == null:
		return
	_pr_now.text = "혈흔 %d  ·  공격 x%.2f" % [prestige_marks, _prestige_mult()]
	var got := PrestigeDefs.marks_for(best_stage, prestige_peak)
	var can := got > 0
	if can:
		# 받고 나면 얼마나 더 갈 수 있는지 — 그게 이 버튼을 누르는 이유다.
		var after := PrestigeDefs.stages_worth(prestige_marks + got)
		var now := PrestigeDefs.stages_worth(prestige_marks)
		_pr_gain.text = "이번 회귀: 혈흔 +%d  ·  구간 +%d 만큼 더" % [got, after - now]
		_pr_btn_lbl.text = "회귀 %d회" % (prestige_count + 1)
	else:
		# **얼마나 더 가야 하는지를 적는다** — 이 판의 유일한 잠금 이유다.
		_pr_gain.text = "%d구간까지 가면 열린다" % PrestigeDefs.next_stage(prestige_peak)
		_pr_btn_lbl.text = "잠김"
	_pr_btn.disabled = not can
	_gate_btn_dim(_pr_btn_tex, _pr_btn_lbl, not can)


func _build_relic_view(root: Control) -> void:
	_relic_view = Control.new()
	_relic_view.size = Vector2(PANEL_W, PANEL_H)
	_relic_view.visible = false
	_relic_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_relic_view)
	_relic_head = _panel_label(_relic_view, Vector2(PAD, PAD + 40.0), Type.SIZE_SMALL,
		Color(0.92, 0.82, 0.62), CONTENT_W, 20.0)
	# 18종이면 6줄이라 창(384)을 넘는다 — 스크롤 안에 격자를 둔다.
	var top := PAD + 64.0
	var sc := Ui.scroll(Vector2(PAD, top), Vector2(CONTENT_W, CONTENT_BOTTOM - top))
	_relic_view.add_child(sc)
	var grid := Control.new()
	var rows := int(ceil(float(RelicDefs.RELICS.size()) / float(RELIC_COLS)))
	grid.custom_minimum_size = Vector2(CONTENT_W - Ui.SCROLL_W,
		float(rows) * RELIC_CELL.y)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(grid)
	# 스크롤 안쪽 폭이 줄어든 만큼 칸도 좁아진다.
	var cell_w := (CONTENT_W - Ui.SCROLL_W) / float(RELIC_COLS)
	for i in RelicDefs.RELICS.size():
		var r: Dictionary = RelicDefs.RELICS[i]
		var at := Vector2(float(i % RELIC_COLS) * cell_w,
			float(i / RELIC_COLS) * RELIC_CELL.y)
		var cell := Control.new()
		cell.position = at
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		# 등급 틀을 두른다 — 무엇이 귀한지가 색으로 먼저 읽힌다(소환 결과와 같은 규칙).
		var frame := Ui.image("res://assets/ui/slot_common.png", Vector2(2.0, 4.0),
			Vector2(46.0, 46.0))
		frame.modulate = Color(GachaDefs.rarity(str(r["rarity"]))["col"])
		cell.add_child(frame)
		var ic := Ui.icon(RelicDefs.icon_path(r), Vector2(7.0, 9.0), 36.0)
		cell.add_child(ic)
		_relic_icons.append(ic)
		_relic_names.append(_panel_label(cell, Vector2(56.0, 2.0), Type.SIZE_SMALL,
			Color(0.92, 0.82, 0.62), cell_w - 62.0, 18.0))
		_relic_effs.append(_panel_label(cell, Vector2(56.0, 22.0), Type.SIZE_SMALL,
			Color(0.72, 0.72, 0.80), cell_w - 62.0, 36.0))


func _refresh_relics() -> void:
	var got := 0
	for i in RelicDefs.RELICS.size():
		var r: Dictionary = RelicDefs.RELICS[i]
		var id := str(r["id"])
		var lv := RelicDefs.level_of(id, relics)
		if lv > 0:
			got += 1
		_relic_icons[i].modulate = Color(1, 1, 1) if lv > 0 else Color(0.22, 0.20, 0.26)
		_relic_names[i].text = str(r["name"]) if lv > 0 else "???"
		_relic_names[i].add_theme_color_override("font_color",
			Color(0.92, 0.82, 0.62) if lv > 0 else Color(0.5, 0.48, 0.55))
		if lv <= 0:
			_relic_effs[i].text = "미발견"
			continue
		# **효과가 첫 줄을 통째로 쓴다.** 앞에 "N단계 ·"를 붙였더니 110px 에서
		# 정작 중요한 %가 잘렸다(실측: "1단계 · 공격"). 단계는 아래 줄로 내린다.
		var eff := RelicDefs.effect_text(r, lv)
		if lv >= RelicDefs.MAX_LV:
			_relic_effs[i].text = "%s
%d단계 · 만렙" % [eff, lv]
		else:
			var sh := int(gacha_shards.get("relic:" + id, 0))
			# "조각"이라는 낱말까지 넣으면 정작 숫자가 잘린다(실측: "1단계 · 조각").
			_relic_effs[i].text = "%s
%d단계 · %d/%d" % [eff, lv, sh,
				RelicDefs.SHARDS_PER_LV]
	_relic_head.text = "유물 %d / %d  ·  소환으로 모은다 (%d구간부터)" % [
		got, RelicDefs.RELICS.size(), RelicDefs.OPEN_STAGE]


# ── 혈맹 화면 (PactDefs) ────────────────────────────────────────────────────
# 참고작 투혼과 같은 자리: 별 등급 + 레벨 + 전용 재화 하나. 화면도 단순해야 한다 —
# 별 줄 · 큰 레벨 · 효과 두 줄 · 레벨업 버튼(x1/x10).
var _pact_view: Control
var _pact_sigil: Label
var _pact_stars: Label
var _pact_level: Label
var _pact_eff: Label
var _pact_btns := {}


func _build_pact_view(root: Control) -> void:
	_pact_view = Control.new()
	_pact_view.size = Vector2(PANEL_W, PANEL_H)
	_pact_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pact_view.visible = false
	root.add_child(_pact_view)
	var top := PAD + 38.0
	# 인장 잔액 — 혈맥의 혈정 칸과 같은 문법.
	_pact_view.add_child(Ui.currency_bar(Vector2(PAD + CONTENT_W / 2.0 - 80.0, top),
		Vector2(160.0, 26.0)))
	_pact_view.add_child(Ui.icon("res://assets/ui/res_sigil.png",
		Vector2(PAD + CONTENT_W / 2.0 - 72.0, top + 3.0), 20.0))
	_pact_sigil = _panel_label(_pact_view,
		Vector2(PAD + CONTENT_W / 2.0 - 46.0, top), Type.SIZE_SMALL,
		Color(0.92, 0.82, 0.62), 118.0, 26.0)
	_pact_sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pact_view.add_child(Ui.card(Vector2(PAD - 8.0, top + 34.0),
		Vector2(CONTENT_W + 16.0, 150.0)))
	_pact_stars = _panel_label(_pact_view, Vector2(PAD, top + 44.0), Type.SIZE_MID,
		Color(0.98, 0.82, 0.45), CONTENT_W, 26.0)
	_pact_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pact_level = _panel_label(_pact_view, Vector2(PAD, top + 74.0), Type.SIZE_TITLE,
		Color(0.96, 0.90, 0.86), CONTENT_W, 40.0)
	_pact_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pact_eff = _panel_label(_pact_view, Vector2(PAD, top + 122.0), Type.SIZE_SMALL,
		Color(0.82, 0.88, 0.72), CONTENT_W, 40.0)
	_pact_eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pact_eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bw := (CONTENT_W - 16.0) * 0.5
	for i in 2:
		var n := 1 if i == 0 else 10
		var b := Ui.button("", Vector2(PAD + float(i) * (bw + 16.0), top + 200.0),
			Vector2(bw, 48.0), Type.SIZE_MID)
		Ui.cost_icon(b, "res://assets/ui/res_sigil.png", 20)
		b.pressed.connect(func() -> void: _pact_up(n))
		_pact_view.add_child(b)
		_pact_btns[n] = b
	var note := _panel_label(_pact_view, Vector2(PAD, top + 256.0), Type.SIZE_SMALL,
		Color(0.62, 0.60, 0.68), CONTENT_W, 16.0)
	# "에서만" 이 거짓이었다 — 인장은 제단 말고도 상점(교환 탭)·성장팩·펫 원정
	# 에서 나온다(2026-08-27 전수). 상점에서 인장을 사고 이 줄을 읽으면 둘 중
	# 하나가 거짓말이다. 어디가 주력인지만 말한다.
	note.text = "인장은 계약의 제단(던전)에서 가장 많이 나온다"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# n 레벨 값. 상한 앞에서는 닿을 만큼만 — 훈련(_step_for)과 같은 규칙이다.
func _pact_cost(n: int) -> float:
	var sum := 0.0
	for k in n:
		sum += PactDefs.cost(pact_lv + k)
	return sum


func _pact_steps(n: int) -> int:
	return mini(n, PactDefs.level_cap() - pact_lv)


func _pact_up(n: int) -> void:
	var steps := _pact_steps(n)
	if steps <= 0:
		return
	var cost := _pact_cost(steps)
	if sigil < cost:
		return
	var old_max := max_hp()
	sigil -= cost
	pact_lv += steps
	_apply_hp_growth(old_max)
	_refresh_pact()
	_refresh_hud()
	_save_game()


func _refresh_pact() -> void:
	if _pact_view == null:
		return
	_pact_sigil.text = _n(sigil)
	var st := PactDefs.stars(pact_lv)
	_pact_stars.text = "%s%s" % ["★".repeat(st), "☆".repeat(PactDefs.STAR_MAX - st)]
	# **"Lv." 금지** — 이 블랙레터 폰트에서 "LD" 로 읽힌다(3318줄 주석의 그 함정을
	# 여기서 다시 밟았다: 화면에 "LD.168" 로 나왔다). 한글 단위가 항상 안전하다.
	_pact_level.text = "%d레벨" % pact_lv
	var b := PactDefs.bonus(pact_lv)
	_pact_eff.text = "공격력 +%d%%  ·  체력 +%d%%\n다음 별까지 %d레벨" \
		% [int(b * 100.0), int(b * 100.0),
		PactDefs.STAR_EVERY - pact_lv % PactDefs.STAR_EVERY] \
		if st < PactDefs.STAR_MAX \
		else "공격력 +%d%%  ·  체력 +%d%%\n만렙" % [int(b * 100.0), int(b * 100.0)]
	for n in _pact_btns:
		var steps := _pact_steps(int(n))
		var btn: Button = _pact_btns[n]
		if steps <= 0:
			btn.text = "만렙"
			btn.disabled = true
			continue
		btn.text = "x%d  %s" % [steps, _n(_pact_cost(steps), true)]
		btn.disabled = sigil < _pact_cost(steps)


# ── 혈맥 화면 ──────────────────────────────────────────────────────────────
# 가지 3열 x 노드 6줄. 노드 버튼 하나에 이름·효과·비용(또는 잠긴 이유)을 다 적는다 —
# 왜 안 되는지가 안 보이면 잠긴 축은 없는 축이다(TraitDefs.lock_reason).
var _trait_view: Control
var _trait_nodes := {}                    # id -> {frame, icon, lv}
var _trait_links: Array[Dictionary] = []  # 노드 사이 ㄴ자 연결 {from, a, b}
var _trait_sel := ""                      # 고른 노드 — 상세와 구매가 이 하나를 본다
var _trait_info: Label
var _trait_buy: Button
var _trait_head: Label


# 노드 종류 → 아이콘. 스탯 창이 쓰는 그림을 그대로 빌린다 — 같은 능력치는
# 어느 창에서든 같은 그림이어야 배우는 값이 한 번이다.
const TRAIT_ICON := {"attack": "stat_damage", "critdmg": "stat_critdmg",
	"skill": "summon_skill", "hp": "stat_tough", "regen": "stat_regen",
	"guard": "summon_armor", "gold": "res_blood", "hours": "stat_sleep",
	"sweep": "res_crystal"}
const BRANCH_ICON := {"attack": "stat_damage", "life": "stat_tough",
	"wealth": "res_blood"}


# 혈맥은 **한 줄기 덩굴**이다 (사장님 + 레퍼런스): 18노드가 하나의 길로
# 아래에서 위로 오르고, 길이 가운데·오른쪽·가운데·왼쪽으로 굽으며 이어진다.
# 노드는 크게(64px), 레벨은 노드 밑에 "n/10", 전체는 **스크롤**로 본다 —
# 레퍼런스 특성 화면의 그 생김새다.
# 잠금도 화면과 같다: 줄기의 바로 앞 노드를 만렙(10) 찍어야 다음이 열린다.
# 칸 88 (사장님: 두 번 키웠다 64 -> 76 -> 88). 선은 **노드 중심까지 통으로**
# 긋는다 — 테두리에서 끊으면 끝이 칸에 안 닿아 떠 보이고(실측), 마디마다
# 두른 검은 테가 이음매를 갈라 보이게 했다. 선을 먼저 깔고 노드가 위에서
# 덮으므로 칸 안쪽은 어차피 안 보인다 — 접점과 이음매가 공짜로 완벽해진다.
const TRAIT_NODE := 88.0
const TRAIT_ROW := 120.0       # 노드 한 단의 세로 간격
const TRAIT_SPREAD := 150.0    # 가운데에서 좌우로 굽는 폭
const TRAIT_LINE := 8.0        # 줄기 두께


func _build_trait_view(root: Control) -> void:
	_trait_view = Control.new()
	_trait_view.size = Vector2(PANEL_W, PANEL_H)
	_trait_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trait_view.visible = false
	root.add_child(_trait_view)
	# 혈정 잔액 — 위 가운데.
	var top := PAD + 30.0
	_trait_view.add_child(Ui.currency_bar(Vector2(PAD + CONTENT_W * 0.5 - 75.0, top),
		Vector2(150.0, 26.0)))
	_trait_view.add_child(Ui.icon("res://assets/ui/res_crystal.png",
		Vector2(PAD + CONTENT_W * 0.5 - 67.0, top + 3.0), 20.0))
	_trait_head = _panel_label(_trait_view, Vector2(PAD + CONTENT_W * 0.5 - 41.0, top),
		Type.SIZE_SMALL, Color(1.0, 0.55, 0.62), 108.0, 26.0)
	# 덩굴 캔버스 — 스크롤 안에 산다. 18단이라 화면보다 훨씬 길다.
	var sc_y := top + 34.0
	var sc_h := CONTENT_BOTTOM - sc_y - 44.0
	var scroll := Ui.scroll(Vector2(PAD, sc_y), Vector2(CONTENT_W, sc_h))
	_trait_view.add_child(scroll)
	var seq := TraitDefs.order()
	var canvas_w := CONTENT_W - Ui.SCROLL_W
	var canvas_h := float(seq.size()) * TRAIT_ROW + 40.0
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)
	scroll.add_child(canvas)
	var cx := canvas_w * 0.5
	# 길이 굽는 무늬: 가운데 -> 오른쪽 -> 가운데 -> 왼쪽 -> ... (레퍼런스의 덩굴)
	var sway := [0.0, 1.0, 0.0, -1.0]
	# 자리 먼저 다 계산한다 — 선을 노드보다 **먼저** 깔아야 칸을 안 침범하고,
	# 선은 칸 테두리에서 멈춰야 한다(가운데까지 이으면 칸 위를 지나간다).
	var centers: Array[Vector2] = []
	for i in seq.size():
		var x := cx + float(sway[i % sway.size()]) * TRAIT_SPREAD
		var y := canvas_h - 30.0 - TRAIT_NODE - float(i) * TRAIT_ROW
		centers.append(Vector2(x, y + TRAIT_NODE * 0.5))
	for i in range(1, seq.size()):
		var p0 := centers[i - 1]
		var p1 := centers[i]
		var lw := TRAIT_LINE * 0.5
		# 중심에서 중심으로. 가로 팔(앞 노드 높이) + 세로 줄기(다음 노드 x) —
		# 모서리는 두 선이 겹쳐 한 덩어리로 보이고, 끝은 노드가 덮는다.
		var arm := Rect2(minf(p0.x, p1.x) - lw, p0.y - lw,
			absf(p1.x - p0.x) + TRAIT_LINE, TRAIT_LINE)
		var stem := Rect2(p1.x - lw, p1.y, TRAIT_LINE, p0.y - p1.y)
		var parts: Array[ColorRect] = []
		for seg in [arm, stem]:
			var line := ColorRect.new()
			line.position = seg.position
			line.size = seg.size
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(line)
			parts.append(line)
		_trait_links.append({"from": str(seq[i - 1]), "a": parts[0], "b": parts[1]})
	for i in seq.size():
		var id := str(seq[i])
		var n := TraitDefs.node(id)
		var at := centers[i] - Vector2(TRAIT_NODE * 0.5, TRAIT_NODE * 0.5)
		var frame := Ui.icon("res://assets/ui/slot_common.png", at, TRAIT_NODE)
		canvas.add_child(frame)
		# 아이콘은 살짝 아래로(사장님) — 레벨 글자와 같이 보면 위로 치우쳐 보였다.
		var ic := Ui.icon("res://assets/ui/%s.png" % TRAIT_ICON[str(n["kind"])],
			at + Vector2((TRAIT_NODE - 40.0) * 0.5, 18.0), 40.0)
		canvas.add_child(ic)
		# 레벨 "n/10" — 노드 안 아래쪽. 칸을 키워(76) 글씨가 안 잘린다.
		var lv_lbl := _panel_label(canvas, at + Vector2(0.0, TRAIT_NODE - 28.0),
			Type.SIZE_SMALL, Color(0.94, 0.90, 0.96), TRAIT_NODE, 18.0)
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hit := Button.new()
		hit.flat = true
		hit.position = at
		hit.size = Vector2(TRAIT_NODE, TRAIT_NODE)
		hit.focus_mode = Control.FOCUS_NONE
		hit.pressed.connect(func() -> void:
			_trait_sel = id
			_refresh_traits())
		canvas.add_child(hit)
		_trait_nodes[id] = {"frame": frame, "icon": ic, "lv": lv_lbl}
	# 처음 열면 **맨 아래(1티어)** 가 보인다 — 오르는 길은 아래에서 시작한다.
	scroll.set_deferred("scroll_vertical", int(canvas_h))
	# 고른 노드의 상세 + 사는 자리 — 스크롤 밖 고정.
	var iy := CONTENT_BOTTOM - 38.0
	# 버튼이 152 인 이유: 값만 적던 시절엔 124 로 됐는데 "x7 1.3K" 가 되면서
	# 뒤의 K 가 잘렸다(캡처 실측). **잘린 가격은 거짓말이다** — 이 파일이
	# _trait_effect_text 주석에 이미 한 번 적어 둔 실패다.
	_trait_info = _panel_label(_trait_view, Vector2(PAD, iy), Type.SIZE_SMALL,
		Color(0.90, 0.86, 0.88), CONTENT_W - 158.0, 34.0)
	_trait_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trait_buy = Ui.button("", Vector2(PAD + CONTENT_W - 152.0, iy),
		Vector2(152.0, 34.0), Type.SIZE_SMALL)
	Ui.cost_icon(_trait_buy, "res://assets/ui/res_crystal.png", 14)
	_trait_buy.pressed.connect(func() -> void: _buy_trait(_trait_sel))
	_trait_view.add_child(_trait_buy)
	_trait_sel = str(seq[0])


func _refresh_traits() -> void:
	if _trait_view == null:
		return
	_trait_head.text = _n(crystal)
	for id in _trait_nodes:
		var reason := TraitDefs.lock_reason(str(id), traits, hero_lv, dungeon_best)
		var cell: Dictionary = _trait_nodes[id]
		# 세 상태를 색으로 가른다: 만렙(금) · 오를 수 있음(흰) · 잠김(어둠).
		# 고른 노드는 한 단계 더 밝다.
		var tone := Color(0.42, 0.40, 0.46)
		if reason == "만렙":
			tone = Color(1.0, 0.86, 0.52)
		elif reason == "":
			tone = Color(0.95, 0.95, 1.0)
		if str(id) == _trait_sel:
			tone = tone.lightened(0.25)
		cell["frame"].modulate = tone
		cell["icon"].modulate = Color(1, 1, 1) if reason == "만렙" or reason == "" 			else Color(0.5, 0.48, 0.54)
		var lv := TraitDefs.level_of(str(id), traits)
		cell["lv"].text = "%d/%d" % [lv, TraitDefs.MAX_LV] if lv > 0 else ""
	# 줄기 — **앞 노드가 만렙이면** 다음으로 가는 길이 금빛으로 이어진다.
	for link in _trait_links:
		var lit := TraitDefs.level_of(str(link["from"]), traits) >= TraitDefs.MAX_LV
		var col := Color(0.86, 0.68, 0.32) if lit else Color(0.22, 0.20, 0.26)
		link["a"].color = col
		link["b"].color = col
	_refresh_trait_info()


func _refresh_trait_info() -> void:
	if _trait_sel == "":
		return
	var n := TraitDefs.node(_trait_sel)
	if n.is_empty():
		return
	var reason := TraitDefs.lock_reason(_trait_sel, traits, hero_lv, dungeon_best)
	var lv := TraitDefs.level_of(_trait_sel, traits)
	_trait_info.text = "%s %d/%d · 만렙 %s" % [str(n["name"]), lv,
		TraitDefs.MAX_LV, _trait_effect_text(n)]
	if reason == "만렙":
		_trait_buy.text = "만렙"
		_trait_buy.disabled = true
	elif reason != "":
		_trait_buy.text = reason
		_trait_buy.disabled = true
	else:
		# 몇 레벨이 오르는지 버튼이 말한다 — 값만 적으면 한 레벨인 줄 안다.
		var cost := TraitDefs.cost(int(n["tier"]))
		var step := _trait_steps(_trait_sel)
		_trait_buy.text = _n(cost, true) if step <= 1 			else "x%d %s" % [step, _n(cost * float(step), true)]
		_trait_buy.disabled = crystal < cost


# 이름은 짧게 — 버튼에 아이콘이 종류를 말해 주니 글은 수치와 비용에 자리를 준다.
# "치명 피해 +15% — 2.0K" 는 열 폭에서 비용이 잘렸다(실측). 잘린 가격은 거짓말이다.
static func _trait_effect_text(n: Dictionary) -> String:
	var v := float(n["value"])
	match str(n["kind"]):
		"attack": return "공격 +%d%%" % int(v * 100.0)
		"critdmg": return "치명 +%d%%" % int(v * 100.0)
		"skill": return "스킬 +%d%%" % int(v * 100.0)
		"hp": return "체력 +%d%%" % int(v * 100.0)
		"regen": return "회복 +%d%%" % int(v * 100.0)
		"guard": return "피해 -%d%%" % int(v * 100.0)
		"critdmg": return "치명 피해 +%d%%" % int(v * 100.0)
		"hours": return "방치 +%d시간" % int(v)
		"sweep": return "소탕 +%d%%" % int(v * 100.0)
	return ""


# 이번에 한 번에 살 레벨 수 — 지갑이 닿는 만큼, 만렙을 넘지 않게.
# **음수는 절대 안 돌려준다**(_step_for 의 그 주의와 같다): 음수가 흘러가면
# 비용이 음수가 되어 혈정이 늘고 레벨이 준다.
func _trait_steps(id: String) -> int:
	var n := TraitDefs.node(id)
	if n.is_empty() or TraitDefs.lock_reason(id, traits, hero_lv, dungeon_best) != "":
		return 0
	return clampi(int(crystal / TraitDefs.cost(int(n["tier"]))), 0,
		TraitDefs.MAX_LV - TraitDefs.level_of(id, traits))


# 노드는 **한 번에 닿는 데까지** 오른다. 원래는 한 레벨이었는데, 18노드 x 10레벨
# 이라 완주에 180번을 눌러야 했다(저장 버그가 부분 레벨을 만렙으로 부활시키던
# 동안에는 안 아팠다 — 그걸 고치면서 드러났다).
# **x1/x10 을 고르게 하지 않는다.** 혈맥은 한 줄기 덩굴이라 앞 노드를 만렙 내야
# 다음이 열리고, 혈정의 소모처도 여기 하나뿐이다 — 덜 사고 아낄 이유가 없으므로
# 고를 이유 없는 선택지를 하나 더 만드는 셈이다.
# "밑을 10레벨 채우면 위가 열린다"(사장님)는 그대로다.
func _buy_trait(id: String) -> void:
	var n := _trait_steps(id)
	if n <= 0:
		return
	crystal = maxf(0.0, crystal
		- TraitDefs.cost(int(TraitDefs.node(id)["tier"])) * float(n))
	traits[id] = TraitDefs.level_of(id, traits) + n
	_refresh_traits()
	_save_game()


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
	# 칸은 **최대치(7)로 깔아 둔다.** 군림 I 전에는 7번째가 잠긴 칸으로 보인다 —
	# 숨기면 "칸이 늘 수 있다"는 사실 자체가 안 보인다(참고작도 잠긴 칸을 보여 준다).
	var slot_n := SkillDefs.SLOTS + 1
	var gap := (CONTENT_W - SK_SLOT * float(slot_n)) / float(slot_n - 1)
	for i in slot_n:
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
		hit.pressed.connect(func() -> void:
			if idx < _equip_cap():
				_unequip_skill(idx))
		cell.add_child(hit)
		_skill_slots.append({"frame": frame, "icon": ic, "lv": lv,
			"shade": shade, "cd": cd})

	# 이 한 줄이 두 가지를 한다: 평소엔 조합 상태, 칸을 누르면 그 스킬 정보.
	# 칸이 좁아 이름을 넣을 자리가 없어서 여기로 몰았다.
	_skill_info = _panel_label(_skill_view, Vector2(PAD, top + 74.0), Type.SIZE_SMALL,
		Color(0.82, 0.88, 0.72), CONTENT_W, 20.0)
	_skill_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var list_y := top + 98.0
	# 프리셋 줄이 버튼 줄 위에 하나 더 들어간다(46). 목록이 그만큼 줄지만
	# 어차피 스크롤이라 보이는 칸만 줄고 내용은 그대로다.
	var sc := Ui.scroll(Vector2(PAD, list_y),
		Vector2(CONTENT_W, CONTENT_BOTTOM - 90.0 - list_y))
	_skill_view.add_child(sc)
	_skill_grid = GridContainer.new()
	_skill_grid.columns = 4
	_skill_grid.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	_skill_grid.add_theme_constant_override("h_separation", 6)
	_skill_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_skill_grid)

	# 버튼이 넷이다(2026-08-10 "전체 해제" 추가). 간격 12 x 3 = 36 을 빼고 넷으로 나눈다 —
	# 3개 기준(24)을 그대로 두면 마지막 버튼이 창 밖으로 나간다.
	var bw := (CONTENT_W - 36.0) / 4.0
	var by := CONTENT_BOTTOM - 38.0
	_preset_row(_skill_view, "skill", by - 42.0)
	# 토글이다. 켜 두면 새 스킬·레벨업·조합 때마다 알아서 다시 낀다 — 방치형에서
	# "더 센 걸 뽑았는데 안 끼고 있었다"는 플레이어 잘못이 아니라 UI 잘못이다.
	_skill_detail = Control.new()
	_skill_detail.size = Vector2(PANEL_W, PANEL_H)
	_skill_detail.visible = false
	_skill_detail.z_index = 4
	root.add_child(_skill_detail)
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
	_skill_synth_btn.pressed.connect(func() -> void: _open_bulk("fuse", "skill"))
	_skill_view.add_child(_skill_synth_btn)
	# 전체 해제 — 여섯 칸을 하나씩 빼는 건 방치형에서 할 짓이 아니다(2026-08-10 사장님).
	# **자동 장착도 같이 끈다**: 안 끄면 다음 레벨업·조합 때 그대로 다시 껴서
	# "해제가 안 된다"로 보인다.
	var off_btn := Ui.button("전체 해제", Vector2(PAD + (bw + 12.0) * 3.0, by),
		Vector2(bw, 38.0), Type.SIZE_SMALL)
	off_btn.pressed.connect(func() -> void:
		if skill_equipped.is_empty():
			return
		skill_auto_equip = false
		skill_equipped.clear()
		_refresh_skills()
		_save_game())
	_skill_view.add_child(off_btn)


# 한 행은 ROW_H 높이의 띠다. 그 안에서 아이콘·글자·버튼이 전부 세로 중앙에 온다.
# 1000 단위 콤마. _n() 은 큰 수를 k/m 으로 줄이는데 레벨은 **정확한 숫자**가
# 읽혀야 해서(참고작도 "Lv.2,979") 줄이지 않고 끊어 준다.
static func _comma(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += ","
		out += t[i]
	return ("-" if v < 0 else "") + out


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
	# 15분할로 "15,750 / 15.7k" 까지 길어졌다. 이 줄은 **위쪽 절반**이라 아래
	# 줄의 효과 칸(208~)과 안 부딪히고, 오른쪽 잠금·버튼이 336 부터라 200 까지
	# 안전하다(148 로는 상한이 잘렸다 — 2026-08-20 실측).
	var lv_lbl := _panel_label(row, Vector2(60.0, 0.0), Type.SIZE_SMALL,
		Color(0.62, 0.62, 0.68), 200.0, ROW_H * 0.5)
	var nm := _panel_label(row, Vector2(60.0, ROW_H * 0.5), Type.SIZE_BODY,
		Color(0.95, 0.90, 0.88), 144.0, ROW_H * 0.5)
	# 누적 배수를 같이 적어야 해서 120 보다 넓히되, **버튼이 w-172 = 336 부터**라
	# 208+124 = 332 가 한계다(160 으로 늘렸다가 32px 겹쳤다 — 2026-08-20 실측).
	var eff := _panel_label(row, Vector2(208.0, ROW_H * 0.5), Type.SIZE_SMALL,
		Color(0.98, 0.72, 0.45), 124.0, ROW_H * 0.5)
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
	elif skill_equipped.size() < _equip_cap():
		skill_equipped.append(key)
	else:
		# 칸이 다 찼으면 **맨 뒤를 밀어낸다.** 순서가 발동 우선순위라 뒤가 제일 덜 급하다.
		skill_equipped[_equip_cap() - 1] = key
	var lv := int(skill_owned.get(key, 0))
	_skill_info.text = "%s  ·  %s  ·  %d레벨" % [SkillDefs.name_of(key),
		SkillDefs.role_of(key), lv]
	_refresh_skills(false)
	_save_game()


# 아직 못 얻은 스킬 — 장비 보관함의 "?" 칸과 같은 문법이다.
# 아직 없는 스킬 칸. **왜 없는지가 두 가지다** — 아직 안 뽑혔거나(미획득),
# 형태 천장이 낮아 소환 풀에 아예 안 들어오거나(잠김). 둘을 같은 "?"로 두면
# 뽑아도 안 나오는 걸 계속 뽑게 된다 — 규칙을 넣었으면 화면이 말해야 한다.
func _skill_unknown_card(rarity: Dictionary, shape := "") -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = SK_CARD
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := Color(rarity["col"]) * 0.42
	var frame := Ui.image("res://assets/ui/slot_common.png",
		Vector2((SK_CARD.x - 56.0) * 0.5, 0.0), Vector2(56.0, 56.0))
	frame.modulate = Color(dim.r, dim.g, dim.b, 0.85)
	cell.add_child(frame)
	var q := _panel_label(cell, Vector2(0.0, 14.0), Type.SIZE_MID,
		Color(dim.r * 1.6, dim.g * 1.6, dim.b * 1.6), SK_CARD.x, 28.0)
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nm := _panel_label(cell, Vector2(0.0, 60.0), Type.SIZE_SMALL,
		Color(dim.r * 1.4, dim.g * 1.4, dim.b * 1.4), SK_CARD.x, 18.0)
	nm.text = "%s · 미획득" % str(rarity["name"])
	# 천장 위면 **무엇을 하면 열리는지**를 적는다. "미획득" 만 적으면 뽑기로
	# 해결되는 줄 알고 계속 뽑는다 — 실제로는 그 형태에 레벨을 부어야 한다.
	if shape != "" and not SkillDefs.shape_allows(shape, str(rarity["key"]),
			skill_owned):
		var pg: Array = SkillDefs.cap_progress(shape, skill_owned)
		q.text = "잠김"
		nm.text = "%s 숙련 +%d" % [str(SkillDefs.SHAPES[shape]["name"]), int(pg[2])]
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return cell


func _skill_card(key: String) -> Control:
	var lv := int(skill_owned.get(key, 0))
	var rarity := SkillDefs.rarity_of(key)
	var cell := Control.new()
	cell.custom_minimum_size = SK_CARD
	var hit := Button.new()
	hit.flat = true
	hit.size = SK_CARD
	hit.focus_mode = Control.FOCUS_NONE
	# 누르면 바로 장착이 아니라 **상세보기**가 열린다. 무엇인지 보지도 않고 끼는
	# 것보다, 위력·쿨다운·조각을 보고 고르는 쪽이 맞다(장비 보관함과 같은 규칙).
	hit.pressed.connect(func() -> void: _open_skill_detail(key))
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
	var maxed := lv >= SkillDefs.MAX_LV
	var cost := SkillDefs.shard_cost(lv)
	var sh := _panel_label(cell, Vector2(0.0, 72.0), Type.SIZE_SMALL,
		Color(0.98, 0.86, 0.56) if maxed
		else (Color(0.98, 0.82, 0.42) if shards >= cost else Color(0.62, 0.62, 0.68)),
		SK_CARD.x, 16.0)
	sh.text = ("만렙 %d" % SkillDefs.MAX_LV) if maxed \
		else "조각 %d / %d" % [shards, cost]
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
		if i >= _equip_cap():
			slot["icon"].texture = null
			slot["frame"].modulate = Color(0.18, 0.16, 0.2)
			slot["lv"].text = "군림 I"
			continue
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
	# 표 20칸(형태 4 x 등급 5)을 등급 순으로 늘어놓고, 못 얻은 것은 "?" 로
	# 채운다 — 장비 보관함과 같은 규칙(사장님). 정렬을 따로 안 해도 표가 곧
	# 순서라, 조합 재료를 찾을 때 자리가 늘 같다.
	for rarity in GachaDefs.RARITIES:
		if GachaDefs.rarity_index(str(rarity["key"])) > GachaDefs.SKILL_TOP_INDEX:
			continue
		for shape in SkillDefs.SHAPE_ORDER:
			var key := SkillDefs.key_of(shape, str(rarity["key"]))
			if skill_owned.has(key):
				_skill_grid.add_child(_skill_card(key))
			else:
				_skill_grid.add_child(_skill_unknown_card(rarity, shape))
	_skill_bulk_btn.disabled = _skill_levelable().is_empty()
	_skill_synth_btn.disabled = false
	_skill_auto_btn.set_pressed_no_signal(skill_auto_equip)
	_skill_auto_btn.text = "자동 장착 켬" if skill_auto_equip else "자동 장착"
	_refresh_presets("skill")
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
		if lv >= SkillDefs.MAX_LV:
			continue
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


# **계정 전체 초기화**다(사장님 2026-08-20: "아예 캐릭터 전부 다").
# 처음부터 다시 돌려 보려는 장치라 스탯만 되돌리면 뜻이 없다 — 저장 파일을
# 지우고 씬을 새로 연다(_wipe_save). 되돌릴 수 없으니 문구로 분명히 경고한다.
func _ask_full_reset() -> void:
	_ask("계정을 처음부터 다시 시작합니다.\n"
		+ "스탯·장비·스킬·펫·칭호·재화가 전부 사라지고 되돌릴 수 없습니다.",
		func() -> void: _wipe_save())


func _stat_refund_total() -> float:
	var sum := 0.0
	for st in StatDefs.STATS:
		var key := str(st["key"])
		var n := stat_lv(key) - 1
		if n > 0:
			sum += Balance.buy_cost(1, n, float(st.get("base", 10.0)),
				StatDefs.cost_exp(key))
	return sum


func _ask_stat_reset() -> void:
	var back := _stat_refund_total()
	if back <= 0.0:
		return
	_ask("훈련을 전부 Lv1 로 되돌리고 혈액 %s 를 돌려받습니다." % _n(back),
		func() -> void:
			var old_max := max_hp()
			gold += _stat_refund_total()
			lv.clear()
			_apply_hp_growth(old_max)
			_refresh_growth()
			_refresh_hud()
			_save_game())


func _set_step(n: int) -> void:
	buy_step = n
	for i in _step_btns.size():
		_step_btns[i].set_pressed_no_signal(BUY_STEPS[i] == n)
	_refresh_hud()


func _refresh_growth() -> void:
	for s in StatDefs.STATS:
		var key := str(s["key"])
		var row: Dictionary = _stat_rows[key]
		var reason := StatDefs.lock_reason(key, StageDefs.major_stage(stage), lv)
		var open := reason == ""
		# 상한을 같이 적는다(참고작 "최대 레벨") — 상한이 보여야 승급이 목표가 된다.
		# 15분할로 레벨이 네 자리가 됐다. 한 칸에 "레벨 2362 / 24205" 를 다 넣으면
		# 잘리므로 참고작처럼 **둘로 나눈다** — 왼쪽 현재, 오른쪽 위 최대.
		row["lv"].text = "%s / %s" % [_comma(stat_lv(key)),
			_n(float(_stat_cap(key)))]
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
		if stat_lv(key) >= _stat_cap(key):
			# 스탯 고유 만렙은 영영 끝, 승급 상한은 **미궁과 구간 둘 다** 연다 —
			# 문구가 길을 알려주므로 **지금 이기고 있는 축**을 가리켜야 한다.
			# 상한을 조이기 전(CAP_BASE 900)에는 초반에 이 문구가 안 뜨는
			# 바람에 안 드러났는데, 미궁이 35구간에나 열리므로 1구간에서
			# "미궁 20층"을 가리키면 **못 가는 곳을 가리키는 것**이었다.
			var nf := StatDefs.next_cap_floor(dungeon_best)
			var maze_wins := StatDefs.CAP_PER_FLOOR * maxi(0, dungeon_best) 					> int(StatDefs.CAP_PER_STAGE * float(maxi(0, best_stage - 1)))
			if StatDefs.at_cap(key, stat_lv(key)):
				row["btn"].text = "만렙"
				row["btn"].icon = null
			elif maze_wins and nf > 0:
				# 승급 배지(사장님 선택 A) — 잠긴 게 아니라 "열 수 있는 문"이라는 표시.
				row["btn"].text = "미궁 %d층" % nf
			else:
				row["btn"].text = "다음 구간"
				row["btn"].icon = null
				Ui.cost_icon(row["btn"], "res://assets/ui/badge_promo.png")
			row["btn"].disabled = true
			continue
		var cost := _buy_cost(key, _step_for(key))
		# 상한이 풀리면 아이콘도 돌아와야 한다 — 만렙 분기가 null 로 지운다.
		Ui.cost_icon(row["btn"], "res://assets/ui/res_blood.png")
		row["btn"].text = "혈액  %s" % _n(cost, true)
		row["btn"].disabled = gold < cost


# 레벨이 아니라 "그래서 뭐가 되는데"를 보여 준다.
func _stat_effect(key: String) -> String:
	# **값 + 누적 배수**를 같이 적는다(사장님 2026-08-20). 15분할로 한 레벨의
	# 절대 증가가 1/15이 되어 정수 표기로는 x1 구매가 화면에 안 잡혔다 —
	# 참고작이 "+2,979" 처럼 누적을 적는 자리가 이것이다.
	# **_stat_eff 를 쓴다**: stat_lv 은 구매 단위(15배)라 15분할 뒤로는 틀리고,
	# 칭호가 준 공짜 레벨도 안 잡혔다(옛 버그).
	var eff := _stat_eff(key)
	match key:
		"damage":
			# "+" 한 칸 때문에 124px 를 넘어 배수 끝자리가 잘렸다(실측).
			# 체력 줄과 같은 문법으로 맞춘다 — 어차피 총 피해값이라 "+" 는
			# 증가분으로 오해될 여지도 있었다.
			return "%s x%.1f" % [_n(damage()),
				1.0 + Balance.DMG_PER_LEVEL * (eff - 1.0)]
		"tough":
			return "%s x%.1f" % [_n(max_hp()), 1.0 + 0.06 * (eff - 1.0)]
		"speed":
			return "%.2f초 x%.1f" % [attack_interval(), 0.60 / attack_interval()]
		"regen":
			return "초당 %s %.1f%%" % [_n(regen_per_sec()),
				minf(Balance.REGEN_CAP, Balance.REGEN_PER_LEVEL * (eff - 1.0)) * 100.0]
		"crit":
			return "%.1f%%" % (minf(1.0, 0.01 * (eff - 1.0)) * 100.0)
		"rage":
			return "+%.0f%% x%.2f" % [(eff - 1.0), 1.0 + 0.01 * (eff - 1.0)]
		"grit":
			return "+%.0f%% x%.2f" % [(eff - 1.0), 1.0 + 0.01 * (eff - 1.0)]
		"critdmg":
			return "x%.2f 피해" % (1.5 + 0.05 * (eff - 1.0))
	return ""


# 여러 단계를 한 번에 살 때의 총액. 비용이 지수라 배수만 곱하면 실제보다 싸진다.
func _buy_cost(key: String, n: int) -> float:
	# **가격은 한 식만 쓴다.** 여기가 표의 raw exp 를, 시뮬레이션 쪽이
	# StatDefs.cost_exp(COST_EXP_SCALE 반영)를 쓰고 있었다 — 지금은 SCALE 이 1.0
	# 이라 값이 같지만, 그 손잡이를 만지는 순간 화면 가격과 곡선이 갈린다.
	return Balance.buy_cost(stat_lv(key), n,
		float(StatDefs.of(key).get("base", 10.0)), StatDefs.cost_exp(key))


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
	# 소탭은 **대장간 세트**다 (사장님 2026-08-14: 탭마다 결을 맞춘다). 장비를
	# 손보는 화면이라 소환 탭의 대장간과 같은 철판을 쓰는 게 뜻이 맞는다 —
	# 새 세트를 뽑는 대신 있는 것을 제자리에 쓴다.
	for i in 2:
		var mode := "equipped" if i == 0 else "inventory"
		var tb := TextureButton.new()
		tb.texture_normal = Assets.tex("res://assets/ui/sets/forge_tab_off.png")
		tb.texture_pressed = Assets.tex("res://assets/ui/sets/forge_tab_on.png")
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.toggle_mode = true
		tb.position = Vector2(PAD + float(i) * 268.0, 18.0)
		tb.size = Vector2(252.0, 36.0)
		tb.z_index = 2
		Ui.hover_pop(tb)
		tb.pressed.connect(func() -> void: _set_gear_mode(mode))
		root.add_child(tb)
		var tl := _panel_label(root, Vector2(tb.position.x, 25.0),
			Type.SIZE_MID, Color(1.0, 0.97, 0.92), 252.0, 22.0)
		tl.text = "장착 장비" if i == 0 else "보관함"
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.z_index = 2
		_shop_outline(tl, 8)
		_gear_mode_buttons[mode] = tb
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
		# 강화(정수 레벨업)는 삭제됐다(사장님 2026-08-25). 대신 **이 장비가
		# 스탯을 얼마나 올리는지**를 적는다 — 전투력 원값("+8")은 그 자체로는
		# 큰지 작은지 읽히지 않는다(같은 날 캡처).
		# **두 줄로 나눈다.** 한 줄에 붙이면 "레벨 320 · 공격 +370" 이 칸(SLOT_GAP)
		# 을 넘쳐 옆 칸과 겹치고 끝이 잘린다(사장님 2026-08-25 캡처).
		var lv_lbl := _panel_label(_gear_equipped_view,
			Vector2(at.x + SLOT_BOX * 0.5 - SLOT_GAP * 0.5, 176.0),
			Type.SIZE_SMALL, Color(0.80, 0.78, 0.84), SLOT_GAP, 20.0)
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stat_lbl := _panel_label(_gear_equipped_view,
			Vector2(at.x + SLOT_BOX * 0.5 - SLOT_GAP * 0.5, 196.0),
			Type.SIZE_SMALL, Color(0.68, 0.86, 0.72), SLOT_GAP, 20.0)
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gear_slots[slot] = {"frame": frame, "icon": ic, "label": name_lbl,
			"lv": lv_lbl, "stat": stat_lbl}
	# 슬롯 이름·수치가 216 에서 끝난다 — 그 아래는 비어 있어 그냥 놓으면 된다.
	_preset_row(_gear_equipped_view, "gear", 232.0)
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
	# 목록 높이는 **창 높이에서 뺀다.** 예전엔 152 로 박아 뒀는데 창을 320 -> 384 로
	# 늘리자 아래가 통째로 비었다. 고정값을 쓰면 창 크기를 바꿀 때마다 다시 찾아야 한다.
	_gear_hold_lbl = _panel_label(_gear_inventory_view, Vector2(PAD, 102.0),
		Type.SIZE_SMALL, Color(0.62, 0.88, 0.70), CONTENT_W, 18.0)
	_gear_hold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var list_top := 124.0
	var scroll := Ui.scroll(Vector2(PAD, list_top),
		Vector2(CONTENT_W, CONTENT_BOTTOM - 50.0 - list_top))
	_gear_inventory_view.add_child(scroll)
	# 분해는 삭제됐다(사장님 2026-08-25) — 남는 건 조합 하나다.
	var b := Ui.button("조합", Vector2(PAD, CONTENT_BOTTOM - 38.0),
		Vector2(CONTENT_W, 38.0), Type.SIZE_SMALL)
	b.pressed.connect(func() -> void: _open_bulk("fuse"))
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


# ── 조합 창 (전체 화면) ────────────────────────────────────────────────────
# 레퍼런스(소울무기 합성)의 뼈대를 그대로 쓴다(사장님 2026-08-25):
#   재료 미리보기 → 등급 탭 → 격자 → 확률 줄 → 초기화/조합 → 확정 바 + 모두.
# 등급 탭이 있는 이유: 조합은 **같은 등급끼리** 확률과 천장이 갈리므로, 탭을
# 고르면 그 등급의 확률·천장이 한눈에 선다. 전체 탭은 등급이 섞여서 확률을
# 한 줄로 못 적는다 — 레퍼런스도 거기서는 "등급별로 다름"이라고만 적는다.
const FUSE_TABS := ["all", "common", "uncommon", "rare", "epic", "legend"]


func _build_bulk(_root: Control) -> void:
	# **화면 전체를 덮는다** — 장비 탭 루트는 반판이라 거기 지으면 아래가
	# 잘린다. 오버레이는 _hud_root 에 붙어 네비 위까지 다 쓴다.
	_bulk_view = _overlay(64)
	# **화면을 통째로 덮는다.** y=24 부터 깔았더니 위쪽 띠로 게임 화면이
	# 비쳤고, 그 틈으로 뒤에 있는 판(가이드 보상)이 눌렸다(사장님 캡처).
	var back := ColorRect.new()
	back.color = Color(0.045, 0.04, 0.055, 0.99)
	back.position = Vector2.ZERO
	back.size = Vector2(Grid.BG)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_bulk_view.add_child(back)
	# 판 밖(네비 위 등)을 눌러도 뒤로 안 넘어가게 막는 투명 버튼.
	var guard := Button.new()
	guard.flat = true
	guard.position = Vector2.ZERO
	guard.size = Vector2(Grid.BG)
	guard.focus_mode = Control.FOCUS_NONE
	guard.modulate = Color(1, 1, 1, 0)
	_bulk_view.add_child(guard)
	_bulk_title = _panel_label(_bulk_view, Vector2(PAD, 16.0), Type.SIZE_BODY,
		Color(0.96, 0.90, 0.86), CONTENT_W, 30.0)
	_bulk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := Ui.button("닫기", Vector2(CONTENT_W + PAD - 92.0, 14.0),
		Vector2(92.0, 34.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _bulk_view.visible = false)
	_bulk_view.add_child(close)
	# 재료 미리보기 — 고른 것 셋(재료 조각 수만큼)과 결과 자리.
	_bulk_view.add_child(Ui.panel(Vector2(PAD, 58.0), Vector2(CONTENT_W, 188.0)))
	_bulk_hint = _panel_label(_bulk_view, Vector2(PAD, 138.0), Type.SIZE_SMALL,
		Color(0.58, 0.56, 0.62), CONTENT_W, 24.0)
	_bulk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bulk_preview = Control.new()
	_bulk_preview.position = Vector2(PAD + 16.0, 76.0)
	_bulk_preview.size = Vector2(CONTENT_W - 32.0, 150.0)
	_bulk_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulk_view.add_child(_bulk_preview)
	# 등급 탭.
	var tw := (CONTENT_W - 6.0 * 5.0) / 6.0
	for i in FUSE_TABS.size():
		var key: String = FUSE_TABS[i]
		var tx := PAD + float(i) * (tw + 6.0)
		var tb := Ui.button("", Vector2(tx, 256.0), Vector2(tw, 40.0),
			Type.SIZE_SMALL)
		tb.pressed.connect(func() -> void:
			_bulk_tab = key
			_bulk_selected.clear()
			_refresh_bulk())
		_bulk_view.add_child(tb)
		var tl := _panel_label(_bulk_view, Vector2(tx, 266.0), Type.SIZE_SMALL,
			Color(0.92, 0.88, 0.86), tw, 20.0)
		tl.text = "전체" if key == "all" \
			else str(GachaDefs.rarity(key)["name"])
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bulk_tabs[key] = {"btn": tb, "lbl": tl}
	var sc := Ui.scroll(Vector2(PAD, 306.0), Vector2(CONTENT_W, 292.0))
	_bulk_view.add_child(sc)
	_bulk_grid = GridContainer.new()
	_bulk_grid.columns = 4
	_bulk_grid.custom_minimum_size.x = CONTENT_W - Ui.SCROLL_W
	_bulk_grid.add_theme_constant_override("h_separation", 6)
	_bulk_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_bulk_grid)
	# 확률 줄.
	_bulk_body = _panel_label(_bulk_view, Vector2(PAD, 608.0), Type.SIZE_SMALL,
		Color(0.90, 0.88, 0.92), CONTENT_W, 24.0)
	_bulk_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 초기화 · 조합.
	var reset := Ui.button("초기화", Vector2(PAD + 20.0, 640.0),
		Vector2(240.0, 46.0), Type.SIZE_SMALL)
	reset.pressed.connect(func() -> void: _bulk_select_all(false))
	_bulk_view.add_child(reset)
	_bulk_run = Ui.button("조합", Vector2(PAD + CONTENT_W - 260.0, 640.0),
		Vector2(240.0, 46.0), Type.SIZE_SMALL)
	_bulk_run.pressed.connect(_run_bulk)
	_bulk_view.add_child(_bulk_run)
	# 확정(천장) 바 + 모두 조합.
	_bulk_pity_lbl = _panel_label(_bulk_view, Vector2(PAD + 20.0, 700.0),
		Type.SIZE_SMALL, Color(0.96, 0.90, 0.70), 300.0, 22.0)
	_bulk_pity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.16, 0.14, 0.19)
	bar_bg.position = Vector2(PAD + 20.0, 728.0)
	bar_bg.size = Vector2(300.0, 20.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulk_view.add_child(bar_bg)
	_bulk_pity_bar = ColorRect.new()
	_bulk_pity_bar.color = Color(0.55, 0.45, 0.95)
	_bulk_pity_bar.position = Vector2(PAD + 20.0, 728.0)
	_bulk_pity_bar.size = Vector2(0.0, 20.0)
	_bulk_pity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulk_view.add_child(_bulk_pity_bar)
	_bulk_pity_num = _panel_label(_bulk_view, Vector2(PAD + 20.0, 728.0),
		Type.SIZE_SMALL, Color(1, 1, 1), 300.0, 20.0)
	_bulk_pity_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bulk_pity_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var all_btn := Ui.button("모두 조합", Vector2(PAD + CONTENT_W - 200.0, 706.0),
		Vector2(180.0, 44.0), Type.SIZE_SMALL)
	all_btn.pressed.connect(func() -> void:
		_bulk_select_all(true)
		_run_bulk())
	_bulk_view.add_child(all_btn)


func _open_bulk(mode: String, kind := "gear") -> void:
	_bulk_mode = mode
	_bulk_kind = kind
	_bulk_tab = "all"
	_front(_bulk_view)
	_bulk_selected.clear()
	_bulk_view.visible = true
	_refresh_bulk()


# 분해 대상: 장착 중이 아닌 보관 장비 전부. 등급으로 미리 거르지 않는다 —
# 무엇을 남길지는 칸을 보고 고르는 게 확실하다.
# 조합 대상: 조각 5개 이상이면서 신화가 아닌 것.
func _bulk_candidates() -> Array[String]:
	if _bulk_kind == "skill":
		return _bulk_skill_candidates()
	var out: Array[String] = []
	for key in gear_inventory:
		var item: Dictionary = gear_inventory[key]
		if GachaDefs.rarity_index(str(item.get("rarity", "common"))) \
				>= GachaDefs.RARITIES.size() - 1:
			continue
		if int(gacha_shards.get("gear:" + str(key), 0)) < GearDefs.FUSE_SHARDS:
			continue
		if _bulk_tab != "all" and str(item.get("rarity", "common")) != _bulk_tab:
			continue
		out.append(str(key))
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GachaDefs.rarity_index(str(gear_inventory[a].get("rarity", "common"))) \
			< GachaDefs.rarity_index(str(gear_inventory[b].get("rarity", "common"))))
	return out


# 스킬 후보 — 조각이 찼고 더 오를 등급이 남은 것.
func _bulk_skill_candidates() -> Array[String]:
	var out: Array[String] = []
	for key in skill_owned:
		var k := str(key)
		if SkillDefs.promote_key(k).is_empty():
			continue
		if int(gacha_shards.get("skill:" + k, 0)) < GearDefs.FUSE_SHARDS:
			continue
		if _bulk_tab != "all" and str(SkillDefs.split(k)[1]) != _bulk_tab:
			continue
		out.append(k)
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		return GachaDefs.rarity_index(str(SkillDefs.split(str(a))[1])) \
			< GachaDefs.rarity_index(str(SkillDefs.split(str(b))[1])))
	return out


# 조합 대상의 등급 키 — 장비와 스킬이 같은 확률·천장 표를 쓴다.
func _bulk_rarity_of(key: String) -> String:
	if _bulk_kind == "skill":
		return str(SkillDefs.split(key)[1])
	return str(gear_inventory.get(key, {}).get("rarity", "common"))


func _bulk_select_all(on: bool) -> void:
	_bulk_selected.clear()
	if on:
		for key in _bulk_candidates():
			_bulk_selected[key] = true
	_refresh_bulk()


func _refresh_bulk() -> void:
	if not _bulk_view or not _bulk_view.visible:
		return
	_bulk_title.text = "스킬 조합" if _bulk_kind == "skill" else "장비 조합"
	# 탭 — 고른 것은 밝게. 조합할 게 있는 등급에는 점을 찍는다(레퍼런스 문법).
	for key in _bulk_tabs:
		var on: bool = key == _bulk_tab
		var t: Dictionary = _bulk_tabs[key]
		t["lbl"].add_theme_color_override("font_color",
			Color(1.0, 0.92, 0.62) if on else Color(0.72, 0.70, 0.74))
		t["btn"].modulate = Color(1, 1, 1) if on else Color(0.68, 0.66, 0.72)
	var keys := _bulk_candidates()
	for child in _bulk_grid.get_children():
		child.queue_free()
	var chosen := 0
	for key in keys:
		if _bulk_selected.has(key):
			chosen += 1
		var pick := func() -> void:
			if _bulk_selected.has(key):
				_bulk_selected.erase(key)
			else:
				_bulk_selected[key] = true
			_refresh_bulk()
		var card := _bulk_card(key, pick)
		# 카드에는 확정 횟수를 안 적는다 — 천장이 **등급 통** 하나라 칸마다
		# 같은 숫자가 반복돼 헷갈린다(사장님 2026-08-25). 아래 확정 바가 그 자리다.
		# 안 고른 칸은 어둡게. 테두리를 덧그리는 대신 밝기로 가르면 등급 색이 안 죽는다.
		card.modulate = Color(1, 1, 1) if _bulk_selected.has(key) else Color(0.42, 0.42, 0.46)
		_bulk_grid.add_child(card)
	# 확률 줄 — 탭이 한 등급이면 그 등급의 실제 확률, 전체면 "등급별로 다름".
	if _bulk_tab == "all":
		_bulk_body.text = "조합 확률: 등급별로 다름  ·  조각 %d개" % GearDefs.FUSE_SHARDS
	else:
		var probe := {"rarity": _bulk_tab}
		var up := int(GearDefs.fuse_rate(probe) * 100.0)
		var next_name := str(GachaDefs.RARITIES[mini(
			GachaDefs.rarity_index(_bulk_tab) + 1,
			GachaDefs.RARITIES.size() - 1)]["name"])
		_bulk_body.text = "조합 확률: %s(%d%%) / %s(%d%%)  ·  조각 %d개" \
			% [next_name, up, str(GachaDefs.rarity(_bulk_tab)["name"]),
			100 - up, GearDefs.FUSE_SHARDS]
	# 재료 미리보기 — 고른 것 앞 넷과 결과 자리.
	_refresh_bulk_preview(keys, chosen)
	# 확정 바 — 고른 게 하나면 그 장비의 천장, 아니면 탭 등급의 규격을 보여 준다.
	_refresh_bulk_pity()
	_bulk_run.disabled = chosen == 0


# 재료 자리 — 고른 것을 앞에서부터 넷까지, 그 뒤에 결과 자리(?).
# 레퍼런스는 재료 슬롯이 셋이지만 우리 조합은 **종마다 조각 3개**를 쓰므로
# 자리에 놓이는 것은 "고른 종"이다 — 몇 종을 한꺼번에 굴리는지가 여기 선다.
# 조각 곳간 키 — 장비는 "gear:", 스킬은 "skill:".
func _bulk_owned_key(key: String) -> String:
	return ("skill:" if _bulk_kind == "skill" else "gear:") + key


# 격자 한 칸. 스킬은 제 카드가 상세를 여는 물건이라 여기서는 **고르는 칸**으로
# 새로 짓는다 — 같은 창에서 누르는 뜻이 둘이면 안 된다.
func _bulk_card(key: String, on_press: Callable) -> Control:
	if _bulk_kind != "skill":
		return _gear_card(key, on_press)
	var rar := SkillDefs.rarity_of(key)
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(116.0, 136.0)
	var hit := Button.new()
	hit.flat = true
	hit.size = cell.custom_minimum_size
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(on_press)
	cell.add_child(hit)
	var body := Control.new()
	body.size = cell.custom_minimum_size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(body)
	var frame := Ui.image("res://assets/ui/gear_card.png", Vector2(2.0, 0.0),
		Vector2(112.0, 128.0))
	frame.modulate = Color(rar["col"])
	body.add_child(frame)
	body.add_child(Ui.icon(SkillDefs.icon_path(key), Vector2(34.0, 30.0), 48.0))
	var nm := _panel_label(body, Vector2(6.0, 84.0), Type.SIZE_SMALL,
		Color(rar["col"]), 104.0, 18.0)
	nm.text = SkillDefs.name_of(key)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dt := _panel_label(body, Vector2(6.0, 100.0), Type.SIZE_SMALL,
		Color(0.82, 0.80, 0.86), 104.0, 18.0)
	dt.text = "%s · %d" % [rar["name"],
		int(gacha_shards.get("skill:" + key, 0))]
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return cell


func _refresh_bulk_preview(keys: Array[String], chosen: int) -> void:
	for c in _bulk_preview.get_children():
		c.queue_free()
	_bulk_hint.visible = chosen == 0
	if chosen == 0:
		var what := "스킬" if _bulk_kind == "skill" else "장비"
		_bulk_hint.text = ("조합할 %s를 고르세요" % what) if not keys.is_empty() \
			else "조각이 %d개 모인 %s가 없습니다" % [GearDefs.FUSE_SHARDS, what]
		return
	var shown := 0
	for key in keys:
		if not _bulk_selected.has(key):
			continue
		if shown >= 4:
			break
		var rar := GachaDefs.rarity(_bulk_rarity_of(key))
		var at := Vector2(float(shown) * 96.0, 8.0)
		var fr := Ui.image("res://assets/ui/gear_card_small.png", at,
			Vector2(80.0, 96.0))
		fr.modulate = Color(rar["col"])
		_bulk_preview.add_child(fr)
		_bulk_preview.add_child(Ui.icon(SkillDefs.icon_path(key) \
			if _bulk_kind == "skill" \
			else GearDefs.icon_path(gear_inventory[key]),
			at + Vector2(16.0, 18.0), 48.0))
		var sh := _panel_label(_bulk_preview, at + Vector2(0.0, 98.0),
			Type.SIZE_SMALL, Color(0.82, 0.80, 0.86), 80.0, 18.0)
		sh.text = "조각 %d" % GearDefs.FUSE_SHARDS
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shown += 1
	if chosen > shown:
		var more := _panel_label(_bulk_preview, Vector2(float(shown) * 96.0, 44.0),
			Type.SIZE_SMALL, Color(0.86, 0.84, 0.90), 80.0, 20.0)
		more.text = "+%d종" % (chosen - shown)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var arrow := _panel_label(_bulk_preview, Vector2(400.0, 44.0), Type.SIZE_BODY,
		Color(0.72, 0.70, 0.76), 40.0, 24.0)
	arrow.text = "»"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var qbox := Ui.image("res://assets/ui/gear_card_small.png",
		Vector2(444.0, 8.0), Vector2(80.0, 96.0))
	qbox.modulate = Color(0.62, 0.60, 0.68)
	_bulk_preview.add_child(qbox)
	var q := _panel_label(_bulk_preview, Vector2(444.0, 40.0), Type.SIZE_BODY,
		Color(0.92, 0.90, 0.94), 80.0, 30.0)
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# 확정까지 남은 횟수. 한 종만 골랐으면 그 종의 누적을, 아니면 탭 등급의
# 규격(0 부터)을 보여 준다 — 여러 종은 각자 천장이라 하나로 못 합친다.
func _refresh_bulk_pity() -> void:
	# **첫 선택 하나를 기준으로 고정한다.** 선택 개수에 따라 기준을 바꿨더니
	# 고를 때마다 막대가 튀었다(사장님: "확정바도 왔다갔다"). 천장은 종마다
	# 따로 쌓이므로 여럿을 하나로 합칠 수 없다 — 대표 하나를 보여 주고
	# 나머지는 라벨에 종 수로 적는다.
	var only := ""
	var picked := 0
	for key in _bulk_candidates():
		if not _bulk_selected.has(key):
			continue
		picked += 1
		if only == "":
			only = str(key)
	# 아무것도 안 골랐어도 **의미 있는 값**을 보여 준다 — 그 탭에서 확정에
	# 가장 가까운 종이 기준이다(사장님: "재료 넣기 전부터 보여야").
	if only == "":
		var best := -1
		for key in _bulk_candidates():
			var t2 := int(fuse_pity.get(_bulk_rarity_of(key), 0))
			if t2 > best:
				best = t2
				only = str(key)
	var rar_key := _bulk_tab if _bulk_tab != "all" else "common"
	var tries := 0
	if only != "":
		rar_key = _bulk_rarity_of(only)
		tries = int(fuse_pity.get(_bulk_rarity_of(only), 0))
	var cap := GearDefs.fuse_pity({"rarity": rar_key})
	var next_name := str(GachaDefs.RARITIES[mini(
		GachaDefs.rarity_index(rar_key) + 1,
		GachaDefs.RARITIES.size() - 1)]["name"])
	_bulk_pity_lbl.text = ("%s 확정까지 %d회" % [next_name, maxi(1, cap - tries)]) if picked <= 1 \
		else "%s 확정 (선택 %d종 중 하나)" % [next_name, picked]
	_bulk_pity_num.text = "%d / %d" % [tries, cap]
	_bulk_pity_bar.size.x = 300.0 * clampf(float(tries) / float(maxi(cap, 1)),
		0.0, 1.0)


# 실행 버튼은 **묻기만 한다.** 되돌릴 수 없는 작업이라 손이 미끄러지면 끝이다.
func _run_bulk() -> void:
	var chosen := 0
	for key in _bulk_candidates():
		if _bulk_selected.has(key):
			chosen += 1
	if chosen == 0:
		return
	_ask("선택한 %s %d종을 조합합니다.\n각각 조각 %d개를 쓰며, 등급별 확률로 성공합니다.\n실패해도 조각은 소모됩니다(천장 있음)."
		% ["스킬" if _bulk_kind == "skill" else "장비", chosen,
		GearDefs.FUSE_SHARDS], _do_bulk)


func _do_bulk() -> void:
	var old_max := max_hp()
	var got: Array = []
	# 후보 목록을 기준으로 돈다 — 선택 사전에는 그새 사라진 키가 남아 있을 수 있다.
	for key in _bulk_candidates():
		if not _bulk_selected.has(key):
			continue
		var new_key := _synthesize_skill(key) if _bulk_kind == "skill" \
			else _synthesize(key)
		if _bulk_kind == "skill":
			if not new_key.is_empty():
				var r5 := SkillDefs.rarity_of(new_key)
				got.append({"icon": SkillDefs.icon_path(new_key),
					"label": SkillDefs.name_of(new_key),
					"sub": str(r5["name"]), "col": r5["col"]})
			elif _fuse_failed and not _fuse_gain.is_empty():
				got.append(_fuse_gain.duplicate())
			continue
		if not new_key.is_empty() and gear_inventory.has(new_key):
			var it: Dictionary = gear_inventory[new_key]
			# 등급 틀+등급명 — 스킬 합성 팝업과 같은 문법(사장님).
			got.append({"icon": GearDefs.icon_path(it),
				"label": str(it["name"]), "col": it["col"],
				"sub": str(GachaDefs.rarity(str(it["rarity"]))["name"])})
		elif _fuse_failed and not _fuse_gain.is_empty():
			got.append({"icon": GearDefs.icon_path(_fuse_gain),
				"label": str(_fuse_gain["name"]), "col": _fuse_gain["col"],
				"sub": str(GachaDefs.rarity(str(_fuse_gain["rarity"]))["name"])})
	_apply_hp_growth(old_max)
	_bulk_selected.clear()
	if _bulk_kind == "skill":
		if skill_auto_equip:
			_auto_equip_skills()
		_refresh_skills()
	if not got.is_empty():
		# 6개까지만 보여 준다 — 그 이상은 한 줄에 안 들어가고, 어차피 보관함에 다 있다.
		_show_reward("조합 결과", got.slice(0, mini(got.size(), 5)))
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
		var total := 0
		for rarity in GachaDefs.RARITIES:
			total += GearDefs.items_of(key, str(rarity["key"])).size()
		b.text = "%s %d/%d" % [str(GearDefs.SLOT_NAME[key]), n, total]


func _refresh_gear_inventory() -> void:
	if _gear_hold_lbl:
		# 보관함에 있기만 해도 붙는 몫. 합성해도 하위 종이 남으므로 이 숫자는
		# **줄지 않는다** — 그게 이 줄을 만든 이유다(사장님).
		# 짧은 이름으로 적는다 — 정식 이름(최대 체력·피 획득)까지 넣으면 한 줄
		# 528px 을 넘겨 끝 항목이 잘렸다(사장님 캡처).
		var short := {"damage": "공격", "tough": "체력", "critdmg": "치명피해"}
		var parts := PackedStringArray()
		for st in ["damage", "tough", "critdmg"]:
			parts.append("%s +%.0f%%" % [short[st], _collection_bonus(st) * 100.0])
		_gear_hold_lbl.text = "보유 효과(%d종)  %s" % [gear_inventory.size(),
			"  ·  ".join(parts)]
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
	# 표 전체를 등급 순으로 늘어놓고, 가진 것은 제 칸으로 못 가진 것은 "?" 로
	# 채운다(사장님: 펫·유물처럼 획득 여부가 한눈에). 슬롯당 24종이라 다 보인다.
	for rarity in GachaDefs.RARITIES:
		for spec in GearDefs.items_of(_gear_filter, str(rarity["key"])):
			var key := str(spec[0])
			if gear_inventory.has(key):
				_gear_inventory_grid.add_child(_gear_card(key,
					func() -> void: _open_gear_detail(key)))
			else:
				_gear_inventory_grid.add_child(_gear_unknown_card(rarity))


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
	# **칸마다 붉은 점** (사장님 2026-08-26: "레벨업할 수 있는 것들은 다").
	# 탭 점은 "이 탭에 뭔가 있다"까지만 말한다 — 스물넷을 눌러 보게 하지 않으려면
	# 어느 칸인지도 말해야 한다. body 가 아니라 cell 에 붙인다: 장착 중이면
	# body 를 통째로 어둡게 하는데 점까지 같이 죽으면 안 된다.
	if _gear_can_level(key) or _gear_can_fuse(key):
		var dot := Ui.icon("res://assets/ui/dot_alert.png",
			Vector2(88.0, 4.0), 16.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(dot)
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


# 아직 못 얻은 종. 등급 테두리만 어둡게 남기고 그림 자리에 "?" 를 놓는다 —
# 무엇이 남았는지가 보여야 모으는 재미가 산다(사장님).
func _gear_unknown_card(rarity: Dictionary) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(116.0, 136.0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := Color(rarity["col"]) * 0.42
	var frame := Ui.image("res://assets/ui/gear_card.png", Vector2(2.0, 0.0),
		Vector2(112.0, 128.0))
	frame.modulate = Color(dim.r, dim.g, dim.b, 0.85)
	cell.add_child(frame)
	var q := _panel_label(cell, Vector2(6.0, 44.0), Type.SIZE_TITLE,
		Color(dim.r * 1.6, dim.g * 1.6, dim.b * 1.6), 104.0, 40.0)
	q.text = "?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nm := _panel_label(cell, Vector2(6.0, 102.0), Type.SIZE_SMALL,
		Color(dim.r * 1.4, dim.g * 1.4, dim.b * 1.4), 104.0, 20.0)
	nm.text = "%s · 미획득" % str(rarity["name"])
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var highest := GachaDefs.rarity_index(str(item["rarity"])) >= GachaDefs.RARITIES.size() - 1
	var pity_left := maxi(1, GearDefs.fuse_pity(item)
		- int(fuse_pity.get(str(item.get("rarity", "common")), 0)))
	var up_cost0 := GearDefs.upgrade_cost(item)
	var resource_values := [
		["조각 %d/%d" % [shards, GearDefs.FUSE_SHARDS], Color(0.72, 0.72, 0.78)],
		["-" if highest else "성공 %d%%" % int(GearDefs.fuse_rate(item) * 100.0),
			Color(0.68, 0.82, 1.0)],
		["-" if highest else "확정까지 %d회" % pity_left, Color(0.82, 0.80, 0.86)],
		["최고 등급" if highest else "조합 가능" if shards >= GearDefs.FUSE_SHARDS \
			else "조합 대기", Color(rarity["col"])],
		["연마석 %s / %s" % [_n(whet), _n(up_cost0, true)],
			Color(0.68, 0.86, 0.72) if whet >= up_cost0 else Color(0.86, 0.62, 0.58)],
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
	# 조합은 **전체 화면 조합 창**에서만 한다(사장님 2026-08-25) — 자리가
	# 둘이면 어느 쪽이 진짜인지 흐려진다. 여기는 레벨업이다.
	var synth_button := Ui.button("레벨업",
		Vector2(130.0, 264.0), Vector2(100.0, 44.0), Type.SIZE_SMALL)
	Ui.cost_icon(synth_button, "res://assets/items/gem.png", 16)
	synth_button.disabled = whet < up_cost0
	synth_button.pressed.connect(_level_up_selected)
	_gear_detail.add_child(synth_button)
	var close := Ui.button("닫기", Vector2(454.0, 264.0),
		Vector2(100.0, 44.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _gear_detail.visible = false)
	_gear_detail.add_child(close)


# 장착 중인 장비는 분해하지 않는다 — 지금 입고 있는 걸 녹이면 전투력이 말없이 떨어진다.
func _is_equipped_key(key: String) -> bool:
	for item in equipped.values():
		if str(item.get("inventory_key", "")) == key:
			return true
	return false


# 레벨업 — 연마석을 내고 한 칸. 장착 중이면 장착본도 같이 올린다.
func _level_up_selected() -> void:
	var item: Dictionary = gear_inventory.get(_gear_selected_key, {})
	if item.is_empty() or GearDefs.is_max_lv(item):
		return
	var cost := GearDefs.upgrade_cost(item)
	if whet < cost:
		return
	# **신화는 100렙부터 조각도 낸다** — 연마석은 시간이 벌지만 조각은 뽑기에서만
	# 나온다. 최고 등급의 끝을 "돈으로 못 사는 구간"으로 두는 자리다.
	var need_sh := GearDefs.upgrade_shards(item)
	var sh_key := "gear:" + _gear_selected_key
	if need_sh > 0 and int(gacha_shards.get(sh_key, 0)) < need_sh:
		return
	var old_max := max_hp()
	whet -= cost
	if need_sh > 0:
		gacha_shards[sh_key] = int(gacha_shards.get(sh_key, 0)) - need_sh
	item["lv"] = int(item.get("lv", 0)) + 1
	var slot := str(item["slot"])
	if str(equipped.get(slot, {}).get("inventory_key", "")) == _gear_selected_key:
		var eq := item.duplicate(true)
		eq["inventory_key"] = _gear_selected_key
		equipped[slot] = eq
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gear_detail()
	_refresh_hud()
	_save_game()


func _synthesize_selected() -> void:
	var key_now := _gear_selected_key
	var new_key := _synthesize(key_now)
	if new_key.is_empty():
		if _fuse_failed and not _fuse_gain.is_empty():
			_show_reward("조합 결과", [{"icon": GearDefs.icon_path(_fuse_gain),
				"label": str(_fuse_gain["name"]), "col": _fuse_gain["col"],
				"sub": str(GachaDefs.rarity(str(_fuse_gain["rarity"]))["name"])}])
			_refresh_gear_slots()
			_refresh_gear_inventory()
			_refresh_gear_detail()
			_refresh_bulk()
			_save_game()
		return
	_gear_selected_key = new_key
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gear_detail()
	_save_game()


# 한 칸 승급 **시도**. 성공하면 승급 후 키, 실패·불가면 "" — 실패 여부는
# _fuse_failed 로 가른다. 시도마다 조각을 소모하고, 등급별 확률로 성공하며,
# 실패가 등급별 천장에 닿으면 그 시도는 확정이다(사장님 2026-08-25).
var _fuse_failed := false
var _fuse_gain := {}      # 실패 보상으로 준 장비
# 이 조합이 만렙을 요구하는가 — **최고 등급 바로 아래**만 그렇다.
# 화면(_refresh_gear_detail)과 실제 조합이 같은 자를 쓰게 함수로 둔다:
# 둘이 갈리면 버튼은 눌리는데 아무 일도 안 일어난다.
func _fuse_needs_max(item: Dictionary) -> bool:
	var i := GachaDefs.rarity_index(str(item.get("rarity", "common")))
	return i == GachaDefs.RARITIES.size() - 2 and not GearDefs.is_max_lv(item)


func _synthesize(old_key: String) -> String:
	_fuse_failed = false
	_fuse_gain = {}
	var item: Dictionary = gear_inventory.get(old_key, {})
	var owned_key := "gear:" + old_key
	if item.is_empty() or int(gacha_shards.get(owned_key, 0)) < GearDefs.FUSE_SHARDS:
		return ""
	# **최고 등급으로 가는 조합만 만렙을 요구한다** (사장님 2026-08-26:
	# "신화 조합하려면 레전더리 다 만렙 찍어야"). 이 한 칸이 최종 사다리를
	# 만든다 — 레전더리 만렙(15일) -> 신화 조합 -> 신화 만렙(60일).
	# 아래 등급은 그대로다: 초반에 만렙을 강제하면 조합이 벌이 된다.
	if _fuse_needs_max(item):
		return ""
	_quest_bump("gear")   # 임무 "장비 조합"은 시도를 센다 — 실패도 조합이다
	# 천장은 **등급 통**에 쌓인다 — 같은 등급이면 무기든 스킬이든 한 줄.
	var rar_pity := str(item.get("rarity", "common"))
	var tries := int(fuse_pity.get(rar_pity, 0)) + 1
	if tries < GearDefs.fuse_pity(item) and randf() >= GearDefs.fuse_rate(item):
		gacha_shards[owned_key] = int(gacha_shards[owned_key]) - GearDefs.FUSE_SHARDS
		fuse_pity[rar_pity] = tries
		_fuse_failed = true
		# **빈손으로 돌려보내지 않는다** (사장님 2026-08-25): 조각 셋을 썼으면
		# 같은 등급 장비 하나는 나온다. 천장은 그대로 쌓인다.
		_fuse_gain = _receive_gacha_gear(str(item.get("rarity", "common")),
			str(item.get("slot", "weapon")))
		return ""
	fuse_pity.erase(rar_pity)
	var old_max := max_hp()
	var slot := str(item["slot"])
	var was_equipped := str(equipped.get(slot, {}).get("inventory_key", "")) == old_key
	var keep := item.duplicate(true)   # 승급 전 모습 — 한 벌은 남는다
	if not GearDefs.promote(item):
		return ""
	var result_key := old_key
	var remaining_shards := int(gacha_shards[owned_key]) - GearDefs.FUSE_SHARDS
	var new_key := str(item["icon"])
	if new_key != old_key:
		# **하위 종을 지우지 않는다**(사장님: 처음 뽑은 건 하나는 무조건).
		# 보유(수집) 효과는 보관함 순회라, 종이 사라지면 그 몫도 사라졌다.
		keep["copies"] = 1
		gear_inventory[old_key] = keep
		gacha_shards[owned_key] = 0    # 조각은 승급에 들어갔다
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
	_refresh_presets("gear")
	for slot in _gear_slots.keys():
		var item: Dictionary = equipped.get(slot, {})
		var nodes: Dictionary = _gear_slots[slot]
		if item.is_empty():
			nodes["icon"].texture = null
			nodes["frame"].texture = Assets.tex("res://assets/ui/slot_common.png")
			nodes["frame"].modulate = Color(0.45, 0.45, 0.5)
			nodes["label"].text = GearDefs.SLOT_NAME[slot]
			nodes["label"].add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			nodes["lv"].text = ""
			nodes["stat"].text = "비었음"
			continue
		nodes["icon"].texture = Assets.tex(GearDefs.icon_path(item))
		nodes["frame"].texture = Assets.tex(GearDefs.slot_frame(item))
		nodes["frame"].modulate = Color(1, 1, 1)
		# 칸 폭이 168px뿐이라 강화 레벨까지 넣으면 옆 칸 글자와 겹친다.
		# 레벨은 강화 버튼을 누르면 오르는 수치로 이미 읽힌다.
		nodes["label"].text = str(item["name"])
		nodes["label"].add_theme_color_override("font_color", Color(item["col"]))
		nodes["lv"].text = "레벨 %d" % int(item.get("lv", 0))
		nodes["stat"].text = _gear_gain_line(item)


# 이 장비 하나가 실제로 올려 주는 값. **슬롯마다 단위가 다르다** — 무기는
# 피해 식에 절대값으로 더해지고(Balance.hero_damage), 방어구는 최대 체력의
# 12%/점, 장신구는 혈액의 2%/점이다. 화면에 같은 단위로 적으면 거짓말이 된다.
func _gear_gain_line(item: Dictionary) -> String:
	var p := GearDefs.power(item)
	# **좁은 칸이라 축약한다** — 후반 값은 네 자리를 넘어 칸을 넘친다
	# (사장님 2026-08-25: "폰트 짤리는거 수정").
	match str(item.get("stat", "")):
		"tough": return "체력 +%s%%" % _n(p * 12.0, true)
		"critdmg": return "치명피해 +%s%%" % _n(p * GEAR_CRITDMG * 100.0, true)
	return "공격 +%s" % _n(p, true)


func _build_gacha(root: Control) -> void:
	# 전면 판 (사장님 2026-08-13, 레퍼런스 문법): 장소 헤더가 위에 서고 — 장비는
	# 대장간, 스킬·유물은 점성소 — 종류를 고르면 장소가 따라 바뀐다. 레퍼런스는
	# 대장간/점성소를 소탭으로 갈랐지만 우리는 종류 탭이 이미 그 일을 한다.
	var head := Control.new()
	head.position = Vector2(PAD, 12.0)
	head.size = Vector2(CONTENT_W, 210.0)
	head.clip_contents = true
	root.add_child(head)
	_gacha_head_tex = TextureRect.new()
	_gacha_head_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gacha_head_tex.size = Vector2(CONTENT_W, CONTENT_W * 224.0 / 576.0)
	_gacha_head_tex.position = Vector2(0.0, -6.0)
	_gacha_head_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gacha_head_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_gacha_head_tex)
	_gacha_place = _panel_label(head, Vector2(16.0, 10.0), Type.SIZE_MID,
		Color(0.97, 0.92, 0.86), 220.0, 24.0)
	_shop_outline(_gacha_place, 8)
	# 말풍선 — 세트의 꺼진 알약을 옆으로 늘려 쓴다(장소 따라 그림이 바뀐다).
	_gacha_bubble = _shop_tex(head, "res://assets/ui/sets/forge_tab_off.png",
		Vector2(8.0, 42.0), Vector2(328.0, 40.0))
	_gacha_line = _panel_label(head, Vector2(26.0, 52.0), Type.SIZE_SMALL,
		Color(0.95, 0.88, 0.80), 300.0, 18.0)
	_shop_outline(_gacha_line, 4)
	# 종류 탭 다섯 — **탭마다 전용 세트**(사장님): 장비 셋은 대장간 철 알약,
	# 스킬·유물은 점성소 달 알약. 어느 장소로 가는 탭인지 그림이 먼저 말한다.
	var kinds := ["weapon", "armor", "trinket", "skill", "relic"]
	var kw := (CONTENT_W - 8.0 * 4.0) / 5.0    # 99.2
	for i in kinds.size():
		var kind: String = kinds[i]
		var set_name := "forge" if i < 3 else "astro"
		var tb := TextureButton.new()
		tb.texture_normal = Assets.tex(
			"res://assets/ui/sets/%s_tab_off.png" % set_name)
		tb.texture_pressed = Assets.tex(
			"res://assets/ui/sets/%s_tab_on.png" % set_name)
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.toggle_mode = true
		tb.position = Vector2(PAD + float(i) * (kw + 8.0), 232.0)
		tb.size = Vector2(kw, 36.0)
		Ui.hover_pop(tb)
		tb.pressed.connect(func() -> void: _set_gacha_kind(kind))
		root.add_child(tb)
		var tl := _panel_label(root, Vector2(tb.position.x, 239.0),
			Type.SIZE_SMALL, Color(1.0, 0.97, 0.92), kw, 22.0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(tl, 6)
		_gacha_buttons[kind] = tb
		_gacha_kind_labels[kind] = tl
	# 소환 카드 — 세트 몸판(대장간 철판/점성소 별판)을 장소 따라 갈아 끼운다.
	# 두 몸판의 원본 크기가 달라도 **528x288 로 고정**해 안 요소가 안 흔들린다.
	_gacha_card_tex = _shop_tex(root, "res://assets/ui/sets/forge_body.png",
		Vector2(PAD, 284.0), Vector2(CONTENT_W, 288.0))
	_gacha_icon = Ui.icon("", Vector2(GACHA_ART_X, GACHA_ART_Y), GACHA_ART_BOX)
	root.add_child(_gacha_icon)
	# 글자 칸 — 액자 오른쪽부터. 확률은 두 줄로 나뉘므로 한 줄 최악값이 300 에 든다.
	var text_x := PAD + 214.0
	var text_w := PAD + CONTENT_W - 14.0 - text_x
	_gacha_labels["pity"] = _panel_label(root, Vector2(text_x, 330.0), Type.SIZE_MID,
		Color(1.0, 0.86, 0.52), text_w, 28.0)
	_gacha_labels["pity"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 2줄: 다음 레벨까지 남은 횟수와 천장. 레벨과 천장은 역할이 달라 같이 보여야 한다.
	_gacha_labels["sub"] = _panel_label(root, Vector2(text_x, 364.0), Type.SIZE_SMALL,
		Color(0.72, 0.72, 0.80), text_w, 20.0)
	_gacha_labels["sub"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_labels["rates"] = _panel_label(root, Vector2(text_x, 390.0), Type.SIZE_SMALL,
		Color(0.62, 0.82, 0.68), text_w, 44.0)
	_gacha_labels["rates"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_labels["rates"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 확률표 버튼 — 세트 알약 그림. **띠 높이가 몸판마다 달라 y 는 세트별**이다
	# (사장님: "두 개 사이즈 공유하니? 같이 움직이네") — TABLE_Y 를 _refresh 가 고른다.
	var tpos := Vector2(PAD + (CONTENT_W - 116.0) * 0.5, TABLE_Y["forge"])
	_gacha_table_tex = _shop_tex(root, "res://assets/ui/sets/forge_pill.png",
		tpos, Vector2(116.0, 34.0))
	_gacha_table_lbl = _panel_label(root, Vector2(tpos.x, tpos.y + 9.0),
		Type.SIZE_SMALL, Color(0.95, 0.90, 0.86), 116.0, 18.0)
	_gacha_table_lbl.text = "확률표"
	_gacha_table_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_gacha_table_lbl, 5)
	var table_btn := _shop_ghost(root, Vector2(116.0, 34.0), _gacha_table_tex)
	table_btn.position = tpos
	_gacha_table_btn = table_btn
	table_btn.pressed.connect(func() -> void:
		_rates_view.visible = not _rates_view.visible
		if _rates_view.visible:
			_refresh_rates_table())
	# 소환권 잔량 — **아이콘 + 숫자, 세트 알약 넷** (참고작 상단 재화 줄 문법).
	var tk_w := (CONTENT_W - 30.0) / 4.0
	for i in TicketDefs.KINDS.size():
		var tk: String = TicketDefs.KINDS[i]
		var tx2 := PAD + float(i) * (tk_w + 10.0)
		_gacha_tk_texs.append(_shop_tex(root,
			"res://assets/ui/sets/forge_pill.png",
			Vector2(tx2, 584.0), Vector2(tk_w, 30.0)))
		# 아이콘 x+16 — 알약 곡선 테두리에 걸치면 일그러져 보인다(사장님 실측).
		root.add_child(Ui.icon(TicketDefs.icon_of(tk), Vector2(tx2 + 16.0, 589.0), 20.0))
		_gacha_ticket_labels.append(_panel_label(root, Vector2(tx2 + 42.0, 585.0),
			Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), tk_w - 50.0, 28.0))
	# 버튼 둘 — 1회 · 10연. 세트 버튼 그림 + 투명 버튼(값 표기는 라벨·아이콘).
	for pair in [["one", 24.0, 1], ["ten", 292.0, 10]]:
		var key: String = pair[0]
		var bpos := Vector2(pair[1], 628.0)
		var count: int = pair[2]
		_gacha_btn_tex[key] = _shop_tex(root,
			"res://assets/ui/sets/forge_button.png", bpos, Vector2(258.0, 58.0))
		var bic := Ui.icon("res://assets/ui/res_gem.png",
			bpos + Vector2(52.0, 15.0), 28.0)
		bic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bic)
		_gacha_btn_icon[key] = bic
		var blb := _panel_label(root, bpos + Vector2(0.0, 17.0), Type.SIZE_MID,
			Color(1.0, 0.96, 0.90), 258.0, 24.0)
		blb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(blb, 8)
		_gacha_btn_lbl[key] = blb
		var gb := _shop_ghost(root, Vector2(258.0, 58.0), _gacha_btn_tex[key])
		gb.position = bpos
		gb.pressed.connect(func() -> void: _pull_gacha(count))
		_gacha_buttons[key] = gb
	# 아랫줄 — 남은 권 털기 (사장님 2026-08-25: "소환권이 6개 애매하게 남았을 때
	# 6개 뽑기"). 2~9장일 때만 보인다 — 1장은 1회 버튼이, 10장부터는 10연이
	# 이미 그 값이다. 30연·50연은 소환 결과 창에서만 판다(같은 날 캡처 피드백).
	for pair2 in [["left", 159.0, 0]]:
		var key2: String = pair2[0]
		var bpos2 := Vector2(pair2[1], 694.0)
		var count2: int = pair2[2]
		_gacha_btn_tex[key2] = _shop_tex(root,
			"res://assets/ui/sets/forge_button.png", bpos2, Vector2(258.0, 58.0))
		var bic2 := Ui.icon("res://assets/ui/res_gem.png",
			bpos2 + Vector2(52.0, 15.0), 28.0)
		bic2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bic2)
		_gacha_btn_icon[key2] = bic2
		var blb2 := _panel_label(root, bpos2 + Vector2(0.0, 16.0), Type.SIZE_MID,
			Color(1.0, 0.96, 0.90), 258.0, 28.0)
		blb2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(blb2, 8)
		_gacha_btn_lbl[key2] = blb2
		var gb2 := _shop_ghost(root, Vector2(258.0, 58.0), _gacha_btn_tex[key2])
		gb2.position = bpos2
		if count2 > 0:
			gb2.pressed.connect(func() -> void: _pull_gacha(count2))
		else:
			# 남은 권 전부 — 누르는 순간의 잔량으로 뽑는다.
			gb2.pressed.connect(func() -> void:
				var n := int(tickets.get(_gacha_kind, 0))
				if n >= 2 and n <= 9:
					_pull_gacha(n))
		_gacha_buttons[key2] = gb2
	_mile_strip(root, Vector2(214.0, 442.0), 300.0)
	_build_rates_table(root)
	_gacha_reveal = Control.new()
	_gacha_reveal.size = Vector2(PANEL_W, PANEL_FULL_H)
	_gacha_reveal.visible = false
	root.add_child(_gacha_reveal)
	_refresh_gacha()


# 세로=등급, 가로=레벨. 반대로 놓으면 머리글에 "레전더리"(72px)가 여섯 번 들어가
# 칸이 안 나온다. 등급 이름은 왼쪽 한 열에만 있으면 된다.
func _rate_cols() -> int:
	return GachaDefs.LEVEL_MAX - GachaDefs.LEVEL_MIN + 1


func _build_rates_table(root: Control) -> void:
	_rates_view = Control.new()
	_rates_view.size = Vector2(PANEL_W, PANEL_FULL_H)
	_rates_view.visible = false
	_rates_view.z_index = 5
	root.add_child(_rates_view)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.05, 0.065)
	back.position = Vector2(PAD * 0.5, PAD * 0.5)
	back.size = Vector2(PANEL_W - PAD, PANEL_FULL_H - PAD)
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
# [테스트용] F10 으로 1막 1-1 로 뛰고, 다시 누르면 원래 자리로 돌아온다.
#
# **저장본을 지우지 않는다.** 보석·장비·레벨·도감은 그대로다 — 새 몹 모션을 보려고
# 진행을 날릴 이유가 없고, 저장본이 실제로 날아간 사고가 한 번 있었다(인계 3-3).
# 되돌아올 자리를 기억해 두는 토글이라 왕복이 한 키로 끝난다.
var _dev_return_stage := 0
# [테스트용] F11 로 영웅 피해를 1/12 로 낮춘다. 새 모션을 **보려고** 있는 값이다.
#
# 왜 필요한가: 1막 몹은 HP 7 이고 영웅 피해는 14 라 **도착하는 순간 한 방에 죽는다.**
# 그래서 몹이 멈춰 서는 것도, 간격을 지키는 것도, 새로 만든 내려찍기 모션도 화면에서
# 볼 수가 없다 - 생애 2.6초가 거의 전부 걸어오는 구간이다.
#
# 실측(2026-08-06) 몹이 "걷는 중"인 시간 비율: 1막 91% / 31막 44% / 61막 17%.
# 사장님: "특정거리에 들어오면 멈춰야하고 ... 계속 걸어옴" - 멈춤·간격 로직은 정상이고
# (61막에서 83% 를 멈춰 서 있다) 1막에서는 멈춘 모습을 볼 시간이 없었던 것이다.
#
# 1/12 는 1막 몹(HP 7)이 여섯 대를 버티는 값이다. 저장하지 않는다 - 다시 켜면 꺼진다.
const DEV_WEAK_MULT := 1.0 / 12.0
var _dev_weak := 1.0


func _unhandled_key_input(event: InputEvent) -> void:
	if _load_layer != null:
		return          # 조립 중 치트키는 반쯤 지어진 판을 만진다
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F10:
		_dev_jump_stage()
		return
	if key.keycode == KEY_F11:
		_dev_toggle_weak()
		return
	if key.keycode == KEY_F12:
		_dev_reset_skill_cd()
		return
	# Ctrl+G — 검수 상태로 한 방에(100구간·전 콘텐츠 해금). 사장님은 빌드한
	# 실행본을 플레이하므로 명령줄 플래그(--god)로는 못 쓴다 — 키로도 연다.
	#
	# **F5~F8 은 못 쓴다**: Godot 에디터가 실행/일시정지/중지로 먼저 먹는다
	# (F8 로 뒀더니 게임이 그대로 꺼졌다 — 사장님 실측). 남은 F9~F12 는 이미
	# 다른 치트가 쓰고 있어서 조합키로 간다. 실수로 눌릴 일도 없다.
	if key.keycode == KEY_G and key.ctrl_pressed:
		_dev_god(100)
		_show_reward("검수 지급", [{"icon": "res://assets/ui/res_gem.png",
			"label": "100구간", "sub": "전 콘텐츠 해금"}])
		return
	# Ctrl+H — **해금만**(재화·구간 점프 없음). Ctrl+G 는 재화를 쏟아서 검수
	# 중 밸런스 체감이 망가진다 — 성소 수호자가 한 방에 죽어 패턴 구경도 못
	# 했다(사장님). 자기 실제 화력으로 콘텐츠만 열어 본다.
	if key.keycode == KEY_H and key.ctrl_pressed:
		_dev_unlock(100)
		_show_reward("검수 해금", [{"icon": "res://assets/ui/badge_promo.png",
			"label": "전 콘텐츠", "sub": "재화·성장은 그대로"}])
		return
	if key.keycode != KEY_F9:
		return
	gem += CHEAT_GEMS
	_refresh_hud()
	_refresh_gacha()
	_save_game()
	_show_reward("테스트 지급", [{"icon": "res://assets/ui/res_gem.png",
		"label": "보석 +%s" % _n(CHEAT_GEMS)}])


func _dev_toggle_weak() -> void:
	_dev_weak = DEV_WEAK_MULT if is_equal_approx(_dev_weak, 1.0) else 1.0
	var on := not is_equal_approx(_dev_weak, 1.0)
	_refresh_hud()


# [테스트용] F12 — **스킬 쿨다운을 전부 0으로.** 스킬 연출을 보려면 최대 23초를
# 기다려야 하는데(가호), 여섯 칸을 돌려 보려면 그게 몇 분이 된다(2026-08-10 사장님).
#
# **누르는 순간 다 나가지는 않는다.** `_tick_skills` 가 한 번에 하나씩만 시전하므로
# 쿨다운이 0이어도 순서대로 나간다 — 그게 오히려 하나씩 보기에 낫다.
#
# 진행 중인 시전(`_skill_action`)은 안 끊는다. 끊으면 그 스킬의 피해가 영영 안 들어가고
# (`_skill_impact_sent`), 화면에는 "스킬이 씹혔다"로 보인다.
func _dev_reset_skill_cd() -> void:
	_skill_cd.clear()


func _dev_jump_stage() -> void:
	if _dev_return_stage > 0:
		stage = clampi(_dev_return_stage, 1, StageDefs.total_stages())
		_dev_return_stage = 0
	else:
		_dev_return_stage = stage
		stage = 1
	# best_stage 는 건드리지 않는다 — 최고 기록이지 현재 위치가 아니다.
	_restart_stage("테스트 이동")
	_refresh_hud()
	_save_game()


# high 면 고급 소환권(에픽 확정) 한 장. 아니면 **무료 > 소환권 > 보석** 순으로
# 낸다 — 소환권을 두고 보석이 나가면 유저가 손해를 본 줄도 모른다. 부분 지불
# (소환권 3장 + 보석 7회)은 안 한다: 값이 두 줄로 읽히면 무엇을 냈는지 흐려진다.
# 값은 **소환권을 있는 만큼 먼저** 치르고 모자란 몫만 보석으로 낸다
# (2026-08-20, 사장님: "소환권이 9개 남아 있으면...").
#
# 예전엔 전부 아니면 전무였다: 10연에 권이 9장이면 `have >= 10` 이 거짓이라
# **9장을 놔둔 채 보석 300** 이 나갔다. 소환권은 소환 말고 쓸 데가 없으므로
# 아껴 둘 이유가 없고, 남겨 두는 쪽이 손해다.
func _pull_gacha(count: int) -> void:
	var have := int(tickets.get(_gacha_kind, 0))
	var free := count == 1 \
		and free_pull_date != Time.get_date_string_from_system()
	var use_tk := 0 if free else mini(have, count)
	var cost := GachaDefs.COST * float(count - use_tk - (1 if free else 0))
	if gem < cost:
		return
	gem -= cost
	if use_tk > 0:
		tickets[_gacha_kind] = have - use_tk
	if free:
		free_pull_date = Time.get_date_string_from_system()
	_quest_bump("summon", count)
	# 레벨은 **이번 뽑기 전** 값으로 굴린다 — 화면에 적힌 확률 그대로여야 한다.
	var result := GachaDefs.pull(count, int(gacha_pity.get(_gacha_kind, 0)),
		GachaDefs.level(int(gacha_pulls.get(_gacha_kind, 0))), _gacha_kind == "skill")
	gacha_pity[_gacha_kind] = int(result["pity"])
	gacha_pulls[_gacha_kind] = int(gacha_pulls.get(_gacha_kind, 0)) + count
	_mile_add(_gacha_kind, count)
	var received_items: Array[Dictionary] = []
	for rarity_key in result["rarities"]:
		var received: Dictionary = {}
		if _gacha_kind in GearDefs.SLOTS:
			received = _receive_gacha_gear(str(rarity_key))
		elif _gacha_kind == "relic":
			received = _receive_gacha_relic(str(rarity_key))
		else:
			received = _receive_gacha_skill(str(rarity_key))
		received_items.append(received)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_gacha()
	_save_game()
	_show_gacha_results(received_items)


# slot_in 을 주면 그 슬롯으로 만든다 — 조합 실패 보상은 **조합한 장비와 같은
# 슬롯**이어야 한다(소환은 지금 고른 종류를 쓴다).
func _receive_gacha_gear(rarity_key: String, slot_in := "") -> Dictionary:
	var slot := slot_in if slot_in != "" else _gacha_kind
	var item := GearDefs.make(slot, StageDefs.major_stage(stage), GachaDefs.rarity(rarity_key))
	if item.is_empty():
		return {}
	item["kind"] = "gear"
	item["copies"] = 1
	gear_seen[str(item["icon"])] = true      # 도감 — 손에 쥔 적이 있는가
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
# 유물 수령. 등급은 소환이 이미 굴렸고 **그 등급 안에서 하나를 고른다**
# (장비의 "형태만 랜덤"과 같은 규칙 — 여기서 등급을 다시 굴리면 표시 확률이
# 거짓말이 된다). 이미 있으면 조각이 쌓이고 5개마다 한 레벨 오른다.
func _receive_gacha_relic(rarity_key: String) -> Dictionary:
	# 유물이 없는 등급(커먼·언커먼·신화)이 나오면 한 칸씩 내려 준다 — 빈손으로
	# 돌려보내면 뽑기 한 번이 통째로 사라진다.
	# 유물은 레어~레전만 있다 — 굴린 등급을 그 범위로 접는다(커먼·언커먼은
	# 레어로 올리고 신화는 레전으로 내린다). 예전 대체 순서는 legend 부터라
	# 커먼(50%)·언커먼(30%)이 전부 전설이 됐다(사장님: 10뽑에 레전 9개).
	var idx := clampi(GachaDefs.rarity_index(rarity_key), 2, 4)
	var pool: Array = RelicDefs.of_rarity(str(GachaDefs.RARITIES[idx]["key"]))
	if pool.is_empty():
		return {}
	var r: Dictionary = pool[randi() % pool.size()]
	var id := str(r["id"])
	var key := "relic:" + id
	var lv := RelicDefs.level_of(id, relics)
	if lv <= 0:
		relics[id] = 1
	elif lv < RelicDefs.MAX_LV:
		var sh := int(gacha_shards.get(key, 0)) + 1
		if sh >= RelicDefs.SHARDS_PER_LV:
			relics[id] = lv + 1
			sh -= RelicDefs.SHARDS_PER_LV
		gacha_shards[key] = sh
	else:
		gacha_shards[key] = int(gacha_shards.get(key, 0)) + 1
	var out := r.duplicate(true)
	out["slot"] = "relic"
	out["icon"] = RelicDefs.icon_path(r)
	out["lv"] = RelicDefs.level_of(id, relics)
	return out


func _receive_gacha_skill(rarity_key: String) -> Dictionary:
	# **열린 형태 중에서 고른다**(2026-08-27, 해금 사슬). 예전에는 네 형태를
	# 균등하게 골랐다 — 초반에 스무 종으로 흩어져 아무것도 못 키웠다.
	#
	# **등급은 여기 오기 전에 이미 정해져 있다.** 천장은 "어느 형태로 나올지"만
	# 좁힌다 — 전설을 굴렸으면 전설이 나온다. 그 등급을 받는 형태가 하나도
	# 없을 때만 조각으로 돌린다(그마저도 커먼은 넷 다 열려 있어서, 커먼
	# 하나라도 가진 뒤에는 사실상 안 일어난다).
	var open_shapes := SkillDefs.shapes_for(rarity_key, skill_owned)
	if open_shapes.is_empty():
		return _skill_cap_shards(rarity_key)
	var shape: String = open_shapes[randi() % open_shapes.size()]
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


# 굴린 등급을 받을 형태가 하나도 없을 때. **뽑기를 무르지 않는다** — 등급은
# 이미 굴러갔고 천장은 형태만 좁히는 규칙이라, 등급값만큼 조각으로 돌려준다.
# 조각은 이미 가진 스킬 중 **제일 낮은 등급**에 얹는다(키울 데가 있는 쪽).
func _skill_cap_shards(rarity_key: String) -> Dictionary:
	var pick := ""
	var low := 99
	for k in skill_owned.keys():
		var ri := GachaDefs.rarity_index(str(SkillDefs.split(str(k))[1]))
		if ri < low:
			low = ri
			pick = str(k)
	if pick == "":
		# 가진 게 하나도 없다 — 커먼은 넷 다 열려 있으니 여기 오면 안 되지만,
		# 오면 커먼 하나를 준다. 빈손으로 돌려보내지 않는다.
		var shape: String = SkillDefs.SHAPE_ORDER[randi() % SkillDefs.SHAPE_ORDER.size()]
		pick = SkillDefs.key_of(shape, "common")
		skill_owned[pick] = 0
		gacha_owned["skill:" + pick] = true
		if skill_auto_equip:
			_auto_equip_skills()
		return {"kind": "skill", "key": pick, "name": SkillDefs.name_of(pick),
			"rarity": "common", "icon": SkillDefs.icon_path(pick)}
	var n := maxi(1, GachaDefs.rarity_index(rarity_key) + 1)
	gacha_shards["skill:" + pick] = int(gacha_shards.get("skill:" + pick, 0)) + n
	return {"kind": "skill", "key": pick, "name": SkillDefs.name_of(pick),
		"rarity": str(SkillDefs.split(pick)[1]), "icon": SkillDefs.icon_path(pick),
		"shards": n}


# ── 스킬 상세보기 ──────────────────────────────────────────────────────────
# 장비 상세창(_refresh_gear_detail)과 **같은 틀**이다. 왼쪽에 아이콘·등급,
# 오른쪽에 무엇을 하는지, 아래에 장착·레벨업·조합·닫기.
# 표기 함정: `Lv.` 는 이 블랙레터 폰트에서 `ℒ𝔇` 로 읽힌다 — 반드시 `N레벨` 로 쓴다.
func _open_skill_detail(key: String) -> void:
	if not skill_owned.has(key):
		return
	_skill_selected_key = key
	_refresh_skill_detail()


func _refresh_skill_detail() -> void:
	var key := _skill_selected_key
	if not skill_owned.has(key):
		_skill_detail.visible = false
		return
	for child in _skill_detail.get_children():
		child.queue_free()
	_skill_detail.visible = true
	var lv := int(skill_owned[key])
	var data := _skill_data(key)
	var rarity := SkillDefs.rarity_of(key)
	var col := Color(rarity["col"])
	# 창 뒤를 눌러도 밑의 카드가 안 눌리게 막는다.
	var shade := ColorRect.new()
	shade.color = Color.TRANSPARENT
	shade.size = Vector2(PANEL_W, PANEL_H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_detail.add_child(shade)
	_skill_detail.add_child(Ui.panel(Vector2.ZERO, Vector2(PANEL_W, PANEL_H)))
	_skill_detail.add_child(Ui.panel(Vector2(18.0, 18.0), Vector2(190.0, 210.0)))
	_skill_detail.add_child(Ui.panel(Vector2(216.0, 18.0), Vector2(342.0, 210.0)))
	var frame := Ui.image("res://assets/ui/slot_common.png",
		Vector2(49.0, 40.0), Vector2(128.0, 128.0))
	frame.modulate = col
	_skill_detail.add_child(frame)
	_skill_detail.add_child(Ui.icon(SkillDefs.icon_path(key), Vector2(75.0, 66.0), 76.0))
	var tier := _panel_label(_skill_detail, Vector2(30.0, 178.0), Type.SIZE_SMALL,
		col, 166.0, 24.0)
	tier.text = "%s · %d레벨" % [rarity["name"], lv]
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name := _panel_label(_skill_detail, Vector2(234.0, 28.0), Type.SIZE_MID,
		col, 306.0, 28.0)
	name.text = SkillDefs.name_of(key)
	var role := _panel_label(_skill_detail, Vector2(234.0, 58.0), Type.SIZE_SMALL,
		Color(0.82, 0.80, 0.86), 306.0, 20.0)
	# data["name"] 은 스킬 이름이라 바로 위 줄과 겹친다 — 여기는 **형태**를 적는다.
	# **패시브에 쿨타임을 적으면 거짓말이다** — 시전을 안 하므로 돌 쿨다운이 없다.
	# 그 자리에 "패시브"를 적어야 액티브와 한눈에 갈린다(2026-08-10 사장님).
	if bool(SkillDefs.rule_of(key).get("passive", false)):
		role.text = "%s · 패시브 · 장착하면 상시" % str(SkillDefs.shape_of(key)["name"])
	else:
		role.text = "%s · %s · 쿨타임 %.1f초" % [str(SkillDefs.shape_of(key)["name"]),
			SkillDefs.role_of(key), float(data["cooldown"])]
	# 무엇을 하는 스킬인지 한 줄. 가호만 피해가 0이라 다른 문장을 쓴다.
	var effect := _panel_label(_skill_detail, Vector2(234.0, 86.0), Type.SIZE_MID,
		Color(0.96, 0.82, 0.56), 306.0, 24.0)
	# **동작이 버프인가**를 본다 — 피의 제단은 진(field)인데 버프다.
	if str(data["act"]) == "ward":
		# 패시브는 지속시간을 쓰면 거짓말이 된다 — 상시이고, 표시값도 실제로 붙는
		# 값(가동률 환산분)이어야 화면과 전투가 안 갈린다.
		if bool(SkillDefs.rule_of(key).get("passive", false)):
			var cd := maxf(0.001, float(data["cooldown"]))
			var eff := float(data["bonus"]) * clampf(float(data["duration"]) / cd, 0.0, 1.0)
			effect.text = "전 피해 +%.1f%% · 상시" % (eff * 100.0)
		elif str(SkillDefs.rule_of(key).get("cleave", "")) != "":
			# 불멸의 심장 — 배수보다 **평타가 광역이 된다**가 이 스킬의 정체다.
			effect.text = "%.1f초 · 평타가 광역" % float(data["duration"])
		else:
			effect.text = "전 피해 +%d%% · %.1f초" % [int(float(data["bonus"]) * 100.0),
				float(data["duration"])]
	else:
		# **"x2.36" 은 무엇의 2.36배인지 안 적혀 있다.** 전투 식이 위력을 2.2 로
		# 나눠 쓰므로(SkillDefs.POWER_NORM) 실제로는 **평타의 몇 %** 다 —
		# 그 숫자여야 다른 스킬·평타와 견줄 수 있다(2026-08-11 사장님).
		# 여러 명을 때리는 스킬은 **한 명당**이라고 밝힌다.
		var per := float(data["power"]) / SkillDefs.POWER_NORM * 100.0
		var many := str(data["act"]) != "strike" \
			or int(SkillDefs.rule_of(key).get("max_targets", 0)) > 1
		effect.text = "%s 평타의 %d%%" % ["한 명당" if many else "", int(per)]
	var combo := _panel_label(_skill_detail, Vector2(234.0, 114.0), Type.SIZE_MID,
		Color(0.62, 0.88, 0.70), 306.0, 24.0)
	var bonus := _skill_combo_bonus(key)
	combo.text = "조합 +%d%%" % int(bonus * 100.0) if bonus > 0.0 else "조합 없음"
	var owned_key := "skill:" + key
	var shards := int(gacha_shards.get(owned_key, 0))
	var cost := SkillDefs.shard_cost(lv)
	var next := SkillDefs.promote_key(key)
	var rows := [
		[("만렙 %d" % SkillDefs.MAX_LV) if lv >= SkillDefs.MAX_LV
			else "조각 %d / %d" % [shards, cost], Color(0.82, 0.80, 0.86)],
		["장착 중" if skill_equipped.has(key) else "미장착", col],
		["조합 %d / %d" % [shards, GearDefs.FUSE_SHARDS], Color(0.72, 0.72, 0.78)],
		["최고 등급" if next.is_empty() else "→ " + SkillDefs.name_of(next), col],
	]
	for i in rows.size():
		var r := _panel_label(_skill_detail,
			Vector2(230.0 + float(i % 2) * 158.0, 146.0 + float(i / 2) * 26.0),
			Type.SIZE_SMALL, rows[i][1], 148.0, 22.0)
		r.text = rows[i][0]
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := _panel_label(_skill_detail, Vector2(22.0, 232.0), Type.SIZE_SMALL,
		Color(0.72, 0.72, 0.78), 532.0, 24.0)
	# **규칙을 여기 적는다**(2026-08-11 사장님: 몇 명을 때리는지·몇 초짜리 버프인지·
	# 몇 %로 때리는지가 보여야 한다). 문장은 `SkillDefs.rule_text` 하나가 만든다 —
	# 규칙을 넣고 설명을 안 적으면 화면에 안 보이는 규칙이 되고, 그건 없는 것과 같다.
	var rule_line := SkillDefs.rule_text(key)
	note.text = rule_line if rule_line != "" else "레벨은 위력을, 등급은 한 칸 위를 연다"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var equipped_now := skill_equipped.has(key)
	var equip := Ui.button("해제" if equipped_now else "장착", Vector2(22.0, 264.0),
		Vector2(128.0, 44.0), Type.SIZE_SMALL)
	equip.pressed.connect(func() -> void:
		_toggle_skill(key)
		_refresh_skill_detail())
	_skill_detail.add_child(equip)
	var level := Ui.button("레벨업", Vector2(158.0, 264.0),
		Vector2(128.0, 44.0), Type.SIZE_SMALL)
	level.disabled = shards < cost
	level.pressed.connect(func() -> void:
		if _level_up_skill(key):
			if skill_auto_equip:
				_auto_equip_skills()
			_refresh_skills()
			_refresh_skill_detail()
			_save_game())
	_skill_detail.add_child(level)
	# **비용은 GearDefs.FUSE_SHARDS 하나가 말한다.** 스킬 조합을 장비와 같은
	# 문법으로 합치면서(2026-08-25) _synthesize_skill 은 3 을 먹게 됐는데 화면만
	# 옛 상수(SkillDefs.SYNTH_SHARDS=5)를 들고 있었다 — 조각 3개면 조합이 되는데
	# 버튼이 잠겨서 못 눌렀고, 줄에는 "조합 3 / 5" 라고 적혀 있었다.
	var synth := Ui.button("최고" if next.is_empty() else "조합 %d" % GearDefs.FUSE_SHARDS,
		Vector2(294.0, 264.0), Vector2(128.0, 44.0), Type.SIZE_SMALL)
	synth.disabled = next.is_empty() or shards < GearDefs.FUSE_SHARDS
	synth.pressed.connect(func() -> void:
		var made := _synthesize_skill(key)
		if made.is_empty():
			return
		# 재료가 사라졌으므로 **결과 스킬로 창을 옮긴다.** 없는 걸 계속 띄우면
		# 버튼이 다 회색인 창을 보게 된다.
		_skill_selected_key = made
		if skill_auto_equip:
			_auto_equip_skills()
		_refresh_skills()
		_refresh_skill_detail()
		_save_game())
	_skill_detail.add_child(synth)
	var close := Ui.button("닫기", Vector2(430.0, 264.0),
		Vector2(124.0, 44.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _skill_detail.visible = false)
	_skill_detail.add_child(close)


# ── 방치 보상 상자 ─────────────────────────────────────────────────────────
# 예전엔 접속하자마자 피가 지갑에 들어가고 배너만 6초 떴다. 그러면 **받은 느낌이
# 없다** — 방치형에서 자리를 비운 보상은 눌러서 여는 게 보상이다(레퍼런스도 그렇다).
# 이제 계산은 접속할 때 하되 상자에 담아 두고, 누르면 그때 지갑에 들어간다.
# 80 = 원본 40px 의 정확히 2배. 틀을 벗겨 상자를 칸 전체로 키웠으니 배수가 정수여야
# 도트가 안 뭉갠다(72 였으면 1.8배).
const CHEST_BOX := 80.0


func _build_chest() -> void:
	_chest_btn = Button.new()
	_chest_btn.flat = true
	_chest_btn.focus_mode = Control.FOCUS_NONE
	# 레퍼런스대로 **화면 정가운데** 아래.
	_chest_btn.position = Vector2((float(Grid.BG.x) - CHEST_BOX) * 0.5,
		VIEW_BOTTOM - CHEST_BOX - 14.0)
	_chest_btn.size = Vector2(CHEST_BOX, CHEST_BOX)
	_chest_btn.visible = false
	_chest_btn.pressed.connect(_claim_chest)
	_hud_root.add_child(_chest_btn)
	# 뒤에 깔았던 원형 틀(round_btn)은 뺐다 — 흙바닥 위에 상자 하나만 놓인 쪽이
	# 레퍼런스에 맞고, 틀이 배경을 가려 지면과 따로 노는 원이 되어 있었다.
	_chest_btn.add_child(Ui.icon("res://assets/ui/chest.png", Vector2.ZERO, CHEST_BOX))
	# 상자는 받을 게 있을 때만 보이므로 점은 늘 붙어 있으면 된다.
	_chest_btn.add_child(Ui.icon("res://assets/ui/dot_alert.png",
		Vector2(CHEST_BOX - 22.0, 2.0), 18.0))


func _refresh_chest() -> void:
	if not _chest_btn:
		return
	# 상자 아래 글자는 뺐다 — 얼마인지는 눌러서 받을 때 알림으로 뜬다.
	# 전면 판 탭에서는 안 보인다 — 전투 화면 소품이라 판 위에 떠 버린다(실측).
	# 레이드 중에도 안 보인다 — 그 화면은 보스 정보만 남는다(레퍼런스).
	_chest_btn.visible = chest_gold > 0.0 and _tab not in FULL_TABS and not _in_raid()


# 방치 보상은 **팝업으로 편다** (사장님 + 레퍼런스 "방치 보상" 창): 한 줄
# 알림으로 흘리면 얼마를 받았는지 남지 않는다. 공용 보상창(_show_reward)을
# 그대로 쓴다 — 소환·가이드가 이미 쓰는 창이라 새로 그릴 이유가 없다.
#
# 담기는 재화는 **자리를 비운 동안 실제로 벌린 것만**이다: 혈액은 상자에,
# 경험치·혈정은 그 시간의 시세로 같이 친다. 없는 재화는 줄을 안 만든다 —
# 빈 칸이 늘어선 창은 "많이 받았다"가 아니라 "뭘 못 받았다"로 읽힌다.
func _claim_chest() -> void:
	if chest_gold <= 0.0:
		return
	_quest_bump("chest")
	var hours := chest_minutes / 60.0
	# 키는 **"label"** 이다(_show_reward). "text" 로 넣었더니 숫자가 통째로
	# 안 뜨고 아이콘만 셋 남았다(실측).
	var entries := [{"icon": "res://assets/ui/res_blood.png",
		"label": _n(chest_gold), "sub": "혈액"}]
	gold += chest_gold
	# 경험치 — 방치 동안 잡은 몫. 접속 중과 같은 시세(절반 효율은 이미 물렸다).
	var xp := _offline_exp(chest_minutes)
	if xp > 0.0:
		_gain_exp(xp)
		entries.append({"icon": "res://assets/items/gem.png",
			"label": _n(xp), "sub": "경험치"})
	# 혈정은 _grant_offline 이 이미 지갑에 넣었다 — 여기서는 **보여만 준다**.
	# 두 번 주면 소탕이 두 배가 된다.
	if dungeon_best > 0 and hours > 0.0:
		entries.append({"icon": "res://assets/ui/res_crystal.png",
			"label": _n(hours * _sweep_per_hour() * 0.5), "sub": "혈정"})
	_show_reward("방치 보상 — %d분" % int(chest_minutes), entries)
	# 상자가 열리는 순간을 눈으로 잡아 준다 — 사라지기만 하면 눌렀는지 모른다.
	_anim_fx("fx_hit", _chest_btn.position + Vector2(CHEST_BOX * 0.5, CHEST_BOX * 0.5),
		16.0, 2.0)
	chest_gold = 0.0
	chest_minutes = 0.0
	_refresh_chest()
	_save_game()


# 자리를 비운 동안의 경험치. 처치 수 x 마리당 경험치 — 혈액과 같은 모델이고
# 절반 효율은 상자에 담을 때 이미 물렸으므로 여기서 또 곱하지 않는다.
func _offline_exp(minutes: float) -> float:
	if minutes <= 0.0:
		return 0.0
	var profile := _offline_profile(stage)
	var kill_time := maxf(0.2, float(profile["hp"]) / maxf(0.001, dps()))
	return (minutes * 60.0 / kill_time) * Balance.exp_per_kill(stage) * 0.5


# 상시 가이드 카드.
#
#                  ┌── 가이드 41 ──┐   <- 헤더 탭: 카드 위로 돌출, 오른쪽
#   ┌──────┬───────┴───────────────┤
#   │ [💎] │ 처치 530마리           │  <- 미션 내용
#   │  1.7k│ [▬▬▬▬   289 / 530   ] │  <- 진행바
#   └──────┴───────────────────────┘
#     ↑ 보상: 두 줄을 통째로 쓴다
#
# **폭이 이 배치를 정했다.** 오른쪽 칸에 미션 내용이 들어가야 하는데, 원래 이름으로는
# 최장이 "누적 처치 999.9k마리" 168px 이라 어떤 칸에도 안 들어갔다(실제 폰트로 잰 값).
# 트랙 이름을 줄여(누적 처치 -> 처치) 132px 로 내리고 카드를 236 으로 넓혀 칸 134px 을
# 확보했다. 카드 왼쪽끝 332 로 보물상자(~328)와 안 겹친다.
#
# **글자를 틀에 붙이지 않는다.** Ui.CARD_PAD_* 는 틀 그림이 끝나는 자리라 거기에
# 그대로 놓으면 글자가 금테에 닿는다 — GOAL_INSET 만큼 한 번 더 띄운다.
#
# 보상 칸의 **틀은 뺐다**(사장님 지적). 카드 안에 또 틀을 두르면 테두리가 두 겹이라
# 60px 칸에서 실제로 쓰는 자리가 34px 밖에 안 남았다 — 보석과 숫자만 놓는다.
const GOAL_CARD := Vector2(236.0, 88.0)
const GOAL_TAB := Vector2(108.0, 26.0)
const GOAL_INSET := 4.0        # 틀 안쪽 면에서 한 번 더 띄우는 여백
const GOAL_QUEST_H := 20.0     # 미션 내용 줄
const GOAL_REWARD_W := 48.0    # 보상 칸 — "999t"(48px)가 최장이라 이보다 못 줄인다
const GOAL_GAP := 6.0
const GOAL_WIDGET_H := GOAL_CARD.y + GOAL_TAB.y - 8.0


func _build_goal_widget() -> void:
	_goal_widget = Button.new()
	_goal_widget.flat = true
	_goal_widget.focus_mode = Control.FOCUS_NONE
	_goal_widget.position = Vector2(float(Grid.BG.x) - GOAL_CARD.x - 8.0,
		VIEW_BOTTOM - GOAL_WIDGET_H - 6.0)
	_goal_widget.size = Vector2(GOAL_CARD.x, GOAL_WIDGET_H)
	_goal_widget.pressed.connect(_on_goal_card_pressed)
	_hud_root.add_child(_goal_widget)
	# 헤더 탭 — 카드 위, 오른쪽 정렬.
	var tab_at := Vector2(GOAL_CARD.x - GOAL_TAB.x, 0.0)
	_goal_widget.add_child(Ui.card_tab(tab_at, GOAL_TAB))
	_goal_widget_name = _panel_label(_goal_widget, tab_at, Type.SIZE_SMALL,
		Color(1.0, 0.88, 0.5), GOAL_TAB.x, GOAL_TAB.y)
	_goal_widget_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_widget_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 카드 몸통.
	var body := Vector2(0.0, GOAL_TAB.y - 8.0)
	# **공용 panel(돌 창)이 아니라 카드 전용 자산.** 돌 창 무늬는 테두리가 굵어서
	# 200px 카드에 쓰면 안쪽이 거의 안 남는다(사장님 지적 "있는 거 쓰지 말고 새로").
	_goal_widget.add_child(Ui.card(body, GOAL_CARD))
	var pad := Vector2(Ui.CARD_PAD_X + GOAL_INSET, Ui.CARD_PAD_Y + GOAL_INSET)
	var inner := body + pad
	var inner_w := GOAL_CARD.x - pad.x * 2.0
	var inner_h := GOAL_CARD.y - pad.y * 2.0
	# ── 왼쪽 보상: 두 줄을 통째로 쓴다. 틀 없이 보석 위 / 숫자 아래, 세로 가운데.
	var num_h := 16.0
	var reward_y := (inner_h - 32.0 - num_h) * 0.5
	_goal_widget_icon = Ui.icon("res://assets/ui/res_gem.png",
		inner + Vector2((GOAL_REWARD_W - 32.0) * 0.5, reward_y), 32.0)
	_goal_widget.add_child(_goal_widget_icon)
	_goal_widget_gem = _panel_label(_goal_widget,
		inner + Vector2(0.0, reward_y + 32.0), Type.SIZE_SMALL,
		Color(0.96, 0.92, 1.0), GOAL_REWARD_W, num_h)
	_goal_widget_gem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_widget_gem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_widget_gem.clip_text = true
	# ── 오른쪽: 위 미션 내용 / 아래 진행바(숫자는 바 안).
	var tx := GOAL_REWARD_W + GOAL_GAP
	var tw := inner_w - tx
	_goal_widget_cta = _panel_label(_goal_widget, inner + Vector2(tx, 0.0),
		Type.SIZE_SMALL, Color(0.94, 0.92, 0.98), tw, GOAL_QUEST_H)
	_goal_widget_cta.clip_text = true
	# 바 원본은 32px 인데 **눈에 보이는 부분은 y9~22** 뿐이다. 그림 기준으로 가운데를
	# 맞춰야 남은 칸 아래쪽에 치우쳐 보이지 않는다.
	var bar_at := inner + Vector2(tx,
		GOAL_QUEST_H + (inner_h - GOAL_QUEST_H) * 0.5 - 15.5)
	_goal_widget.add_child(Ui.bar_mini(bar_at, tw))
	# 채움은 **틀 위에** 그린다. bar_mini 는 홈통이 불투명이라(실측 alpha 255) 밑에
	# 깔면 통째로 가려져 진행도가 영영 안 보였다 — 실제로 그 상태였다(사장님 지적).
	# 대신 홈통 안(y13~18, 좌우 캡 8)만 덮어 테두리를 안 건드린다.
	_goal_widget_fill = ColorRect.new()
	_goal_widget_fill.color = Color(0.85, 0.63, 0.22)
	_goal_widget_fill.position = bar_at + Vector2(Ui.BAR_MINI_SIDE, Ui.BAR_MINI_INNER_Y)
	_goal_widget_fill.size = Vector2(0.0, Ui.BAR_MINI_INNER_H)
	_goal_widget_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_widget.add_child(_goal_widget_fill)
	_goal_widget_bar_label = _panel_label(_goal_widget, bar_at, Type.SIZE_SMALL,
		Color(0.98, 0.96, 0.98), tw, 32.0)
	_goal_widget_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_widget_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_bar_width = tw - Ui.BAR_MINI_SIDE * 2.0
	# 알림 점 — 받을 게 있을 때만. 방치형에서 보상이 쌓인 걸 모르고 지나가면
	# 그건 플레이어 잘못이 아니라 UI 잘못이다.
	_goal_dot = Ui.icon("res://assets/ui/dot_alert.png", tab_at + Vector2(-8.0, -4.0), 18.0)
	_goal_dot.visible = false
	_goal_widget.add_child(_goal_dot)


# 카드를 눌렀을 때. **깼을 때만 반응한다** — 받고, 보상 창을 띄우고, 다음 가이드가
# 그 자리에 올라온다. 아직이면 아무 일도 없다(예전엔 목록 창이 열렸는데 그 창이
# 지워 달라던 바로 그 창이다).
func _on_goal_card_pressed() -> void:
	if not _goal_ready():
		return
	var q := GoalDefs.quest(goal_index)
	var got := _claim_goal()
	if got > 0.0:
		_show_reward("보상 획득", [{"icon": "res://assets/ui/res_gem.png",
			"label": "보석 +%s" % _n(got),
			"sub": GoalDefs.label(str(q["kind"]), int(q["step"]))}])


func _refresh_goal_widget() -> void:
	if not _goal_widget:
		return
	var q := GoalDefs.quest(goal_index)
	var kind := str(q["kind"])
	var step := int(q["step"])
	var need := GoalDefs.need(kind, step)
	var now := _goal_value(kind)
	var done := now >= need
	_goal_widget_name.text = "가이드 %d" % (goal_index + 1)
	# 보상 칸(48px)에는 소수점이 안 들어간다 — "999.9t"는 72px 이다. 여기서는
	# 자릿수만 읽히면 되므로 정수로 줄인다("7.6m" -> "7m").
	_goal_widget_gem.text = _n_int(GoalDefs.gem_reward(kind, step))
	# 목표 줄은 **무엇을 얼마나**를 다 적는다("누적 처치 530마리"). 트랙 이름만
	# 있으면 다음에 뭘 해야 하는지가 안 보인다.
	# 최장 168px, 칸 176px (GearTest 가 실제 폰트로 지킨다).
	_goal_widget_cta.text = "눌러서 받기" if done else GoalDefs.label(kind, step)
	_goal_widget_cta.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if done else Color(0.94, 0.92, 0.98))
	# 바 안(122px)에는 "999.9k / 999.9k"(180px)가 안 들어간다. 소수점과 공백을 뺀다 —
	# 비율은 바 길이로 이미 보이고 여기 숫자는 자릿수만 읽히면 된다.
	# 단계는 "100-10/100-10"이 156px 이라 그마저도 넘는다. 목표는 바로 윗줄에
	# 이미 있으니 지금 자리만 적는다.
	_goal_widget_bar_label.text = StageDefs.label(now) if kind == "stage" \
		else "%s/%s" % [_n_int(float(now)), _n_int(float(need))]
	_goal_widget_fill.size.x = _goal_bar_width \
		* clampf(float(now) / maxf(1.0, float(need)), 0.0, 1.0)
	_goal_dot.visible = done


# ── 성장 가이드 ────────────────────────────────────────────────────────────
# 트랙마다 "지금 값"을 돌려준다. GoalDefs.TRACKS 에 새 kind 를 넣으면 여기도
# 한 줄이 필요하다 — GoalTest 가 빠진 걸 잡는다.
func _goal_value(kind: String) -> int:
	match kind:
		"stage": return best_stage
		"kills": return _total_kills()
		"hero_lv": return hero_lv
		"damage_lv": return stat_lv("damage")
		"pulls":
			var sum := 0
			for k in gacha_pulls:
				sum += int(gacha_pulls[k])
			return sum
		"knowledge": return codex_knowledge
		# 업적 전용(AchieveDefs). 가이드는 안 쓰지만 열쇠는 한 군데서 푼다.
		"dungeon": return dungeon_best
		"trial": return trial_stage
	return 0


func _total_kills() -> int:
	var sum := 0
	for k in codex:
		sum += int(codex[k])
	return sum


# 지금 가이드를 깼나. 버튼에 점을 찍는 데도 쓴다 — 방치형에서 보상이 쌓인 걸
# 모르고 지나가면 그건 플레이어 잘못이 아니라 UI 잘못이다.
func _goal_ready() -> bool:
	var q := GoalDefs.quest(goal_index)
	return _goal_value(str(q["kind"])) >= GoalDefs.need(str(q["kind"]), int(q["step"]))


# **한 번에 하나만** 올린다. 이미 다음 것까지 깨 있어도 누를 때마다 하나씩 준다 —
# 한꺼번에 주면 무엇을 몇 개 받았는지 화면에서 안 읽힌다. 다음 것이 이미 깨져
# 있으면 카드가 곧바로 "눌러서 받기"로 바뀌므로 또 누르면 된다.
# 받은 보석을 돌려준다(0 = 아직 못 받음).
func _claim_goal() -> float:
	if not _goal_ready():
		return 0.0
	var q := GoalDefs.quest(goal_index)
	var reward := GoalDefs.gem_reward(str(q["kind"]), int(q["step"]))
	gem += reward
	_currency_seen["gem"] = true
	goal_index += 1
	if _goal_widget == null:
		return reward   # 화면 없이 도는 계측기 — 지급은 끝났고 그릴 것만 없다
	_save_game()
	_refresh_goal_widget()   # _refresh_hud 는 매 프레임 도니까 여기서 부를 필요가 없다
	return reward


# 조각으로 스킬 레벨을 올린다. 장비 강화가 정수를 쓰듯 스킬은 조각을 쓴다 —
# 재화를 새로 만들지 않는다.
func _level_up_skill(key: String) -> bool:
	if not skill_owned.has(key):
		return false
	var owned_key := "skill:" + key
	var lv := int(skill_owned[key])
	if lv >= SkillDefs.MAX_LV:
		return false
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
# 장비 조합과 **같은 규칙**이다(사장님 2026-08-25): 조각 FUSE_SHARDS 개로
# 1회 시도, 등급별 확률·천장, 실패해도 같은 등급 하나를 준다.
func _synthesize_skill(key: String) -> String:
	_fuse_failed = false
	_fuse_gain = {}
	var next := SkillDefs.promote_key(key)
	var owned_key := "skill:" + key
	if next.is_empty() or not skill_owned.has(key):
		return ""
	if int(gacha_shards.get(owned_key, 0)) < GearDefs.FUSE_SHARDS:
		return ""
	var probe := {"rarity": str(SkillDefs.split(key)[1])}
	var rar_pity := str(probe["rarity"])
	var tries := int(fuse_pity.get(rar_pity, 0)) + 1
	if tries < GearDefs.fuse_pity(probe) and randf() >= GearDefs.fuse_rate(probe):
		gacha_shards[owned_key] = int(gacha_shards[owned_key]) - GearDefs.FUSE_SHARDS
		fuse_pity[rar_pity] = tries
		_fuse_failed = true
		# 빈손으로 안 보낸다 — 같은 등급 스킬 하나(장비와 같은 규칙).
		var got_row := _receive_gacha_skill(str(probe["rarity"]))
		if not got_row.is_empty():
			var rr := SkillDefs.rarity_of(str(got_row["key"]))
			_fuse_gain = {"icon": str(got_row["icon"]),
				"label": str(got_row["name"]),
				"sub": str(rr["name"]), "col": rr["col"]}
		return ""
	fuse_pity.erase(rar_pity)
	gacha_shards[owned_key] = int(gacha_shards[owned_key]) - GearDefs.FUSE_SHARDS
	# 원본은 남는다(사장님: 보유 보상이 있으니 한 벌은 무조건) — 장착도 그대로.
	if skill_owned.has(next):
		# 이미 있으면 조각으로 들어간다(장비 합성과 같은 규칙).
		gacha_shards["skill:" + next] = int(gacha_shards.get("skill:" + next, 0)) + 1
	else:
		skill_owned[next] = 0
		gacha_owned["skill:" + next] = true
	return next


func _gacha_kind_name() -> String:
	if _gacha_kind in GearDefs.SLOTS:
		return str(GearDefs.SLOT_NAME[_gacha_kind])
	return "유물" if _gacha_kind == "relic" else "스킬"


# 값 표기 조각 — 아이콘(16px) + 숫자. "권/보석" 글자 대신 아이콘으로 적는다
# (사장님 2026-08-25: "이것도 권이라 나옴").
func _price_bit(row: Control, icon_path: String, txt: String) -> void:
	if icon_path != "":
		var ic := TextureRect.new()
		ic.texture = Assets.tex(icon_path)
		ic.custom_minimum_size = Vector2(16.0, 16.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	if txt != "":
		var lb := _panel_label(row, Vector2.ZERO, Type.SIZE_SMALL,
			Color(0.98, 0.88, 0.62), 60.0, 18.0)
		lb.text = txt


func _show_gacha_results(items: Array[Dictionary]) -> void:
	if not _gacha_reveal:
		return
	for child in _gacha_reveal.get_children():
		child.queue_free()
	_gacha_reveal.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.025, 0.94)
	# **전면 판 전체를 덮는다** (사장님) — 반판 크기로 두면 아래 반이 비쳐서
	# 결과 창 밑으로 확률표·버튼이 그대로 보였다.
	shade.size = Vector2(PANEL_W, PANEL_FULL_H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_gacha_reveal.add_child(shade)
	_gacha_reveal.add_child(Ui.panel(Vector2.ZERO, Vector2(PANEL_W, PANEL_FULL_H)))
	var title := _panel_label(_gacha_reveal, Vector2(PAD, 16.0), Type.SIZE_MID,
		Color(0.96, 0.84, 0.58), CONTENT_W, 28.0)
	title.text = "%s 소환 결과" % _gacha_kind_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 30·50연은 카드가 판을 넘는다 — 여럿이면 스크롤 통에 담는다(사장님 2026-08-25).
	var grid2: Control = null
	if items.size() > 1:
		var scroll2 := ScrollContainer.new()
		scroll2.position = Vector2(0.0, 48.0)
		scroll2.size = Vector2(PANEL_W, 560.0)
		scroll2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_gacha_reveal.add_child(scroll2)
		grid2 = Control.new()
		grid2.custom_minimum_size = Vector2(PANEL_W - 16.0,
			float((items.size() + 4) / 5) * 100.0 + 8.0)
		scroll2.add_child(grid2)
	var cards: Array[Control] = []
	for i in items.size():
		var item: Dictionary = items[i]
		if item.is_empty():
			continue
		var one := items.size() == 1
		var card := Control.new()
		card.position = Vector2(232.0, 56.0) if one else \
			Vector2(48.0 + float(i % 5) * 100.0, 6.0 + float(i / 5) * 100.0)
		card.size = Vector2(112.0, 160.0) if one else Vector2(80.0, 96.0)
		if one:
			_gacha_reveal.add_child(card)
		else:
			grid2.add_child(card)
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
	# **버튼 둘이다** (사장님 2026-08-13): 예전엔 장비 소환에 "보관함 확인" 하나뿐이라
	# 연달아 뽑으려면 보관함에 들렀다가 되돌아와야 했다. 창을 닫기만 하는 "확인"과
	# 그 자리로 데려가는 "보러 가기"를 나눈다 — 뽑은 것마다 갈 곳이 다르다.
	# 결과 창에서 바로 이어 뽑기 (사장님 2026-08-25) — 1·10·30·50연.
	# 30·50연은 여기서만 판다. 보유 재화 한 줄 + 버튼마다 값을 같이 적는다
	# (같은 날 캡처 피드백: "보유 재화랑 필요한 재화량도 보여주면 좋겠고").
	var have2 := int(tickets.get(_gacha_kind, 0))
	# 보유 줄 — 메인 판과 같은 문법(알약 + 아이콘 + 숫자, 사장님 캡처).
	# 소환권 4종 전부 + 보석. 세트 결도 종류를 따른다(대장간/점성소).
	var setn2 := "forge" if _gacha_kind in GearDefs.SLOTS else "astro"
	# **지금 소환의 권 + 보석만** (사장님: "다 나와있네") — 다른 권은 여기서
	# 못 쓰는 재화라 소음이다.
	var px2 := (PANEL_W - 320.0) * 0.5
	_gacha_reveal.add_child(Ui.image(
		"res://assets/ui/sets/%s_pill.png" % setn2,
		Vector2(px2, 612.0), Vector2(150.0, 30.0)))
	_gacha_reveal.add_child(Ui.icon(TicketDefs.icon_of(_gacha_kind),
		Vector2(px2 + 14.0, 617.0), 20.0))
	var tl2 := _panel_label(_gacha_reveal, Vector2(px2 + 40.0, 613.0),
		Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), 100.0, 28.0)
	tl2.text = str(have2)
	_gacha_reveal.add_child(Ui.image(
		"res://assets/ui/sets/%s_pill.png" % setn2,
		Vector2(px2 + 158.0, 612.0), Vector2(162.0, 30.0)))
	_gacha_reveal.add_child(Ui.icon("res://assets/ui/res_gem.png",
		Vector2(px2 + 172.0, 617.0), 20.0))
	var gl2 := _panel_label(_gacha_reveal, Vector2(px2 + 198.0, 613.0),
		Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), 112.0, 28.0)
	gl2.text = _n(gem)
	var free2 := free_pull_date != Time.get_date_string_from_system()
	# 30·50연은 **낼 수 있을 때만 버튼이 보인다** — 잠긴 큰 버튼은 자리만
	# 차지한다(사장님). 권이 2~9장 애매하게 남으면 "권 N장" 털기도 여기 낀다.
	var opts: Array = []
	for cnt4 in [1, 10, 30, 50]:
		var tk4: int = mini(have2, cnt4)
		var gm4 := GachaDefs.COST * float(cnt4 - tk4)
		var fr4: bool = cnt4 == 1 and free2
		if fr4:
			gm4 = 0.0
		if cnt4 >= 30 and gem < gm4:
			continue
		opts.append({"label": ("%d연" % cnt4) if cnt4 > 1 else "1회",
			"count": cnt4, "tk": (0 if fr4 else tk4), "gm": int(gm4),
			"free": fr4, "off": gem < gm4})
		if cnt4 == 10 and have2 >= 2 and have2 <= 9:
			opts.append({"label": "권 %d장" % have2, "count": have2,
				"tk": have2, "gm": 0, "free": false, "off": false})
	var bw := minf(126.0, (516.0 - float(opts.size() - 1) * 9.0) / float(opts.size()))
	var bx0 := (PANEL_W - (bw * float(opts.size())
		+ 9.0 * float(opts.size() - 1))) * 0.5
	for i3 in opts.size():
		var o2: Dictionary = opts[i3]
		var bx := bx0 + float(i3) * (bw + 9.0)
		# 값은 **버튼 안** 아랫줄에 (사장님: "아이콘이 버튼 안으로").
		var pb := Ui.button("", Vector2(bx, 646.0),
			Vector2(bw, 54.0), Type.SIZE_SMALL)
		pb.disabled = bool(o2["off"])
		pb.pressed.connect(_pull_gacha.bind(int(o2["count"])))
		_gacha_reveal.add_child(pb)
		var nm2 := _panel_label(_gacha_reveal, Vector2(bx, 652.0),
			Type.SIZE_SMALL, Color(1.0, 0.96, 0.90), bw, 18.0)
		nm2.text = str(o2["label"])
		nm2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(bx + bw * 0.5 - 67.0, 674.0)
		row.size = Vector2(134.0, 20.0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		_gacha_reveal.add_child(row)
		if bool(o2["free"]):
			_price_bit(row, "", "무료")
		else:
			if int(o2["tk"]) > 0:
				_price_bit(row, TicketDefs.icon_of(_gacha_kind), str(o2["tk"]))
			if int(o2["gm"]) > 0:
				if int(o2["tk"]) > 0:
					_price_bit(row, "", "+")
				_price_bit(row, "res://assets/ui/res_gem.png", str(o2["gm"]))
	var kind_now := _gacha_kind
	var ok := Ui.button("확인", Vector2(30.0, FULL_BOTTOM - 60.0),
		Vector2(250.0, 50.0), Type.SIZE_SMALL)
	ok.pressed.connect(func() -> void:
		_gacha_reveal.visible = false
		_mile_pop())
	_gacha_reveal.add_child(ok)
	var go := Ui.button("보관함" if kind_now in GearDefs.SLOTS else "보러 가기",
		Vector2(296.0, FULL_BOTTOM - 60.0),
		Vector2(250.0, 50.0), Type.SIZE_SMALL)
	go.pressed.connect(func() -> void:
		_gacha_reveal.visible = false
		_mile_pop()
		if kind_now in GearDefs.SLOTS:
			_select_tab("gear")
			_set_gear_mode("inventory")
		else:
			# 스킬·유물은 성장 탭의 제 소탭으로 — 뽑은 것이 어디 쌓였는지 보여 준다.
			_select_tab("growth")
			_set_growth_mode("relic" if kind_now == "relic" else "skill"))
	_gacha_reveal.add_child(go)
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
	# 종류마다 전용 그림 — 세트 결(대장간=모루, 점성소=별빛)로 새로 뽑았다.
	_gacha_icon.texture = Assets.tex(
		"res://assets/ui/sets/altar_%s.png" % _gacha_kind)
	# 유물이 "스킬 소환"으로 적히던 버그 — 장비가 아니면 다 스킬로 뭉뚱그렸다.
	var kind_name: String = GearDefs.SLOT_NAME[_gacha_kind] \
		if _gacha_kind in GearDefs.SLOTS \
		else ("유물" if _gacha_kind == "relic" else "스킬")
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
	# 장소가 종류를 따라간다 — 장비는 대장간, 스킬·유물은 점성소(레퍼런스 문법).
	# 헤더뿐 아니라 **판 재질까지** 갈아 끼운다(사장님: 탭마다 전용 세트).
	var forge := _gacha_kind in GearDefs.SLOTS
	var set_name := "forge" if forge else "astro"
	_gacha_head_tex.texture = Assets.tex("res://assets/ui/head_forge.png" \
		if forge else "res://assets/ui/head_astro.png")
	_gacha_card_tex.texture = Assets.tex(
		"res://assets/ui/sets/%s_body.png" % set_name)
	_gacha_bubble.texture = Assets.tex(
		"res://assets/ui/sets/%s_tab_off.png" % set_name)
	# 액자가 세트마다 다른 자리다 — 그림도 따라 옮긴다.
	_gacha_icon.position = Vector2(GACHA_ART_X, GACHA_ART_Y) if forge \
		else Vector2(88.0, 369.0)
	_gacha_place.text = "핏빛 대장간" if forge else "달의 제단"
	_gacha_line.text = "좋은 재료가 들어왔다. 골라 봐라." if forge \
		else "운명의 조각이 떨리고 있어요…"
	for kind in ["weapon", "armor", "trinket", "skill", "relic"]:
		_gacha_buttons[kind].set_pressed_no_signal(_gacha_kind == kind)
		var lbl: Label = _gacha_kind_labels[kind]
		if kind in GearDefs.SLOTS:
			var reason := GearDefs.lock_reason(kind, StageDefs.major_stage(stage))
			_gacha_buttons[kind].disabled = not reason.is_empty()
			lbl.text = reason if not reason.is_empty() \
				else str(GearDefs.SLOT_NAME[kind])
		elif kind == "relic":
			# 유물은 **후반 축**이라 중반에 열린다(RelicDefs.OPEN_STAGE).
			var locked := best_stage < RelicDefs.OPEN_STAGE
			_gacha_buttons[kind].disabled = locked
			lbl.text = "%d구간" % RelicDefs.OPEN_STAGE if locked else "유물"
		else:
			lbl.text = "스킬"
		lbl.modulate = Color(1, 1, 1) \
			if not _gacha_buttons[kind].disabled else Color(0.55, 0.52, 0.58)
	# 값이 세 갈래다: 무료 · 소환권 · 보석. **무엇으로 내는지 버튼에 적는다** —
	# 아이콘까지 바꿔야 곁눈질로 갈린다(보석 알약 vs 소환권).
	var free := free_pull_date != Time.get_date_string_from_system()
	# 값은 **지금 고른 종류의 권**을 먼저 본다 — 무기 탭에서 스킬권이 나가면 안 된다.
	var have := int(tickets.get(_gacha_kind, 0))
	var one_ticket := not free and have >= 1
	_gacha_btn_lbl["one"].text = "오늘 무료 1회" if free \
		else ("1회  1" if one_ticket else "1회  30")
	_gacha_btn_icon["one"].visible = not free
	if not free:
		_gacha_btn_icon["one"].texture = Assets.tex(
			TicketDefs.icon_of(_gacha_kind) if one_ticket \
			else "res://assets/ui/res_gem.png")
	# 10연은 값이 **섞일 수 있다**: 권 9장이면 권 9 + 보석 30 이다. 아이콘은
	# 하나뿐이라 섞였을 때는 글자로 갈라 적는다 — 얼마가 나가는지 누르기 전에
	# 보여야 한다(사장님).
	var ten_tk := mini(have, 10)
	var ten_gem := GachaDefs.COST * float(10 - ten_tk)
	var ten_mid := true
	if ten_tk >= 10:
		_gacha_btn_lbl["ten"].text = "10연  10"
	elif ten_tk > 0:
		# 섞인 값만 글자가 길다(16자). SIZE_MID 로는 버튼 폭 258 을 넘어
		# 왼쪽으로 삐져나갔다(사장님 캡처) — 이 줄에서만 한 치수 내린다.
		_gacha_btn_lbl["ten"].text = "10연  권%d+보석%d" % [ten_tk, int(ten_gem)]
		ten_mid = false
	else:
		_gacha_btn_lbl["ten"].text = "10연  300"
	_gacha_btn_lbl["ten"].add_theme_font_size_override("font_size",
		Type.SIZE_MID if ten_mid else Type.SIZE_SMALL)
	_gacha_btn_icon["ten"].texture = Assets.tex(
		TicketDefs.icon_of(_gacha_kind) if ten_tk > 0 \
		else "res://assets/ui/res_gem.png")
	_gacha_buttons["one"].disabled = not free and not one_ticket and gem < GachaDefs.COST
	_gacha_buttons["ten"].disabled = gem < ten_gem
	var odd := have >= 2 and have <= 9
	_gacha_btn_tex["left"].visible = odd
	_gacha_btn_lbl["left"].visible = odd
	_gacha_buttons["left"].visible = odd
	_gacha_btn_icon["left"].visible = odd
	if odd:
		_gacha_btn_lbl["left"].text = "권 %d장 뽑기" % have
		_gacha_btn_icon["left"].texture = Assets.tex(TicketDefs.icon_of(_gacha_kind))
		_gacha_buttons["left"].disabled = false
	# 아이콘을 글자 바로 왼쪽에 붙인다 — 고정 x 는 글자 길이에 따라 간격이
	# 들쭉였다(사장님: "배치가 일그러진 부분"). 라벨이 가운데 정렬이라 폭을 재서 옮긴다.
	for key in ["one", "ten", "left"]:
		var lbl2: Label = _gacha_btn_lbl[key]
		var fs := lbl2.get_theme_font_size("font_size")
		var fw := lbl2.get_theme_font("font").get_string_size(lbl2.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_gacha_btn_icon[key].position.x = lbl2.position.x \
			+ (258.0 - fw) * 0.5 - 34.0
	# 그림 버튼·알약의 세트 전환 + 잠김 표시(어두워진다).
	for key in ["one", "ten", "left"]:
		_gacha_btn_tex[key].texture = Assets.tex(
			"res://assets/ui/sets/%s_button.png" % set_name)
		var dim: bool = _gacha_buttons[key].disabled
		_gacha_btn_tex[key].modulate = Color(0.5, 0.47, 0.5) if dim else Color(1, 1, 1)
		_gacha_btn_lbl[key].modulate = Color(0.6, 0.58, 0.6) if dim else Color(1, 1, 1)
		if key in _gacha_btn_icon:
			_gacha_btn_icon[key].modulate = Color(0.6, 0.58, 0.6) if dim else Color(1, 1, 1)
	_gacha_table_tex.texture = Assets.tex(
		"res://assets/ui/sets/%s_pill.png" % set_name)
	var ty: float = TABLE_Y[set_name]
	_gacha_table_tex.position.y = ty
	_gacha_table_lbl.position.y = ty + 9.0
	_gacha_table_btn.position.y = ty
	for t in _gacha_tk_texs:
		t.texture = Assets.tex("res://assets/ui/sets/%s_pill.png" % set_name)
	# 잔량은 **네 종류를 다** 적는다 — 어느 탭에서 무엇을 쓸 수 있는지 한눈에.
	for i in TicketDefs.KINDS.size():
		var k: String = TicketDefs.KINDS[i]
		_gacha_ticket_labels[i].text = "%d" % int(tickets.get(k, 0))
		# 가진 종류는 밝게 — 곁눈질로 "지금 쓸 수 있는 게 있나"가 읽힌다.
		_gacha_ticket_labels[i].add_theme_color_override("font_color",
			Color(0.92, 0.86, 0.86) if int(tickets.get(k, 0)) > 0
			else Color(0.5, 0.48, 0.55))


const CODEX_COLS := 6   # 5칸이면 5줄이 되어 세로가 창을 넘는다
const CODEX_ROWS := 4
const CODEX_ICON := 44.0
# 목록 + 상세 2단. 6x4 격자는 22종을 한눈에 보여 줬지만 몹마다 붙은 지식 레벨·효과·
# 다음 단계를 넣을 자리가 없다. 목록은 "뭐가 남았나", 상세는 "이걸 더 잡으면 뭐가 되나".
const CODEX_HEAD_H := 24.0        # 맨 위 종수 보상 한 줄
const CODEX_LIST_W := 156.0       # 칸 글자폭 74px — "999.9t"(72) 가 들어가는 최소값
const CODEX_ROW_H := 62.0
const CODEX_BIG := 72.0           # 상세의 큰 그림
const CODEX_TAB_Y := 58.0         # 머리 두 줄 아래 소탭 줄
# 격자 열 수. **8 로 두면 pane(454)을 66px 넘겨** 중앙 정렬이 음수가 되고
# 격자가 왼쪽으로 밀린다(실측 캡처). 스크롤바가 24px 라 생각보다 좁다.
const LORE_COLS := 6
const LORE_CELL := 60.0
const LORE_GAP := 6.0


# 도감. 방치형에서 "언젠가 다 채운다"는 장기 목표는 공짜다 — 처치 수는 이미 세고 있다.
# 도감은 **팝업**이다 (사장님 2026-08-18). 하단 탭 자리는 펫이 가져간다.
#
# 안쪽 코드는 그대로 두고 **담는 그릇만** 바꾼다: 내용이 PAD~CODEX_BOTTOM
# 좌표를 쓰므로, 그 좌표계를 통째로 판 안쪽으로 옮기는 Control 을 하나 끼운다
# (미궁 스크롤이 쓰는 것과 같은 수법). 팝업은 세로 560 이라 반판(358)보다
# 넓어서 격자가 더 보인다.
const CODEX_BOTTOM := 526.0     # 팝업 안에서 쓸 수 있는 아래 끝(테두리 앞)
# 팝업 안쪽 폭. **CONTENT_W(528, 탭 폭)를 쓰면 오른쪽이 판을 넘는다** —
# 좌우 22 여백을 뺀 값이다(실측 캡처: 소탭 "연대기"가 테두리에 걸쳤다).
const CODEX_W := QUEST_PANEL.size.x - 44.0
# 내용 좌표(PAD 기준)를 판 안쪽으로 미는 값. 판 x+22 가 글이 시작하는 자리다.
const CODEX_SHIFT := Vector2(QUEST_PANEL.position.x + 22.0 - PAD,
	QUEST_PANEL.position.y + 8.0)


func _build_codex_view() -> void:
	_codex_view = Control.new()
	_codex_view.size = Vector2(Grid.BG)
	_codex_view.visible = false
	_codex_view.z_index = 55       # 임무판과 같은 층
	_hud_root.add_child(_codex_view)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.size = Vector2(Grid.BG)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex_view.add_child(dim)
	# 가죽책 세트 — 임무판(양피지)과 한 벌이고 결은 다르다.
	_codex_view.add_child(Ui.set_body(TOME, QUEST_PANEL.position,
		QUEST_PANEL.size))
	var cbx := Vector2(QUEST_PANEL.position.x + QUEST_PANEL.size.x - 110.0,
		QUEST_PANEL.position.y + 12.0)
	var cclose_art := Ui.set_row(TOME, cbx, Vector2(88.0, 34.0))
	_codex_view.add_child(cclose_art)
	var clb := _panel_label(_codex_view, Vector2(cbx.x, cbx.y + 9.0),
		Type.SIZE_SMALL, Color(0.96, 0.92, 0.88), 88.0, 20.0)
	clb.text = "닫기"
	clb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cclose := Ui.button("", cbx, Vector2(88.0, 34.0), Type.SIZE_SMALL)
	cclose.modulate = Color(1, 1, 1, 0)
	cclose.pressed.connect(func() -> void: _codex_view.visible = false)
	_codex_view.add_child(cclose)
	_pet_hover(cclose, cclose_art)
	var body := Control.new()
	body.position = CODEX_SHIFT
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_codex_view.add_child(body)
	_build_codex(body)


func _build_codex(root: Control) -> void:
	var keys := FoeTiers.all_keys()
	# 지식 합계는 몹 하나가 아니라 도감 전체에 걸린 값이라 맨 위 한 줄에 둔다.
	# 오른쪽 버튼은 그 합계가 실제로 무슨 능력치가 됐는지 펼쳐 본다.
	# 칭호가 빠져 버튼이 하나(능력치)다 — 머리글이 그만큼 넓어졌다.
	# ── 머리 두 줄 ── 위: 얼마나 모았나. 아래: **그래서 지금 뭘 받고 있나**.
	# 소탭마다 같은 자리에 같은 형식으로 적는다(사장님 2026-08-18) — 예전에는
	# 몬스터 전용 "능력치" 버튼 하나가 오른쪽에 떠 있어서, 다른 소탭에서는
	# 자리도 안 맞고 그 소탭이 주는 것도 알 수 없었다.
	_codex_summary = _panel_label(root, Vector2(PAD, 12.0), Type.SIZE_SMALL,
		Color(0.90, 0.86, 0.84), CODEX_W - 120.0, 18.0)
	_codex_gain = _panel_label(root, Vector2(PAD, 32.0), Type.SIZE_SMALL,
		Color(0.98, 0.82, 0.46), CODEX_W - 120.0, 18.0)
	# 몬스터 소탭만 상세 창이 따로 있다(지식이 무슨 능력치가 됐는지 7줄).
	# 머리줄을 누르면 열린다 — 버튼 하나를 덜 세운다.
	var head_btn := Ui.button("", Vector2(PAD, 10.0),
		Vector2(CODEX_W - 120.0, 42.0), Type.SIZE_SMALL)
	head_btn.modulate = Color(1, 1, 1, 0)
	head_btn.pressed.connect(func() -> void:
		if _codex_mode != "foe":
			return
		_status_view.visible = not _status_view.visible
		if _status_view.visible:
			_refresh_status())
	root.add_child(head_btn)
	# **칭호는 여기서 뺐다** (사장님 2026-08-12): 능력치는 도감의 결산이지만
	# 칭호는 완전히 다른 계열(본편 돌파·미궁 층·스킬 종수)이라 같은 줄에 두면
	# 도감 첫 화면이 세 갈래로 갈린다. 임무판처럼 **전투 화면 오른쪽 버튼**으로
	# 옮겼다(_build_quests 옆) — 도감 탭은 몬스터 도감 하나만 본다.

	# ── 소탭 넷 ── (사장님 2026-08-18: 도감에 장비·스킬·연대기를 더한다)
	# 몬스터만 있던 판이라 오른쪽 상세가 늘 비어 보였다. 소탭은 임무판과
	# 같은 문법이고, 세트만 가죽책(tome)으로 다르다.
	var ctabs := [["foe", "몬스터"], ["gear", "장비"], ["skill", "스킬"],
		["title", "칭호"], ["oath", "계약"], ["act", "연대기"]]
	var ctw := (CODEX_W - 30.0) / 6.0
	for i in ctabs.size():
		var cm := str(ctabs[i][0])
		var cp := Vector2(PAD + float(i) * (ctw + 6.0), CODEX_TAB_Y)
		var con := Ui.set_tab(TOME, true, cp, Vector2(ctw, 32.0))
		var coff := Ui.set_tab(TOME, false, cp, Vector2(ctw, 32.0))
		root.add_child(coff)
		root.add_child(con)
		var cl := _panel_label(root, Vector2(cp.x, cp.y + 8.0),
			Type.SIZE_SMALL, Color(0.92, 0.88, 0.84), ctw, 18.0)
		cl.text = str(ctabs[i][1])
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cb := Ui.button("", cp, Vector2(ctw, 32.0), Type.SIZE_SMALL)
		cb.modulate = Color(1, 1, 1, 0)
		cb.pressed.connect(func() -> void: _codex_set_mode(cm))
		root.add_child(cb)
		_pet_hover(cb, coff)
		_codex_tab_art[cm] = {"on": con, "lbl": cl}
	for key in ["foe", "gear", "skill", "title", "oath", "act"]:
		var r := Control.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(r)
		_codex_roots[key] = r
	_codex_build_foe(_codex_roots["foe"])
	_lore_build(_codex_roots["gear"], "gear")
	_lore_build(_codex_roots["skill"], "skill")
	_title_build(_codex_roots["title"])
	_oath_codex_build(_codex_roots["oath"])
	_act_build(_codex_roots["act"])
	_codex_set_mode("foe")
	_build_status(root)


# 몬스터 도감 본문 — 왼쪽 목록과 오른쪽 상세. 소탭이 생기면서 통째로
# 떼어냈다(내용은 그대로다).

# 도감 안의 스크롤바를 얇게. 공용 폭(24)은 이 판에서 굵어 붉은 막대가 벽처럼
# 선다(사장님 지적) — 판마다 목록 폭이 달라 전역 값을 바꿀 수는 없다.
const CODEX_BAR_W := 10.0


func _codex_thin_bar(sc: ScrollContainer) -> ScrollContainer:
	sc.get_v_scroll_bar().custom_minimum_size.x = CODEX_BAR_W
	return sc

func _codex_build_foe(root: Control) -> void:
	var keys := FoeTiers.all_keys()
	# 소탭 줄(CODEX_TAB_Y ~ +32) 아래에서 시작한다 — 예전 자리(58)에 그대로
	# 두었더니 목록 첫 칸과 상세가 소탭에 깔렸다(실측 캡처).
	var body_y := CODEX_TAB_Y + 40.0
	var body_h := CODEX_BOTTOM - body_y
	var sc := _codex_thin_bar(
		Ui.scroll(Vector2(PAD, body_y), Vector2(CODEX_LIST_W, body_h)))
	root.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = CODEX_LIST_W - Ui.SCROLL_W
	sc.add_child(col)
	for key in keys:
		col.add_child(_codex_row(str(key)))

	# ── 상세 ──
	var dx := PAD + CODEX_LIST_W + 16.0
	var dw := CODEX_W + PAD - dx
	_codex_detail = {}
	# 세로 배치는 아래에서부터 잡는다. 진행바(52px)가 제일 크고 자리가 고정이라
	# 위에서부터 쌓으면 마지막에 바가 글자를 덮는다 — 실제로 한 번 덮었다.
	var bar_y := CODEX_BOTTOM - Ui.BAR_H - 12.0
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
	# 채움은 **피 계열**로. 보라(0.62,0.32,0.72)는 이 게임 어디에도 없는 색이라
	# 도감만 다른 게임처럼 보였다(사장님 지적).
	var bar := Ui.bar(Vector2(dx, bar_y), dw, Color(0.72, 0.16, 0.20))
	root.add_child(bar)
	_codex_detail["bar"] = bar
	_codex_selected = str(keys[0])


# 지식 합계가 실제로 무슨 능력치가 됐는지 한 장에 편다.
# 도감 목록은 "몹 하나를 얼마나 잡았나"만 보여 줘서, 그게 합쳐져 뭐가 됐는지가 안 보였다.
# 7줄 x 28 = 196px. 머리글(30) + 현재값(22) + 여백까지 296 안에 들어간다 —
# 닫기 버튼을 목록 아래에 두면 마지막 줄을 덮는다(실제로 덮었다). 그래서 오른쪽 위,
# "능력치" 버튼이 있던 바로 그 자리에 둔다.
const STATUS_ROW_H := 28.0


# ── 분당 수입 (참고작 Pt/m) ─────────────────────────────────────────────────
# 1초마다 그 초의 처치 수입을 60칸 고리에 밀어 넣는다 — 합이 곧 분당 수입이다.
var _income_ring := PackedFloat64Array()
var _income_acc := 0.0
var _income_idx := 0
var _lbl_income: Label


# 초당 혈액 배급 — 처치 보상을 대신한다. 방치와 접속이 **같은 요율**이라
# "켜 두면 이득"이 아니라 "켜 두든 아니든 같다"가 된다(방치형의 약속).
#
# 5/9 인 이유: 옛 하루 = 방치 8h x 0.5 + 접속 1h x 1.0 = 5.0h 등가.
# 새 모델은 9h x (5/9) = 5.0h — 무과금 하루 총량이 소수점까지 같다.
const IDLE_EFF := 5.0 / 9.0


func blood_per_sec() -> float:
	if dungeon_on or raid_on != "":
		return 0.0   # 던전은 제 보상표가 있다(RaidDefs) — 두 번 주지 않는다
	var p := _offline_profile(stage)
	var kill_time := maxf(0.2, float(p["hp"]) / maxf(0.001, dps()))
	return StageDefs.gold_per_kill(stage) * gold_mult() / kill_time * IDLE_EFF


func _tick_income() -> void:
	# 배급은 여기(1초 틱)에서 한 번에 넣는다 — 프레임마다 더하면 부동소수 오차가
	# 쌓이고, 분당 수입 표시도 같은 자를 써야 한다.
	var drip := blood_per_sec()
	if drip > 0.0:
		gold += drip
		_income_acc += drip
	if _income_ring.size() < 60:
		_income_ring.resize(60)
	_income_ring[_income_idx] = _income_acc
	_income_acc = 0.0
	_income_idx = (_income_idx + 1) % 60
	var per_min := 0.0   # 게시판도 같이 읽는다(_income_per_min)
	for v in _income_ring:
		per_min += v
	if _lbl_income:
		# 레이드에서는 상단이 비어야 한다 — 여기서도 같은 규칙을 본다
		# (이 함수가 매 초 다시 켜므로 _refresh_currency_visibility 만으로는 못 막는다).
		_income_per_min = per_min
		# 상단 수입 줄은 은퇴 — 게시판 알약이 같은 값을 말한다(사장님 2026-08-18).
		_lbl_income.visible = false


# ── 칭호 목록 (도감 탭 오버레이) ───────────────────────────────────────────
var title_worn := ""        # 장착 칭호 id — 겉멋이다. 효과는 딴 것 전부에서 온다
var _lbl_worn: Label
var _lbl_name: Label
var _title_ms: Label
var _title_names: Array[Label] = []
var _title_conds: Array[Label] = []
var _title_rewards: Array[Label] = []
var _title_reward_icons: Array[TextureRect] = []
var _title_badges: Array[TextureRect] = []

# 칭호 보상 스탯 → 아이콘 (스탯 창과 같은 그림).
const TITLE_STAT_ICON := {"damage": "stat_damage", "speed": "stat_speed",
	"tough": "stat_tough", "critdmg": "stat_critdmg"}
# 임무판과 같은 판(QUEST_PANEL) 안에 산다 — 줄 폭도 그 판 기준이다.
# 칭호 줄 폭 — 도감 팝업 안쪽(484)에서 스크롤 여백 16 과 얇은 바 10 을 뺀다.
const TITLE_ROW_W := 484.0 - 16.0 - CODEX_BAR_W


# 칭호 — **도감의 한 소탭**이다 (사장님 2026-08-18). 별도 판을 안 만든다.
#
# 칭호는 성격상 "모으는 것"이고 조건도 전부 도감·구간·미궁 기록을 본다 —
# 도감과 같은 자리에 있어야 "무엇을 더 하면 따는지"가 보인다.
func _title_build(root: Control) -> void:
	var tx := PAD
	var tw := CODEX_W
	# 칭호 수는 머리 두 줄이 적는다 — 여기는 이정표(다음 뭉치)만 남긴다.
	_title_ms = _panel_label(root, Vector2(tx, CODEX_TAB_Y + 42.0),
		Type.SIZE_SMALL, Color(0.72, 0.72, 0.80), tw, 18.0)
	var sy := CODEX_TAB_Y + 66.0
	var sc := _codex_thin_bar(Ui.scroll(Vector2(tx, sy),
		Vector2(CODEX_W - 16.0, CODEX_BOTTOM - sy)))
	root.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size.x = tw - Ui.SCROLL_W
	sc.add_child(col)
	for i in TitleDefs.TITLES.size():
		# 한 칭호 = 카드 한 장. 배지 · 이름 · 조건 둘 · 오른쪽에 보상 아이콘+수치.
		# 줄을 누르면 **장착**한다(딴 것만) — 같은 걸 다시 누르면 벗는다.
		var row := Control.new()
		row.custom_minimum_size = Vector2(TITLE_ROW_W, 48.0)
		col.add_child(row)
		row.add_child(Ui.set_row(TOME, Vector2.ZERO,
			Vector2(TITLE_ROW_W, 48.0)))
		var tid := str(TitleDefs.TITLES[i]["id"])
		var wear := Button.new()
		wear.flat = true
		wear.size = Vector2(TITLE_ROW_W, 48.0)
		wear.focus_mode = Control.FOCUS_NONE
		wear.pressed.connect(func() -> void:
			if not titles_got.has(tid):
				return
			title_worn = "" if title_worn == tid else tid
			_save_game()
			_refresh_titles())
		row.add_child(wear)
		# 배지(badge_title, 사장님 선택 A — 핏방울 인장). 딴 것만 밝다(_refresh).
		var bd := Ui.icon("res://assets/ui/badge_title.png", Vector2(10.0, 10.0), 28.0)
		row.add_child(bd)
		_title_badges.append(bd)
		_title_names.append(_panel_label(row, Vector2(46.0, 7.0), Type.SIZE_SMALL,
			Color(0.92, 0.82, 0.62), TITLE_ROW_W - 150.0, 16.0))
		_title_conds.append(_panel_label(row, Vector2(46.0, 26.0), Type.SIZE_SMALL,
			Color(0.62, 0.60, 0.68), TITLE_ROW_W - 150.0, 16.0))
		var ri := Ui.icon("res://assets/ui/stat_damage.png",
			Vector2(TITLE_ROW_W - 96.0, 14.0), 20.0)
		row.add_child(ri)
		_title_reward_icons.append(ri)
		_title_rewards.append(_panel_label(row, Vector2(TITLE_ROW_W - 72.0, 7.0),
			Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), 66.0, 34.0))


func _refresh_titles() -> void:
	var state := _title_state()
	# 긴 설명("조건 둘을 채우면 스스로 딴다")은 SIZE_BODY 폭에서 잘렸다(실측) —
	# 줄마다 ✓/─ 가 이미 그 규칙을 보여 준다.
	# **다음 이정표**를 한 줄로 — 칭호는 조건이 제각각이라 하나씩 보면 순서가
	# 안 보이는데, "몇 개 더 모으면 무엇"이 그 줄을 세워 준다.
	_title_ms.text = "모두 모았다"
	for m in TitleDefs.MILESTONES:
		if titles_got.size() < int(m["n"]):
			_title_ms.text = "%d종을 모으면 %s %d" % [int(m["n"]),
				_reward_name(str(m["reward"])), int(m["amount"])]
			break
	for i in TitleDefs.TITLES.size():
		var t: Dictionary = TitleDefs.TITLES[i]
		var got: bool = titles_got.has(str(t["id"]))
		var conds: Array = t["conds"]
		var cond_str := ""
		for c in conds:
			cond_str += "%s %s   " % ["✓" if TitleDefs.cond_met(c, state) else "─",
				TitleDefs.cond_text(c)]
		_title_names[i].text = str(t["name"]) \
			+ ("  · 장착" if title_worn == str(t["id"]) else "")
		_title_conds[i].text = cond_str
		_title_rewards[i].text = "%s\n+%d" % [TitleDefs.stat_name(str(t["stat"])),
			int(t["levels"])]
		# 표에 없는 스탯이 와도 화면이 죽지 않게 기본값을 둔다 — 대괄호
		# 접근은 키가 없으면 그 자리에서 터진다(2026-08-25 실측).
		_title_reward_icons[i].texture = Assets.tex("res://assets/ui/%s.png" \
			% str(TITLE_STAT_ICON.get(str(t["stat"]), "stat_damage")))
		_title_names[i].add_theme_color_override("font_color",
			Color(0.92, 0.82, 0.62) if got else Color(0.62, 0.60, 0.68))
		if i < _title_badges.size():
			_title_badges[i].modulate = Color(1, 1, 1) if got \
				else Color(0.4, 0.38, 0.45)


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
		var extra := FoeTiers.codex_extra(r)
		gain.text = "%s +%d%%%s" % [FoeTiers.codex_stat_name(str(r["stat"])),
			int(float(r["rate"]) * 100.0),
			"" if extra.is_empty() else "  %s %d" % [_reward_name(str(extra["kind"])),
				int(float(extra["amount"]))]]
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
	# 진행 초기화 (사장님: 테스트용). 능력치 창 안에 두는 이유 — 평소 플레이 동선
	# 밖이라 오터치가 없고, "내 진행 상황" 화면이라 뜻이 맞는다.
	# 실수 방지는 **두 번 누르기**: 한 번 누르면 3초간 확인 문구로 바뀐다.
	var reset_btn := Ui.button("진행 초기화", Vector2(PAD, CONTENT_BOTTOM - 42.0),
		Vector2(170.0, 36.0), Type.SIZE_SMALL)
	reset_btn.modulate = Color(1.0, 0.72, 0.72)
	reset_btn.pressed.connect(func() -> void:
		if reset_btn.text != "진행 초기화":
			_wipe_save()
			return
		reset_btn.text = "정말? 한 번 더"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(reset_btn):
				reset_btn.text = "진행 초기화"))
	_status_view.add_child(reset_btn)


func _refresh_status() -> void:
	if not _status_view or not _status_view.visible:
		return
	_status_head.text = "지식 합계  %d / %d" % [codex_knowledge,
		FoeTiers.codex_max_knowledge()]
	var now: Array[String] = []
	for stat in ["damage", "crit", "tough"]:
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
	# 선택 표시는 **별빛 보라**다 — 도감이 점성소 결로 왔으니 금빛 띠는 겉돈다.
	var mark := ColorRect.new()
	mark.color = Color(0.62, 0.55, 0.85, 0.20)
	mark.size = Vector2(w, CODEX_ROW_H - 4.0)
	mark.position = Vector2(0, 2.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var ic := Ui.icon(FoeTiers.sprite_of(key), Vector2(6.0, 4.0 + _sprite_drop(key)),
		CODEX_ICON)
	row.add_child(ic)
	# 두 줄(숙련 / 처치 수)을 아이콘 오른쪽에 **세로 가운데로 모은다.** 6/32 로
	# 벌려 놨더니 좁은 칸(112px)에서 위아래로 흩어져 스크롤바 옆에 뭉쳐 보였다.
	var lv := _panel_label(row, Vector2(CODEX_ICON + 10.0, 10.0), Type.SIZE_SMALL,
		Color(1.0, 0.86, 0.52), w - CODEX_ICON - 14.0, 20.0)
	var cnt := _panel_label(row, Vector2(CODEX_ICON + 10.0, 31.0), Type.SIZE_SMALL,
		Color(0.68, 0.68, 0.74), w - CODEX_ICON - 14.0, 20.0)
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
	# **말을 줄인다.** 버튼 둘을 뺀 폭(312px)에 세 토막을 넣으면 마지막이 잘려
	# "다" 만 남았다(실측). 자릿수는 그대로 두고 이름만 짧게 — "다음 보상까지"는
	# 화살표 하나로 읽힌다.
	var parts := ["도감 %d/%d" % [codex_found, FoeTiers.codex_keys().size()],
		"지식 %d" % codex_knowledge]
	for r in FoeTiers.CODEX_REWARDS:
		if int(r["need"]) > codex_knowledge:
			parts.append("다음 %d" % (int(r["need"]) - codex_knowledge))
			break
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
	# "지식"은 도감 합계(전역 보상)의 말이고, 종별 단계는 참고작처럼 "숙련"이다 —
	# 같은 말을 두 군데 쓰면 어느 쪽 숫자인지 헷갈린다.
	_codex_detail["lv"].text = "숙련 %d단계" % level
	_codex_detail["effect"].text = "%s 상대 피해 +%d%%" % [
		str(tier["name"]) if seen else "???", int(FoeTiers.codex_kill_bonus(n) * 100.0)]
	var need := FoeTiers.codex_next_need(n)
	if need <= 0:
		_codex_detail["next"].text = "숙련 만렙"
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
# 일일 임무는 탭이 아니라 **전투 화면 오른쪽 가장자리 버튼**이다(사장님 + 레퍼런스:
# 오른쪽 세로 원형 바로가기 줄). 탭은 "머무는 곳", 임무판은 "들러서 받는 곳"이다.
# 미궁과 재화 던전은 탭이 다르다(사장님) — 미궁 = 기록(혈맥·승급의 열쇠),
# 던전 = 배급(하루 한 번 재화 뭉치). 성격이 다른 걸 한 창에 두면 섞여 읽힌다.
# **미궁을 던전 탭 안으로 넣었다** (사장님 2026-08-13). 둘 다 "들어가서 도는 곳"이라
# 성격이 같고, 던전 탭엔 이미 소탭이 있었다 — 그 옆에 미궁을 붙이면 탭 수는 여섯
# 그대로고 빈 자리가 상점 몫이 된다. 7탭으로 늘리면 아이콘이 48 -> 40px 로 깎여
# 전 탭이 조금씩 작아진다(그 안은 기각).
# 순서는 사장님 지정(2026-08-13): 성장 / 장비 / 도감 / 소환 / 던전 / 상점 —
# 왼쪽 셋은 내 것(성장·장비·기록), 오른쪽 셋은 나가는 곳(소환·던전·상점).
const TABS := [["growth", "tab_growth", "성장"], ["gear", "tab_gear", "장비"],
	["pet", "tab_pet", "펫"], ["home", "tab_home", "사냥"],
	["summon", "tab_battle", "소환"],
	["raid", "tab_raid", "던전"], ["shop", "shop", "상점"]]

# 붉은 알림 점을 다는 탭. **도감은 뺐다** — 눌러서 올릴 게 없고 처치가 알아서 쌓인다.
# 누를 게 없는 곳에 점이 붙으면 점 자체가 "눌러도 소용없는 것"으로 학습된다.
# 던전은 "오늘 표가 남아 있다"에 켠다 — 자정에 사라지는 것이라 점의 원칙에 맞다.
const TAB_DOT_ON := ["growth", "gear", "pet", "summon", "raid", "shop"]
const TAB_DOT := 18.0
const TAB_DOT_AT := Vector2(42.0, 2.0)   # 아이콘(48,6)의 왼쪽 위 모서리에 걸친다


func _build_tabbar() -> void:
	# 칸 폭은 탭 수가 정한다 — 36유닛(화면 폭)을 고르게 나눈다. 5탭이면 7.2유닛.
	# 아이콘·점 자리도 칸 폭에서 계산한다: 상수로 두면 탭을 넣을 때마다 어긋난다.
	var w := 36.0 / float(TABS.size())
	var cell := Grid.uv(w, 6)
	var icon_x := (cell.x - 48.0) * 0.5
	_nav_root = Control.new()
	_hud_root.add_child(_nav_root)
	for i in TABS.size():
		var name: String = TABS[i][0]
		var b := Button.new()
		b.flat = true
		b.position = Grid.uv(i * w, 50.0)
		b.size = cell
		b.pressed.connect(func() -> void: _select_tab(name))
		_nav_root.add_child(b)
		# 눌렀을 때 스타일(사장님) — marker 는 선택 흐림이 색을 쓰니 크기로만.
		var marker := Control.new()
		marker.position = Grid.uv(i * w, 50.0)
		marker.size = cell
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nav_root.add_child(marker)
		marker.add_child(Ui.image("res://assets/ui/tab_cell.png", Vector2.ZERO, cell))
		var ic := Ui.icon("res://assets/ui/%s.png" % TABS[i][1],
			Vector2(icon_x, 6.0), 48.0)
		marker.add_child(ic)
		var label := _panel_label(marker, Vector2(0.0, 54.0), Type.SIZE_SMALL,
			Color(0.82, 0.78, 0.82), cell.x, 24.0)
		label.text = TABS[i][2]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tab_btns[name] = marker
		_nav_hover(b, marker)
		# 점은 marker **밖**(_hud_root)에 단다. _select_tab 이 안 고른 탭의 marker 를
		# 통째로 어둡게 하는데, 점이 그 안에 있으면 같이 죽는다 — 지금 보고 있지 않은
		# 탭이야말로 점을 봐야 하는 탭이라 그러면 기능이 통째로 뒤집힌다.
		if name in TAB_DOT_ON:
			var dot := Ui.icon("res://assets/ui/dot_alert.png",
				Grid.uv(i * w, 50.0) + Vector2(icon_x - 6.0, 2.0), TAB_DOT)
			dot.visible = false
			_nav_root.add_child(dot)
			_tab_dots[name] = dot
	# 던전 전투 하단(사장님: 수동 조작이 없으니 빈 바닥이 그대로 드러났다) —
	# 어둠을 깔고 **판 정보 카드**(어디서 뭘 하는 중인가)를 세운다.
	# ── 전장 게시판 (사장님 승인 2026-08-18: 안 C + 스킬 줄) ──────────────
	# 홈·던전이 같은 뼈대다: 돌벽 어둠 + 장착 스킬 줄(쿨다운) + 지표 알약 3 +
	# 큰 버튼 1. 판 이름·타이머는 상단 HUD 몫이라 여기 안 적는다.
	_board = Control.new()
	_board.visible = false
	_hud_root.add_child(_board)
	# 탭 바 **뒤**에 깐다 — 던전 밖에서는 탭 바가 게시판 위에 떠야 한다(사장님).
	# 던전에서는 탭 바가 숨으니 벽이 끝까지 드러난다.
	_hud_root.move_child(_board, _nav_root.get_index())
	# 배경·테두리는 장비 탭과 동일하게(사장님 2026-08-18) — 표준 판 텍스처.
	_board.add_child(Ui.panel(Vector2(0.0, VIEW_BOTTOM),
		Vector2(Grid.BG.x, Grid.BG.y - VIEW_BOTTOM)))
	# 스킬 줄 — 7칸(기본 6 + 군림이 여는 7번째). 자동 시전이라 누르는 게 아니라
	# **도는 게 보이는** 줄이다: 쿨다운은 위에서 내려오는 어둠, 시전은 금빛 번쩍.
	var bcell := 64.0
	var bgap := (CONTENT_W - bcell * 7.0) / 6.0
	for i in 7:
		var cx := PAD + float(i) * (bcell + bgap)
		var frame := Ui.image("res://assets/ui/slot_common.png",
			Vector2(cx, 452.0), Vector2(bcell, bcell))
		_board.add_child(frame)
		var ic := Ui.icon("", Vector2(cx + 5.0, 457.0), bcell - 10.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(ic)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.015, 0.03, 0.78)
		shade.position = Vector2(cx + 5.0, 457.0)
		shade.size = Vector2(bcell - 10.0, 0.0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(shade)
		var num := _panel_label(_board, Vector2(cx, 470.0), Type.SIZE_MID,
			Color(0.98, 0.95, 0.90), bcell, 24.0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(num, 8)
		_board_cells.append({"frame": frame, "icon": ic, "shade": shade,
			"num": num})
	# 지표 알약 3 — 값은 전부 이미 재는 것들이다.
	var pw := (CONTENT_W - 24.0) / 3.0
	for i in 3:
		var pl := Ui.button("", Vector2(PAD + float(i) * (pw + 12.0), 548.0),
			Vector2(pw, 38.0), Type.SIZE_SMALL)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 지표지 버튼이 아니다
		pl.focus_mode = Control.FOCUS_NONE
		_board.add_child(pl)
		_board_pills.append(pl)
	# 큰 버튼 — 던전에서는 중단, 홈에서는 방치 상자. 장비 탭과 같은 Ui.button.
	_board_btn = Ui.button("", Vector2((Grid.BG.x - 240.0) * 0.5, 716.0),
		Vector2(240.0, 56.0), Type.SIZE_MID)
	_board_btn.pressed.connect(func() -> void:
		if _in_raid() or dungeon_on:
			_gate_exit_pressed()
		else:
			_claim_chest())
	_board.add_child(_board_btn)


# ── 미궁 탭 ─────────────────────────────────────────────────────────────────
# 창은 셋뿐이다: 상태 두 줄 + 버튼 하나. 미궁의 본체는 전투 띠에서 벌어지고,
# 이 창은 들어가는 문이다 — 참고작도 미궁 UI 는 "도전하기" 버튼 하나다.
var _dungeon_info: Label
var _dungeon_sub: Label
var _dungeon_btn: Button
var _dungeon_mastery: Array[Label] = []
var _dungeon_badges: Array[TextureRect] = []
var _dungeon_chips: Array[Label] = []
var _raid_list: Control
var _raid_mode_btns := {}
# ── 시련 (TrialDefs) — 격파 수가 곧 영구 보너스다. 도전 중인 단계 = +1 ──
var trial_stage := 0
var _trial_panel: Control
var _trial_ui := {}
# ── 핏빛 계약 (OathDefs, docs/OATH_DESIGN.md) — 운빨 돌파 ──
var oath_cards := 1          # 보유 — 첫 장은 채워 시작(첫 경험이 에픽 확정이다)
var oath_gold := 0           # 황금 계약서
var oath_charge := 0.0       # 충전 진행(분)
var oath_pity := 0           # 일반 천장(100 — 만월)
var oath_gold_pity := 0      # 황금 천장(30)
var oath_lv := {}            # 계약 id -> 중복 수(레벨)
var oath_first := false      # 계정 첫 카드(에픽 확정)를 썼는가
var oath_daily := ""         # 일일 행운(첫 카드 시프트) 날짜
var oath_last_rarity := ""   # 공명 감지 — 직전 등급
var oath_vow := false        # 피의 서약 토글
var oath_used := 0           # 굴린 횟수 — 계약의 서(미니 패스)가 이걸로 찬다
var oath_book_free := {}     # 계약의 서 무료 줄 수령
var oath_book_paid := {}     # 유료 줄 수령
var oath_week := ""          # 멤버십 주간 황금 지급 주
var oath_col_got := 0        # 수집 보상 — 몇 번째 이정표까지 받았나
var _dev_oath_force := ""    # [개발 도구] 연출 캡처용 등급 강제(--oathroll=)
var oath_fx := {}            # 활성 버프 효과(레벨·공명·각인 반영 후)
var oath_fx_t := 0.0
var oath_fx_name := ""
var oath_fx_id := ""         # 활성 계약 id — 전투 화면 카드 그림에 쓴다
var oath_fx_rarity := "common"
var _oath_view: Control
var _oath_ui := {}
var _oath_reveal: Control
var _oath_icon: TextureRect
var _oath_buff_lbl: Label
var _maze_panel: Control
var _maze_scroll: Control
var _boss_panel: Control
var _boss_name: Label
var _boss_sub: Label
var _boss_btn: Button
var _boss_rows: Array[Dictionary] = []
var _boss_art: TextureRect
var _boss_dmg_lbl: Label
var _raid_info := {}
var _raid_reward := {}
var _raid_btn := {}          # 투명 버튼 — 글자는 _raid_btn_lbl, 그림은 _raid_btn_tex
var _raid_btn_lbl := {}
var _raid_btn_tex := {}
var _dungeon_btn_tex: TextureRect
var _dungeon_btn_lbl: Label
# ── 과금 상태 (IapDefs) ────────────────────────────────────────────────────
# **결제 SDK 는 아직 없다.** 여기는 "샀다"가 정해진 뒤의 세계 — SDK 가 붙으면
# 결제 성공 콜백이 _iap_buy 를 부르면 된다. 지금은 개발 플래그로만 부른다.
var iap_subs := {}          # 구독 id -> 만료 날짜 문자열
var iap_bought := {}        # 1회성 팩 id -> true
var iap_first_buy := false  # 첫 구매 2배를 이미 썼는가
var iap_daily_date := ""    # 구독 일일 지급을 오늘 줬는가
# 성장 패스 — 점수는 **임무를 채울 때만** 들어온다(PassDefs). 패스를 사도 할
# 일이 늘지 않는 게 이 상품의 원칙이라, 진행은 산 사람과 안 산 사람이 같다.
var pass_points := 0
var pass_free_got := {}     # 단계 -> true (무료 줄 수령)
var pass_paid_got := {}     # 단계 -> true (유료 줄 수령)
var pass_season := -1       # 지금 굴러가는 시즌 번호 (PassDefs.season_of)
var flash_open := {}        # 달성 세일 id -> 만료 유닉스 시각 (지나면 닫힘)
var flash_bought := {}      # 산 것 — 세일은 계정당 1회다


# 구간을 처음 밟는 순간 그 구간의 세일이 열린다(24시간). _advance_stage 가
# best_stage 를 올린 직후 부른다 — 여기 말고 다른 갱신 경로는 없다.
# _advance_stage 초입에서 부르면 best_stage 갱신 전이라 한 구간 늦는다 —
# 다음 프레임으로 미룬다(그 사이 best_stage 는 이미 올라 있다).
func _flash_roll_later() -> void:
	call_deferred("_flash_roll")


func _flash_roll() -> void:
	for f in IapDefs.FLASH:
		var id := str(f["id"])
		if best_stage >= int(f["at"]) and not flash_open.has(id) \
				and not flash_bought.has(id):
			flash_open[id] = Time.get_unix_time_from_system() \
				+ IapDefs.FLASH_HOURS * 3600.0


func _flash_left(id: String) -> float:
	return float(flash_open.get(id, 0.0)) - Time.get_unix_time_from_system()


func _flash_buy(id: String) -> void:
	var f := IapDefs.flash_of(id)
	if f.is_empty() or flash_bought.has(id) or _flash_left(id) <= 0.0:
		return
	flash_bought[id] = true
	flash_open.erase(id)
	_iap_grant(f["reward"], str(f["name"]))
	_refresh_shop()
	_save_game()


# 시즌이 넘어갔으면 트랙을 새로 연다(2026-08-20, 사장님 "시즌 배틀패스").
# **안 받은 칸은 그냥 사라진다** — 시즌제의 뜻이 그것이고, 남겨 두면 다음
# 시즌에 두 배로 받는 자리가 된다. 그래서 진열에 "n일 남음"을 적는다.
func _pass_roll_season() -> void:
	var now := PassDefs.season_of(Time.get_date_string_from_system())
	if pass_season < 0:
		pass_season = now      # 첫 실행 — 지금 시즌에서 시작한다
		return
	if now == pass_season:
		return
	pass_season = now
	pass_points = 0
	pass_free_got = {}
	pass_paid_got = {}
# ── 프레스티지 "핏빛 회귀" (PrestigeDefs) ──────────────────────────────────
var prestige_marks := 0     # 혈흔 — 누적. 리셋해도 안 사라진다
var prestige_count := 0     # 몇 번 회귀했나(화면 표기용)
var prestige_peak := 0      # 회귀로 혈흔을 받은 최고 구간 — 여기까진 이미 받았다


# 회귀 배율. **공격력에만** 붙인다 — 체력·수입까지 곱하면 곡선을 다시 재야 한다.
func _prestige_mult() -> float:
	return PrestigeDefs.power_mult(prestige_marks)


# 회귀 — 구간과 혈액으로 산 것을 되돌리고 혈흔을 받는다.
#
# **뽑은 것은 안 뺏는다**(사장님 승인): 장비·스킬·유물은 돈과 시간이 들어간
# 자리라, 리셋이 그걸 지우면 과금 가치가 흔들린다. 기록(미궁·도감·칭호)과
# 다른 재화 축(혈맹·혈맥)도 남는다 — 지우는 건 **혈액으로 산 것**뿐이다.
func _prestige_do() -> void:
	if _fade_t > 0.0:
		return
	var got := PrestigeDefs.marks_for(best_stage, prestige_peak)
	if got <= 0:
		return
	prestige_marks += got
	prestige_count += 1
	prestige_peak = maxi(prestige_peak, best_stage)
	# 되돌리는 것: 구간과 스탯 레벨과 혈액.
	stage = 1
	best_stage = 1
	kills = 0
	gold = 0.0
	lv = {}
	# 던전·보스 안이었으면 데리고 나온다 — 판 한가운데서 구간이 1이 되면
	# 그 판의 몹과 래퍼가 어긋난다.
	raid_on = ""
	dungeon_on = false
	_raid_again = ""
	hero_hp = max_hp()
	_show_reward("핏빛 회귀 %d회" % prestige_count,
		[{"icon": "res://assets/ui/res_blood.png",
		"label": "혈흔 +%d" % got,
		"sub": "공격 x%.2f" % _prestige_mult()}])
	_apply_stage_bg()
	_restart_stage("핏빛 회귀")
	_refresh_currency_visibility()
	_refresh_hud()
	_refresh_prestige()
	_save_game()


# 패스를 샀는가 — 유료 줄은 이게 켜져야 받는다. 만료돼도 **받은 것은 남고**
# 안 받은 유료 줄은 잠긴다(구독의 일반 규칙과 같다).
func _pass_active() -> bool:
	return IapDefs.sub_active(iap_subs, "season_pass")


# 임무를 채우면 점수가 오른다. 여기 한 곳만 부르면 트랙이 따라 오른다.
func _pass_add(points: int) -> void:
	if points <= 0:
		return
	_pass_roll_season()
	pass_points += points
	if _pass_rows.is_empty():
		return
	_refresh_pass()


func _claim_pass(step: int, paid: bool) -> void:
	if step <= 0 or step > PassDefs.step_of(pass_points):
		return
	if paid and not _pass_active():
		return
	var got: Dictionary = pass_paid_got if paid else pass_free_got
	if got.has(step):
		return
	got[step] = true
	var r := PassDefs.paid_reward(step) if paid else PassDefs.free_reward(step)
	_grant_reward(str(r["kind"]), float(r["amount"]))
	_show_reward("성장 패스 %d단계" % step, [{"icon": _shop_kind_icon(str(r["kind"])),
		"label": "+%s" % _n(float(r["amount"])), "sub": _reward_name(str(r["kind"]))}])
	_refresh_currency_visibility()
	_refresh_hud()
	_refresh_pass()
	_save_game()


# 받을 수 있는 것을 **한 번에** 받는다 — 30단계를 60번 누르게 하면 그건 보상이
# 아니라 일이다(레퍼런스도 일괄 수령을 둔다).
func _claim_pass_all() -> void:
	var step := PassDefs.step_of(pass_points)
	var entries: Array = []
	var sums := {}
	for i in range(1, step + 1):
		for paid in [false, true]:
			if paid and not _pass_active():
				continue
			var got: Dictionary = pass_paid_got if paid else pass_free_got
			if got.has(i):
				continue
			got[i] = true
			var r := PassDefs.paid_reward(i) if paid else PassDefs.free_reward(i)
			var k := str(r["kind"])
			sums[k] = float(sums.get(k, 0.0)) + float(r["amount"])
	if sums.is_empty():
		return
	for k in sums:
		_grant_reward(str(k), float(sums[k]))
		entries.append({"icon": _shop_kind_icon(str(k)),
			"label": "+%s" % _n(float(sums[k])), "sub": _reward_name(str(k))})
	_show_reward("성장 패스 — 일괄 수령", entries)
	_refresh_currency_visibility()
	_refresh_hud()
	_refresh_pass()
	_save_game()
var _boss_btn_tex: TextureRect
var _boss_btn_lbl: Label
var _raid_head: Label
var _raid_repeat := false        # 연속 도전 — 격파하고 나오면 그 던전에 다시
var _raid_again := ""            # 암전이 걷히면 들어갈 던전(연속 도전 대기)


# 철창 버튼의 잠김 표시 — 그림 버튼이라 붉은 빛이 꺼지는 걸로 말한다.
# 던전 탭 버튼 넷(재화 3 · 미궁 · 보스 · 이정표 4)이 다 같은 규칙을 쓴다.
static func _gate_btn_dim(tex: TextureRect, lbl: Label, off: bool) -> void:
	tex.modulate = Color(0.45, 0.42, 0.45) if off else Color(1, 1, 1)
	lbl.modulate = Color(0.6, 0.58, 0.6) if off else Color(1, 1, 1)


# 미궁 화면 폭. **스크롤바 + 여백만큼 좁다** — 카드가 스크롤바 밑으로 들어가면
# 손잡이 무늬가 카드 위에 겹쳐 보인다(사장님이 짚은 그 노란 조각).
const MAZE_W := CONTENT_W - Ui.SCROLL_W - 26.0


func _build_dungeon(root: Control) -> void:
	# 머리그림 — 미궁 배경(wide_maze)에서 260x40 을 떠내 2배로 편 판. 전투 화면과
	# 같은 그림이라 "여기가 그 미궁"이 그림으로 읽힌다. 밝은 벽돌 위 글자는
	# 외곽선만으로 약해서 얇은 어둠막을 한 장 덮는다.
	# 머리판은 **그림과 검은 테두리만**이다 (사장님). 금테 카드를 두르고 그 안에
	# 버튼까지 넣었더니 테두리가 두 겹이고 버튼이 그림 위에 떠 있었다.
	var edge := ColorRect.new()
	# 던전 세트의 돌·철 색. 새까맣게 두면 이 판만 다른 화면처럼 뜬다(사장님).
	edge.color = Color(0.26, 0.24, 0.25)
	# 테두리는 **6px** — 3px 로 뒀더니 오른쪽 변이 얇아 안 보여서 그림이 판을
	# 튀어나온 것처럼 읽혔다(사장님).
	edge.position = Vector2(PAD - 6.0, PAD - 10.0)
	edge.size = Vector2(MAZE_W + 12.0, 92.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edge)
	# **잘라서 넣는다.** TextureRect 는 스크롤 안에서 size 가 되밀려 원본 폭(520)으로
	# 그려졌고, 그래서 판을 뚫고 스크롤바 밑까지 갔다(사장님). 클립 상자에 담으면
	# 폭이 확실히 지켜진다.
	var hdr_clip := Control.new()
	hdr_clip.position = Vector2(PAD, PAD - 4.0)
	hdr_clip.size = Vector2(MAZE_W, 80.0)
	hdr_clip.clip_contents = true
	hdr_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hdr_clip)
	hdr_clip.add_child(Ui.image("res://assets/ui/dungeon_header.png",
		Vector2.ZERO, Vector2(MAZE_W, 80.0)))
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.02, 0.05, 0.42)
	scrim.position = Vector2(PAD, PAD - 4.0)
	scrim.size = Vector2(MAZE_W, 80.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)
	var title := _panel_label(root, Vector2(PAD + 12.0, PAD + 4.0), Type.SIZE_MID,
		Color(0.95, 0.68, 0.68), MAZE_W - 190.0, 28.0)
	title.text = "핏빛 미궁"
	_dungeon_info = _panel_label(root, Vector2(PAD + 12.0, PAD + 38.0), Type.SIZE_SMALL,
		Color(0.92, 0.88, 0.92), MAZE_W - 190.0, 22.0)
	# 도전 버튼은 **그림 안**에 둔다 (사장님). 그림 위 어둠막(scrim)이 이미 깔려
	# 있어서 버튼 글자가 배경에 묻히지 않는다. 던전 탭이므로 철창 버튼 그림이다
	# (사장님 2026-08-13: 미궁·보스도 같은 세트로).
	var dbx := Vector2(PAD + MAZE_W - 162.0, PAD + 16.0)
	_dungeon_btn_tex = _shop_tex(root, "res://assets/ui/sets/gate_button.png",
		dbx, Vector2(150.0, 44.0))
	_dungeon_btn_lbl = _panel_label(root, Vector2(dbx.x, dbx.y + 11.0),
		Type.SIZE_MID, Color(1.0, 0.95, 0.90), 150.0, 22.0)
	_dungeon_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_dungeon_btn_lbl, 8)
	_dungeon_btn = _shop_ghost(root, Vector2(150.0, 44.0), _dungeon_btn_tex)
	_dungeon_btn.position = dbx
	# 재화 던전·주간 보스와 같은 문법 — 상세 판을 한 번 거친다(사장님 2026-08-14).
	_dungeon_btn.pressed.connect(func() -> void:
		if dungeon_on:
			_dungeon_exit("미궁 이탈")
			_refresh_dungeon()
		else:
			_raid_detail_open("maze"))
	# 수치 칸 3개 — 최고층(왕관) · 개방층(철문) · 혈정. 돌 알약.
	var chip_w := (MAZE_W - 20.0) / 3.0
	var chip_icons := ["badge_mastery", "tab_dungeon", "res_crystal"]
	for i in 3:
		var x := PAD + float(i) * (chip_w + 10.0)
		_shop_tex(root, "res://assets/ui/sets/gate_pill.png",
			Vector2(x, 122.0), Vector2(chip_w, 32.0))
		root.add_child(Ui.icon("res://assets/ui/%s.png" % chip_icons[i],
			Vector2(x + 16.0, 127.0), 20.0))
		var chip := _panel_label(root, Vector2(x + 42.0, 123.0),
			Type.SIZE_SMALL, Color(0.95, 0.90, 0.90), chip_w - 50.0, 30.0)
		_shop_outline(chip, 5)
		_dungeon_chips.append(chip)
	_dungeon_sub = _panel_label(root, Vector2(PAD, 156.0), Type.SIZE_SMALL,
		Color(0.72, 0.70, 0.76), MAZE_W, 18.0)
	# 군림 판 — 본편 돌파가 자동으로 여는 기능 5개. 창은 미궁 탭을 빌린다:
	# 교차 잠금의 다른 축들(가지·상한)이 다 이 창에 적혀 있어서 자리가 맞다.
	# (재화 던전이 잠깐 이 자리를 썼다가 제 탭으로 갔다 — 성격이 다르다, 사장님.)
	# **사슬 없는 전용 판**(gate_panel) — 사슬 카드를 세로로 늘렸더니 사슬이
	# 판 가운데까지 들어와 글자를 먹었다(사장님: "깨지는 부분은 신규 UI").
	_shop_tex(root, "res://assets/ui/sets/gate_panel.png", Vector2(PAD - 8.0, 178.0),
		Vector2(MAZE_W + 16.0, CONTENT_BOTTOM - 178.0))
	var mt := _panel_label(root, Vector2(PAD + 12.0, 190.0), Type.SIZE_SMALL,
		Color(1.0, 0.86, 0.55), MAZE_W - 24.0, 18.0)
	mt.text = "군림 — 구간을 넘으면 스스로 열린다"
	_shop_outline(mt, 6)
	for i in MasteryDefs.RANKS.size():
		# 배지(badge_mastery, 사장님 선택 A) — 색은 해금 여부가 정한다(_refresh).
		var bd := Ui.icon("res://assets/ui/badge_mastery.png",
			Vector2(PAD + 14.0, 216.0 + float(i) * 28.0), 20.0)
		root.add_child(bd)
		_dungeon_badges.append(bd)
		var ml := _panel_label(root,
			Vector2(PAD + 40.0, 216.0 + float(i) * 28.0),
			Type.SIZE_SMALL, Color(0.86, 0.84, 0.86), MAZE_W - 52.0, 20.0)
		_shop_outline(ml, 5)
		_dungeon_mastery.append(ml)
	_refresh_dungeon()


# ── 던전 탭 — 재화 던전 2종 (RaidDefs). 참고작 "던전 입구"의 우리 버전 ──────
func _build_raids(root: Control) -> void:
	# 전면 판 (사장님 2026-08-13, 레퍼런스 문법): 성문 헤더가 위에 서고 콘텐츠
	# 컨테이너(미궁·던전·보스)는 통째로 그 아래로 내린다 — 내부 좌표는 안 바꾼다.
	var head := Control.new()
	head.position = Vector2(PAD, 12.0)
	head.size = Vector2(CONTENT_W, 210.0)
	head.clip_contents = true
	root.add_child(head)
	var gate := TextureRect.new()
	gate.texture = Assets.tex("res://assets/ui/head_gate.png")
	gate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gate.size = Vector2(CONTENT_W, CONTENT_W * 224.0 / 576.0)
	gate.position = Vector2(0.0, -6.0)
	gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gate)
	_raid_place = _panel_label(head, Vector2(16.0, 10.0), Type.SIZE_MID,
		Color(0.97, 0.92, 0.86), 220.0, 24.0)
	_shop_outline(_raid_place, 8)
	_shop_tex(head, "card_title", Vector2(8.0, 42.0), Vector2(328.0, 40.0))
	_raid_line = _panel_label(head, Vector2(26.0, 52.0), Type.SIZE_SMALL,
		Color(0.95, 0.88, 0.80), 300.0, 18.0)
	_shop_outline(_raid_line, 4)
	# 미궁은 **버튼 아래에서 시작하는 스크롤** 안에 산다 (사장님). 안쪽 폭은
	# 스크롤바 + 여백만큼 줄여 둔다(MAZE_W).
	_maze_scroll = Ui.scroll(Vector2(0.0, 274.0),
		Vector2(PANEL_W, FULL_BOTTOM - 274.0 + 12.0))
	_maze_scroll.visible = false
	root.add_child(_maze_scroll)
	_maze_panel = Control.new()
	_maze_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 내용은 PAD~CONTENT_BOTTOM 좌표를 그대로 쓰므로 그만큼 세로를 확보한다.
	_maze_panel.custom_minimum_size = Vector2(PANEL_W - Ui.SCROLL_W,
		CONTENT_BOTTOM + 12.0)
	_maze_scroll.add_child(_maze_panel)
	_build_dungeon(_maze_panel)
	# [미궁][재화 던전][주간 보스] — 셋 다 "들어가서 도는 곳"이다. 성격은 다르다:
	# 미궁은 기록(혈맥의 열쇠), 던전은 배급(하루 뭉치), 보스는 도전(못 죽여도 누적).
	# 상점·소환과 같은 박쥐 알약 — 그림 버튼이라 글자는 라벨로 얹는다.
	var modes := [["maze", "미궁"], ["raid", "재화 던전"], ["boss", "주간 보스"],
		["trial", "시련"]]
	var mw := (CONTENT_W - 10.0 * 3.0) / 4.0
	for i in modes.size():
		var mode: String = modes[i][0]
		var mb := TextureButton.new()
		mb.texture_normal = Assets.tex("res://assets/ui/sets/gate_tab_off.png")
		mb.texture_pressed = Assets.tex("res://assets/ui/sets/gate_tab_on.png")
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_SCALE
		mb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mb.toggle_mode = true
		mb.position = Vector2(PAD + float(i) * (mw + 10.0), 232.0)
		mb.size = Vector2(mw, 36.0)
		Ui.hover_pop(mb)
		mb.pressed.connect(func() -> void: _raid_set_mode(mode))
		root.add_child(mb)
		var ml := _panel_label(root, Vector2(mb.position.x, 239.0),
			Type.SIZE_MID, Color(1.0, 0.97, 0.92), mw, 22.0)
		ml.text = str(modes[i][1])
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(ml, 8)
		_raid_mode_btns[mode] = mb
	_raid_list = Control.new()
	_raid_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_list.position.y = 214.0
	root.add_child(_raid_list)
	_boss_panel = Control.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	_boss_panel.position.y = 214.0
	root.add_child(_boss_panel)
	_build_boss_panel(_boss_panel)
	_trial_panel = Control.new()
	_trial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trial_panel.visible = false
	_trial_panel.position.y = 214.0
	root.add_child(_trial_panel)
	_build_trial_panel(_trial_panel)
	_build_raid_list(_raid_list)
	_build_raid_detail(root)
	_raid_set_mode("raid")


func _raid_set_mode(mode: String) -> void:
	if _raid_detail:
		_raid_detail.visible = false   # 소탭을 옮기면 상세는 닫는다
	_raid_list.visible = mode == "raid"
	_boss_panel.visible = mode == "boss"
	_maze_scroll.visible = mode == "maze"
	_trial_panel.visible = mode == "trial"
	# 헤더 이름표·대사 — 장소는 성문 하나지만 말은 소탭을 따라간다.
	match mode:
		"maze":
			_raid_place.text = "심연의 미궁"
			_raid_line.text = "깊이 내려갈수록 좋은 것이 잠들어 있지."
		"raid":
			_raid_place.text = "던전 성문"
			_raid_line.text = "오늘의 사냥감이 기다린다."
		"boss":
			_raid_place.text = "제물의 제단"
			_raid_line.text = "이번 주의 제물은… 강하다."
		"trial":
			_raid_place.text = "고대 유적지"
			_raid_line.text = "물러날 줄 아는 것도 실력이지."
	for key in _raid_mode_btns:
		_raid_mode_btns[key].button_pressed = key == mode
	_refresh_dungeon()


# 주간 보스 판 — 이름 · 남은 도전 · 누적 피해 · 마일스톤 4줄 · 도전 버튼.
func _build_boss_panel(root: Control) -> void:
	# **초상화를 앞세운다** (사장님: "텍스트 덩어리"). 이 판은 주마다 얼굴이 바뀌는
	# 곳인데 이름 한 줄로는 그게 안 읽힌다 — 왼쪽에 72px 그림, 오른쪽에 이름·단계·
	# 이번 주 성과, 그 아래 이정표 넷.
	# 토글 버튼(y 20~54) 아래에서 시작한다 — 46 에 두면 글자가 버튼을 뚫는다.
	# **사슬 없는 전용 판** — 사슬 카드로는 초상화·이름·버튼이 다 사슬에 물렸다.
	_shop_tex(root, "res://assets/ui/sets/gate_panel.png", Vector2(PAD - 8.0, 56.0),
		Vector2(CONTENT_W + 16.0, 140.0))
	# 초상화 액자 — 전용 그림 한 장을 모든 초상이 같이 쓴다(사장님 2026-08-18).
	# 그림을 먼저, 액자를 위에 — 테두리가 초상 가장자리를 덮어야 액자다.
	_boss_art = _framed_portrait(root, Vector2(PAD + 10.0, 96.0))
	var text_x := PAD + 92.0
	var text_w := CONTENT_W - 92.0 - 168.0
	_boss_name = _panel_label(root, Vector2(text_x, 76.0), Type.SIZE_MID,
		Color(0.98, 0.82, 0.62), text_w, 24.0)
	_shop_outline(_boss_name, 6)
	# 이번 주 성과를 **큰 숫자로** 따로 세운다 — 누적 피해가 이 판의 점수판이다.
	_boss_dmg_lbl = _panel_label(root, Vector2(text_x, 106.0), Type.SIZE_MID,
		Color(0.98, 0.90, 0.70), text_w, 24.0)
	_shop_outline(_boss_dmg_lbl, 6)
	_boss_sub = _panel_label(root, Vector2(text_x, 140.0), Type.SIZE_SMALL,
		Color(0.86, 0.84, 0.86), CONTENT_W - 100.0, 16.0)
	_shop_outline(_boss_sub, 5)
	var bbx := Vector2(PAD + CONTENT_W - 156.0, 96.0)
	_boss_btn_tex = _shop_tex(root, "res://assets/ui/sets/gate_button.png",
		bbx, Vector2(148.0, 50.0))
	_boss_btn_lbl = _panel_label(root, Vector2(bbx.x, bbx.y + 15.0), Type.SIZE_MID,
		Color(1.0, 0.95, 0.90), 148.0, 22.0)
	_boss_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_boss_btn_lbl, 8)
	_boss_btn = _shop_ghost(root, Vector2(148.0, 50.0), _boss_btn_tex)
	_boss_btn.position = bbx
	# 재화 던전과 같은 문법 — 바로 안 들어가고 상세 판을 한 번 거친다.
	_boss_btn.pressed.connect(func() -> void:
		if raid_on == "boss":
			_boss_exit("도전 중단")
			_refresh_dungeon()
		else:
			_raid_detail_open("boss"))
	# 이정표 넷 — **가로로 긴 전용 띠**(gate_bar). 알약(214px)을 544 로 펴면
	# 끝 곡선이 뭉갠다(실측) — 그래서 이 비율 전용 자산을 따로 뽑았다.
	for i in EventDefs.MILESTONES.size():
		var m: Dictionary = EventDefs.MILESTONES[i]
		var y := 210.0 + float(i) * 58.0
		_shop_tex(root, "res://assets/ui/sets/gate_bar.png",
			Vector2(PAD - 8.0, y), Vector2(CONTENT_W + 16.0, 50.0))
		root.add_child(Ui.icon("res://assets/ui/%s.png" % _reward_icon(str(m["reward"])),
			Vector2(PAD + 8.0, y + 12.0), 26.0))
		var nm := _panel_label(root, Vector2(PAD + 44.0, y + 6.0), Type.SIZE_SMALL,
			Color(0.95, 0.90, 0.90), CONTENT_W - 200.0, 16.0)
		# "이정표 3"보다 **무엇을 주는가**가 먼저다 — 번호는 옆 진행도가 말해 준다.
		nm.text = "%d차 · %s" % [i + 1, _reward_name(str(m["reward"]))]
		_shop_outline(nm, 5)
		var track := ColorRect.new()
		track.color = Color(0.52, 0.42, 0.33)
		track.position = Vector2(PAD + 44.0, y + 30.0)
		track.size = Vector2(BOSS_BAR_W, 8.0)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(track)
		var fill := ColorRect.new()
		fill.color = Color(0.98, 0.62, 0.30)
		fill.position = track.position
		fill.size = Vector2(0.0, 8.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)
		var pr := _panel_label(root, Vector2(PAD + 44.0 + BOSS_BAR_W + 8.0, y + 24.0),
			Type.SIZE_SMALL, Color(0.86, 0.84, 0.86), 150.0, 20.0)
		_shop_outline(pr, 5)
		var idx := i
		var mbx := Vector2(PAD + CONTENT_W - 118.0, y + 6.0)
		var mtex := _shop_tex(root, "res://assets/ui/sets/gate_button.png",
			mbx, Vector2(110.0, 38.0))
		var mlb := _panel_label(root, Vector2(mbx.x + 16.0, mbx.y + 10.0),
			Type.SIZE_SMALL, Color(1.0, 0.95, 0.90), 78.0, 18.0)
		mlb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(mlb, 6)
		var mic := Ui.icon("res://assets/ui/%s.png" % _reward_icon(str(m["reward"])),
			mbx + Vector2(8.0, 12.0), 16.0)
		mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(mic)
		var b := _shop_ghost(root, Vector2(114.0, 38.0), mtex)
		b.position = mbx
		b.pressed.connect(func() -> void: _claim_milestone(idx))
		_boss_rows.append({"prog": pr, "btn": b, "fill": fill,
			"tex": mtex, "lbl": mlb, "icon": mic})


# ── 던전 상세 판 (사장님 2026-08-14, 레퍼런스 "던전 입구") ──────────────────
# 카드를 누르면 바로 안 들어가고 **한 판 더** 거친다: 그 던전의 이름·단계·목표·
# 이번 판 보상·오늘 남은 표를 크게 보여 주고 거기서 도전을 누른다.
#
# 왜 한 겹 더 두나: 목록 카드는 셋을 견주는 자리라 한 줄씩밖에 못 적는다.
# "무엇을 해야 이기는 판인지"는 들어가기 직전에 큰 글자로 읽혀야 한다.
var _raid_detail: Control
var _raid_detail_kind := ""
var _rd_name: Label
var _rd_stage: Label
var _rd_goal: Label
var _rd_reward: Label
var _rd_left: Label
var _rd_btn: Button
var _rd_btn_tex: TextureRect
var _rd_btn_lbl: Label
var _rd_icon: TextureRect
var _rd_sweep: Button          # 소탕 — 이미 깬 단계를 전투 없이
var _rd_sweep_tex: TextureRect
var _rd_sweep_lbl: Label
var _rd_chain: Button          # 연속 도전 — 입장 팝업의 세 번째 버튼
var _rd_chain_tex: TextureRect
var _rd_chain_lbl: Label
# 돌판(gate_detail 414x559)을 화면에 400x540 으로 놓고 **조각을 실측한** 값들.
# 원본 자리 x 배율(0.966) + 돌판 상단(RD_TOP). 눈대중으로 옮기면 판을 다시
# 뽑을 때마다 처음부터 맞추게 된다 — 여기 한 곳만 고치면 전부 따라온다.
const RD_W := 400.0
const RD_H := 540.0
const RD_TOP := 218.0
const RD_PLAQUE_Y := 262.0     # 제목판(원본 y44~91)의 글자 자리
const RD_STAGE_Y := 318.0      # 제목판 아래 여백
const RD_GOAL_Y := 372.0       # 설명란 — 알코브 위 빈 자리
const RD_ALCOVE_Y := 443.0     # 알코브 안쪽(원본 y233~436) 시작
# 알코브 안쪽 폭. **여기 넘는 글자는 알코브 밖 돌판 위로 샌다**(사장님 실측) —
# 알코브 안에 놓는 라벨은 화면 폭이 아니라 이 값으로 묶는다.
const RD_ALCOVE_W := 168.0
const RD_ICON := 96.0
const RD_ICON_Y := 460.0
const RD_VALUE_Y := 566.0      # 알코브 안 아래 — 그림이 뜻하는 값
const RD_SUB_Y := 602.0
const RD_BTN_Y := 656.0
const RD_BTN_H := 32.0   # 56→40→32, 두 번 줄였다(사장님)
const RD_BTN_W := 178.0        # 둘일 때. 하나면 RD_BTN_SOLO
const RD_BTN_SOLO := 170.0
const RD_CLOSE_Y := 722.0


# 버튼 줄을 다시 놓는다. 소탕이 없는 판(보스·미궁)은 **도전 하나가 가운데**에
# 크게 선다 — 비활성 버튼을 남겨 두면 "여긴 왜 못 누르지"만 남는다(사장님).
func _rd_place_buttons(with_sweep: bool) -> void:
	_rd_sweep_tex.visible = with_sweep
	_rd_sweep_lbl.visible = with_sweep
	_rd_sweep.visible = with_sweep
	# 연속 도전은 재화 던전(소탕 있는 판)에만 선다 — 보스·미궁은 성격이 다르다.
	_rd_chain_tex.visible = with_sweep
	_rd_chain_lbl.visible = with_sweep
	_rd_chain.visible = with_sweep
	# 셋일 때 120 x 3 + 틈 20 = 380 — 판(576) 안에 넉넉히 든다.
	var w := 120.0 if with_sweep else RD_BTN_SOLO
	for n in [_rd_btn_tex, _rd_btn, _rd_sweep_tex, _rd_sweep,
			_rd_chain_tex, _rd_chain]:
		(n as Control).size = Vector2(w, RD_BTN_H)
	_rd_btn_lbl.size.x = w
	_rd_sweep_lbl.size.x = w
	_rd_chain_lbl.size.x = w
	if with_sweep:
		var sx := (PANEL_W - w * 3.0 - 10.0 * 2.0) * 0.5
		_rd_sweep_tex.position = Vector2(sx, RD_BTN_Y)
		_rd_btn_tex.position = Vector2(sx + w + 10.0, RD_BTN_Y)
		_rd_chain_tex.position = Vector2(sx + (w + 10.0) * 2.0, RD_BTN_Y)
	else:
		_rd_btn_tex.position = Vector2((PANEL_W - w) * 0.5, RD_BTN_Y)
	_rd_sweep.position = _rd_sweep_tex.position
	_rd_sweep_lbl.position = _rd_sweep_tex.position + Vector2(0.0, 7.0)
	_rd_btn.position = _rd_btn_tex.position
	_rd_btn_lbl.position = _rd_btn_tex.position + Vector2(0.0, 7.0)
	_rd_chain.position = _rd_chain_tex.position
	_rd_chain_lbl.position = _rd_chain_tex.position + Vector2(0.0, 7.0)
	# 그림 버튼은 가운데를 기준으로 부풀므로 축도 다시 잡는다.
	_rd_btn_tex.pivot_offset = _rd_btn_tex.size * 0.5
	_rd_sweep_tex.pivot_offset = _rd_sweep_tex.size * 0.5
	_rd_chain_tex.pivot_offset = _rd_chain_tex.size * 0.5


# 시련 판 — 주간 보스 판과 같은 문법(초상 + 이름 + 큰 숫자 + 버튼). 이정표는
# 없다: 이 판의 점수는 누적이 아니라 "몇 단계까지 넘었나" 하나다.
func _build_trial_panel(root: Control) -> void:
	_shop_tex(root, "res://assets/ui/sets/gate_panel.png", Vector2(PAD - 8.0, 56.0),
		Vector2(CONTENT_W + 16.0, 140.0))
	_trial_ui["art"] = _framed_portrait(root, Vector2(PAD + 10.0, 96.0))
	var text_x := PAD + 92.0
	var text_w := CONTENT_W - 92.0 - 168.0
	_trial_ui["name"] = _panel_label(root, Vector2(text_x, 76.0), Type.SIZE_MID,
		Color(0.86, 0.96, 0.82), text_w, 24.0)
	_shop_outline(_trial_ui["name"], 6)
	_trial_ui["bonus"] = _panel_label(root, Vector2(text_x, 106.0), Type.SIZE_MID,
		Color(0.98, 0.90, 0.70), text_w, 24.0)
	_shop_outline(_trial_ui["bonus"], 6)
	_trial_ui["sub"] = _panel_label(root, Vector2(text_x, 140.0), Type.SIZE_SMALL,
		Color(0.86, 0.84, 0.86), CONTENT_W - 100.0, 16.0)
	_shop_outline(_trial_ui["sub"], 5)
	var bx := Vector2(PAD + CONTENT_W - 156.0, 96.0)
	_trial_ui["btn_tex"] = _shop_tex(root, "res://assets/ui/sets/gate_button.png",
		bx, Vector2(148.0, 50.0))
	_trial_ui["btn_lbl"] = _panel_label(root, Vector2(bx.x, bx.y + 15.0),
		Type.SIZE_MID, Color(1.0, 0.95, 0.90), 148.0, 22.0)
	_trial_ui["btn_lbl"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_trial_ui["btn_lbl"], 8)
	var b := _shop_ghost(root, Vector2(148.0, 50.0), _trial_ui["btn_tex"])
	b.position = bx
	b.pressed.connect(func() -> void:
		if raid_on == "trial":
			_trial_exit("도전 중단")
		else:
			_trial_enter())
	_trial_ui["btn"] = b
	# 규칙 카드 — 이 판이 뭘 주는지 두 줄로.
	_shop_tex(root, "res://assets/ui/sets/gate_panel.png", Vector2(PAD - 8.0, 220.0),
		Vector2(CONTENT_W + 16.0, 96.0))
	var r1 := _panel_label(root, Vector2(PAD + 18.0, 244.0), Type.SIZE_SMALL,
		Color(0.86, 0.84, 0.86), CONTENT_W - 36.0, 16.0)
	r1.text = "단계 보스를 눕히면 공격·체력이 영구히 오른다"
	_shop_outline(r1, 5)
	var r2 := _panel_label(root, Vector2(PAD + 18.0, 272.0), Type.SIZE_SMALL,
		Color(0.72, 0.70, 0.74), CONTENT_W - 36.0, 16.0)
	r2.text = "실패해도 잃는 것은 없다 — 미궁을 오르면 다음 단계가 열린다"
	_shop_outline(r2, 5)
	_refresh_trial()


func _refresh_trial() -> void:
	if _trial_ui.is_empty():
		return
	var n := trial_stage + 1
	var done := n > TrialDefs.max_stage()
	var show_n := mini(n, TrialDefs.max_stage())
	_trial_ui["art"].texture = Assets.tex("res://assets/ui/boss_warden.png")
	# "시련"은 탭이 이미 말한다 — 붙이면 이름이 잘렸다(실측 폭 268).
	_trial_ui["name"].text = "완주" if done \
		else "%d단계  ·  유적의 파수꾼" % show_n
	_trial_ui["bonus"].text = "공격·체력 +%d%%" % int(round(
		TrialDefs.BONUS_PER * 100.0 * float(trial_stage)))
	var need := TrialDefs.floor_need(n)
	var open := not done and dungeon_best >= need
	if done:
		_trial_ui["sub"].text = "모든 시련을 넘었다"
	elif open:
		_trial_ui["sub"].text = "격파 시 +%d%%  ·  도전 무제한" % int(round(
			TrialDefs.BONUS_PER * 100.0 * float(n)))
	else:
		_trial_ui["sub"].text = "미궁 %d층 정복 필요 (지금 %d층)" % [need, dungeon_best]
	if raid_on == "trial":
		_trial_ui["btn_lbl"].text = "돌아가기"
		_trial_ui["btn"].disabled = false
	else:
		_trial_ui["btn_lbl"].text = "도전"
		_trial_ui["btn"].disabled = not open or dungeon_on or raid_on != ""
	_gate_btn_dim(_trial_ui["btn_tex"], _trial_ui["btn_lbl"],
		_trial_ui["btn"].disabled)


func _build_raid_detail(root: Control) -> void:
	_raid_detail = Control.new()
	_raid_detail.visible = false
	_raid_detail.size = Vector2(PANEL_W, PANEL_FULL_H)
	_raid_detail.z_index = 8
	root.add_child(_raid_detail)
	# 뒤 목록을 덮는다 — 반투명이면 두 판의 글자가 섞여 읽힌다(임무판과 같은 규칙).
	var back := ColorRect.new()
	# **보이지 않는다** (사장님 2026-08-14: 검은 화면 없애 줘) — 돌판이 이미
	# 불투명이라 가릴 것은 그놈이 가린다. 이 판이 하는 일은 **뒤 버튼을 막는
	# 것** 하나다: 없애면 상세 뒤의 입장 버튼이 그대로 눌린다.
	back.color = Color(0.03, 0.02, 0.04, 0.55)
	back.position = Vector2(PAD - 14.0, 218.0)
	back.size = Vector2(CONTENT_W + 28.0, FULL_BOTTOM - 208.0)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_raid_detail.add_child(back)
	# 그 위에 **던전 세트의 돌판**을 얹는다 — 검은 배경에 글자만 있으면 다른
	# 화면들과 결이 안 맞아 이질적이다(사장님). 원본 비율(414x559)을 지킨다.
	#
	# **자리는 돌판의 조각을 실측해서 잡는다**(사장님: 설명란과 아이콘 자리가
	# 따로 있어야 하는데 뒤섞였다). 원본에서 잰 값:
	#   제목판  y 44~91   · 알코브 y 233~436 (안쪽 밝은 면) · 폭 약 160
	# 화면 배율 540/559 = 0.966 을 곱해 상수로 못 박는다 — 매번 눈대중으로
	# 옮기면 판을 다시 뽑을 때마다 처음부터 맞추게 된다.
	_shop_tex(_raid_detail, "res://assets/ui/sets/gate_detail.png",
		Vector2((PANEL_W - RD_W) * 0.5, RD_TOP), Vector2(RD_W, RD_H))
	# ── 제목판: 던전 이름 ──────────────────────────────────────────────
	_rd_name = _panel_label(_raid_detail, Vector2(0.0, RD_PLAQUE_Y),
		Type.SIZE_TITLE, Color(0.98, 0.88, 0.62), PANEL_W, 44.0)
	_rd_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_name, 8)
	# ── 제목판 아래: 단계 알약 ─────────────────────────────────────────
	_shop_tex(_raid_detail, "res://assets/ui/sets/gate_pill.png",
		Vector2((PANEL_W - 200.0) * 0.5, RD_STAGE_Y), Vector2(200.0, 34.0))
	_rd_stage = _panel_label(_raid_detail, Vector2(0.0, RD_STAGE_Y + 8.0),
		Type.SIZE_MID, Color(0.95, 0.92, 0.90), PANEL_W, 22.0)
	_rd_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_stage, 6)
	# ── 설명란: 알코브 **위** 빈 자리. 이 판이 무엇을 요구하는지 한 줄 ───
	_rd_goal = _panel_label(_raid_detail, Vector2(0.0, RD_GOAL_Y),
		Type.SIZE_MID, Color(0.86, 0.90, 0.98), PANEL_W, 24.0)
	_rd_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_goal, 6)
	# ── 알코브: 그림 하나만. 액자는 안 두른다(알코브가 이미 액자다) ─────
	_rd_icon = Ui.icon("", Vector2((PANEL_W - RD_ICON) * 0.5, RD_ICON_Y), RD_ICON)
	_rd_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_detail.add_child(_rd_icon)
	# 알코브 안 아래: 그 그림이 뜻하는 값(보상·성과)과 부가 한 줄
	_rd_reward = _panel_label(_raid_detail,
		Vector2((PANEL_W - RD_ALCOVE_W) * 0.5, RD_VALUE_Y),
		Type.SIZE_MID, Color(0.98, 0.90, 0.70), RD_ALCOVE_W, 24.0)
	_rd_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_reward, 6)
	# 부가 정보는 **두 줄**이다 — 한 줄로 이으면 알코브 폭에 절대 안 들어간다.
	_rd_left = _panel_label(_raid_detail,
		Vector2((PANEL_W - RD_ALCOVE_W) * 0.5, RD_SUB_Y),
		Type.SIZE_SMALL, Color(0.84, 0.82, 0.86), RD_ALCOVE_W, 40.0)
	_rd_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_left, 5)
	# ── 알코브 아래: 버튼. 소탕이 없는 판(보스·미궁)은 도전 하나가 가운데에
	# 크게 선다 — 비활성 버튼을 남겨 두면 "여긴 왜 못 누르지"만 남는다(사장님).
	_rd_sweep_tex = _shop_tex(_raid_detail, "res://assets/ui/sets/gate_button.png",
		Vector2.ZERO, Vector2(RD_BTN_W, RD_BTN_H))
	_rd_sweep_lbl = _panel_label(_raid_detail, Vector2.ZERO,
		Type.SIZE_MID, Color(1.0, 0.95, 0.90), RD_BTN_W, 24.0)
	_rd_sweep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_sweep_lbl, 8)
	_rd_sweep = _shop_ghost(_raid_detail, Vector2(RD_BTN_W, RD_BTN_H), _rd_sweep_tex)
	_rd_sweep.pressed.connect(func() -> void: _raid_sweep(_raid_detail_kind))
	_rd_btn_tex = _shop_tex(_raid_detail, "res://assets/ui/sets/gate_button.png",
		Vector2.ZERO, Vector2(RD_BTN_W, RD_BTN_H))
	_rd_btn_lbl = _panel_label(_raid_detail, Vector2.ZERO,
		Type.SIZE_MID, Color(1.0, 0.95, 0.90), RD_BTN_W, 24.0)
	_rd_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_rd_btn_lbl, 8)
	_rd_btn = _shop_ghost(_raid_detail, Vector2(RD_BTN_W, RD_BTN_H), _rd_btn_tex)
	_rd_btn.pressed.connect(func() -> void:
		var k := _raid_detail_kind
		_raid_detail.visible = false
		match k:
			"boss": _boss_enter()
			"maze": _dungeon_enter()
			_:
				_raid_repeat = false   # 한 판만 — 연속은 옆 버튼이 맡는다
				_raid_enter(k)
		_refresh_dungeon())
	# 연속 도전 (사장님 2026-08-18: 목록 토글보다 입장 팝업 버튼이 깔끔하다) —
	# 이 판부터 표가 남는 동안 연달아 돈다. 저장 안 하는 원칙은 그대로:
	# 켠 채로 잊고 표를 태우면 도움이 아니라 사고다.
	_rd_chain_tex = _shop_tex(_raid_detail, "res://assets/ui/sets/gate_button.png",
		Vector2.ZERO, Vector2(RD_BTN_W, RD_BTN_H))
	_rd_chain_lbl = _panel_label(_raid_detail, Vector2.ZERO,
		Type.SIZE_MID, Color(1.0, 0.95, 0.90), RD_BTN_W, 24.0)
	_rd_chain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rd_chain_lbl.text = "연속 도전"
	_shop_outline(_rd_chain_lbl, 8)
	_rd_chain = _shop_ghost(_raid_detail, Vector2(RD_BTN_W, RD_BTN_H), _rd_chain_tex)
	_rd_chain.pressed.connect(func() -> void:
		var k := _raid_detail_kind
		_raid_detail.visible = false
		_raid_repeat = true
		_raid_enter(k)
		_refresh_dungeon())
	# 돌아가기 — 상세는 덮는 판이라 나갈 길이 반드시 있어야 한다.
	var close := Ui.button("돌아가기", Vector2((PANEL_W - 150.0) * 0.5, RD_CLOSE_Y),
		Vector2(150.0, 32.0), Type.SIZE_SMALL)
	close.pressed.connect(func() -> void: _raid_detail.visible = false)
	_raid_detail.add_child(close)


# 소탕 — **이미 깬 단계**를 전투 없이 받는다(레퍼런스 "소탕", 사장님 요청).
# 표를 한 장 쓰고 그 던전 최고 기록 단계의 뭉치를 그대로 준다.
#
# 지키는 것 둘:
#   1. **한 번은 손으로 깨야 한다** — 기록이 없으면 소탕할 것도 없다. 소탕이
#      선행 도전을 건너뛰면 던전을 아무도 안 돈다
#   2. **단계는 안 오른다** — 다음 단계는 직접 도전해서만 열린다. 소탕이 기록을
#      밀면 벽이 사라지고 재화 배급이 무한이 된다(재화 격리)
func _raid_sweep(kind: String) -> void:
	var n := int(raid_best.get(kind, 0))
	_raid_roll_day()
	if n <= 0 or _raid_left(kind) <= 0 or raid_on != "" or dungeon_on:
		return
	raid_left[kind] = maxi(0, _raid_left(kind) - 1)
	var amount := _raid_gain(kind, n)
	match kind:
		"blood": gold += amount
		"pact": sigil += amount
		"hunt": feed += amount
		"forge": whet += amount
	_quest_bump("raid")   # 손으로 깬 것과 같은 값이므로 임무도 같이 센다
	_show_reward("%s 소탕" % str(RaidDefs.RAIDS[kind]["name"]),
		[{"icon": str(RaidDefs.RAIDS[kind]["icon"]),
		"label": "+%s" % _n(amount),
		"sub": "%d단계" % n}])
	_refresh_currency_visibility()
	_refresh_hud()
	_refresh_dungeon()
	_raid_detail_open(kind)   # 남은 표가 줄었으니 판을 다시 그린다
	_save_game()


func _raid_detail_open(kind: String) -> void:
	if _raid_detail == null:
		return
	_raid_detail_kind = kind
	_raid_detail.visible = true
	# 주간 보스도 **같은 판**을 쓴다(사장님 2026-08-14) — 들어가기 전에 무엇을
	# 상대하는지 보는 자리라는 뜻이 같다. 다른 건 재는 값뿐이다: 단계는 주간
	# 티어, 보상은 이정표가 따로 있으니 이 판은 **누적 피해**를 보여 준다.
	# 미궁도 같은 판이다 — 다른 건 재는 값뿐이다: 표가 없고(무제한) 다음 층과
	# 그 층의 첫 돌파 혈정이 이 판의 값이다.
	if kind == "maze":
		var open := DungeonDefs.open_floors(best_stage)
		var next := clampi(dungeon_best + 1, 1, maxi(1, open))
		_rd_name.text = "핏빛 미궁"
		_rd_stage.text = "%d층 도전" % next
		_rd_goal.text = DungeonDefs.label(next)
		_rd_icon.texture = Assets.tex("res://assets/ui/res_crystal.png")
		# 이미 오른 층을 다시 돌면 혈정이 안 나온다 — 그 사실을 여기서 말해 준다.
		_rd_reward.text = "혈정 +%s" % _n(DungeonDefs.first_clear_reward(next)) \
			if next > dungeon_best else "기록 갱신 없음"
		_rd_left.text = "최고 %d층 · 개방 %d층\n표 없음" % [dungeon_best, open]
		var can := open > 0 and raid_on == "" and not dungeon_on
		_rd_btn_lbl.text = "도전" if can \
			else "%d구간 필요" % DungeonDefs.OPEN_STAGE
		_rd_btn.disabled = not can
		_gate_btn_dim(_rd_btn_tex, _rd_btn_lbl, _rd_btn.disabled)
		# 미궁은 소탕이 없다 — 소탕 시급(혈맥)이 이미 그 몫을 딴 데서 치른다.
		_rd_place_buttons(false)
		return
	if kind == "boss":
		_boss_roll()
		var eb := EventDefs.boss_of(_boss_week_index())
		_rd_name.text = str(eb["name"])
		_rd_stage.text = "%d단계" % boss_tier
		_rd_goal.text = "40초 동안 최대한 때린다"
		_rd_icon.texture = Assets.tex(EventDefs.art_path(eb))
		_rd_reward.text = "누적 피해 %s" % _n(boss_dmg)
		_rd_left.text = "오늘 %d / %d판\n이정표 넷이면 다음 단계" \
			% [boss_tries, EventDefs.TRIES_PER_DAY]
		_rd_btn_lbl.text = "도전" if boss_tries > 0 else "내일"
		_rd_btn.disabled = boss_tries <= 0 or dungeon_on or raid_on != ""
		_gate_btn_dim(_rd_btn_tex, _rd_btn_lbl, _rd_btn.disabled)
		# 보스는 소탕이 없다 — 성과가 누적 피해라 "대신 돌아 준다"가 성립 안 한다.
		_rd_place_buttons(false)
		return
	var info: Dictionary = RaidDefs.RAIDS[kind]
	var n := int(raid_best.get(kind, 0)) + 1
	_rd_name.text = str(info["name"])
	_rd_stage.text = "도전 %d단계" % n
	_rd_goal.text = RaidDefs.goal_line(kind)
	_rd_icon.texture = Assets.tex(str(info["icon"]))
	_rd_reward.text = "%s  +%s" % [str(info["currency"]),
		_n(_raid_gain(kind, n))]
	var left := _raid_left(kind)
	var per_day := RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(iap_subs)
	_rd_left.text = "오늘 %d / %d판" % [left, per_day]
	var locked := best_stage < RaidDefs.open_stage(kind)
	_rd_btn_lbl.text = "%d구간 필요" % RaidDefs.open_stage(kind) if locked \
		else ("도전" if left > 0 else "내일")
	_rd_btn.disabled = locked or left <= 0 or dungeon_on or raid_on != ""
	_gate_btn_dim(_rd_btn_tex, _rd_btn_lbl, _rd_btn.disabled)
	# 소탕은 **깬 적이 있어야** 열린다 — 기록이 없으면 소탕할 것도 없다.
	_rd_place_buttons(true)
	var best := int(raid_best.get(kind, 0))
	_rd_sweep_lbl.text = "소탕" if best > 0 else "미개척"
	_rd_sweep.disabled = best <= 0 or _rd_btn.disabled
	_gate_btn_dim(_rd_sweep_tex, _rd_sweep_lbl, _rd_sweep.disabled)
	_rd_chain.disabled = _rd_btn.disabled
	_gate_btn_dim(_rd_chain_tex, _rd_chain_lbl, _rd_chain.disabled)


# 이정표 게이지는 임무보다 짧다 — 옆 수치가 "43.3K / 144.2K" 라 자리가 더 필요하다.
# 단계가 오르면 요구가 x1.6 씩 커져 자릿수가 계속 는다(실측: 4차에서 잘렸다).
const BOSS_BAR_W := 118.0


func _refresh_boss() -> void:
	if _boss_rows.is_empty():
		return
	_boss_roll()
	var eb := EventDefs.boss_of(_boss_week_index())
	_boss_art.texture = Assets.tex(EventDefs.art_path(eb))
	_boss_name.text = "%s  ·  %d단계" % [str(eb["name"]), boss_tier]
	_boss_dmg_lbl.text = "누적 피해 %s" % _n(boss_dmg)
	# 폭 316px 이라 긴 문장은 잘린다(실측: "넷을 다 받으면 다"). 짧게 쓴다.
	_boss_sub.text = "도전 %d / %d  ·  넷을 받으면 다음 단계" 		% [boss_tries, EventDefs.TRIES_PER_DAY]
	if raid_on == "boss":
		_boss_btn_lbl.text = "돌아가기"
		_boss_btn.disabled = false
	else:
		_boss_btn_lbl.text = "도전" if boss_tries > 0 else "내일"
		_boss_btn.disabled = boss_tries <= 0 or dungeon_on or raid_on != ""
	_gate_btn_dim(_boss_btn_tex, _boss_btn_lbl, _boss_btn.disabled)
	for i in EventDefs.MILESTONES.size():
		var need := _boss_need(i)
		var row: Dictionary = _boss_rows[i]
		row["prog"].text = "%s / %s" % [_n(minf(boss_dmg, need)), _n(need)]
		row["fill"].size.x = BOSS_BAR_W * clampf(boss_dmg / maxf(1.0, need), 0.0, 1.0)
		var b: Button = row["btn"]
		if boss_got.has(i):
			row["lbl"].text = "완료"
			b.disabled = true
		else:
			row["lbl"].text = "+%d" % EventDefs.milestone_amount(i, boss_tier)
			b.disabled = boss_dmg < need
		# 받은 줄은 아이콘도 끈다 — "완료"에 값 아이콘이 붙으면 아직 줄 게 남은 듯 읽힌다.
		row["icon"].visible = not boss_got.has(i)
		_gate_btn_dim(row["tex"], row["lbl"], b.disabled)


# 보상 지급 **한 곳**. 임무·주간·이벤트·도감이 저마다 match 를 갖고 있었는데,
# 종류가 늘 때마다 한 곳을 빠뜨려 조용히 안 들어온다(그 사고를 막는 자리다).
# 칭호를 몇 개 모았는가에 걸린 상. 여러 개가 한꺼번에 열릴 수 있어 전부 돈다.
func _claim_title_milestones() -> void:
	var entries: Array = []
	for i in TitleDefs.claimable_milestones(titles_got.size(), title_ms_got):
		var m: Dictionary = TitleDefs.MILESTONES[i]
		title_ms_got[i] = true
		_grant_reward(str(m["reward"]), float(m["amount"]))
		entries.append({"icon": "res://assets/ui/%s.png" % _reward_icon(str(m["reward"])),
			"label": "+%d" % int(m["amount"]),
			"sub": "칭호 %d종" % int(m["n"])})
	if not entries.is_empty():
		_show_reward("칭호 수집 보상", entries)
		_save_game()


# 승급(미궁 층이 여는 훈련 단계)에 걸린 상. 상한만 열고 손에 쥐는 게 없으면
# 승급이 이정표로 안 읽힌다.
func _claim_promo_reward() -> void:
	var idx := StatDefs.promo_index(dungeon_best)
	var entries: Array = []
	for i in range(1, idx + 1):
		if promo_got.has(i) or i >= StatDefs.PROMO_REWARDS.size():
			continue
		var m: Dictionary = StatDefs.PROMO_REWARDS[i]
		if m.is_empty():
			continue
		promo_got[i] = true
		_grant_reward(str(m["reward"]), float(m["amount"]))
		entries.append({"icon": "res://assets/ui/%s.png" % _reward_icon(str(m["reward"])),
			"label": "+%d" % int(m["amount"]),
			"sub": "승급 %d단계" % (i + 1)})
	if not entries.is_empty():
		_show_reward("승급 보상", entries)
		_save_game()


func _grant_reward(kind: String, amount: float) -> void:
	match kind:
		"gem": gem += amount
		"crystal": crystal += amount
		"sigil": sigil += amount
		"gold": gold += amount
		"feed": feed += amount
		"whet": whet += amount
		"oath_card": oath_cards += int(amount)     # 보관 상한을 넘겨 받는다
		"oath_gold": oath_gold += int(amount)
		_:
			# 소환권은 "ticket_<종류>" 로 온다 — 표에 종류가 늘어도 여기는 그대로다.
			var tk := TicketDefs.kind_of(kind)
			if tk != "":
				tickets[tk] = int(tickets.get(tk, 0)) + int(amount)


static func _reward_name(kind: String) -> String:
	match kind:
		"crystal": return "혈정"
		"sigil": return "인장"
		"gold": return "혈액"
		"feed": return "먹이"
		"whet": return "연마석"
		"oath_card": return "계약 카드"
		"oath_gold": return "황금 계약서"
	var tk := TicketDefs.kind_of(kind)
	return TicketDefs.short_of(tk) if tk != "" else "보석"


static func _reward_icon(kind: String) -> String:
	match kind:
		"crystal": return "res_crystal"
		"sigil": return "res_sigil"
		"oath_card", "oath_gold": return "side_oath"
	return "res_gem"


func _build_raid_list(root: Control) -> void:
	var sub := _panel_label(root, Vector2(PAD, 64.0), Type.SIZE_SMALL,
		Color(0.72, 0.70, 0.76), CONTENT_W, 16.0)
	_raid_head = sub                     # 혈세가 붙으면 판 수가 바뀐다
	# 연속 도전 토글은 **입장 팝업의 버튼**으로 옮겼다(사장님 2026-08-18).
	# 던전 전용 세트(사장님: 탭마다 다르게) — 사슬 감긴 돌벽 카드 + 철창 입장 버튼.
	# 입장 버튼이 그림이라 글자·잠금 표시는 라벨과 modulate 가 맡는다.
	var kinds := ["blood", "forge", "pact", "hunt"]
	# **스크롤에 넣는다.** 4줄 x 154 = 616 인데 이 루트는 화면 214 에서 시작하고
	# 판 아래는 774 다 — 쓸 수 있는 높이가 468 뿐이라 네 번째(야수 우리)가 하단
	# 네비에 깔렸다(사장님 캡처 2회. 처음엔 루트 오프셋을 안 재고 682 로 잡아
	# 스크롤 자신이 화면 밖까지 뻗었고, 내용이 그 안에 다 들어가 안 굴렀다).
	var rsc := _codex_thin_bar(Ui.scroll(Vector2(0.0, 86.0),
		Vector2(PANEL_W, FULL_BOTTOM - 214.0 - 86.0)))
	root.add_child(rsc)
	var rpane := Control.new()
	rpane.custom_minimum_size = Vector2(PANEL_W - CODEX_BAR_W,
		float(kinds.size()) * 148.0)
	rsc.add_child(rpane)
	for i in kinds.size():
		var kind: String = kinds[i]
		# 피치 148 — 카드(140)에 틈 8. 판 높이 474 에서 4번째 줄이 30px 넘게
		# 엿보인다: 엿보임이 곧 "굴려라"라는 표지판이다.
		var y := float(i) * 148.0
		_shop_tex(rpane, "res://assets/ui/sets/gate_row.png",
			Vector2(PAD - 8.0, y), Vector2(CONTENT_W + 16.0, 140.0))
		# 엠블럼 홈(사슬 안 사각 창) 실측 자리에 재화 아이콘.
		rpane.add_child(Ui.icon(str(RaidDefs.RAIDS[kind]["icon"]),
			Vector2(PAD + 36.0, y + 36.0), 64.0))
		var nm := _panel_label(rpane, Vector2(PAD + 132.0, y + 22.0), Type.SIZE_MID,
			Color(0.95, 0.88, 0.80), CONTENT_W - 320.0, 20.0)
		nm.text = str(RaidDefs.RAIDS[kind]["name"])
		_shop_outline(nm, 6)
		_raid_info[kind] = _panel_label(rpane, Vector2(PAD + 132.0, y + 54.0),
			Type.SIZE_SMALL, Color(0.80, 0.78, 0.80), CONTENT_W - 296.0, 14.0)
		_shop_outline(_raid_info[kind], 4)
		_raid_reward[kind] = _panel_label(rpane, Vector2(PAD + 132.0, y + 78.0),
			Type.SIZE_SMALL, Color(0.92, 0.84, 0.72), CONTENT_W - 296.0, 14.0)
		_shop_outline(_raid_reward[kind], 4)
		var bx := Vector2(PAD + CONTENT_W - 164.0, y + 42.0)
		_raid_btn_tex[kind] = _shop_tex(rpane,
			"res://assets/ui/sets/gate_button.png", bx, Vector2(156.0, 50.0))
		var bl := _panel_label(rpane, Vector2(bx.x, bx.y + 15.0), Type.SIZE_MID,
			Color(1.0, 0.95, 0.90), 156.0, 22.0)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(bl, 8)
		_raid_btn_lbl[kind] = bl
		var eb := _shop_ghost(rpane, Vector2(156.0, 50.0), _raid_btn_tex[kind])
		eb.position = bx
		# **바로 안 들어간다** — 레퍼런스처럼 상세 판을 한 번 거친다(사장님
		# 2026-08-14). 거기서 목표·보상·단계를 보고 도전을 누른다.
		eb.pressed.connect(func() -> void:
			if raid_on == kind:
				_raid_exit("이탈 — 빈손")
				_refresh_dungeon()
			else:
				_raid_detail_open(kind))
		_raid_btn[kind] = eb
	_refresh_dungeon()


func _refresh_dungeon() -> void:
	if _dungeon_info == null:
		return
	_refresh_trial()
	for i in _dungeon_mastery.size():
		var r: Dictionary = MasteryDefs.RANKS[i]
		var got := best_stage > int(r["stage"])
		# 줄이 길어 화면을 꽉 채웠다(사장님: "군림 폰트 좀 더 작게"). 폰트는 이미
		# 최소(SIZE_SMALL)라 **글을 줄인다** — 이름과 효과만, 조건은 괄호 없이.
		_dungeon_mastery[i].text = "%s · %s" % [str(r["name"]), str(r["desc"])] 			if got else "%s · %s  (%d구간)" % [str(r["name"]), str(r["desc"]),
			int(r["stage"])]
		_dungeon_mastery[i].add_theme_color_override("font_color",
			Color(0.92, 0.82, 0.62) if got else Color(0.55, 0.53, 0.6))
		if i < _dungeon_badges.size():
			_dungeon_badges[i].modulate = Color(1, 1, 1) if got \
				else Color(0.4, 0.38, 0.45)
	var open := DungeonDefs.open_floors(best_stage)
	_dungeon_chips[0].text = "최고 %d층" % dungeon_best
	_dungeon_chips[1].text = "개방 %d층" % open
	_dungeon_chips[2].text = "혈정 %s" % _n(crystal)
	# 재화 던전 카드 — 도전 단계·보상 미리보기·오늘 표.
	_raid_roll_day()
	# _build_dungeon 이 이 함수를 먼저 부르므로(재화 던전 줄은 그 뒤에 선다)
	# 아직 없을 수 있다 — 그때는 _build_raid_list 끝의 호출이 채운다.
	if _raid_head:
		_raid_head.text = "하루 %d판 — 표는 격파할 때만 깎인다" \
			% (RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(iap_subs))
	for kind in _raid_btn:
		var n := int(raid_best.get(kind, 0)) + 1
		# **목표를 적는다** — 던전마다 이기는 방법이 다르다(사장님 2026-08-14).
		_raid_info[kind].text = "%d단계 · %s" % [n, RaidDefs.goal_line(kind)]
		# "격파 시 …"까지 적으면 세트 카드의 글자 폭을 넘어 잘린다(실측 두 번) —
		# "격파"는 윗줄 안내("표는 격파할 때만 깎인다")가 이미 말한다.
		_raid_reward[kind].text = "%s +%s · 오늘 %d/%d" \
			% [str(RaidDefs.RAIDS[kind]["currency"]), _n(_raid_gain(kind, n)),
			_raid_left(kind),
			RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(iap_subs)]
		var eb: Button = _raid_btn[kind]
		var lbl: Label = _raid_btn_lbl[kind]
		if raid_on == kind:
			lbl.text = "돌아가기"
			eb.disabled = false
		elif best_stage < RaidDefs.open_stage(kind):
			lbl.text = "%d구간" % RaidDefs.open_stage(kind)
			eb.disabled = true
		elif _raid_left(kind) <= 0:
			lbl.text = "내일"
			eb.disabled = true
		else:
			lbl.text = "입장"
			eb.disabled = dungeon_on or raid_on != ""
		_gate_btn_dim(_raid_btn_tex[kind], lbl, eb.disabled)
	_refresh_boss()
	if open <= 0:
		_dungeon_info.text = "%d구간을 넘으면 열린다" % DungeonDefs.OPEN_STAGE
		_dungeon_sub.text = "층을 오른 기록이 다음 성장(혈맥)의 열쇠가 된다"
		_dungeon_btn_lbl.text = "잠김"
		_dungeon_btn.disabled = true
		_gate_btn_dim(_dungeon_btn_tex, _dungeon_btn_lbl, true)
		return
	_dungeon_btn.disabled = false
	_gate_btn_dim(_dungeon_btn_tex, _dungeon_btn_lbl, false)
	if dungeon_on:
		_dungeon_info.text = "%s 도전 중" % DungeonDefs.label(dungeon_floor)
		_dungeon_sub.text = "쓰러지거나 시간을 넘기면 밖으로 나온다 — 기록은 남는다"
		_dungeon_btn_lbl.text = "돌아가기"
		return
	var next := clampi(dungeon_best + 1, 1, open)
	_dungeon_info.text = "다음 %d층" % next
	_dungeon_sub.text = "첫 돌파 혈정 %d  ·  소탕 시간당 %.1f" \
		% [int(DungeonDefs.first_clear_reward(next)), _sweep_per_hour()]
	_dungeon_btn_lbl.text = "도전"


# ── 일일 임무 (QuestDefs, REFERENCE_TEARDOWN 4장-1) ───────────────────────
# 날짜 문자열 비교는 무료 뽑기(free_pull_date)와 같은 문법이다. 자정 롤오버는
# 칭호와 같은 1초 틱이 잡는다.
var quest_date := ""
var quest_prog := {}
var quest_got := {}
var quest_week := ""        # 이번 주 열쇠(월요일 날짜)
var quest_wprog := {}       # 주간 카운터 (kind -> 수)
var quest_wgot := {}        # 주간 수령 (id -> true)
var _quest_rows: Array[Dictionary] = []
var _quest_wrows: Array[Dictionary] = []
var _quest_day_root: Control
var _quest_week_root: Control
# 업적 — 트랙별로 **몇 계단까지 받았나**만 센다(AchieveDefs). 계단 목록을
# 저장하면 표를 고칠 때 옛 저장이 어긋난다 — 개수 하나면 표가 늘어도 안전하다.
var achieve_got := {}
var _achieve_root: Control
var _achieve_rows: Array[Dictionary] = []
var _quest_mode_btns := {}
var _quest_tab_art := {}
var _quest_claim_all: Button
var _quest_claim_art: Array[Control] = []

# ── 출석 (AttendDefs) ──────────────────────────────────────────────────────
# **연속을 안 센다** — 누적이다. 하루 놓쳤다고 처음으로 되돌리면 그 순간이
# 이탈 지점이 된다(AttendDefs 주석). 그래서 상태가 둘뿐이다:
# 몇 칸까지 받았나, 오늘 받았나.
var _attend_btn_art: Control   # 받기 알약 — 오늘 받을 게 있으면 금빛
var attend_got := 0          # 지금까지 받은 칸 수(30 을 넘으면 다음 바퀴)
var attend_date := ""        # 마지막으로 받은 날
var _attend_root: Control
var _attend_cells: Array[Dictionary] = []
var _attend_btn: Button
var _attend_lbl: Label

# ── 은총 (BoonDefs) — 주마다 바뀌는 특전 ───────────────────────────────────
var _boon_root: Control
var _boon_labels := {}


# 이번 주 은총이 그 종류면 값을, 아니면 0. 배율 훅마다 한 줄로 붙는다.
func _boon(kind: String) -> float:
	return BoonDefs.bonus(_quest_week_key(), kind)


# 재화 던전 보상 — **표시와 지급이 같은 함수를 지난다.** 은총(풍요의 광맥)이
# 붙는 자리라 한쪽만 곱하면 화면에 적힌 수와 실제 들어오는 양이 갈린다.
# 부르는 곳이 넷이다: 소탕 지급 · 격파 지급 · 상세판 표시 · 목록 표시.
func _raid_gain(kind: String, n: int) -> float:
	return RaidDefs.reward(kind, n, best_stage) * (1.0 + _boon("raid"))


# 이번 주의 열쇠 — 가장 가까운 지난 월요일. 날짜만 쓰므로 시간대 경계의 몇 시간
# 오차는 무시한다 (ponytail: 주 경계가 몇 시간 밀려도 게임은 안 깨진다).
func _quest_week_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	var back := (int(d["weekday"]) + 6) % 7   # Godot 은 일요일이 0 — 월요일 기준으로
	return Time.get_date_string_from_unix_time(
		int(Time.get_unix_time_from_system()) - back * 86400)


func _quest_roll_day() -> void:
	var wk := _quest_week_key()
	if quest_week != wk:
		quest_week = wk
		quest_wprog = {}
		quest_wgot = {}
	var today := Time.get_date_string_from_system()
	if quest_date == today:
		return
	quest_date = today
	quest_prog = QuestDefs.fresh_prog()
	quest_got = {}
	# 은총 "소환의 별" — 자정을 넘기면 소환권이 들어온다. **세 종류에 돌려가며**
	# 준다: 한 종류로 몰면 나머지 천장이 안 찬다(TicketDefs 와 같은 이유).
	var star := int(_boon("ticket"))
	if star > 0:
		var kinds := ["ticket_weapon", "ticket_armor", "ticket_skill"]
		for i in star:
			_grant_reward(str(kinds[i % kinds.size()]), 1.0)


# 훅 하나가 일일·주간 두 카운터를 같이 올린다 — 훅을 두 벌 심으면 하나를
# 빠뜨린 자리가 조용히 주간만 안 오른다.
func _quest_bump(id: String, n := 1) -> void:
	_quest_roll_day()
	quest_prog[id] = int(quest_prog.get(id, 0)) + n
	quest_wprog[id] = int(quest_wprog.get(id, 0)) + n


func _quest_count(id: String) -> int:
	# 마무리 임무는 따로 안 센다 — "받은 기본 임무 수"가 곧 진행도다.
	if id == "all":
		var got := 0
		for q in QuestDefs.QUESTS:
			if str(q["id"]) != "all" and quest_got.has(str(q["id"])):
				got += 1
		return got
	return int(quest_prog.get(id, 0))


func _quest_claimable(id: String) -> bool:
	return not quest_got.has(id) \
		and _quest_count(id) >= int(QuestDefs.of(id)["need"])


func _claim_quest(id: String) -> void:
	if not _quest_claimable(id):
		return
	quest_got[id] = true
	# 받은 일일 임무 하나 = 주간 연동 임무 한 칸.
	quest_wprog["daily"] = int(quest_wprog.get("daily", 0)) + 1
	var q := QuestDefs.of(id)
	_grant_reward(str(q["reward"]), float(q["amount"]))
	# 성장 패스는 **이미 하는 행동에 얹는다** — 임무를 받는 순간 트랙이 오른다.
	_pass_add(PassDefs.POINT_QUEST)
	_refresh_currency_visibility()
	_save_game()
	_refresh_quests()


# ── 출석 (AttendDefs) ──────────────────────────────────────────────────────
# 오늘 받았나만 본다. **어제 받았는지는 안 본다** — 연속이 아니라 누적이다.
# 업적 — 조건을 넘겼는데 아직 안 받은 계단이 있나. _claim_achieve 가 while 로
# 계단을 훑으므로 여기도 "한 계단이라도 넘겼나"만 본다.
func _achieve_claimable() -> bool:
	for t in AchieveDefs.TRACKS:
		var kind := str(t["kind"])
		var step: Dictionary = AchieveDefs.at(kind, int(achieve_got.get(kind, 0)))
		if not step.is_empty() and _goal_value(kind) >= int(step["need"]):
			return true
	return false


# 패스 — 열린 단계 중 안 받은 줄이 있나. 유료 줄은 구독 중일 때만 센다.
func _pass_claimable() -> bool:
	var step := PassDefs.step_of(pass_points)
	var paid_on := _pass_active()
	for i in range(1, step + 1):
		if not pass_free_got.has(i):
			return true
		if paid_on and not pass_paid_got.has(i):
			return true
	return false


func _attend_claimable() -> bool:
	return attend_date != Time.get_date_string_from_system()


func _claim_attend() -> void:
	if not _attend_claimable():
		return
	var a := AttendDefs.of(AttendDefs.next_day(attend_got))
	attend_date = Time.get_date_string_from_system()
	attend_got += 1
	_grant_reward(str(a["reward"]), float(a["amount"]))
	_pass_add(PassDefs.POINT_QUEST)
	_show_reward("%d일차 출석" % int(a["day"]),
		[{"icon": _reward_icon(str(a["reward"])),
		"label": "%s +%d" % [_reward_name(str(a["reward"])), int(a["amount"])]}])
	_refresh_currency_visibility()
	_save_game()
	_refresh_attend()


func _wquest_claimable(id: String) -> bool:
	var q := QuestDefs.wof(id)
	return not quest_wgot.has(id) \
		and int(quest_wprog.get(str(q["kind"]), 0)) >= int(q["need"])


func _claim_wquest(id: String) -> void:
	if not _wquest_claimable(id):
		return
	quest_wgot[id] = true
	var q := QuestDefs.wof(id)
	_grant_reward(str(q["reward"]), float(q["amount"]))
	_pass_add(PassDefs.POINT_WEEKLY)
	_refresh_currency_visibility()
	_save_game()
	_refresh_quests()


# 임무판 팝업 배치 (레퍼런스: 화면 가운데 모달 + 줄마다 진행바).
const QUEST_PANEL := Rect2(24.0, 150.0, 528.0, 560.0)
# 임무판(양피지) · 도감(가죽책) 세트 이름과 **그 위에 얹는 잉크 색**.
#
# 다른 판은 어두운 바탕이라 글자가 밝았다. 양피지는 크림색이라 그 색을 그대로
# 쓰면 글자가 사라진다 — 판을 갈면 글자 색도 같이 갈아야 한다.
const DUTY := "duty"
const TOME := "tome"
const NEST := "nest"      # 펫 탭 전용(나무판·밧줄·뼈)
const OATH := "oath"      # 핏빛 계약 전용(검은 철판·핏자국 테두리)
# 계약 판은 담을 게 많다(카드·알약·등급띠·천장 둘·서약·버튼 넷·광고·수집).
# 임무판 크기(560)로는 줄이 서로 올라탔다(사장님 실측) — 전용 사각형을 둔다.
const OATH_PANEL := Rect2(20.0, 108.0, 536.0, 664.0)
const OATH_INK := Color(0.98, 0.94, 0.92)
const OATH_DIM := Color(0.80, 0.72, 0.72)
const OATH_RED := Color(0.98, 0.46, 0.44)
# **흰 글씨 + 검은 테두리**(사장님 2026-08-18). 짙은 갈색 잉크는 판과 대비가
# 맞는데도 안 읽혔다 — 11px 도트 폰트는 획이 얇아서 색 대비만으로는 부족하고,
# 검은 테두리가 글자를 배경에서 떼어 내야 보인다. 판이 밝든 어둡든 같은 규칙이다.
const DUTY_INK := Color(0.99, 0.97, 0.95)      # 본문 — 흰색
const DUTY_DIM := Color(0.84, 0.80, 0.76)      # 보조 — 조금 죽인 흰색
const DUTY_RED := Color(0.98, 0.42, 0.40)      # 강조 — 밝은 핏빛
# 아래 게시판·알약과 겹쳐서 열 전체를 위로 올렸다(사장님 2026-08-18).
const QUEST_BTN_AT := Vector2(508.0, 96.0)    # 오른쪽 가장자리, 상단바 아래
const TITLE_BTN_AT := Vector2(508.0, 154.0)   # 그 바로 아래 — 같은 세로 줄
const OATH_BTN_AT := Vector2(508.0, 212.0)    # 핏빛 계약 — 상시 아이콘(사장님)
# 280 이었다가 220 — 수치 라벨이 받기 버튼 밑으로 들어가 "1 / 1"이 "1 /"로
# 잘렸다(실측). 잘린 진행도는 거짓말이다.
# 막대 220 이면 그 뒤 진행 글자 칸이 54px 뿐이라 "300/300"(7글자, 56px)이
# "300/3" 으로 잘렸다(사장님 캡처). 막대를 30 줄여 글자에 84px 를 준다 —
# 막대는 비율만 보여 주면 되고, 정확한 수를 말하는 건 글자 쪽이다.
const QUEST_BAR_W := 190.0
# 줄이 서는 창 높이. 판 아래의 "자정에 새로 온다"(-92)에 **닿지 않는** 값이다:
# 560 - 96(머리) - 92(안내) = 372 는 딱 맞닿아서 마지막 줄이 그 글자에 걸쳤다.
# 16 을 비워 둔다(실측 캡처).
const QUEST_ROWS_H := 356.0
var _quest_view: Control
var _quest_dot: TextureRect
var _codex_dot: TextureRect
var _side_root: Control      # 오른쪽 바로가기 줄(임무·칭호) — 전면 판이 숨긴다
var _raid_place: Label       # 도전 헤더 이름표·대사 — 소탭 따라 바뀐다
var _raid_line: Label


func _build_quests() -> void:
	# 오른쪽 세로 바로가기 줄을 한 컨테이너로 묶는다 — 전면 판 탭(상점 등)에서
	# 통째로 숨겨야 한다(사장님: 완전 전체 화면).
	_side_root = Control.new()
	_side_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_side_root)
	# 여는 버튼 — 전투 화면 오른쪽 가장자리(레퍼런스의 세로 바로가기 줄 자리).
	var open_btn := Button.new()
	open_btn.flat = true
	open_btn.position = QUEST_BTN_AT
	open_btn.size = Vector2(56.0, 56.0)
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.pressed.connect(func() -> void:
		_quest_view.visible = not _quest_view.visible
		if _quest_view.visible:
			_boss_cut_clear()
			_refresh_quests())
	_side_root.add_child(open_btn)
	var q_icon := Ui.icon("res://assets/ui/tab_quest.png",
		QUEST_BTN_AT + Vector2(4.0, 4.0), 48.0)
	_side_root.add_child(q_icon)
	_nav_hover(open_btn, q_icon)
	_quest_dot = Ui.icon("res://assets/ui/dot_alert.png",
		QUEST_BTN_AT + Vector2(-4.0, -2.0), TAB_DOT)
	_quest_dot.visible = false
	_side_root.add_child(_quest_dot)
	# **둘째 버튼은 도감이다** (사장님 2026-08-18). 하단 탭에서 도감을 빼고
	# 그 자리를 펫에게 줬다 — 도감은 임무판과 같은 자리에 뜨는 팝업이 된다.
	# 칭호는 그 안의 소탭으로 들어갔다(별도 판을 안 만든다).
	var t_btn := Button.new()
	t_btn.flat = true
	t_btn.position = TITLE_BTN_AT
	t_btn.size = Vector2(56.0, 56.0)
	t_btn.focus_mode = Control.FOCUS_NONE
	t_btn.pressed.connect(func() -> void:
		_codex_view.visible = not _codex_view.visible
		if _codex_view.visible:
			_boss_cut_clear()
			_codex_set_mode(_codex_mode))
	_side_root.add_child(t_btn)
	# 임무 아이콘(48)과 같은 크기 — 짝짝이였다(사장님 2026-08-18).
	var c_icon := Ui.icon("res://assets/ui/tab_codex.png",
		TITLE_BTN_AT + Vector2(4.0, 4.0), 48.0)
	_side_root.add_child(c_icon)
	_nav_hover(t_btn, c_icon)
	_codex_dot = Ui.icon("res://assets/ui/dot_alert.png",
		TITLE_BTN_AT + Vector2(-4.0, -2.0), TAB_DOT)
	_codex_dot.visible = false
	_side_root.add_child(_codex_dot)
	# 셋째 버튼 — **핏빛 계약**(사장님: 언제든 돌리는 상시 아이콘). 카드가 차
	# 있으면 붉게 고동친다(_refresh_oath) — "지금 굴릴 수 있다"가 눈에 밟히게.
	var o_btn := Button.new()
	o_btn.flat = true
	o_btn.position = OATH_BTN_AT
	o_btn.size = Vector2(56.0, 56.0)
	o_btn.focus_mode = Control.FOCUS_NONE
	o_btn.pressed.connect(func() -> void:
		_oath_view.visible = not _oath_view.visible
		if _oath_view.visible:
			_boss_cut_clear()
			_refresh_oath())
	_side_root.add_child(o_btn)
	_oath_icon = Ui.icon("res://assets/ui/side_oath.png",
		OATH_BTN_AT + Vector2(4.0, 4.0), 48.0)
	_side_root.add_child(_oath_icon)
	_nav_hover(o_btn, _oath_icon)
	# 상점 진입점은 **일부러 안 만든다** (사장님 2026-08-12): 상점은 과금과 한
	# 묶음으로 **별도 탭**이 되고 지금 이 판은 그 탭 안의 한 소탭으로 들어간다.
	# 옆줄에 버튼을 세워 두면 곧 두 곳에서 같은 걸 파는 화면이 된다.
	# 판과 로직은 그대로 살려 둔다 — 탭이 생기면 그때 여기만 갈아 끼운다.
	# 지금 보려면 개발 플래그 `--shop`.
	# 판 — 모달 팝업. 뒤가 비치면 어느 숫자가 어느 창 것인지 헷갈린다(불투명 규칙).
	_quest_view = Control.new()
	_quest_view.visible = false
	# 크기를 준다 — Ui.pop_in 이 이 크기로 중심을 잡는다(0이면 왼쪽 위에서 커진다).
	_quest_view.size = Vector2(Grid.BG)
	_quest_view.z_index = 55
	_hud_root.add_child(_quest_view)
	# 주변 어둠막 (사장님: "보상 화면처럼") — 판 밖이 훤하면 뒤 창의 글자가
	# 팝업 줄과 섞여 읽힌다(실측: 능력치 창 숫자가 임무 줄 밑에 비쳤다).
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.size = Vector2(Grid.BG)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_view.add_child(dim)
	# **양피지 세트**(사장님 2026-08-18). 임무는 "할 일 목록"이라 두루마리의 결을
	# 쓴다 — 도감(가죽책)과 한 벌이고, 기존 넷(돌·보라·철)과는 겹치지 않는다.
	# 뒤에 어두운 판을 깔지 않는다: 양피지가 불투명이라 그대로 덮인다.
	_quest_view.add_child(Ui.set_body(DUTY, QUEST_PANEL.position, QUEST_PANEL.size))
	var x := QUEST_PANEL.position.x + 22.0
	var w := QUEST_PANEL.size.x - 44.0
	var cbx := Vector2(x + w - 88.0, QUEST_PANEL.position.y + 12.0)
	var close_art := Ui.set_button(DUTY, cbx, Vector2(88.0, 34.0))
	_quest_view.add_child(close_art)
	var clbl := _panel_label(_quest_view, Vector2(cbx.x, cbx.y + 9.0),
		Type.SIZE_SMALL, DUTY_INK, 88.0, 20.0)
	clbl.text = "닫기"
	clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := Ui.button("", cbx, Vector2(88.0, 34.0), Type.SIZE_SMALL)
	close.modulate = Color(1, 1, 1, 0)      # 그림이 이미 버튼이다 — 판정만 얹는다
	close.pressed.connect(func() -> void: _quest_view.visible = false)
	_quest_view.add_child(close)
	_pet_hover(close, close_art)
	# [일일] [주간] [출석] [은총] — 하루에 들를 곳을 한 판에 모은다(사장님
	# 2026-08-18). 넷이 별개 판이면 "오늘 뭐 남았지"를 네 번 열어 봐야 한다.
	# **닫기와 같은 줄에 넷을 못 넣는다** — 폭 484 에서 닫기 88 을 빼면 버튼당
	# 96px 이라 글자가 잘린다. 소탭은 아래 줄로 내리고 넷이 폭을 고르게 쓴다.
	# 업적이 다섯 번째다(2026-08-20). 폭 440 을 다섯으로 나누면 칸당 83px 이라
	# 두 글자 라벨(11px)은 그대로 들어간다 — 여기가 늘어날 수 있는 마지막 칸이다.
	var tabs := [["day", "일일"], ["week", "주간"], ["achieve", "업적"],
		["attend", "출석"], ["boon", "은총"]]
	var tw := (w - 24.0) / 5.0
	for i in tabs.size():
		var mode := str(tabs[i][0])
		var tp := Vector2(x + float(i) * (tw + 6.0), QUEST_PANEL.position.y + 54.0)
		# 켜짐·꺼짐 그림을 겹쳐 두고 _quest_set_mode 가 보이는 쪽을 고른다 —
		# 누를 때마다 텍스처를 갈아 끼우면 NinePatch 여백을 매번 다시 잰다.
		var on := Ui.set_tab(DUTY, true, tp, Vector2(tw, 36.0))
		var off := Ui.set_tab(DUTY, false, tp, Vector2(tw, 36.0))
		_quest_view.add_child(off)
		_quest_view.add_child(on)
		var lbl := _panel_label(_quest_view, Vector2(tp.x, tp.y + 10.0),
			Type.SIZE_SMALL, DUTY_INK, tw, 20.0)
		lbl.text = str(tabs[i][1])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var mb := Ui.button("", tp, Vector2(tw, 36.0), Type.SIZE_SMALL)
		mb.modulate = Color(1, 1, 1, 0)
		mb.toggle_mode = true
		mb.pressed.connect(func() -> void: _quest_set_mode(mode))
		_quest_view.add_child(mb)
		_pet_hover(mb, off)
		_quest_mode_btns[mode] = mb
		_quest_tab_art[mode] = {"on": on, "off": off, "lbl": lbl}
	_quest_day_root = Control.new()
	_quest_day_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_view.add_child(_quest_day_root)
	_quest_week_root = Control.new()
	_quest_week_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_week_root.visible = false
	_quest_view.add_child(_quest_week_root)
	_quest_rows = _quest_build_rows(_quest_day_root, QuestDefs.QUESTS, false)
	_quest_wrows = _quest_build_rows(_quest_week_root, QuestDefs.WEEKLY, true)
	_achieve_root = Control.new()
	_achieve_root.visible = false
	_quest_view.add_child(_achieve_root)
	_achieve_rows = _achieve_build_rows(_achieve_root)
	_attend_root = Control.new()
	_attend_root.visible = false
	_quest_view.add_child(_attend_root)
	_attend_build(_attend_root)
	_boon_root = Control.new()
	_boon_root.visible = false
	_boon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_view.add_child(_boon_root)
	_boon_build(_boon_root)
	# 판 하단의 갱신 주기 멘트("자정에 새로 온다" 들)는 사장님 지시로 전부
	# 뺐다(2026-08-24) — 자리만 차지하는 잔소리였다.
	var cap := Vector2(x + w * 0.5 - 100.0,
		QUEST_PANEL.position.y + QUEST_PANEL.size.y - 56.0)
	var cap_art := Ui.set_row(DUTY, cap, Vector2(200.0, 42.0))
	_quest_view.add_child(cap_art)
	var cap_lbl := _panel_label(_quest_view, Vector2(cap.x, cap.y + 12.0),
		Type.SIZE_MID, DUTY_INK, 200.0, 20.0)
	cap_lbl.text = "일괄 받기"
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_claim_all = Ui.button("", cap, Vector2(200.0, 42.0), Type.SIZE_MID)
	_quest_claim_all.modulate = Color(1, 1, 1, 0)
	_pet_hover(_quest_claim_all, cap_art)
	# **그림과 글자도 같이 숨긴다** — 버튼만 숨기면 양피지 줄과 "일괄 받기"가
	# 남아 출석의 "오늘 받기" 위에 겹친다(실측 캡처).
	_quest_claim_art = [cap_art, cap_lbl]
	_quest_claim_all.pressed.connect(func() -> void:
		for q in QuestDefs.QUESTS:
			_claim_quest(str(q["id"]))
		for q in QuestDefs.WEEKLY:
			_claim_wquest(str(q["id"]))
		for t in AchieveDefs.TRACKS:
			_claim_achieve(str(t["kind"])))
	_quest_view.add_child(_quest_claim_all)
	_quest_set_mode("day")


# ── 상점 (ShopDefs) — 보석으로 하루 배급을 앞당기는 곳 ──────────────────────
var shop_date := ""
var shop_used := {}          # id -> 오늘 산 횟수
var _shop_view: Control
var _wear_view: Control
var _wear_rows: Array[Dictionary] = []
var _pack_view: Control
var _sub_view: Control
var _shop_mode_btns := {}
var _pack_rows: Array[Dictionary] = []
var _shop_cards: Array[Dictionary] = []   # 교환 카드(vcard) 5장
# 정기 탭 카드 — 탭을 열 때마다 다시 그린다(_refresh_subs). 지을 때 한 번
# 그리고 끝이던 동안 첫 구매 2배 라벨과 시즌 남은 날이 얼어 있었다.
var _sub_cards := {}
var _sub_gem_cards: Array = []
var _shop_line: Label                      # 상인 대사 — 소탭마다 바뀐다
# 전면 재설계(사장님 2026-08-13: "상점은 제일 꽃이야") — 레퍼런스 9장의 문법:
# **카드 한 장에 배지·그림·구성·한도·가격이 다 들어간다.** 줄 나열이 아니라
# 카드 격자고, 위에는 상인이 서서 가게 분위기를 만든다. 자산은 전부 새로
# 뽑았다(assets/ui/shop/, tools/slice_shop_ui.py 가 시트를 조각낸다).
const SHOP_DIR := "res://assets/ui/shop/"
# 전면 판(사장님 2026-08-13: 반판 스크롤 208 로는 카드 한 장도 다 안 보였다).
# 헤더를 원본 비율 그대로 크게 두고, 카드 스크롤이 두 장 넘게 선다.
const SHOP_HEAD_H := 210.0
const SHOP_TAB_Y := 232.0
const SHOP_SCROLL_Y := 274.0
const SHOP_LIST_W := CONTENT_W - Ui.SCROLL_W - 6.0   # 스크롤 안 콘텐츠 폭 498
const SHOP_COL_W := 240.0     # 세로 카드 폭 — (498-14)/2 를 넘지 않게
const SHOP_VCARD_H := 214.0   # 세로 카드 높이(제목 38 + 액자 116 + 한도 + 가격 36)
const SHOP_WCARD_H := 227.0   # 와이드 카드 — 원본 565x260 을 폭 494 로 축소한 비율


# **상점은 이제 탭이다** (사장님 2026-08-13). 소탭 셋: 특가(1회성 팩) ·
# 정기(구독+보석 충전) · 교환(보석으로 하루 배급 앞당기기).
func _build_shop(root: Control) -> void:
	# 1) 상인 헤더 — 그림(576x224)을 클립 창으로 떠낸다(미궁 머리판과 같은 수법).
	var head := Control.new()
	head.position = Vector2(PAD, 12.0)
	head.size = Vector2(CONTENT_W, SHOP_HEAD_H)
	head.clip_contents = true
	root.add_child(head)
	var mer := TextureRect.new()
	mer.texture = Assets.tex(SHOP_DIR + "merchant.png")
	mer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mer.size = Vector2(CONTENT_W, CONTENT_W * 224.0 / 576.0)   # 528x205
	mer.position = Vector2(0.0, -6.0)      # 전면 판이라 거의 원본대로 다 보인다
	mer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(mer)
	# 장소명 — 레퍼런스 문법(왼쪽 위 큰 글자). 상인 대사보다 위에 선다.
	var place := _panel_label(head, Vector2(16.0, 10.0), Type.SIZE_MID,
		Color(0.97, 0.92, 0.86), 200.0, 24.0)
	place.text = "밤의 상점"
	_shop_outline(place, 8)
	# 말풍선 — 새 카드의 제목 띠를 늘려 쓴다. 대사는 소탭마다 바뀐다.
	# 폭 328: 제일 긴 대사("매일 들러 주시는…")가 300 에서 끝이 잘렸다(실측).
	_shop_tex(head, "card_title", Vector2(8.0, 42.0), Vector2(328.0, 40.0))
	_shop_line = _panel_label(head, Vector2(26.0, 52.0), Type.SIZE_SMALL,
		Color(0.95, 0.88, 0.80), 300.0, 18.0)
	_shop_outline(_shop_line, 4)
	# 2) 소탭 — 박쥐 알약. 켬/끔이 그림이라 TextureButton 이다.
	# 넷째로 **패스**가 붙었다 — 정기 소탭에서 사는 물건이지만 진행 트랙은
	# 따로 볼 자리가 있어야 한다(30단계를 카드 한 장에 못 적는다).
	var modes := [["pack", "특가"], ["sub", "정기"], ["pass", "패스"],
		["book", "계약서"], ["trade", "교환"], ["wear", "의상"]]
	var sw := (CONTENT_W - 8.0 * 5.0) / 6.0
	for i in modes.size():
		var mode: String = modes[i][0]
		var tb := TextureButton.new()
		tb.texture_normal = Assets.tex(SHOP_DIR + "tab_off.png")
		tb.texture_pressed = Assets.tex(SHOP_DIR + "tab_on.png")
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.toggle_mode = true
		tb.position = Vector2(PAD + float(i) * (sw + 8.0), SHOP_TAB_Y)
		tb.size = Vector2(sw, 36.0)
		Ui.hover_pop(tb)
		tb.pressed.connect(func() -> void: _shop_set_mode(mode))
		root.add_child(tb)
		# 박쥐 문양이 알약 정중앙이라 글자와 무조건 겹친다 — 11px 는 문양에
		# 묻혔다(실측). 16px + 두꺼운 외곽선으로 글자가 문양을 이기게 한다.
		var tl := _panel_label(root, Vector2(tb.position.x, SHOP_TAB_Y + 7.0),
			Type.SIZE_MID, Color(1.0, 0.97, 0.92), sw, 22.0)
		tl.text = str(modes[i][1])
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(tl, 8)
		_shop_mode_btns[mode] = tb
	# 3) 모드별 스크롤 — 카드가 커서(레퍼런스 문법) 진열은 전부 스크롤이다.
	_pack_view = _shop_scroll_view(root)
	_build_shop_packs(_pack_view)
	_sub_view = _shop_scroll_view(root)
	_build_shop_subs(_sub_view)
	_pass_view = _shop_scroll_view(root)
	_build_shop_pass(_pass_view)
	_book_view = _shop_scroll_view(root)
	_build_shop_book(_book_view)
	_shop_view = _shop_scroll_view(root)
	_build_shop_trade(_shop_view)
	_wear_view = _shop_scroll_view(root)
	_build_shop_wear(_wear_view)
	_shop_set_mode("pack")


func _shop_scroll_view(root: Control) -> Control:
	var sc := Ui.scroll(Vector2(PAD, SHOP_SCROLL_Y),
		Vector2(CONTENT_W, FULL_BOTTOM - SHOP_SCROLL_Y))
	root.add_child(sc)
	var inner := Control.new()
	inner.custom_minimum_size.x = SHOP_LIST_W
	sc.add_child(inner)
	return inner


# ── 카드 조립 조각들 ────────────────────────────────────────────────────────
# 그림 위에 얹는 글자는 전부 이걸 거친다 — 박쥐 문양·별 무늬 위에서 맨 글자가
# 뭉개졌다(사장님 실측 지적). 외곽선 문법은 수량 라벨과 같다.
func _shop_outline(l: Label, size := 5) -> void:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.04))


# 시트 조각 하나. 도트라 NEAREST, 전부 마우스 무시(버튼은 투명 버튼이 따로 덮는다).
# 이름만 주면 상점 세트, "res://" 로 시작하면 다른 세트(대장간·점성소·던전)다.
func _shop_tex(parent: Control, file: String, pos: Vector2,
		size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.tex(file if file.begins_with("res://") \
		else SHOP_DIR + file + ".png")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = pos
	t.size = size
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


# 카드 전체를 덮는 투명 버튼 — 가격 띠가 이미 버튼처럼 그려져 있어서
# 그림 위에 또 버튼 판을 얹으면 이중 액자가 된다.
#
# 투명하니 **자기가 커져 봤자 안 보인다** — 호버 반응은 짝지어진 그림(tex)이
# 대신 낸다(사장님 2026-08-14: 전 버튼에 호버). tex 를 안 넘기면 반응이 없다.
func _shop_ghost(parent: Control, size: Vector2, tex: Control = null) -> Button:
	var b := Button.new()
	b.size = size
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	parent.add_child(b)
	if tex:
		tex.pivot_offset = tex.size * 0.5
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				Ui._pop_to(tex, Ui.HOVER_SCALE))
		b.mouse_exited.connect(func() -> void: Ui._pop_to(tex, 1.0))
		b.button_down.connect(func() -> void: tex.scale = Vector2(0.95, 0.95))
		b.button_up.connect(func() -> void: Ui._pop_to(tex, Ui.HOVER_SCALE))
	return b


# 리본 머리 — "필수 구매" 같은 섹션 이름표.
func _shop_ribbon(parent: Control, y: float, text: String) -> void:
	_shop_tex(parent, "ribbon", Vector2(0.0, y), Vector2(SHOP_LIST_W, 53.0))
	var l := _panel_label(parent, Vector2(0.0, y + 17.0), Type.SIZE_MID,
		Color(0.96, 0.84, 0.55), SHOP_LIST_W, 20.0)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(l, 4)


# 별 배지 — "가치 N%". 카드 왼쪽 위 모서리에 겹친다(레퍼런스).
func _shop_badge(parent: Control, value: int) -> void:
	_shop_tex(parent, "badge_star", Vector2(-10.0, -12.0), Vector2(62.0, 62.0))
	var l := _panel_label(parent, Vector2(-10.0, 6.0), Type.SIZE_SMALL,
		Color(1.0, 1.0, 1.0), 62.0, 30.0)
	l.text = "%d%%\n가치" % value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(l, 8)      # 별 무늬가 복잡해서 순백 + 두꺼운 외곽선이어야 산다


# 보상 알약 하나 — 아이콘 + 수. 와이드 카드의 "구성" 표기.
func _shop_pill(parent: Control, pos: Vector2, icon: String, text: String) -> void:
	_shop_tex(parent, "pill", pos, Vector2(108.0, 34.0))
	var ic := Ui.icon(icon, pos + Vector2(10.0, 7.0), 20.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ic)
	var l := _panel_label(parent, pos + Vector2(34.0, 8.0), Type.SIZE_SMALL,
		Color(0.97, 0.93, 0.88), 70.0, 18.0)
	l.text = text


# 보상 종류의 아이콘 — 재화·소환권을 다 안다(알약과 팩 대표 그림이 쓴다).
func _shop_kind_icon(kind: String) -> String:
	var t := TicketDefs.kind_of(kind)
	if t != "":
		return TicketDefs.icon_of(t)
	match kind:
		"crystal": return "res://assets/ui/res_crystal.png"
		"sigil": return "res://assets/ui/res_sigil.png"
		"gold": return "res://assets/ui/res_blood.png"
		"whet": return "res://assets/items/gem.png"
		"oath_card", "oath_gold": return "res://assets/ui/side_oath.png"
	return "res://assets/ui/res_gem.png"


# 세로 카드 — 제목 띠 / 금테 액자(그림+수량) / 한도 줄 / 가격 띠.
# 교환과 보석 충전이 같은 틀이다. 반환 사전의 라벨들을 _refresh 가 채운다.
func _shop_vcard(parent: Control, pos: Vector2) -> Dictionary:
	var card := Control.new()
	card.position = pos
	card.size = Vector2(SHOP_COL_W, SHOP_VCARD_H)
	parent.add_child(card)
	_shop_tex(card, "card_title", Vector2(0.0, 0.0), Vector2(SHOP_COL_W, 38.0))
	var title := _panel_label(card, Vector2(8.0, 9.0), Type.SIZE_SMALL,
		Color(0.96, 0.88, 0.78), SHOP_COL_W - 16.0, 18.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_tex(card, "card_art", Vector2(66.0, 42.0), Vector2(108.0, 114.0))
	var icon := Ui.icon("res://assets/ui/res_gem.png", Vector2(92.0, 62.0), 56.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	# 수량 — 레퍼런스처럼 그림 위에 겹쳐 적는다(외곽선이 있어야 그림 위에서 읽힌다).
	var amount := _panel_label(card, Vector2(66.0, 128.0), Type.SIZE_SMALL,
		Color(1.0, 1.0, 1.0), 108.0, 18.0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_constant_override("outline_size", 6)
	amount.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	var left := _panel_label(card, Vector2(0.0, 158.0), Type.SIZE_SMALL,
		Color(0.72, 0.68, 0.72), SHOP_COL_W, 16.0)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_tex(card, "card_price", Vector2(0.0, SHOP_VCARD_H - 36.0),
		Vector2(SHOP_COL_W, 36.0))
	var price := _panel_label(card, Vector2(0.0, SHOP_VCARD_H - 27.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.55), SHOP_COL_W, 18.0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 상태 도장들 — 위에서 그려야 카드를 덮는다.
	var stamp := _shop_tex(card, "stamp_soldout", Vector2(48.0, 78.0),
		Vector2(144.0, 61.0))
	stamp.rotation_degrees = -8.0
	stamp.visible = false
	var lock := _shop_tex(card, "lock", Vector2(94.0, 62.0), Vector2(52.0, 77.0))
	lock.visible = false
	var btn := _shop_ghost(card, card.size, card)
	return {"root": card, "title": title, "icon": icon, "amount": amount,
		"left": left, "price": price, "stamp": stamp, "lock": lock, "btn": btn}


# 와이드 카드 — 패키지·구독용. 왼쪽 금테 액자 + 오른쪽 이름·구성 알약 +
# 아래 검은 가격 띠. 그림 왜곡을 피해 **원본 비율 그대로** 폭만 맞춘다.
func _shop_wcard(parent: Control, y: float, name: String, icon_path: String,
		value: int) -> Dictionary:
	var card := Control.new()
	card.position = Vector2(0.0, y)
	card.size = Vector2(SHOP_LIST_W, SHOP_WCARD_H)
	parent.add_child(card)
	_shop_tex(card, "wide_body", Vector2.ZERO, card.size)
	# 액자 창 실측(원본 x67..150 y55..145)을 축소 배율 0.874 로 옮긴 자리.
	var icon := Ui.icon(icon_path, Vector2(63.0, 54.0), 64.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	if value > 0:
		_shop_badge(card, value)
	# 이름·계정당은 166 — 150 이면 액자 모서리 장식에 첫 글자가 물린다(실측).
	var title := _panel_label(card, Vector2(166.0, 22.0), Type.SIZE_MID,
		Color(0.96, 0.88, 0.78), SHOP_LIST_W - 186.0, 22.0)
	title.text = name
	var sub := _panel_label(card, Vector2(166.0, 102.0), Type.SIZE_SMALL,
		Color(0.72, 0.68, 0.72), SHOP_LIST_W - 186.0, 34.0)
	var price := _panel_label(card, Vector2(0.0, 186.0), Type.SIZE_MID,
		Color(0.98, 0.86, 0.55), SHOP_LIST_W, 22.0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lock := _shop_tex(card, "lock", Vector2(219.0, 52.0), Vector2(56.0, 83.0))
	lock.visible = false
	var btn := _shop_ghost(card, card.size, card)
	return {"root": card, "title": title, "icon": icon, "sub": sub,
		"price": price, "lock": lock, "btn": btn}


func _refresh_outfit() -> void:
	for i in SkinDefs.SKINS.size():
		var sk2: Dictionary = SkinDefs.SKINS[i]
		var id2 := str(sk2["id"])
		var cell: Dictionary = _outfit_cells[i]
		var owned := skins_owned.has(id2) or id2 == "valentino_1"
		if skin == id2:
			cell["state"].text = "장착 중"
			cell["name"].add_theme_color_override("font_color",
				Color(1.0, 0.88, 0.55))
		else:
			cell["state"].text = "" if owned else "미보유"
			cell["name"].add_theme_color_override("font_color",
				Color(0.92, 0.88, 0.86))
		cell["root"].modulate = Color(1, 1, 1) if owned \
			else Color(0.55, 0.52, 0.56)


func _outfit_pick(id: String) -> void:
	if skin == id:
		return
	if not (skins_owned.has(id) or id == "valentino_1"):
		_outfit_note.text = "상점 의상실에서 살 수 있다"
		_outfit_note.modulate.a = 1.0
		var tw3 := create_tween()
		tw3.tween_property(_outfit_note, "modulate:a", 0.0, 1.6).set_delay(0.8)
		return
	skin = id
	_motion = ""
	_play("idle")
	_refresh_outfit()
	_save_game()


# ── 의상실 (사장님 2026-08-24) ──────────────────────────────────────────────
# 스킨은 보석으로 사고, 산 것 중 하나를 입는다. 카드 그림은 그 스킨의
# idle 첫 프레임 — 소스는 왼쪽 보기라 뒤집어 화면 규칙(오른쪽)에 맞춘다.
func _build_shop_wear(view: Control) -> void:
	var y := 0.0
	for sk in SkinDefs.SKINS:
		var id := str(sk["id"])
		var card := _shop_wcard(view, y, str(sk["name"]),
			"res://assets/anim/%s_idle/0.png" % id, 0)
		card["icon"].flip_h = true
		card["sub"].text = str(sk["desc"])
		card["btn"].pressed.connect(_wear_click.bind(id))
		_wear_rows.append(card)
		y += SHOP_WCARD_H + 10.0
	view.custom_minimum_size.y = y


func _refresh_wear() -> void:
	if _wear_rows.is_empty():
		return
	for i in SkinDefs.SKINS.size():
		var sk: Dictionary = SkinDefs.SKINS[i]
		var id := str(sk["id"])
		var card: Dictionary = _wear_rows[i]
		var owned := skins_owned.has(id) or id == "valentino_1"
		# 상점은 **구매 전용** — 갈아입기는 군주의 기록 > 외형 변경에서
		# (사장님 2026-08-24). 산 것은 "보유 중"으로 못 박는다.
		card["price"].text = "보유 중" if owned else "보석 %d" % int(sk["price"])
		card["btn"].disabled = owned
		card["root"].modulate = Color(1, 1, 1) if not owned \
			else Color(0.74, 0.70, 0.74)


func _wear_click(id: String) -> void:
	var sk := SkinDefs.of(id)
	if sk.is_empty() or skins_owned.has(id) or id == "valentino_1":
		return
	if gem < float(sk["price"]):
		return
	gem -= float(sk["price"])
	skins_owned[id] = true
	_show_reward("의상 구매", [{"icon": "res://assets/anim/%s_idle/0.png" % id,
		"label": str(sk["name"]), "sub": str(sk["desc"])}])
	_refresh_wear()
	_refresh_hud()
	_save_game()


# ── 소탭 셋의 진열 ──────────────────────────────────────────────────────────
# 특가: 리본 + 성장 패키지 카드. **구매 버튼은 잠가 둔다** — 결제 SDK 가 아직
# 없다(사장님 결정: 표와 화면까지). SDK 가 붙으면 ghost 버튼의 pressed 만 잇는다.
func _build_shop_packs(view: Control) -> void:
	# 달성 세일이 맨 위 — "네가 해낸 것"의 상장이라 날짜 로테이션(오늘의
	# 특가)보다 개인적이다. 열린 것만 진열하고 24시간이 지나면 사라진다.
	var ftop := 0.0
	for f in IapDefs.FLASH:
		var fid := str(f["id"])
		if _flash_left(fid) <= 0.0 or flash_bought.has(fid):
			continue
		if ftop == 0.0:
			_shop_ribbon(view, 0.0, "달성 세일 — 24시간")
			ftop = 63.0
		var fr: Dictionary = f["reward"]
		var ficon := ""
		var fpills: Array = []
		for k in fr:
			if ficon == "":
				ficon = _shop_kind_icon(str(k))
			if fpills.size() < 3:
				fpills.append([_shop_kind_icon(str(k)), _n(float(fr[k]))])
		# 배지 칸은 **가치%** 다 — _shop_badge 가 그 숫자 밑에 "가치" 를 적는다.
		# 할인율을 넣던 동안 정가 1/3 짜리 세일이 "67% 가치" 로 떠서,
		# 180~600% 를 단 옆 카드들 사이에서 제일 손해로 읽혔다. 할인율은
		# 밑줄이 이미 말한다("n시간 남음 · 정가 …").
		var fc := _shop_wcard(view, ftop, str(f["name"]),
			ficon, int(round(100.0 * float(f["orig"]) / float(f["price"]))))
		for j in fpills.size():
			_shop_pill(fc["root"], Vector2(150.0 + float(j) * 114.0, 60.0),
				str(fpills[j][0]), str(fpills[j][1]))
		var hrs := int(ceil(_flash_left(fid) / 3600.0))
		fc["sub"].text = "%s시간 남음 · 정가 %s" 			% [hrs, IapDefs.price_text(int(f["orig"]))]
		fc["price"].text = IapDefs.price_text(int(f["price"]))
		fc["btn"].disabled = not IapDefs.DEV_FREE
		fc["btn"].pressed.connect(_flash_buy.bind(fid))
		ftop += SHOP_WCARD_H + 10.0
	if ftop > 0.0:
		ftop += 4.0
	# 오늘의 특가가 맨 위다 — 아래 성장팩은 구간이 열어 주는 상시 진열이라
	# **기간제가 그 밑에 깔리면 기간제로 안 읽힌다**(사장님 2026-08-20).
	_shop_ribbon(view, ftop, "오늘의 특가 — 자정까지")
	var ltd := IapDefs.limited_today(Time.get_date_string_from_system())
	var top := ftop + 63.0
	if not ltd.is_empty():
		var lr: Dictionary = ltd["reward"]
		var licon := ""
		var lpills: Array = []
		for k in lr:
			if licon == "":
				licon = _shop_kind_icon(str(k))
			if lpills.size() < 3:
				lpills.append([_shop_kind_icon(str(k)), _n(float(lr[k]))])
		var lc := _shop_wcard(view, top, str(ltd["name"]), licon,
			int(ltd["value"]))
		for j in lpills.size():
			_shop_pill(lc["root"], Vector2(150.0 + float(j) * 114.0, 60.0),
				str(lpills[j][0]), str(lpills[j][1]))
		lc["sub"].text = str(ltd["desc"])
		lc["price"].text = IapDefs.price_text(int(ltd["price"]))
		lc["btn"].disabled = not IapDefs.DEV_FREE
		# **이 줄이 없었다**(2026-08-27). 카드·값·설명을 다 그리고 버튼도
		# 켜 두면서 pressed 를 아무 데도 안 이었다 — 3,300원짜리 다섯 장이
		# 눌러도 아무 일도 안 났다. 형제 카드는 전부 이어져 있다.
		lc["btn"].pressed.connect(_iap_buy.bind(str(ltd["id"])))
		top += SHOP_WCARD_H + 10.0
	_shop_ribbon(view, top + 4.0, "성장 패키지 — 계정당 1회")
	top += 67.0
	for i in IapDefs.PACKS.size():
		var it: Dictionary = IapDefs.PACKS[i]
		var y := top + float(i) * (SHOP_WCARD_H + 10.0)
		var reward: Dictionary = it["reward"]
		var main_icon := ""
		var pills: Array = []
		for k in reward:
			if float(reward[k]) <= 0.0:
				continue
			if main_icon == "":
				main_icon = _shop_kind_icon(str(k))
			if pills.size() < 3:
				pills.append([_shop_kind_icon(str(k)), _n(float(reward[k]))])
		var card := _shop_wcard(view, y, str(it["name"]), main_icon,
			int(it["value"]))
		for j in pills.size():
			_shop_pill(card["root"], Vector2(150.0 + float(j) * 114.0, 60.0),
				str(pills[j][0]), str(pills[j][1]))
		card["sub"].text = "계정당 1 / 1"
		# SDK 전 테스트 모드 — 눌리면 즉시 지급(IapDefs.DEV_FREE 주석).
		card["btn"].disabled = not IapDefs.DEV_FREE or iap_bought.has(str(it["id"]))
		card["btn"].pressed.connect(_iap_buy.bind(str(it["id"])))
		_pack_rows.append(card)
	view.custom_minimum_size.y = top \
		+ float(IapDefs.PACKS.size()) * (SHOP_WCARD_H + 10.0)


# 정기: 구독 카드 + 보석 충전(등급마다 그림이 다르다 — 레퍼런스 충전소 문법).
func _build_shop_subs(view: Control) -> void:
	_shop_ribbon(view, 0.0, "정기 구독 — 최고 효율")
	var y := 63.0
	for i in IapDefs.SUBS.size():
		var it: Dictionary = IapDefs.SUBS[i]
		# 그림은 **표가 들고 있다**(IapDefs 의 art). 여기 짝 배열로 두었더니
		# 구독을 하나 늘리자마자 인덱스가 넘쳐 상점이 통째로 안 그려졌다.
		var card := _shop_wcard(view, y, "%s  ·  %d일" % [str(it["name"]),
			int(it["days"])], SHOP_DIR + str(it.get("art", "badge_star")) + ".png",
			int(it["value"]))
		card["sub"].text = str(it["desc"])
		_sub_cards[str(it["id"])] = card
		if str(it["id"]) == "season_pass":
			# 시즌제 — "언제까지"가 안 보이면 지금 살 이유가 없다.
			card["sub"].text += "\n이번 시즌 %d일 남음" \
				% PassDefs.season_days_left(Time.get_date_string_from_system())
		card["sub"].position.y = 58.0          # 알약 대신 설명 두 줄이 그 자리다
		card["sub"].size.y = 40.0
		card["price"].text = IapDefs.price_text(int(it["price"]))
		card["btn"].disabled = not IapDefs.DEV_FREE
		card["btn"].pressed.connect(_iap_buy.bind(str(it["id"])))
		y += SHOP_WCARD_H + 10.0
	_shop_ribbon(view, y + 4.0, "보석 충전 — 첫 구매 2배")
	y += 67.0
	var gem_art := ["gem_cluster", "gem_pouch", "gem_barrel", "gem_chest"]
	for i in IapDefs.GEMS.size():
		var g: Dictionary = IapDefs.GEMS[i]
		var pos := Vector2(float(i % 2) * (SHOP_COL_W + 14.0),
			y + float(i / 2) * (SHOP_VCARD_H + 10.0))
		var card := _shop_vcard(view, pos)
		card["title"].text = "보석 %s" % _n(float(g["gem"]))
		card["icon"].texture = Assets.tex(SHOP_DIR + gem_art[i] + ".png")
		card["amount"].text = _n(float(g["gem"]))
		_sub_gem_cards.append([card, g])
		card["price"].text = IapDefs.price_text(int(g["price"]))
		card["btn"].disabled = not IapDefs.DEV_FREE
		card["btn"].pressed.connect(_iap_buy.bind(str(g["id"])))
	view.custom_minimum_size.y = y + 2.0 * (SHOP_VCARD_H + 10.0)
	_refresh_subs()


# 정기 탭은 **지을 때 한 번** 그려지고 끝이었다(2026-08-27). 그래서
# 첫 구매 2배 라벨이 이미 쓴 뒤에도 두 배 수량을 계속 광고했고 —
# 33,000원 카드가 "첫 구매 7,000" 이라 적고 3,500 만 줬다 — 시즌 남은
# 날도 앱 켠 순간 숫자로 얼어 있었다. 결제 SDK 가 붙는 날 그대로 나가면
# 표기 오류가 아니라 환불 사유다. 아래는 `_refresh_packs` 와 같은 일이다.
func _refresh_subs() -> void:
	for pair in _sub_gem_cards:
		var card: Dictionary = pair[0]
		var g: Dictionary = pair[1]
		# 첫 구매를 이미 썼으면 2배를 약속하지 않는다.
		card["left"].text = "첫 구매 %s" % _n(float(g["gem"])
			* IapDefs.FIRST_BUY_MULT) if not iap_first_buy else ""
	var today := Time.get_date_string_from_system()
	for id in _sub_cards:
		var card: Dictionary = _sub_cards[id]
		var it := IapDefs.sub_of(str(id))
		if it.is_empty():
			continue
		# 산 구독은 남은 날을 값 자리에 띄운다 — 안 그러면 산 사람과
		# 안 산 사람의 화면이 한 글자도 다르지 않다.
		if IapDefs.sub_active(iap_subs, str(id)):
			var end := Time.get_unix_time_from_datetime_string(
				str(iap_subs.get(id, "")))
			var now := Time.get_unix_time_from_datetime_string(today)
			card["price"].text = "%d일 남음" % maxi(0,
				int(round((end - now) / 86400.0)))
		else:
			card["price"].text = IapDefs.price_text(int(it["price"]))
		if str(id) == "season_pass":
			card["sub"].text = "%s\n이번 시즌 %d일 남음" % [str(it["desc"]),
				PassDefs.season_days_left(today)]


# 패스: 30단계 트랙. 한 줄이 한 단계고 **무료·유료 두 칸**이 나란히 선다 —
# 안 산 사람도 같은 트랙을 오르되 받는 것이 적다(PassDefs 의 설계 원칙).
const PASS_ROW_H := 56.0
var _book_view: Control
var _book_rows: Array[Dictionary] = []
var _book_head: Label
var _book_fill: ColorRect
var _book_all_btn: Button
var _pass_view: Control
var _pass_rows: Array[Dictionary] = []
var _pass_head: Label
var _pass_fill: ColorRect
var _pass_all_btn: Button


# 계약의 서 — 카드를 **쓴 횟수**로 차는 30칸. 성장 패스와 같은 트랙 문법이라
# 판을 통째로 복제한다(사장님 승인 설계 7-6). 유료 줄은 성장 패스 구독이 연다.
func _build_shop_book(view: Control) -> void:
	_shop_ribbon(view, 0.0, "계약의 서 — 굴린 만큼 차오른다")
	_book_head = _panel_label(view, Vector2(0.0, 62.0), Type.SIZE_MID,
		Color(0.98, 0.72, 0.66), SHOP_LIST_W, 24.0)
	_book_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_book_head, 6)
	var track := ColorRect.new()
	track.color = Color(0.10, 0.09, 0.12)
	track.position = Vector2(60.0, 94.0)
	track.size = Vector2(SHOP_LIST_W - 120.0, 10.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(track)
	_book_fill = ColorRect.new()
	_book_fill.color = Color(0.90, 0.36, 0.34)
	_book_fill.position = track.position
	_book_fill.size = Vector2(0.0, 10.0)
	_book_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_book_fill)
	_book_all_btn = Ui.button("일괄 수령", Vector2((SHOP_LIST_W - 160.0) * 0.5, 116.0),
		Vector2(160.0, 34.0), Type.SIZE_SMALL)
	_book_all_btn.pressed.connect(_claim_book_all)
	view.add_child(_book_all_btn)
	for i in range(1, OathDefs.BOOK_STEPS + 1):
		var y := 162.0 + float(i - 1) * PASS_ROW_H
		var sep := ColorRect.new()
		sep.color = Color(0.30, 0.27, 0.32)
		sep.position = Vector2(0.0, y + 52.0)
		sep.size = Vector2(SHOP_LIST_W, 1.0)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(sep)
		var lv := _panel_label(view, Vector2(0.0, y + 15.0), Type.SIZE_MID,
			Color(0.95, 0.90, 0.90), 52.0, 22.0)
		lv.text = "%d" % i
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(lv, 5)
		var row := {"step": i}
		var cw := (SHOP_LIST_W - 68.0) * 0.5 - 6.0
		for j in 2:
			var paid := j == 1
			var cx := 62.0 + float(j) * (cw + 12.0)
			var st := ColorRect.new()
			st.position = Vector2(cx - 6.0, y)
			st.size = Vector2(cw + 12.0, 50.0)
			st.visible = false
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(st)
			var ic := Ui.icon("", Vector2(cx + 16.0, y + 13.0), 24.0)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(ic)
			var tx := _panel_label(view, Vector2(cx + 46.0, y + 16.0),
				Type.SIZE_SMALL, Color(0.92, 0.88, 0.86), cw - 56.0, 20.0)
			_shop_outline(tx, 5)
			var b := _shop_ghost(view, Vector2(cw, 50.0))
			b.position = Vector2(cx, y)
			var step := i
			b.pressed.connect(func() -> void: _claim_book(step, paid))
			row["band_paid" if paid else "band_free"] = st
			row["icon_paid" if paid else "icon_free"] = ic
			row["lbl_paid" if paid else "lbl_free"] = tx
			row["btn_paid" if paid else "btn_free"] = b
		_book_rows.append(row)
	view.custom_minimum_size.y = 162.0 + float(OathDefs.BOOK_STEPS) * PASS_ROW_H
	_refresh_book()


func _refresh_book() -> void:
	if _book_rows.is_empty():
		return
	var step := OathDefs.book_step(oath_used)
	var active := IapDefs.sub_active(iap_subs, "season_pass")
	_book_head.text = "%d / %d칸  ·  %s  ·  굴린 %d회" % [step,
		OathDefs.BOOK_STEPS, "구매함" if active else "무료 줄만", oath_used]
	var into := oath_used % OathDefs.BOOK_PER_STEP
	_book_fill.size.x = (SHOP_LIST_W - 120.0) \
		* (float(into) / float(OathDefs.BOOK_PER_STEP))
	var can_any := false
	for row in _book_rows:
		var i: int = row["step"]
		var open := i <= step
		for paid in [false, true]:
			var r := OathDefs.book_paid(i) if paid else OathDefs.book_free(i)
			var key := "paid" if paid else "free"
			var got: Dictionary = oath_book_paid if paid else oath_book_free
			var ic: TextureRect = row["icon_" + key]
			var lbl: Label = row["lbl_" + key]
			var b: Button = row["btn_" + key]
			ic.texture = Assets.tex(_shop_kind_icon(str(r["kind"])))
			var claimed := got.has(i)
			lbl.text = "받음" if claimed else _n(float(r["amount"]))
			var live: bool = open and not claimed and (active or not paid)
			b.disabled = not live
			var st: ColorRect = row["band_" + key]
			st.visible = claimed or live
			if claimed:
				st.color = Color(0.30, 0.52, 0.34, 0.26)
				ic.modulate = Color(0.55, 0.62, 0.56)
				lbl.modulate = Color(0.62, 0.95, 0.68)
			elif live:
				st.color = Color(0.92, 0.70, 0.30, 0.16)
				ic.modulate = Color(1, 1, 1)
				lbl.modulate = Color(1.0, 0.94, 0.72)
			else:
				ic.modulate = Color(0.45, 0.43, 0.48)
				lbl.modulate = ic.modulate
			can_any = can_any or live
	_book_all_btn.disabled = not can_any


func _claim_book(step: int, paid: bool) -> void:
	if step <= 0 or step > OathDefs.book_step(oath_used):
		return
	if paid and not IapDefs.sub_active(iap_subs, "season_pass"):
		return
	var got: Dictionary = oath_book_paid if paid else oath_book_free
	if got.has(step):
		return
	got[step] = true
	var r := OathDefs.book_paid(step) if paid else OathDefs.book_free(step)
	_grant_reward(str(r["kind"]), float(r["amount"]))
	_show_reward("계약의 서 %d칸" % step,
		[{"icon": "res://assets/ui/%s.png" % _reward_icon(str(r["kind"])),
		"label": "%s +%s" % [_reward_name(str(r["kind"])), _n(float(r["amount"]))]}])
	_refresh_currency_visibility()
	_save_game()
	_refresh_book()
	_refresh_oath()


func _claim_book_all() -> void:
	var step := OathDefs.book_step(oath_used)
	var active := IapDefs.sub_active(iap_subs, "season_pass")
	var got := {}
	for i in range(1, step + 1):
		for paid in [false, true]:
			if paid and not active:
				continue
			var bag: Dictionary = oath_book_paid if paid else oath_book_free
			if bag.has(i):
				continue
			bag[i] = true
			var r := OathDefs.book_paid(i) if paid else OathDefs.book_free(i)
			var k := str(r["kind"])
			got[k] = float(got.get(k, 0.0)) + float(r["amount"])
	if got.is_empty():
		return
	var rows: Array = []
	for k in got:
		_grant_reward(str(k), float(got[k]))
		rows.append({"icon": "res://assets/ui/%s.png" % _reward_icon(str(k)),
			"label": "%s +%s" % [_reward_name(str(k)), _n(float(got[k]))]})
	_show_reward("계약의 서 — 일괄 수령", rows)
	_refresh_currency_visibility()
	_save_game()
	_refresh_book()
	_refresh_oath()


func _build_shop_pass(view: Control) -> void:
	_shop_ribbon(view, 0.0, "성장 패스 — 임무를 채우면 오른다")
	# 머리: 지금 단계와 다음 단계까지의 게이지. 트랙이 길어 위에 요약이 필요하다.
	_pass_head = _panel_label(view, Vector2(0.0, 62.0), Type.SIZE_MID,
		Color(0.98, 0.90, 0.70), SHOP_LIST_W, 24.0)
	_pass_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_pass_head, 6)
	var track := ColorRect.new()
	track.color = Color(0.10, 0.09, 0.12)
	track.position = Vector2(60.0, 94.0)
	track.size = Vector2(SHOP_LIST_W - 120.0, 10.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(track)
	_pass_fill = ColorRect.new()
	_pass_fill.color = Color(0.88, 0.66, 0.30)
	_pass_fill.position = track.position
	_pass_fill.size = Vector2(0.0, 10.0)
	_pass_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_pass_fill)
	# 일괄 수령 — 60칸을 손으로 누르게 하면 그건 보상이 아니라 일이다.
	_pass_all_btn = Ui.button("일괄 수령", Vector2((SHOP_LIST_W - 160.0) * 0.5, 116.0),
		Vector2(160.0, 34.0), Type.SIZE_SMALL)
	_pass_all_btn.pressed.connect(_claim_pass_all)
	view.add_child(_pass_all_btn)
	for i in range(1, PassDefs.STEPS + 1):
		var y := 162.0 + float(i - 1) * PASS_ROW_H
		# **배경은 안 깐다.** 알약을 줄마다 늘렸더니 둥근 끝이 가운데로 몰려
		# 한 줄이 세 덩어리로 보였다(실측 두 번). 30줄짜리 트랙은 선 하나로
		# 나누는 편이 읽기 쉽고, 그림이 늘어날 일도 없다.
		var sep := ColorRect.new()
		sep.color = Color(0.30, 0.27, 0.32)
		sep.position = Vector2(0.0, y + 52.0)
		sep.size = Vector2(SHOP_LIST_W, 1.0)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(sep)
		var lv := _panel_label(view, Vector2(0.0, y + 15.0), Type.SIZE_MID,
			Color(0.95, 0.90, 0.90), 52.0, 22.0)
		lv.text = "%d" % i
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(lv, 5)
		var row := {"step": i}
		# 무료(왼쪽) · 유료(오른쪽) 두 칸. 각 칸은 아이콘 + 수량 + 누르는 자리.
		var cw := (SHOP_LIST_W - 68.0) * 0.5 - 6.0
		for j in 2:
			var paid := j == 1
			var cx := 62.0 + float(j) * (cw + 12.0)
			# 유료 줄만 옅은 띠를 깔아 둘을 가른다 — 사면 열리는 쪽이 어디인지
			# 글자를 안 읽고도 갈려야 한다.
			if paid:
				var band := ColorRect.new()
				band.color = Color(0.42, 0.24, 0.30, 0.28)
				band.position = Vector2(cx - 6.0, y)
				band.size = Vector2(cw + 12.0, 50.0)
				band.mouse_filter = Control.MOUSE_FILTER_IGNORE
				view.add_child(band)
			# 상태 띠 — 받은 칸(초록)·받을 수 있는 칸(금빛)을 색으로 가른다.
			var st := ColorRect.new()
			st.position = Vector2(cx - 6.0, y)
			st.size = Vector2(cw + 12.0, 50.0)
			st.visible = false
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(st)
			var ic := Ui.icon("", Vector2(cx + 16.0, y + 13.0), 24.0)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(ic)
			var tx := _panel_label(view, Vector2(cx + 46.0, y + 16.0),
				Type.SIZE_SMALL, Color(0.92, 0.88, 0.86), cw - 56.0, 20.0)
			_shop_outline(tx, 5)
			var b := _shop_ghost(view, Vector2(cw, 50.0))
			b.position = Vector2(cx, y)
			var step := i
			b.pressed.connect(func() -> void: _claim_pass(step, paid))
			row["band_paid" if paid else "band_free"] = st
			row["icon_paid" if paid else "icon_free"] = ic
			row["lbl_paid" if paid else "lbl_free"] = tx
			row["btn_paid" if paid else "btn_free"] = b
		_pass_rows.append(row)
	view.custom_minimum_size.y = 162.0 + float(PassDefs.STEPS) * PASS_ROW_H
	_refresh_pass()


func _refresh_pass() -> void:
	if _pass_rows.is_empty():
		return
	var step := PassDefs.step_of(pass_points)
	var active := _pass_active()
	_pass_head.text = "%d / %d단계  ·  %s" % [step, PassDefs.STEPS,
		"구매함" if active else "무료 줄만"]
	var need := PassDefs.to_next(pass_points)
	_pass_fill.size.x = (SHOP_LIST_W - 120.0) * (0.0 if need == 0 \
		else float(PassDefs.STEP_POINT - need) / float(PassDefs.STEP_POINT))
	var can_any := false
	for row in _pass_rows:
		var i: int = row["step"]
		var open := i <= step
		for paid in [false, true]:
			var r := PassDefs.paid_reward(i) if paid else PassDefs.free_reward(i)
			var key := "paid" if paid else "free"
			var got: Dictionary = pass_paid_got if paid else pass_free_got
			var ic: TextureRect = row["icon_" + key]
			var lbl: Label = row["lbl_" + key]
			var b: Button = row["btn_" + key]
			ic.texture = Assets.tex(_shop_kind_icon(str(r["kind"])))
			var claimed := got.has(i)
			lbl.text = "받음" if claimed else _n(float(r["amount"]))
			var live: bool = open and not claimed and (active or not paid)
			b.disabled = not live
			# 세 상태를 색으로 가른다(사장님: 받은 건지 못 받은 건지 헷갈린다) —
			# 받음 = 초록 띠·초록 글씨, 받을 수 있음 = 금빛 띠·밝은 글씨,
			# 잠김 = 띠 없이 회색. "받음" 글씨만으론 잠김과 같은 회색이었다.
			var st: ColorRect = row["band_" + key]
			st.visible = claimed or live
			if claimed:
				st.color = Color(0.30, 0.52, 0.34, 0.26)
				ic.modulate = Color(0.55, 0.62, 0.56)
				lbl.modulate = Color(0.62, 0.95, 0.68)
			elif live:
				st.color = Color(0.92, 0.70, 0.30, 0.16)
				ic.modulate = Color(1, 1, 1)
				lbl.modulate = Color(1.0, 0.94, 0.72)
			else:
				ic.modulate = Color(0.45, 0.43, 0.48)
				lbl.modulate = ic.modulate
			can_any = can_any or live
	_pass_all_btn.disabled = not can_any


# 교환: 원래 있던 판 — 보석으로 오늘치 배급을 앞당긴다. 카드 5장, 2열.
func _build_shop_trade(view: Control) -> void:
	for i in ShopDefs.ITEMS.size():
		var it: Dictionary = ShopDefs.ITEMS[i]
		var id := str(it["id"])
		var pos := Vector2(float(i % 2) * (SHOP_COL_W + 14.0),
			float(i / 2) * (SHOP_VCARD_H + 10.0))
		var card := _shop_vcard(view, pos)
		card["icon"].texture = Assets.tex(str(it["icon"]))
		card["btn"].pressed.connect(func() -> void: _shop_buy(id))
		_shop_cards.append(card)
	var rows := ceili(ShopDefs.ITEMS.size() / 2.0)
	view.custom_minimum_size.y = float(rows) * (SHOP_VCARD_H + 10.0)


func _shop_set_mode(mode: String) -> void:
	# 스크롤 안 inner 를 들고 있으므로 겉(ScrollContainer)을 눌러 끈다.
	_shop_view.get_parent().visible = mode == "trade"
	_wear_view.get_parent().visible = mode == "wear"
	_pack_view.get_parent().visible = mode == "pack"
	_sub_view.get_parent().visible = mode == "sub"
	_pass_view.get_parent().visible = mode == "pass"
	_book_view.get_parent().visible = mode == "book"
	for key in _shop_mode_btns:
		_shop_mode_btns[key].set_pressed_no_signal(key == mode)
	if mode == "book":
		_refresh_book()
	match mode:
		"pack": _shop_line.text = "귀한 손님이군요… 좋은 것만 꺼내 왔어요."
		"sub":
			_shop_line.text = "매일 들러 주시는 분께는 값을 맞춰 드려요."
			_refresh_subs()
		"pass": _shop_line.text = "부지런한 분께는 매일 몫이 쌓이지요."
		"book": _shop_line.text = "운을 굴리는 분께는… 이 서(書)가 어울리죠."
		"trade": _shop_line.text = "보석이라면 무엇이든 바꿔 드리죠."
		"wear": _shop_line.text = "옷이 날개랬죠… 군주님껜 더더욱."
	if mode == "trade":
		_refresh_shop()
	elif mode == "wear":
		_refresh_wear()
	elif mode == "pack":
		_refresh_packs()
	elif mode == "pass":
		_refresh_pass()


# 패키지는 **벽 직전에 하나씩** 열린다 — 아직 못 간 구간의 것은 잠가 둔다.
# 이미 산 것은 "구매 완료"로 못 박는다(계정당 1회).
func _refresh_packs() -> void:
	if _pack_rows.is_empty():
		return
	for i in IapDefs.PACKS.size():
		var it: Dictionary = IapDefs.PACKS[i]
		var id := str(it["id"])
		var open := best_stage >= int(it["open"])
		var got := iap_bought.has(id)
		var row: Dictionary = _pack_rows[i]
		row["lock"].visible = not open
		row["root"].modulate = Color(1, 1, 1) if open and not got \
			else Color(0.5, 0.47, 0.52)
		row["price"].text = "구매 완료" if got \
			else (IapDefs.price_text(int(it["price"])) if open \
			else "%d구간 돌파 시" % int(it["open"]))
		row["sub"].text = "계정당 %d / 1" % (0 if got else 1)


# ── 구매 훅 **한 곳** ──────────────────────────────────────────────────────
# 팩·구독·보석이 저마다 지급 코드를 갖고 있으면 SDK 가 붙을 때 세 곳을 잇게
# 되고, 그중 하나를 빠뜨리면 돈은 받고 물건은 안 주는 사고가 된다.
# 반환값은 "실제로 팔렸나" — 이미 산 1회성 팩은 false 다.
func _iap_buy(id: String) -> bool:
	# 오늘의 특가 — pack/sub/GEMS 셋 중 어디에도 안 걸려서 여기까지 오면
	# 그대로 false 로 떨어지던 자리다(limited_of 호출부가 0건이었다).
	var ltd := IapDefs.limited_of(id)
	if not ltd.is_empty():
		if iap_bought.has(id):
			return false
		iap_bought[id] = true
		_iap_grant(ltd["reward"], str(ltd["name"]))
		_iap_after()
		return true
	var pack := IapDefs.pack_of(id)
	if not pack.is_empty():
		if iap_bought.has(id) or best_stage < int(pack["open"]):
			return false
		iap_bought[id] = true
		_iap_grant(pack["reward"], str(pack["name"]))
		_iap_after()
		return true
	var sub := IapDefs.sub_of(id)
	if not sub.is_empty():
		# 재구매는 **이어 붙인다** — 남은 날을 버리면 미리 사는 사람이 손해를 본다.
		var base := str(iap_subs.get(id, ""))
		var left := 0
		if IapDefs.sub_active(iap_subs, id):
			# 남은 날수 = 만료일 - 오늘. 날짜 문자열이라 유닉스로 되돌려 뺀다.
			var a := Time.get_unix_time_from_datetime_string(base)
			var b := Time.get_unix_time_from_datetime_string(
				Time.get_date_string_from_system())
			left = int(maxf(0.0, (a - b) / 86400.0))
		iap_subs[id] = IapDefs.expiry_date(int(sub["days"]) + left)
		_iap_grant(sub["instant"], str(sub["name"]))
		_iap_daily_grant(true)     # 산 날에도 오늘치가 들어온다
		_iap_after()
		return true
	for g in IapDefs.GEMS:
		if str(g["id"]) != id:
			continue
		var amount := float(g["gem"])
		var doubled := not iap_first_buy
		if doubled:
			amount *= IapDefs.FIRST_BUY_MULT
			iap_first_buy = true
		_iap_grant({"gem": amount}, "보석 충전 x2" if doubled else "보석 충전")
		_iap_after()
		return true
	return false


# 지급은 _grant_reward 로 흘린다 — 재화·소환권 이름을 아는 곳은 거기 하나다.
func _iap_grant(reward: Dictionary, title: String) -> void:
	var entries: Array = []
	for k in reward:
		var amount := float(reward[k])
		if amount <= 0.0:
			continue
		_grant_reward(str(k), amount)
		entries.append({"icon": _shop_kind_icon(str(k)),
			"label": "+%s" % _n(amount), "sub": _reward_name(str(k))})
	if not entries.is_empty():
		_show_reward(title, entries)


# 구독의 매일 지급. **접속해야 받는다**(설계서 5-1: 돌아올 이유를 만드는 상품).
# force 면 날짜 검사를 건너뛴다 — 구독을 산 그날은 오늘치를 바로 준다.
func _iap_daily_grant(force := false) -> void:
	var today := Time.get_date_string_from_system()
	if not force and iap_daily_date == today:
		return
	iap_daily_date = today
	for sub in IapDefs.SUBS:
		var id := str(sub["id"])
		if not IapDefs.sub_active(iap_subs, id):
			continue
		var daily: Dictionary = sub["daily"]
		if daily.is_empty():
			continue
		_iap_grant(daily, "%s — 오늘의 몫" % str(sub["name"]))


func _iap_after() -> void:
	_refresh_currency_visibility()
	_refresh_hud()
	_refresh_packs()
	_save_game()


func _shop_roll_day() -> void:
	var today := Time.get_date_string_from_system()
	if shop_date == today:
		return
	shop_date = today
	shop_used = {}


func _shop_left(id: String) -> int:
	var it := ShopDefs.of(id)
	return int(it["per_day"]) - int(shop_used.get(id, 0))


func _shop_buy(id: String) -> void:
	var it := ShopDefs.of(id)
	if it.is_empty() or best_stage < ShopDefs.open_stage(id):
		return
	# **광고 줄은 아직 못 산다.** 붙일 SDK 가 없다. 이 가드가 없던 동안
	# `match id:` 에 ad_* 갈래가 없어서 값(0)만 치르고 하루 한도가 깎인 뒤
	# **"보석 50 획득" 창까지 떴다** — 지갑은 그대로였다(2026-08-27 실측).
	# ShopDefs 주석과 HANDOFF 가 "잠금은 Main 이 건다"고 약속해 둔 것을
	# 실제로 거는 줄이다. SDK 가 붙는 날 이 줄과 아래 화면 잠금을 같이 푼다.
	if ShopDefs.is_ad(id):
		return
	_shop_roll_day()
	if _shop_left(id) <= 0 or gem < float(it["cost"]):
		return
	gem -= float(it["cost"])
	shop_used[id] = int(shop_used.get(id, 0)) + 1
	var amt := ShopDefs.amount(id, stage, dungeon_best,
		int(raid_best.get("pact", 0)))
	match id:
		"crystal": crystal += amt
		"sigil": sigil += amt
		"ticket":
			# 오늘 표를 **하루 상한 위로** 올린다 — 산 판은 덤이지 상한 안이 아니다.
			_raid_roll_day()
			for k in RaidDefs.RAIDS:
				raid_left[k] = _raid_left(str(k)) + 1
		"warp":
			# 방치 적립과 **같은 식**(blood_per_sec + 소탕 절반) — 요율이 다르면
			# 이 상품이 방치의 시세표를 거짓말로 만든다. 지갑이 아니라 상자에
			# 담는 것도 같은 이유: 눌러 여는 게 방치 보상의 보상이다.
			chest_gold += blood_per_sec() * ShopDefs.WARP_HOURS * 3600.0
			chest_minutes += ShopDefs.WARP_HOURS * 60.0
			if dungeon_best > 0:
				crystal += ShopDefs.WARP_HOURS * _sweep_per_hour() * 0.5
			_refresh_chest()
	# 산 것을 보상창으로 편다 — 지갑 숫자만 바뀌면 눌렀는지 모른다(방치 보상과 같은 길).
	var big := "+1판" if id == "ticket" \
		else ("+%d시간" % int(ShopDefs.WARP_HOURS) if id == "warp" else _n(amt))
	_show_reward(str(it["name"]), [{"icon": str(it["icon"]),
		"label": big, "sub": str(it["sub"])}])
	_refresh_currency_visibility()
	_save_game()
	_refresh_shop()
	_refresh_hud()


func _refresh_shop() -> void:
	_shop_roll_day()
	for i in ShopDefs.ITEMS.size():
		var it: Dictionary = ShopDefs.ITEMS[i]
		var id := str(it["id"])
		var need := ShopDefs.open_stage(id)
		var locked := best_stage < need
		var left := _shop_left(id)
		var card: Dictionary = _shop_cards[i]
		card["title"].text = str(it["name"])
		# 그림 위 숫자는 수량만 — "1회 6"이 값으로 읽힌 사고의 재발 방지.
		card["amount"].text = "+1판" if id == "ticket" \
			else ("+%d시간" % int(ShopDefs.WARP_HOURS) if id == "warp" \
			else _n(ShopDefs.amount(id, stage, dungeon_best,
				int(raid_best.get("pact", 0)))))
		card["left"].text = "%d구간부터" % need if locked \
			else "오늘 %d / %d" % [left, int(it["per_day"])]
		# 광고 줄은 값이 0 이라 "보석 0" 으로 떴고 `gem < 0` 이 늘 거짓이라
		# 버튼이 살아 있었다. 붙일 SDK 가 없으니 눌리면 안 된다.
		var ad := ShopDefs.is_ad(id)
		card["price"].text = "준비 중" if ad \
			else ("잠김" if locked else "보석 %d" % int(it["cost"]))
		card["btn"].disabled = ad or locked or left <= 0 \
			or gem < float(it["cost"])
		card["lock"].visible = locked
		card["stamp"].visible = not locked and left <= 0
		card["root"].modulate = Color(1, 1, 1) if not ad and not locked and left > 0 \
			else Color(0.62, 0.58, 0.62)


# 임무 줄 한 벌 — 일일·주간이 같은 생김새라 짜개는 하나다.
# 주간 게이지만 금빛 — 어느 판에 있는지 곁눈으로 갈린다.
# 줄이 12개(일일)·9개(주간)로 늘면서 판 밖으로 넘쳤다 — **스크롤로 감싼다**
# (2026-08-20). 예전 7줄도 사실 마지막 줄이 "자정에 새로 온다"를 덮고 있었다.
# 스크롤 안은 지역 좌표라 줄을 0 부터 쌓는다.
func _quest_build_rows(root: Control, table: Array, weekly: bool) -> Array[Dictionary]:
	# 오른쪽 22 는 판 여백, 16 은 **두루마리 장식 폭**이다 — 그만큼 안 비우면
	# 스크롤바가 장식 위에 그려진다(실측 캡처).
	var w := QUEST_PANEL.size.x - 60.0 - Ui.SCROLL_W
	var sc := Ui.scroll(Vector2(QUEST_PANEL.position.x + 22.0,
		QUEST_PANEL.position.y + 96.0),
		Vector2(w + Ui.SCROLL_W, QUEST_ROWS_H))
	root.add_child(sc)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(w, float(table.size()) * 56.0)
	sc.add_child(inner)
	var x := 0.0
	var rows: Array[Dictionary] = []
	for i in table.size():
		var q: Dictionary = table[i]
		var y := float(i) * 56.0
		inner.add_child(Ui.set_row(DUTY, Vector2(x, y), Vector2(w, 50.0)))
		inner.add_child(Ui.icon("res://assets/ui/%s.png" % str(q["icon"]),
			Vector2(x + 10.0, y + 11.0), 28.0))
		var nm := _panel_label(inner, Vector2(x + 48.0, y + 6.0),
			Type.SIZE_SMALL, DUTY_INK, w - 170.0, 16.0)
		nm.text = str(q["name"])
		var track := ColorRect.new()
		track.color = Color(0.10, 0.09, 0.12)
		track.position = Vector2(x + 48.0, y + 30.0)
		track.size = Vector2(QUEST_BAR_W, 8.0)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(track)
		var fill := ColorRect.new()
		fill.color = Color(0.62, 0.42, 0.14) if weekly else DUTY_RED
		fill.position = track.position
		fill.size = Vector2(0.0, 8.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(fill)
		var prx := x + 48.0 + QUEST_BAR_W + 8.0
		var qid := str(q["id"])
		var bp := Vector2(x + w - 108.0, y + 9.0)
		var pr := _panel_label(inner, Vector2(prx, y + 24.0), Type.SIZE_SMALL,
			DUTY_DIM, bp.x - prx - 6.0, 20.0)
		var pill_art := Ui.set_row(DUTY, bp, Vector2(100.0, 32.0))
		inner.add_child(pill_art)
		var ricon := Ui.icon("res://assets/ui/%s.png"
			% _reward_icon(str(q["reward"])), Vector2(bp.x + 12.0, bp.y + 8.0), 16.0)
		inner.add_child(ricon)
		_art_set_base(pill_art, Color.WHITE)   # 호버가 이 색을 지우지 않게
		var rw := _panel_label(inner, Vector2(bp.x + 34.0, bp.y + 8.0),
			Type.SIZE_SMALL, DUTY_INK, 58.0, 16.0)
		rw.text = "+%d" % int(q["amount"])
		var b := Ui.button("", bp, Vector2(100.0, 32.0), Type.SIZE_SMALL)
		b.modulate = Color(1, 1, 1, 0)      # 양피지 줄이 이미 버튼이다
		_pet_hover(b, pill_art)
		if weekly:
			b.pressed.connect(func() -> void: _claim_wquest(qid))
		else:
			b.pressed.connect(func() -> void: _claim_quest(qid))
		inner.add_child(b)
		rows.append({"prog": pr, "btn": b, "fill": fill, "rw": rw,
			"icon": ricon, "pill": pill_art})
	return rows


# 출석 격자 — 30칸을 6열 5줄로. 칸 하나에 일차·보상 아이콘·수량이 들어간다.
const ATTEND_COLS := 6
const ATTEND_CELL := 68.0
const ATTEND_GAP := 5.0


func _attend_build(root: Control) -> void:
	var x := QUEST_PANEL.position.x + 22.0
	var w := QUEST_PANEL.size.x - 44.0
	var span := ATTEND_CELL + ATTEND_GAP
	# 6열이 판 안에서 가운데 오게. 남는 폭을 양쪽으로 나눈다.
	var x0 := x + (w - (span * float(ATTEND_COLS) - ATTEND_GAP)) * 0.5
	var y0 := QUEST_PANEL.position.y + 96.0
	for i in AttendDefs.DAYS:
		var a := AttendDefs.of(i + 1)
		var cx := x0 + float(i % ATTEND_COLS) * span
		var cy := y0 + float(i / ATTEND_COLS) * span
		# 큰 날(7·14·21·30)은 카드 대신 탭 액자 — 한눈에 이정표가 보인다.
		var frame := Ui.set_tab(DUTY, true, Vector2(cx, cy),
			Vector2(ATTEND_CELL, ATTEND_CELL)) if bool(a["big"]) \
			else Ui.set_row(DUTY, Vector2(cx, cy),
				Vector2(ATTEND_CELL, ATTEND_CELL))
		root.add_child(frame)
		var day := _panel_label(root, Vector2(cx, cy + 4.0), Type.SIZE_SMALL,
			DUTY_DIM, ATTEND_CELL, 14.0)
		day.text = "%d일" % int(a["day"])
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ico := Ui.icon("res://assets/ui/%s.png" % _reward_icon(str(a["reward"])),
			Vector2(cx + (ATTEND_CELL - 26.0) * 0.5, cy + 22.0), 26.0)
		root.add_child(ico)
		var amt := _panel_label(root, Vector2(cx, cy + 52.0), Type.SIZE_SMALL,
			DUTY_INK, ATTEND_CELL, 14.0)
		amt.text = "x%d" % int(a["amount"])
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# 받은 칸 표시. **어둠막만으로는 구분이 안 된다** — 카드가 이미 어두워서
		# 알파 0.66 을 덮어도 안 받은 칸과 비슷해 보였다(실측 캡처). 막을 진하게
		# 하고 그 위에 표식을 얹는다.
		var done := ColorRect.new()
		done.color = Color(0.30, 0.22, 0.16, 0.78)
		done.position = Vector2(cx, cy)
		done.size = Vector2(ATTEND_CELL, ATTEND_CELL)
		done.visible = false
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(done)
		var mark := _panel_label(root, Vector2(cx, cy + 24.0), Type.NATIVE * 2,
			DUTY_RED, ATTEND_CELL, 26.0)
		mark.text = "✓"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.visible = false
		_art_set_base(frame, Color.WHITE)   # 호버가 이 색을 지우지 않게
		_attend_cells.append({"frame": frame, "done": done, "ico": ico,
			"mark": mark, "day": day})
	var ap := Vector2(x + w * 0.5 - 100.0,
		QUEST_PANEL.position.y + QUEST_PANEL.size.y - 56.0)
	var ap_art := Ui.set_row(DUTY, ap, Vector2(200.0, 42.0))
	root.add_child(ap_art)
	_attend_btn_art = ap_art
	_attend_lbl = _panel_label(root, Vector2(ap.x, ap.y + 12.0),
		Type.SIZE_MID, DUTY_INK, 200.0, 20.0)
	_attend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attend_btn = Ui.button("", ap, Vector2(200.0, 42.0), Type.SIZE_MID)
	_pet_hover(_attend_btn, ap_art)
	_attend_btn.modulate = Color(1, 1, 1, 0)
	_attend_btn.pressed.connect(_claim_attend)
	root.add_child(_attend_btn)


func _refresh_attend() -> void:
	if _attend_cells.is_empty():
		return
	# 이번 바퀴에서 받은 칸 수. 30 을 넘으면 다음 바퀴라 나머지로 센다.
	var done := attend_got % AttendDefs.DAYS
	# 딱 30 을 채운 순간은 나머지가 0 이 되는데, 그건 "한 칸도 안 받음"과
	# 같은 값이다 — 오늘 아직 안 받았으면 다 채운 상태로 보여 준다.
	if attend_got > 0 and done == 0 and not _attend_claimable():
		done = AttendDefs.DAYS
	var ready := _attend_claimable()
	for i in _attend_cells.size():
		var c: Dictionary = _attend_cells[i]
		var got := i < done
		# **오늘 받을 칸**은 지금 받을 수 있을 때만이다 — 이미 받았으면 그
		# 다음 칸은 내일 것이라 금빛으로 부르면 거짓말이 된다.
		var today := ready and i == done
		c["done"].visible = got
		c["mark"].visible = got
		# 액자를 금빛으로 — 임무 줄의 [받기] 와 같은 색이다. 밝기만으로 가르면
		# 서른 칸 중 어느 것이 오늘인지 안 읽힌다(사장님).
		_art_set_base(c["frame"], CLAIM_GOLD if today else Color.WHITE)
		c["day"].text = "오늘" if today else "%d일" % (i + 1)
		c["day"].add_theme_color_override("font_color",
			DUTY_INK if today else DUTY_DIM)
		c["ico"].modulate = Color(1, 1, 1, 1) if today or got 			else Color(1, 1, 1, 0.72)
	_attend_btn.disabled = not ready
	_attend_lbl.text = "오늘 받기" if ready else "내일 또"
	_attend_lbl.add_theme_color_override("font_color",
		DUTY_INK if ready else DUTY_DIM)
	if _attend_btn_art:
		_art_set_base(_attend_btn_art, CLAIM_GOLD if ready else Color.WHITE)


func _boon_build(root: Control) -> void:
	var x := QUEST_PANEL.position.x + 22.0
	var w := QUEST_PANEL.size.x - 44.0
	var y := QUEST_PANEL.position.y + 104.0
	root.add_child(Ui.set_card(DUTY, Vector2(x, y), Vector2(w, 150.0)))
	var now := _panel_label(root, Vector2(x, y + 22.0), Type.NATIVE * 2,
		DUTY_RED, w, 30.0)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var now_text := _panel_label(root, Vector2(x, y + 70.0), Type.SIZE_BODY,
		DUTY_INK, w, 26.0)
	now_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# **여섯 종을 다 늘어놓는다.** 다음 주 하나만 예고하면 "언제 그게 오나"를
	# 못 세는데, 차례가 보이면 기다릴 주를 고를 수 있다. 긴 설명이 큰 글씨로는
	# 카드를 넘쳐서(실측) 줄마다 작은 글씨 한 줄로 눕힌다.
	var rows: Array = []
	for i in BoonDefs.BOONS.size():
		var ry := y + 180.0 + float(i) * 38.0
		root.add_child(Ui.set_pill(DUTY, Vector2(x, ry), Vector2(w, 32.0)))
		var l := _panel_label(root, Vector2(x + 14.0, ry + 8.0), Type.SIZE_SMALL,
			DUTY_DIM, w - 28.0, 16.0)
		rows.append(l)
	_boon_labels = {"now": now, "text": now_text, "rows": rows}


func _refresh_boon() -> void:
	if _boon_labels.is_empty():
		return
	var wk := _quest_week_key()
	var b := BoonDefs.of(wk)
	_boon_labels["now"].text = str(b["name"])
	_boon_labels["text"].text = str(b["text"])
	var rows: Array = _boon_labels["rows"]
	for i in rows.size():
		var e: Dictionary = BoonDefs.BOONS[i]
		var here := str(e["id"]) == str(b["id"])
		rows[i].text = "%s%s — %s" % ["▶ " if here else "   ",
			str(e["name"]), str(e["text"])]
		rows[i].add_theme_color_override("font_color",
			DUTY_RED if here else DUTY_DIM)


# 업적 줄 — **트랙마다 한 줄**이고 지금 노리는 계단 하나만 적는다.
# 계단을 전부 늘어놓으면 55줄이라 판이 목록이 아니라 벽이 된다. 다 받은 트랙은
# "완주"로 남겨 둔다 — 지운 자리는 성취가 아니라 빈칸으로 읽힌다.
func _achieve_build_rows(root: Control) -> Array[Dictionary]:
	# 오른쪽 22 는 판 여백, 16 은 **두루마리 장식 폭**이다 — 그만큼 안 비우면
	# 스크롤바가 장식 위에 그려진다(실측 캡처).
	var w := QUEST_PANEL.size.x - 60.0 - Ui.SCROLL_W
	var sc := Ui.scroll(Vector2(QUEST_PANEL.position.x + 22.0,
		QUEST_PANEL.position.y + 96.0),
		Vector2(w + Ui.SCROLL_W, QUEST_ROWS_H))
	root.add_child(sc)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(w, float(AchieveDefs.TRACKS.size()) * 56.0)
	sc.add_child(inner)
	var rows: Array[Dictionary] = []
	for i in AchieveDefs.TRACKS.size():
		var t: Dictionary = AchieveDefs.TRACKS[i]
		var kind := str(t["kind"])
		var y := float(i) * 56.0
		inner.add_child(Ui.set_row(DUTY, Vector2(0.0, y), Vector2(w, 50.0)))
		inner.add_child(Ui.icon("res://assets/ui/%s.png" % str(t["icon"]),
			Vector2(10.0, y + 11.0), 28.0))
		var nm := _panel_label(inner, Vector2(48.0, y + 6.0),
			Type.SIZE_SMALL, DUTY_INK, w - 170.0, 16.0)
		var bar := ColorRect.new()
		bar.color = Color(0.10, 0.09, 0.12)
		bar.position = Vector2(48.0, y + 30.0)
		bar.size = Vector2(QUEST_BAR_W, 8.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(bar)
		var fill := ColorRect.new()
		fill.color = Color(0.72, 0.60, 0.24)      # 업적은 금빛 — 일일(붉음)과 구분
		fill.position = bar.position
		fill.size = Vector2(0.0, 8.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(fill)
		var pr := _panel_label(inner, Vector2(48.0 + QUEST_BAR_W + 8.0, y + 24.0),
			Type.SIZE_SMALL, DUTY_DIM, 90.0, 20.0)
		var bp := Vector2(w - 108.0, y + 9.0)
		var pill_art := Ui.set_row(DUTY, bp, Vector2(100.0, 32.0))
		inner.add_child(pill_art)
		var ricon := Ui.icon("res://assets/ui/res_blood.png",
			Vector2(bp.x + 12.0, bp.y + 8.0), 16.0)
		inner.add_child(ricon)
		_art_set_base(pill_art, Color.WHITE)   # 호버가 이 색을 지우지 않게
		var rw := _panel_label(inner, Vector2(bp.x + 34.0, bp.y + 8.0),
			Type.SIZE_SMALL, DUTY_INK, 58.0, 16.0)
		var b := Ui.button("", bp, Vector2(100.0, 32.0), Type.SIZE_SMALL)
		b.modulate = Color(1, 1, 1, 0)
		_pet_hover(b, pill_art)
		b.pressed.connect(func() -> void: _claim_achieve(kind))
		inner.add_child(b)
		rows.append({"name": nm, "prog": pr, "fill": fill, "btn": b,
			"rw": rw, "icon": ricon, "pill": pill_art})
	return rows


func _refresh_achieve() -> void:
	if _achieve_rows.is_empty():
		return
	for i in AchieveDefs.TRACKS.size():
		var t: Dictionary = AchieveDefs.TRACKS[i]
		var kind := str(t["kind"])
		var row: Dictionary = _achieve_rows[i]
		var got := int(achieve_got.get(kind, 0))
		var step: Dictionary = AchieveDefs.at(kind, got)
		if step.is_empty():
			row["name"].text = "%s — 완주" % str(t["name"])
			row["prog"].text = ""
			row["fill"].size.x = QUEST_BAR_W
			_row_claim_state(row, "done", 0)
			continue
		var value := _goal_value(kind)
		var need := int(step["need"])
		row["name"].text = str(step["name"])
		row["prog"].text = "%s/%s" % [_n(float(value)), _n(float(need))]
		row["fill"].size.x = QUEST_BAR_W * clampf(float(value) / float(need), 0.0, 1.0)
		row["icon"].texture = Assets.tex("res://assets/ui/%s.png"
			% _reward_icon(str(step["reward"])))
		_row_claim_state(row, "ready" if value >= need else "wait",
			int(step["amount"]))


# 한 번 누르면 **닿은 계단을 다 준다** — 오래 안 열었으면 계단이 여럿 쌓이는데
# 한 칸씩 누르게 하면 그건 보상이 아니라 일이다.
func _claim_achieve(kind: String) -> void:
	var value := _goal_value(kind)
	var got := int(achieve_got.get(kind, 0))
	var entries: Array = []
	while true:
		var step: Dictionary = AchieveDefs.at(kind, got)
		if step.is_empty() or value < int(step["need"]):
			break
		_grant_reward(str(step["reward"]), float(step["amount"]))
		entries.append({"icon": "res://assets/ui/%s.png"
			% _reward_icon(str(step["reward"])),
			"label": "+%d" % int(step["amount"]), "sub": str(step["name"])})
		got += 1
	if entries.is_empty():
		return
	achieve_got[kind] = got
	_show_reward("업적 달성", entries)
	if _achieve_rows.is_empty():
		return   # 계측기 — 지급은 끝났다
	_refresh_achieve()
	_refresh_hud()
	_save_game()


func _quest_set_mode(mode: String) -> void:
	_quest_day_root.visible = mode == "day"
	_quest_week_root.visible = mode == "week"
	_achieve_root.visible = mode == "achieve"
	_attend_root.visible = mode == "attend"
	_boon_root.visible = mode == "boon"
	for key in _quest_mode_btns:
		_quest_mode_btns[key].button_pressed = key == mode
	for key in _quest_tab_art:
		var art: Dictionary = _quest_tab_art[key]
		art["on"].visible = key == mode
		art["lbl"].add_theme_color_override("font_color",
			DUTY_RED if key == mode else DUTY_DIM)
	# 일괄 받기는 임무 소탭에서만 뜻이 있다 — 출석은 하루 한 칸이고 은총은
	# 받을 게 없다. 남겨 두면 누를 수는 있는데 아무 일도 안 일어난다.
	# 일괄 받기는 **업적에서도** 뜻이 있다 — 오래 안 열었으면 계단이 여럿 쌓인다.
	var on_quest := mode == "day" or mode == "week" or mode == "achieve"
	_quest_claim_all.visible = on_quest
	for n in _quest_claim_art:
		n.visible = on_quest
	_refresh_quests()
	_refresh_achieve()
	_refresh_attend()
	_refresh_boon()


# 줄 하나의 **받을 수 있음**을 화면에 새긴다. 셋(일일·주간·업적)이 같은 문법을
# 쓴다 — 목록마다 다르게 칠하면 같은 뜻이 세 가지로 보인다.
#
#   ready : 알약이 금빛 + "받기"   — 지금 누르면 들어온다
#   wait  : 보통 + "+N"            — 아직 조건이 안 찼다
#   done  : 죽은 색 + "완료"       — 오늘(또는 영영) 끝났다
const CLAIM_GOLD := Color(1.0, 0.82, 0.34)
const CLAIM_DONE := Color(0.52, 0.50, 0.50)


func _row_claim_state(row: Dictionary, state: String, amount: int) -> void:
	var pill: Control = row.get("pill")
	var rw: Label = row.get("rw")
	var icon: Control = row.get("icon")
	var b: Button = row["btn"]
	b.disabled = state != "ready"
	if pill == null or rw == null:
		return
	match state:
		"ready":
			_art_set_base(pill, CLAIM_GOLD)
			rw.text = "받기"
			# 본문과 같은 흰색 — 외곽선이 있어 금빛에도 안 묻힌다(사장님:
			# 어두운 글자는 이질감).
			rw.add_theme_color_override("font_color", DUTY_INK)
			if icon:
				icon.visible = false          # "받기" 가 칸을 다 쓴다
		"done":
			_art_set_base(pill, CLAIM_DONE)
			rw.text = "완료"
			rw.add_theme_color_override("font_color", Color(0.72, 0.70, 0.68))
			if icon:
				icon.visible = false
		_:
			_art_set_base(pill, Color.WHITE)
			rw.text = "+%d" % amount
			rw.add_theme_color_override("font_color", DUTY_INK)
			if icon:
				icon.visible = true


func _refresh_quests() -> void:
	if _quest_rows.is_empty():
		return
	_quest_roll_day()
	var any := false
	for i in QuestDefs.QUESTS.size():
		var q: Dictionary = QuestDefs.QUESTS[i]
		var id := str(q["id"])
		var row: Dictionary = _quest_rows[i]
		var need := int(q["need"])
		var cnt := mini(_quest_count(id), need)
		row["prog"].text = "%d/%d" % [cnt, need]
		row["fill"].size.x = QUEST_BAR_W * float(cnt) / float(need)
		_row_claim_state(row, "done" if quest_got.has(id) \
			else ("ready" if _quest_claimable(id) else "wait"), int(q["amount"]))
		any = any or _quest_claimable(id)
	for i in QuestDefs.WEEKLY.size():
		var q: Dictionary = QuestDefs.WEEKLY[i]
		var id := str(q["id"])
		var row: Dictionary = _quest_wrows[i]
		var need := int(q["need"])
		var cnt := mini(int(quest_wprog.get(str(q["kind"]), 0)), need)
		row["prog"].text = "%d/%d" % [cnt, need]
		row["fill"].size.x = QUEST_BAR_W * float(cnt) / float(need)
		_row_claim_state(row, "done" if quest_wgot.has(id) \
			else ("ready" if _wquest_claimable(id) else "wait"),
			int(q["amount"]))
		any = any or _wquest_claimable(id)
	# 일괄 받기 버튼은 **일일·주간만** 받으므로 그 둘로 판단한다.
	_quest_claim_all.disabled = not any
	# **점은 창 전체를 대표한다.** 창 안에 소탭이 다섯인데(일일·주간·업적·출석·
	# 패스) 점은 앞의 둘만 보고 있었다 — 출석이 안 찍혀 있어도, 업적이 넘겨져
	# 있어도, 패스 단계가 열려 있어도 점이 안 켜졌다(사장님 2026-08-26:
	# "모든 컨텐츠에서 ... 보상 있으면 알림"). 다섯을 다 본다.
	if _quest_dot:
		_quest_dot.visible = any or _attend_claimable() 			or _achieve_claimable() or _pass_claimable()


func _select_tab(name: String) -> void:
	var switched := _tab != name
	_tab = name
	if switched and name in FULL_TABS:
		_boss_cut_clear()
	for key in _panels.keys():
		_panels[key].visible = key == name
	# 홈(사냥)은 판이 없는 탭이다 — 창을 다 걷고 사냥터만 남긴다(사장님,
	# 레퍼런스의 가운데 홈 버튼).
	_panel_bg.visible = name not in FULL_TABS and name != "home"
	_panel_bg_full.visible = name in FULL_TABS
	if _board:
		_board.visible = name == "home" or raid_on != "" or dungeon_on
		if _board.visible:
			_refresh_board()
	_boss_cut_clear()      # 판을 열면 컷신 띠는 즉시 걷는다
	# 전투 화면에 떠 있는 소품(가이드·방치 상자·오른쪽 바로가기 줄)은 전면 판과
	# 겹친다 — 같이 숨긴다(사장님: 임무·업적 아이콘도 안 보이게, 완전 전체 화면).
	_goal_widget.visible = name not in FULL_TABS
	if _side_root:
		_side_root.visible = name not in FULL_TABS
	_refresh_chest()
	# 창 전환은 **짧게 떠오르며** 나타난다(0.12초). 그냥 바뀌면 밋밋하다(사장님).
	# 원위치는 meta 에 한 번 적어 둔다 — 연타로 트윈이 겹쳐도 늘 제자리로 수렴한다.
	if switched and _panels.has(name):
		var p: Control = _panels[name]
		if not p.has_meta("base_y"):
			p.set_meta("base_y", p.position.y)
		var base_y: float = p.get_meta("base_y")
		p.modulate.a = 0.0
		p.position.y = base_y + 12.0
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "modulate:a", 1.0, 0.12)
		tw.tween_property(p, "position:y", base_y, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for key in _tab_btns.keys():
		# 선택 안 된 탭은 어둡게. 아이콘이 4개뿐이라 밝기만으로 충분히 읽힌다.
		# 고른 탭은 살짝 커진다 — 밝기와 크기, 신호 둘이면 곁눈으로도 읽힌다.
		var m: Control = _tab_btns[key]
		m.modulate = Color(1, 1, 1) if key == name else Color(0.5, 0.5, 0.55)
		m.pivot_offset = m.size * 0.5
		m.scale = Vector2(1.06, 1.06) if key == name else Vector2.ONE
	if name == "pet":
		_refresh_pet()
	elif name == "summon":
		_refresh_gacha()
	elif name == "raid":
		_refresh_dungeon()
	elif name == "shop":
		_refresh_packs()
		_refresh_shop()


# 지금 올릴 수 있는 게 있는 탭인가. 방치형에서 "뭘 눌러야 하나"를 탭을 하나씩 열어
# 보고 알아내게 하면 안 된다 — 그 확인 작업이 방치를 깬다.
#
# 점의 뜻은 "살 수 있다"가 아니라 **놀고 있는 자원이 있다**로 잡았다:
#   성장·장비  벌어서 쓰는 재화(혈액·정수)다. 쥐고 있는 게 곧 손해라 사면 켠다
#   소환      보석은 아껴 두는 재화다. "살 수 있다"로 켜면 늘 켜져 있어서 잔소리가
#             되고, 늘 켜진 점은 없는 점과 같다. **안 쓰면 사라지는 것**만 켠다 —
#             오늘 공짜 뽑기와, 이미 모여서 쓰기만 하면 되는 스킬 조각
# 이 장비를 지금 올릴 수 있나 — 격자 점과 탭 점이 **같은 자**를 쓴다.
# 만렙·연마석·신화 조각(100렙부터)을 다 본다.
func _gear_can_level(key: String) -> bool:
	var it: Dictionary = gear_inventory.get(key, {})
	if it.is_empty() or GearDefs.is_max_lv(it):
		return false
	if whet < GearDefs.upgrade_cost(it):
		return false
	var need := GearDefs.upgrade_shards(it)
	return need <= 0 or int(gacha_shards.get("gear:" + key, 0)) >= need


# 이 장비를 지금 조합할 수 있나. 최고 등급 바로 아래는 만렙까지 채워야 한다.
func _gear_can_fuse(key: String) -> bool:
	var it: Dictionary = gear_inventory.get(key, {})
	if it.is_empty():
		return false
	if GachaDefs.rarity_index(str(it.get("rarity", "common"))) 			>= GachaDefs.RARITIES.size() - 1:
		return false
	if _fuse_needs_max(it):
		return false
	return int(gacha_shards.get("gear:" + key, 0)) >= GearDefs.FUSE_SHARDS


# 성장 탭의 여섯 소탭 중 지금 손댈 게 있나. 스탯만 보던 것을 전부로 넓힌다
# (사장님 2026-08-26) — 혈맥·혈맹·유물·회귀는 각자 재화가 따로라, 하나가
# 마르는 동안 다른 하나가 차 있는 게 이 게임의 보통 상태다.
func _growth_todo() -> bool:
	var major := StageDefs.major_stage(stage)
	for st in StatDefs.STATS:
		var k := str(st["key"])
		if StatDefs.is_open(k, major, lv) and stat_lv(k) < _stat_cap(k) 				and gold >= _buy_cost(k, _step_for(k)):
			return true
	# 혈맥 — 열려 있고 혈정이 닿는 노드가 하나라도 있나.
	for n in TraitDefs.NODES:
		if _trait_steps(str(n["id"])) > 0:
			return true
	# 혈맹 — 인장으로 한 칸.
	if _pact_steps(1) > 0 and sigil >= _pact_cost(1):
		return true
	# 유물 — 조각이 다 모인 것.
	for r in RelicDefs.RELICS:
		var rid := str(r["id"])
		if RelicDefs.level_of(rid, relics) > 0 				and RelicDefs.level_of(rid, relics) < RelicDefs.MAX_LV 				and int(gacha_shards.get("relic:" + rid, 0)) >= RelicDefs.SHARDS_PER_LV:
			return true
	# 회귀 — 지금 돌면 혈흔이 나오나.
	if best_stage >= PrestigeDefs.OPEN_STAGE 			and PrestigeDefs.marks_for(best_stage, prestige_peak) > 0:
		return true
	return false


func _tab_todo(tab: String) -> bool:
	match tab:
		"growth":
			return _growth_todo()
		"gear":
			# **레벨업도 켠다** (사장님 2026-08-26). 연마석이 생긴 뒤로 장비는
			# 조합만이 아니라 올릴 수도 있는데 점은 조합만 보고 있었다.
			for key in gear_inventory:
				if _gear_can_level(str(key)) or _gear_can_fuse(str(key)):
					return true
		"raid":
			# 오늘 표가 남아 있다 — 자정에 사라지는 것이라 점의 원칙에 맞다.
			if raid_on == "" and not dungeon_on:
				_raid_roll_day()
				for kind in RaidDefs.RAIDS:
					if best_stage >= RaidDefs.open_stage(str(kind)) \
							and _raid_left(str(kind)) > 0:
						return true
			# 주간 보스 — 받을 이정표가 있으면 켠다(도전 횟수로는 안 켠다: 매일
			# 켜져 있으면 잔소리가 되고, 늘 켜진 점은 없는 점과 같다).
			for i in EventDefs.MILESTONES.size():
				if not boss_got.has(i) \
						and boss_dmg >= _boss_need(i):
					return true
			# 시련 — 열린 단계가 남아 있으면 켠다. 격파하면 꺼진다(미궁이 다시
			# 열 때까지) — "받을 보상이 존재하면 알림"(사장님 2026-08-18).
			if trial_stage < TrialDefs.max_stage() \
					and dungeon_best >= TrialDefs.floor_need(trial_stage + 1):
				return true
			# 미궁 — **아직 안 뚫은 층이 열려 있다**(사장님 2026-08-26:
			# "진행 가능한 던전"). 상한까지 다 뚫었으면 안 켠다 — 제자리를
			# 도는 건 첫 돌파 보상이 없어서 "받을 게 있다"가 아니다.
			if raid_on == "" and not dungeon_on 					and dungeon_best < DungeonDefs.open_floors(best_stage):
				return true
		"pet":
			# 소환권·다 모인 먹이·물어온 재화 — 전부 "쓰기만 하면 되는" 것들이다.
			if int(tickets.get("pet", 0)) > 0 \
					or int(tickets.get("petgear", 0)) > 0:
				return true
			# pet_bank 는 **펫 탭을 열 때만** 갱신된다(_pet_tick 의 호출처가 셋뿐이고
			# 전부 펫 화면이다). 그래서 한 번 걷고 나면 저장된 값이 0 에 머물러
			# 점이 다시는 안 켜졌다. accrue 는 순수 함수라 여기서는 값을 쓰지 않고
			# 지금 쌓였을 양만 재 본다.
			var pet_h := 0.0 if pet_at <= 0.0 \
				else maxf(0.0, (Time.get_unix_time_from_system() - pet_at) / 3600.0)
			for id in pets_got:
				var plv := _pet_lv(str(id))
				if plv < PetDefs.lv_cap(_pet_star(str(id))) \
						and feed >= PetDefs.feed_cost(plv):
					return true
				if is_equal_approx(_trip_left(str(id)), 0.0):
					return true
				if PetDefs.accrue(str(id), float(pet_bank.get(id, 0.0)), pet_h,
						plv, _pet_star(str(id)),
						_pet_gear_value(str(id), "gather")) >= 1.0:
					return true
		"shop":
			# 계약의 서 — 받을 칸이 남아 있다.
			var bstep := OathDefs.book_step(oath_used)
			var bactive := IapDefs.sub_active(iap_subs, "season_pass")
			for i in range(1, bstep + 1):
				if not oath_book_free.has(i):
					return true
				if bactive and not oath_book_paid.has(i):
					return true
			# 성장 패스 — 받을 칸이 남아 있다.
			var pstep := PassDefs.step_of(pass_points)
			var pactive := _pass_active()
			for i in range(1, pstep + 1):
				if not pass_free_got.has(i):
					return true
				if pactive and not pass_paid_got.has(i):
					return true
		"summon":
			if free_pull_date != Time.get_date_string_from_system():
				return true
			# _skill_levelable() 를 안 쓴다 — 매 프레임 도는 자리라 배열을 새로 만들
			# 이유가 없다. 여기는 "하나라도 있나"만 알면 된다.
			for key in skill_owned:
				if int(skill_owned[key]) >= SkillDefs.MAX_LV:
					continue
				if int(gacha_shards.get("skill:" + str(key), 0)) \
						>= SkillDefs.shard_cost(int(skill_owned[key])):
					return true
	return false


func _refresh_tab_dots() -> void:
	for key in _tab_dots:
		_tab_dots[key].visible = _tab_todo(key)


# 실효 상한 — 스탯 고유 cap 과 승급 공통 상한(미궁 층이 연다) 중 작은 쪽.
func _stat_cap(key: String) -> int:
	var s := StatDefs.of(key)
	var cap := StatDefs.train_cap(dungeon_best, best_stage)
	return mini(cap, int(s["cap"])) if s.has("cap") else cap


# 이번 구매의 실제 단계 수 — 상한 앞에서는 닿을 만큼만.
func _step_for(key: String) -> int:
	var room := _stat_cap(key) - stat_lv(key)
	if buy_step >= 0:
		return mini(buy_step, room)
	# MAX — 지갑이 닿는 데까지, 단 상한을 넘지 않는다. **음수는 절대 안 돌려준다**:
	# 음수 n 이 흘러가면 비용이 음수가 되어 혈액이 늘고 레벨이 준다.
	var st := StatDefs.of(key)
	return clampi(Balance.max_steps(stat_lv(key), gold,
		float(st.get("base", 10.0)), StatDefs.cost_exp(key)), 0, room)


func _buy(key: String) -> void:
	if not StatDefs.is_open(key, StageDefs.major_stage(stage), lv) \
			or stat_lv(key) >= _stat_cap(key):
		return
	# 상한 앞에서는 **닿을 만큼만 산다.** 예전엔 x100 값을 다 받고 레벨만
	# 상한에서 잘랐다 — 묶음이 상한을 걸치면 바가지였다. 값과 단계 수를 같은
	# n 으로 묶는다(표시 가격도 _step_for 를 쓴다 — 다른 n 을 쓰면 가격 거짓말).
	var n := _step_for(key)
	var cost := _buy_cost(key, n)
	if gold < cost:
		return
	var old_max := max_hp()
	gold -= cost
	lv[key] = stat_lv(key) + n
	_apply_hp_growth(old_max)
	_quest_bump("train")
	_save_game()
	_refresh_hud()


# 전투력으로 안 잡히는 스탯이 올랐을 때의 알림. 전투력 알림과 **같은 줄**을 쓴다 —
# 둘이 동시에 뜰 일이 없고(한 번에 한 스탯만 산다), 줄을 늘리면 전투를 가린다.
func _notify_stat(text: String) -> void:
	# 씬을 안 띄운 검사에서도 불린다(가이드 수령 검사). 라벨이 없으면 조용히 넘긴다.
	if _power_toast == null:
		return
	_power_gain = 0.0
	_power_toast_t = POWER_TOAST_TIME
	# 전투력으로 안 잡히는 스탯 — 같은 띠에 문장만 얹는다.
	if _power_band:
		_power_num.text = text
		_power_up.text = ""
		_power_band_show(0.0, 0.0)
		_power_num.text = text


# ── 모바일 수명주기 ────────────────────────────────────────────────────────
#
# **폰은 껐다 켜는 게 아니라 전환이 기본이다.** 앱을 안 죽이고 홈으로 나갔다
# 몇 시간 뒤 돌아온다 — 그 사이를 안 쳐 주면 방치형인데 "들어왔더니 아무것도
# 안 쌓였다"가 된다. 실행할 때만 보던 `left_at` 을 여기서도 본다.
#
# 저장소에 `_notification` 이 한 곳도 없어서(2026-08-27) 셋 다 비어 있었다:
# 뒤로가기는 앱을 바로 껐고, 복귀는 아무 일도 안 했고, 백그라운드에서 OS 가
# 죽이면 마지막 저장 이후가 날아갔다.

# 나간 시각. 0 이면 지금 화면 안에 있다는 뜻이다.
var _away_at := 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_app_paused()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_app_resumed()
		NOTIFICATION_WM_CLOSE_REQUEST:
			# 데스크톱에서 창을 닫을 때. 저장하고 나간다.
			if _hud_root:
				_save_game()


func _app_paused() -> void:
	# 아직 다 안 지어졌으면(로딩 중) 건드리지 않는다.
	if _hud_root == null or _away_at > 0.0:
		return
	_away_at = Time.get_unix_time_from_system()
	# **여기서 저장한다.** 백그라운드에서 OS 가 죽이면 다시 저장할 기회가 없다.
	_save_game()


func _app_resumed() -> void:
	if _hud_root == null or _away_at <= 0.0:
		return
	var at := _away_at
	_away_at = 0.0
	_grant_offline(at)
	# 켤 때와 **같은 함수**를 탄다 — 요율이 갈리면 "전환은 손해"가 된다.
	# 1분 미만은 이 함수가 스스로 걸러내므로 데스크톱 알트탭에는 무해하다.
	_refresh_chest()
	_refresh_hud()


# **뒤로가기가 닫을 팝업들.** 빠뜨리면 그 창이 떠 있는데 탭이 닫히거나 종료
# 확인이 뜬다 — 화면이 하나 밀린 것처럼 읽힌다. 새 팝업을 만들면 여기 넣는다.
# (판 안의 `_stat_view`·`_shop_view` 같은 것은 팝업이 아니라 탭 내용이라 뺀다.)
func _popups() -> Array:
	return [_confirm_view, _reward_view, _info_view, _name_view,
		_outfit_view, _bulk_view, _codex_view, _quest_view,
		_oath_view, _rates_view, _status_view]


# 안드로이드 뒤로가기. **한 겹씩 걷는다** — 팝업 -> 탭 -> 종료 확인.
# 바로 끄면 방치형에서 실수 한 번에 그날 판이 날아간 것처럼 읽힌다.
func _go_back() -> void:
	if _hud_root == null:
		return
	# 맨 위 팝업 하나만 닫는다.
	for v in _popups():
		if v != null and v.visible:
			v.visible = false
			return
	if _tab != "home":
		_select_tab("home")
		return
	_ask("게임을 끝냅니다. 진행은 저장돼 있습니다.", func() -> void:
		_save_game()
		get_tree().quit())


# ── 루프 ───────────────────────────────────────────────────────────────────
# [개발 도구] 프레임 시간 프로브. 2초마다 한 줄 찍는다.
#
# **평균이 아니라 꼬리를 본다.** 60fps 는 16.7ms 인데, 평균이 8ms 라도 매 초
# 한 번 40ms 가 끼면 화면은 끊긴 것으로 읽힌다 — 그래서 최악과 상위 5%(p95)를
# 같이 찍는다. 무엇이 그 프레임을 만들었는지 좁히려고 그 순간의 개수도 같이
# 적는다(몹·시체·이펙트·그리기 호출).
# [개발 도구] 한 구간의 시간을 _perf_spent 에 쌓는다. 프로브가 꺼져 있으면
# 아무 일도 안 한다 — 켜 두지 않으면 비용이 없다.
# ── 자산 미리 데우기 ──────────────────────────────────────────────────────
#
# **왜 필요한가**(2026-08-27 실측): 몹이 처음 공격하거나 죽을 때 그 애니의
# 프레임을 그 자리에서 읽어 디코드한다. `Assets.reach_peak_frame` 은 프레임마다
# `get_image()` 를 부르므로 9프레임 보스면 아홉 번이다 — `--perf` 로 재니
# 평타 구간이 한 창에서 **194.7ms** 를 찍고 그다음 창엔 9.8ms 였다. 신규 몹
# 15종(245장)이 들어오면서 더 두드러졌다.
#
# 그래서 막이 바뀔 때 그 막이 쓸 폴더를 줄에 세워 두고 **프레임마다 하나씩**
# 데운다. 한 칸이 곧 한 폴더이고, 데우는 값은 Assets 가 캐시에 넣는다.
func _warm_enqueue_act() -> void:
	var act: Dictionary = _c_act_data()
	var keys: Array = (act.get("roster", []) as Array).duplicate()
	keys.append(str(act.get("boss", "")))
	for k in keys:
		if str(k) == "":
			continue
		for m in ["walk", "attack", "special"]:
			var dir := "res://assets/anim/%s_%s" % [str(k), str(m)]
			if not _warm_queue.has(dir):
				_warm_queue.append(dir)


# 줄에서 한 칸을 꺼내 데운다. **전투 중에 하는 일과 같은 것을 미리 한다** —
# 프레임을 올리고, 잉크 폭·발밑 여백·정점 프레임까지 캐시에 넣는다. 여기서
# 안 해 두면 그 계산이 첫 타격 프레임에 통째로 얹힌다.
func _warm_step() -> void:
	# **시간 예산으로 돈다.** 한 프레임에 폴더 하나만 데우면 줄이 45프레임
	# 넘게 남아서, 첫 몹이 공격할 때까지 못 끝난다 — 실측에서 평타가
	# 그대로 125ms 를 찍었다. 2ms 안에서 되는 만큼 삼킨다: 평상시 한
	# 프레임이 7.2ms 라 9.2ms 여도 60fps 예산(16.7)에 든다.
	if _warm_queue.is_empty():
		return
	var until := Time.get_ticks_usec() + 2000
	while not _warm_queue.is_empty() and Time.get_ticks_usec() < until:
		_warm_one(_warm_queue.pop_front())
	if _warm_queue.is_empty():
		# 다 데웠으면 편 이미지를 버린다 — 값은 이미 캐시에 들어가 있고,
		# 이미지를 계속 들고 있으면 메모리만 먹는다(폰에서 중요하다).
		Assets.drop_images()


func _warm_one(dir: String) -> void:
	var fr := Assets.frames(dir)
	if fr.is_empty():
		return
	for t in fr:
		Assets.ink_half_width(t)
		Assets.bottom_gap(t)
	Assets.bottom_pad(dir)
	if dir.ends_with("_special"):
		Assets.slam_peak_frame(dir)
	else:
		Assets.reach_peak_frame(dir)


func _perf_mark(key: String, usec: int) -> void:
	if not _perf_probe:
		return
	_perf_spent[key] = float(_perf_spent.get(key, 0.0)) \
		+ float(Time.get_ticks_usec() - usec) / 1000.0


func _perf_tick(delta: float) -> void:
	_perf_ms.append(delta * 1000.0)
	_perf_t += delta
	if _perf_t < 2.0:
		return
	_perf_t = 0.0
	var sorted_ms := _perf_ms.duplicate()
	sorted_ms.sort()
	var n := sorted_ms.size()
	var sum := 0.0
	for v in sorted_ms:
		sum += v
	var p95: float = sorted_ms[mini(n - 1, int(float(n) * 0.95))]
	var foes := get_tree().get_nodes_in_group("foes").size()
	var corpses := get_tree().get_nodes_in_group("corpses").size()
	print("[perf] n=%d  평균 %.1fms  p95 %.1fms  최악 %.1fms  |  몹 %d 시체 %d 노드 %d  그리기 %d"
		% [n, sum / float(n), p95, sorted_ms[n - 1], foes, corpses,
		get_tree().get_node_count(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if not _perf_spent.is_empty():
		var spent := PackedStringArray()
		var keys: Array = _perf_spent.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return float(_perf_spent[a]) > float(_perf_spent[b]))
		for k in keys:
			spent.append("%s %.1f" % [str(k), float(_perf_spent[k])])
		print("[perf] 2초간 쓴 시간(ms): " + "  ".join(spent))
		_perf_spent.clear()
	_perf_ms.clear()


func _process(delta: float) -> void:
	play_time += delta
	if _perf_probe:
		_perf_tick(delta)
	# 프레임마다 한 칸. 줄이 비어 있으면 곧바로 돌아온다.
	var _pw := Time.get_ticks_usec()
	_warm_step()
	_perf_mark("데우기", _pw)
	_drop_tick(delta)
	if _dev_shatter:
		# [개발 도구] 0.9초마다 교전 몹을 그 자리에서 흩뿌린다(안 죽인다).
		# 터짐이 0.75초라 한 방 캡처는 운이다 — --slam 과 같은 길.
		_shatter_demo_t -= delta
		if _shatter_demo_t <= 0.0:
			_shatter_demo_t = 1.05
			if is_instance_valid(_engaged) and not _engaged.dying:
				# **느리게 돌린다.** 터짐이 1초도 안 되는데 부팅 시간이 들쭉날쭉해
				# --wait 로 그 창을 맞추는 건 운이었다(여러 번 놓쳤다). 8배 늦추면
				# 아무 때나 찍어도 잡힌다 — 튜닝은 눈으로 보고 해야 한다.
				_shatter(_engaged)
	if _slam_demo != "":
		_slam_demo_t -= delta
		if _slam_demo_t <= 0.0:
			_slam_demo_t = 0.55   # 임팩트가 0.45초 - 주기를 붙여야 캡처가 운이 아니다
			# **실전 숫자를 쓴다.** 실측(2026-08-27): 영웅-보스 간격 중간 59px,
			# 특수 사거리 촉수 412 · 음파 464 · 처형 243 · 유령 231 px.
			# 예전엔 보스를 hero_x+170 에, 사거리를 190 으로 놓고 그려서 캡처가
			# 실전과 딴판이었다 — 그 그림을 보고 판단하면 틀린다.
			var demo_boss := hero_x + 59.0
			_slam_wave(_slam_at_x(str(FoeTiers.slam_theme(_slam_demo)[0]), demo_boss),
				412.0, _slam_demo, 1.0)
	_tick_hero_state(delta)
	var visual_frozen := _visual_hitstop_t > 0.0
	_visual_hitstop_t = maxf(0.0, _visual_hitstop_t - delta)
	_hitstop_cd = maxf(0.0, _hitstop_cd - delta)
	_shake_cd = maxf(0.0, _shake_cd - delta)
	var _pf := Time.get_ticks_usec()
	_tick_motion(0.0 if visual_frozen else delta)
	_perf_mark("모션", _pf)
	queue_redraw()   # 그림자는 몹이 움직일 때마다 다시 그려야 한다
	_boss_pan_t = maxf(0.0, _boss_pan_t - delta)
	# 연속 도전 — 암전이 걷히고 판이 비었을 때 다시 들어간다.
	if _raid_again != "" and _fade_t <= 0.0 and raid_on == "" and not dungeon_on:
		var again_kind := _raid_again
		_raid_again = ""
		_raid_enter(again_kind)
	_fade_t = maxf(0.0, _fade_t - delta)
	# 소탕 — 미궁 최고 기록이 곧 광산이다. 어디에 있든 시간당 최고층x0.2 로 쌓인다
	# (EXPANSION 6장). 초당으로 나누면 값이 작아 화면 숫자는 몇 분에 1씩 는다 —
	# 그게 맞다: 소탕은 배경 수입이고, 목돈은 첫 돌파가 준다.
	if dungeon_best > 0:
		crystal += _sweep_per_hour() / 3600.0 * delta
	var _pa := Time.get_ticks_usec()
	_tick_titles(delta)
	_perf_mark("1초틱", _pa)
	if _power_toast_t > 0.0:
		_power_toast_t -= delta
		if _power_toast_t <= 0.0:
			_power_gain = 0.0   # 다음 상승은 처음부터 다시 센다
			if _power_band and _power_band.visible:
				var ft := _power_band.create_tween()
				ft.tween_property(_power_band, "modulate:a", 0.0, 0.25)
				ft.tween_callback(func() -> void:
					_power_band.visible = false)

	var foes := get_tree().get_nodes_in_group("foes")
	if _tick_boss_timer(delta):
		_refresh_hud()
		return
	var _pb := Time.get_ticks_usec()
	_tick_advance(delta, foes)
	_perf_mark("전진", _pb)
	var _pc := Time.get_ticks_usec()
	_tick_engage(foes)
	_perf_mark("교전", _pc)
	for f in foes:
		if is_instance_valid(f):
			f.set_visual_frozen(visual_frozen)
			f.set_combat_active(_phase == "fight" and not _hero_dead)
			f.engaged = f == _engaged
			# 영웅 위치를 넘겨 **닿을 때만 휘두르게** 한다. 예전엔 사거리와 무관하게
			# 스윙을 시작하고 임팩트 때 빗나갔다 — 6칸 중 절반 이상이 매번 그랬고,
			# 화면에서는 "몹이 때리는데 아무 일도 안 일어난다"로 보인다.
			f.hero_x = hero_x
	var _pd := Time.get_ticks_usec()
	_tick_skills(delta, foes)
	_perf_mark("스킬", _pd)
	var _pe := Time.get_ticks_usec()
	_tick_hero_attack(delta, foes)
	_perf_mark("평타", _pe)
	_tick_dash(delta)
	_refresh_hud()
	# [개발 도구] --gaps : 영웅과 몹이 겹치는 순간만 골라 찍는다.
	# **눈으로는 "겹쳐 보이네"까지밖에 못 간다.** 얼마나, 어떤 몹과, 걸어오는 중인지
	# 서 있는 중인지가 나와야 원인이 갈린다(자리 계산이냐 칸 간격이냐).
	if _gap_probe:
		_gap_t += delta
		if _gap_t >= 0.25:
			_gap_t = 0.0
			for f in foes:
				if not is_instance_valid(f) or f.dying:
					continue
				# **잉크로 잰다.** 상자(_size()*0.5)로 재면 한쪽당 6px 씩 과장돼
				# 화면에서는 안 닿는데 겹쳤다고 나온다 — 그 수치로 칸을 옮기면 과보정된다.
				var clr: float = absf(f.position.x - hero_x) - f.body_half() - BODY_HALF
				# **영웅이 멈춰 있는지도 같이 찍는다.** 큰 겹침은 대부분 대시로
				# 지나가는 중인데, 그게 안 찍히면 서 있는 겹침과 구분이 안 돼서
				# 고칠 수 없는 값을 고치려 들게 된다.
				var settled := absf(_dash_to - hero_x) <= 1.0
				# **양쪽을 다 찍는다.** 예전엔 겹침(음수)만 찍었다 — 자가 한쪽으로만
				# 열려 있으면 반대쪽 고장은 아무리 돌려도 안 잡힌다. 실제로 겹침을
				# 없애고 나니 이번엔 "멀리서 싸운다"가 남았는데 지표에는 안 보였다.
				# 겹침은 아무 몹이나 다 찍는다 — 몸이 겹치면 누구든 눈에 띈다.
				# 뜸은 **지금 상대하는 몹만** 찍는다. 다른 칸 몹과는 원래 멀고,
				# 그걸 같이 찍으면 진짜 문제가 잡음에 묻힌다(첫 판이 그랬다).
				var fighting := settled and absf(_strike_spot(f) - hero_x) <= 1.0
				if clr < -1.0 or (fighting and clr > GAP_MAX):
					print("%s %6.1f  영웅 %6.1f %s  %s %6.1f  몹도착 %s"
						% [("겹침" if clr < 0.0 else "뜸  "), clr, hero_x,
						("정지" if settled else "대시중"),
						f.display_name, f.position.x, str(_foe_arrived(f))])


# 자동 공격은 모션 시작이 아니라 7프레임 중 네 번째에 피해가 들어간다. 예약한 대상이
# 그 전에 사라졌으면 피해도 이펙트도 만들지 않는다.
# **순차 교전 관리.** 가장 가까운 놈 하나와만 싸운다. 죽으면 전진이 다시 시작되고
# (`_tick_advance`) 다음 놈이 전열로 흘러 들어온다.
#
# **몹 자리를 만지지 않는다**(2026-08-06). 예전엔 교전 몹을 전열로 끌어당기고 대기 몹을
# 앞칸으로 당겼는데(`_reflow_side`), 그건 "웨이브가 몰려온다"의 장치였다. 몹이 서 있고
# 영웅이 찾아가는 지금은 당길 것이 없다 — 간격은 스폰 때 `FOE_GAP` 으로 정해지고
# `_advance_world` 가 그 간격을 유지한 채 통째로 민다.
# 처치하고 다음 표적을 잡기까지의 박자. 옛 Foe.DIE_DUR 값이다 — 사망
# 연출을 늘려도 전투 페이스는 그대로여야 한다(수입 곡선이 여기 걸려 있다).
const ENGAGE_PAUSE := 0.42


func _tick_engage(foes: Array) -> void:
	if _phase != "fight":
		_engaged = null
		return
	if is_instance_valid(_engaged) and not _engaged.dying:
		return
	# 사망 연출 중에는 다음을 안 부른다 — 그 박자가 "처치했다"를 읽게 한다.
	# **연출 전체를 기다리지는 않는다.** Foe.DIE_DUR 를 늘린 건 그림을
	# 부드럽게 하려는 것이지 전투를 느리게 하려는 게 아니다 — 시체가
	# 무너지는 동안 영웅은 다음 놈에게 간다(2026-08-25).
	if is_instance_valid(_engaged) and _engaged.dying \
			and _engaged.dying_t < ENGAGE_PAUSE:
		return
	_engaged = null
	var best := INF
	for f in foes:
		if not is_instance_valid(f) or f.dying:
			continue
		var d := absf(f.position.x - hero_x)
		if d < best:
			best = d
			_engaged = f


# 불멸의 심장 — **버프가 도는 동안 기본공격이 광역이 된다**(2026-08-10 사장님:
# "기본공격실현시 몬스터를 광역으로 공격하는 붉은검기가 나감").
#
# 이미 맞은 놈은 빼고 **나머지**에게 같은 피해를 넣는다. 검기는 무리 가운데 하나만
# 띄운다 — 오늘 정한 "광역은 가운데 하나" 규칙과 같다.
#
# 이건 `dps()` 가 모르는 피해다(평타 한 번이 여러 마리를 때린다). 오프라인 모델은
# 한 마리씩 세므로 **방치 수익이 늘지 않는다** — 실제로만 빨라진다. 그쪽이 안전한
# 방향이라 그대로 둔다(반대면 과지급이 된다).
# ponytail: 버프 가동률까지 오프라인에 넣으려면 Balance 쪽에 축을 하나 더 세워야 한다.
# 군림 III — 3연격 마무리 광역. 불멸의 심장 검기(fx_cleave_wave)를 그대로 쓴다:
# 버프 기준(_summon_*)을 잠깐 세워 `_cleave_swing` 을 지나가게 하는 게 아니라,
# 같은 몸통을 공유하는 별도 진입로를 둔다 — 버프 상태를 흉내 내면 만료 코드가
# 그 가짜 상태를 밟는다.
var _pending_finisher := false


func _mastery_cleave(hit_already: Foe) -> void:
	var rest: Array[Foe] = []
	for f in _aoe_targets():
		if f != hit_already:
			rest.append(f)
	if rest.is_empty():
		return
	var mid := 0.0
	for f in rest:
		f.take_damage(_combat_damage(f))
		mid += f.position.x
	mid /= float(rest.size())
	_anim_fx("fx_cleave_wave", Vector2(mid, ground_y - float(Grid.SPRITE)),
		16.0, 1.6, "sweep", 0, 1.0, hero_face, 1.0)


func _cleave_swing(hit_already: Foe) -> void:
	# 박쥐 폭풍(계약) — 가호 없이도 평타가 광역이 된다.
	if (_summon_t <= 0.0 or _summon_cleave.is_empty()) \
			and _oath_val("cleave") <= 0.0:
		return
	var rest: Array[Foe] = []
	for f in _aoe_targets():
		if f != hit_already:
			rest.append(f)
	if rest.is_empty():
		return
	var mid := 0.0
	for f in rest:
		f.take_damage(_combat_damage(f))
		mid += f.position.x
	mid /= float(rest.size())
	_anim_fx(_summon_cleave if _summon_t > 0.0 and not _summon_cleave.is_empty() \
		else "fx_cleave_wave",
		Vector2(mid, ground_y - float(Grid.SPRITE)),
		16.0, 1.6, "sweep", 0, 1.0, hero_face, 1.0)


func _tick_hero_attack(delta: float, foes: Array) -> void:
	if _hero_hit_t >= 0.0:
		_hero_hit_t -= delta
		if _hero_hit_t <= 0.0:
			_hero_hit_t = -1.0
			if _can_hit_foe(_pending_target):
				_pending_target.take_damage(_combat_damage(_pending_target))
				_anim_fx("fx_cleave", _pending_target.position + Vector2(0, -28), 18.0, 2.0)
				_cleave_swing(_pending_target)
				# 군림 III — 3연격 마무리는 불멸의 심장과 같은 검기로 광역이 된다.
				# 새 기계 없음: 버프 광역(_cleave_swing)의 기준을 잠깐 세워 재사용한다.
				if _pending_finisher and MasteryDefs.has("cleave3", best_stage) \
						and (_summon_t <= 0.0 or _summon_cleave.is_empty()):
					_mastery_cleave(_pending_target)
			_pending_target = null
	if _hero_dead:
		return
	# 쿨다운은 **전진 중에도, 스킬 중에도 돈다.**
	#
	# 전진: 예전엔 phase 가드가 이 줄 **위에** 있어서 몹에게 달려가는 동안 쿨다운이
	# 얼어붙었다가, 마주친 뒤에야 0.60초를 처음부터 셌다 — 화면에서는 "붙어서 한참
	# 멈췄다가 공격"으로 보인다(사장님). 실측: 사거리 진입 -> 첫 피해 0.56초(중간 0.60,
	# 최대 0.87). 그 앞의 두 구간(표적 선정·이동)은 0.00초였다.
	#
	# 스킬: 같은 실수를 여기서 이미 한 번 했다 — 스킬 중에 통째로 빠져나가서 끝난 뒤
	# 남은 쿨다운을 처음부터 기다렸고, 네 형태를 다 끼면 시간의 22%가 스킬인데 그만큼
	# 기본공격이 두 번 지연됐다(계측: CombatRulesTest "계측 C").
	#
	# 칼을 뽑아 든 채로 달리는 것이지 쉬는 것이 아니다. 스윙 타이머는 계속 돈다.
	_attack_t -= delta
	if _phase != "fight":
		return
	if _skill_action != "":
		# 표적을 다시 고르지는 않지만(모션이 끊긴다) **자리는 따라간다.** 전열을
		# ±56 에서 ±120 으로 밀면서 굳은 자리와 표적 사이가 최대 68px 까지 벌어졌다
		# (실측). 그러면 스킬이 통째로 허공을 친다.
		if is_instance_valid(_engaged) and not _engaged.dying and _foe_arrived(_engaged):
			_dash_to = _strike_spot(_engaged)
		return
	# **표적은 교전 몹 하나다.** 고르는 건 _tick_engage 가 한다. 죽는 동안은
	# 표적이 없어서 영웅이 잠깐 선다 — 그 박자가 "처치했다"를 읽게 한다.
	var target: Foe = _engaged if is_instance_valid(_engaged) and not _engaged.dying else null
	if target == null:
		return
	hero_face = 1 if target.position.x >= hero_x else -1
	# **자리는 늘 몸통 바로 바깥을 겨눈다.** 예전엔 사거리에 들어오면 `_dash_to = hero_x`
	# 로 그 자리에 못 박았는데, `_in_front_reach` 는 "때릴 수 있나"이지 "제 자리인가"가
	# 아니다 — `_stand_ok` 이 가장 짧은 근접 모션 사거리(_front_reach, 51px)까지
	# 허용하므로 밴드의 **먼 쪽 끝**에서 멈춘다. 몹을 hero_x 앞으로 끌어당기던 동안은
	# 틈이 0 이라 안 드러났고, 고정 칸으로 바꾸자 몸통에서 21px 떨어져 팼다(실측).
	# 넉백으로 밀려도 이 값이 다시 당겨 준다.
	_dash_to = _strike_spot(target)
	# **나가는 거리를 못 박는다.** 표적은 줄에서 가장 가까운 놈인데 그놈이 아직 저
	# 뒤에 있을 수 있다 — 그냥 두면 영웅이 화면 밖까지 쫓아간다(실측: 중앙에서
	# 172px, 화면 전체). 전진은 세상을 미는 쪽이 하고(`_advance_world`), 영웅의
	# 화면 이동은 전열까지로 묶는다.
	#
	# 한계는 **전열이 아니라 전열의 몹을 칠 자리**다(120 - 몸통 = 65). 전열(120)로
	# 잡으면 영웅이 거기까지 나가 서서 기다리는데, 그건 마주 걷는 게 아니라 먼저
	# 가서 진 치는 그림이다.
	var park: float = FRONT_X - (target.body_half() + BODY_HALF)
	_dash_to = clampf(_dash_to, minf(HERO_X, park), maxf(HERO_X, park))
	# 사거리 밖이면 달려간다. 붙는 동안 공격 쿨다운은 계속 돌아서 도착하면 바로 친다.
	#
	# **움직일 때만 대시 모션이다.** 마주 나가는 거리를 `park` 로 제한한 뒤로 "자리에는
	# 닿았는데 몹이 아직 걸어오는" 구간이 생겼는데, 거기서 dash 를 계속 재생하면
	# 제자리에서 달리는 그림이 된다 — 실측 dash 프레임의 **62%**가 그랬다
	# (사장님: "달리는데 앞으로 안 나가고 제자리에서 걷는다").
	if not _in_front_reach(target):
		_play("dash" if absf(_dash_to - hero_x) > 1.0 else "idle")
		return
	if _attack_t > 0.0:
		return
	var interval := attack_interval()
	_attack_t = interval
	# 피해는 **스윙 안에서** 들어온다. 주기로 재면 짧게 휘두르고도 피해는 늦게 나가
	# 그림과 결과가 어긋난다.
	# **임팩트는 그 연격의 그림에서 잰다.** "attack" 으로 고정하면 2·3연격의 뻗는
	# 순간과 피해 시점이 어긋난다 — 모션마다 뻗는 프레임이 다르다.
	var swing := _attack_motion()
	_hero_hit_t = _impact_time(swing, _attack_swing())
	_pending_target = target
	# 군림 III(파도베기) — 이 스윙이 3연격 마무리인지 **시작할 때** 기억한다.
	# 명중 시점에는 _combo 가 이미 다음으로 넘어가 있어 그때 물으면 늘 틀린다.
	_pending_finisher = swing == "attack3"
	_play(swing)
	_combo += 1


# 표적이 없을 때도 **몹 몸통 안에는 안 선다.**
#
# `_strike_spot` 은 표적이 있을 때만 불린다. 그런데 `_tick_hero_attack` 은 스킬
# 시전 중(`SKILL_DUR` 0.70초)에는 통째로 return 해서 표적을 다시 잡지 않는다 —
# 그 사이 큰 몹이 옆 칸에 도착하면 영웅이 대기 자리에 굳은 채로 겹쳐 선다
# (`--gaps` 로 프로스트 골렘과 -15.3 확인).
#
# **잉크로 잰다.** 이건 화면에 겹쳐 보이느냐만 따지는 순수 표시 제약이라,
# 상자로 재면 필요 이상으로 밀어내 대시가 길어진다. 표적이 생기면 다음 프레임에
# `_strike_spot`(상자 기준, 더 넉넉)이 이 값을 덮으므로 서로 싸우지 않는다.
func _clear_idle(x: float) -> float:
	if not is_inside_tree():
		return x
	for f in get_tree().get_nodes_in_group("foes"):
		if not _foe_arrived(f):
			continue
		var need: float = f.body_half() + BODY_HALF
		var d: float = x - f.position.x
		if absf(d) >= need:
			continue
		x = f.position.x + (need if d >= 0.0 else -need)
	return x


# 대시. 모션·공격과 무관하게 매 프레임 자리로 민다 — 공격 중에도 조금씩 파고들어야
# 몹이 죽으면서 밀려나도 계속 닿는다.
func _tick_dash(delta: float) -> void:
	if _hero_dead:
		return
	var fighting := _phase == "fight"
	if not fighting:
		_dash_to = HERO_X   # 자리를 비웠으면 앵커로 돌아온다
	_dash_to = _clear_idle(_dash_to)
	# 넉백은 **대시보다 먼저** 자리를 옮긴다. 맞은 순간 뒤로 밀리고, 그 다음 프레임부터
	# 대시가 다시 파고든다 — 밀림과 되돌아옴이 한 몸이라 "얻어맞았다"가 몸으로 읽힌다.
	if absf(_knock_vx) > 1.0:
		hero_x += _knock_vx * delta
		_knock_vx = move_toward(_knock_vx, 0.0, KNOCK_DECAY * delta)
	# 전투 밖에서는 **걷는 속도**로 움직인다. 대시(240)로 등장하면 화면을 1.4초에
	# 지나면서 걷기 모션을 재생하게 되어 발이 겉돈다 — 지금 고치는 그 버그다.
	var was := hero_x
	hero_x = move_toward(hero_x, clampf(_dash_to, 24.0, Grid.BG.x - 24.0),
		(DASH_SPEED if fighting else ENTER_SPEED) * delta)
	# 화면 안에 묶는다. **등장 중에는 하한을 푼다** — 왼쪽 밖에서 걸어 들어오는데
	# 여기서 24 로 잡아 버리면 화면 안에서 튀어나온다(실측: -32 로 놨는데 65.7 이 나왔다).
	hero_x = clampf(hero_x, -float(Grid.SPRITE) if _boss_entry else 24.0,
		Grid.BG.x - 24.0)
	# **실제로 안 움직였으면 달리기를 끈다.** 목표점 검사(_dash_to 대 hero_x)는
	# 목표가 흔들리면(_clear_idle·넉백) 영영 안 맞아서 몹과 맞닿은 채로
	# 제자리 달리기가 남았다(사장님). 움직임 사실만 본다.
	if fighting and _motion == "dash" and is_equal_approx(hero_x, was):
		_play("idle")
	_hero.position.x = hero_x
	_pet_follow(delta)
	# **배경은 영웅이 실제로 움직인 만큼만 흐른다**(PARALLAX 주석 참고). 전투 중에는
	# 안 흘린다 — 결투의 앞뒤 발놀림까지 따라가면 배경이 좌우로 흔들린다.
	if not fighting and not is_equal_approx(hero_x, was):
		_scroll += (hero_x - was) * PARALLAX
		_apply_scroll()
	_hero.flip_h = hero_face > 0


# 모션의 실제 임팩트 프레임에서 불투명 픽셀 끝을 읽는다. **길이**만 돌려준다 —
# 영웅이 좌우로 움직이므로 절대 좌표로 두면 뒤돌아섰을 때 값이 틀린다.
#
# 프레임 번호는 실제 프레임 수에서 비율로 뽑는다. 7프레임이면 3(지금과 동일),
# 8프레임이면 3, 9프레임이면 4 — 모션을 다시 뽑아도 사거리 측정이 따라간다.
# 그 모션에서 피해가 들어갈 프레임. 그림에서 가장 멀리 뻗은 프레임을 쓴다 —
# 이유는 Assets.reach_peak_frame 주석에 있다. 그림이 없으면 옛 고정 비율로 떨어진다.
func _impact_frame(motion: String) -> int:
	var dir := "res://assets/anim/%s_%s" % [skin, motion]
	var n := Assets.frames(dir).size()
	if n <= 0:
		return 0
	return Assets.reach_peak_frame(dir, true)


# 임팩트 프레임이 화면에 떠 있는 **동안**의 시각. 프레임 f 는
# [f/n, (f+1)/n) x 길이 구간에 보이므로 그 가운데를 잡는다.
func _impact_time(motion: String, dur: float) -> float:
	var dir := "res://assets/anim/%s_%s" % [skin, motion]
	var n := Assets.frames(dir).size()
	if n <= 0:
		return dur * IMPACT_RATIO
	return dur * (float(_impact_frame(motion)) + 0.5) / float(n)


# **큰 동작 모션은 여백 있는 캔버스에 뽑는다.** 32x32 에서는 잉크가 이미 26~31칸을
# 차지해서 자세가 바뀔 여지가 2~4px 뿐이고, 배율 2를 곱해도 화면에서 4~8px 다 —
# 프롬프트를 어떻게 쓰든 "크게 휘두르기"도 "달려나가 멈추기"도 "쓰러져 눕기"도
# 물리적으로 안 들어간다(2026-08-06 전 모션 실측).
#
# **그런데 배율은 2.0 그대로 둔다.** 캔버스 폭으로 배율을 나누면 투명 여백까지
# 화면에 맞춰 축소돼서 캐릭터가 절반이 된다(실측: 화면 폭 54~60 -> 28~48).
# 여백은 안 보이는 영역일 뿐이고, 64 캔버스의 아래 여백 16px x 2 = 32 가 정확히
# 발을 ground_y 에 놓는다 — Sprite2D 중심 정렬 + position.y = ground_y - Grid.SPRITE
# 라서 캔버스가 커져도 발 높이가 안 변한다. 아래 frame_reach 도 캔버스 중심
# 기준이라 64 에서 그대로 맞는다.
func _motion_reach(motion: String) -> float:
	var dir := "res://assets/anim/%s_%s" % [skin, motion]
	return Assets.frame_reach(dir, _impact_frame(motion), HERO_DRAW_SCALE, true)


# 근접 사거리는 **쓰는 근접 모션 중 가장 짧은 것**에 맞춘다. 긴 쪽에 맞추면
# 짧은 모션이 허공을 벤다. 근접은 격(strike) 하나뿐이라 그 모션만 보면 된다.
func _front_reach() -> float:
	return minf(_motion_reach("attack"),
		_motion_reach(str(SkillDefs.SHAPES["strike"]["motion"])))


func _foe_arrived(foe: Foe) -> bool:
	return _phase == "fight" and is_instance_valid(foe) and not foe.dying 		and absf(foe.position.x - foe.stop_x) <= 1.0


# 칼끝과 적 외곽 사이의 빈 거리. 좌우 어느 쪽에 있든 같은 식이 되도록 **거리**로만 잰다.
# **잉크로 잰다.** 상자로 재면 빈 캔버스만큼 적이 넓은 셈이 돼서, 보스는 한쪽당
# 20~28px 떨어진 자리를 "몸통 바로 바깥"이라고 잡는다(사장님: 멀리서 싸우는 느낌).
func _foe_gap(foe: Foe) -> float:
	return absf(foe.position.x - hero_x) - foe.body_half()


# 피해 순간에 해당 모션의 실제 픽셀 사거리와 적 외곽을 다시 비교한다.
# **_strike_spot 과 같은 값을 본다.** 모션 사거리가 몸통 절반보다 짧아도 몸이 닿아
# 있으면 맞는 것이 맞다 — 그림상 휘두르는 팔이 짧을 뿐이다.
func _can_hit_foe(foe: Foe, motion: String = "attack") -> bool:
	return _foe_arrived(foe) 		and _foe_gap(foe) <= maxf(_motion_reach(motion), BODY_HALF) + 1.0


# **쓰는 근접 모션이 전부 닿는가.** 대시는 이 기준으로 붙어야 한다 —
# 기본공격(30)만 보고 멈추면 더 짧은 스킬 모션(heavy 24)이 안 닿아서
# 격 스킬이 영영 사거리 밖이 되고, 그러면 쿨다운도 안 돌아 뒤 스킬까지 막힌다.
# **_strike_spot · _can_hit_foe 와 같은 값을 본다.** 셋이 갈리면 영웅이 서는 자리와
# 휘두르는 조건이 어긋나서, 제 자리에 서 놓고도 "아직 멀다"며 dash 만 반복한다 —
# 화면에서는 공격이 가끔 한 대씩 나가는 것으로 보인다("기본공격이 너무 느리다").
func _in_front_reach(foe: Foe) -> bool:
	return _foe_arrived(foe) and _stand_ok(foe, hero_x)


# 영웅 몸통 절반. 32px 원본의 잉크가 30이고 2배로 그리므로 60px, 절반 30이다(실측).
#
# **설 자리와 닿는지 판정이 이 값 하나를 같이 본다.** 예전엔 자리는 모션 사거리로,
# 판정은 모션 사거리로 따로 재서 둘 다 만족하는 거리가 아예 없었다:
#   겹치지 않으려면 |dx| >= 52   ·   닿으려면 |dx| <= 48
# 그래서 영웅이 몹 몸통 안으로 15px 파고든 채로 싸웠다(사장님 지적).
# 8프레임 재생성으로 attack 사거리가 30 -> 20 으로 줄면서 생긴 일이다.
const BODY_HALF := 30.0

# 서 있을 때 몸 사이에 남아도 되는 빈 거리. 이보다 벌어지면 화면에서 "멀리서
# 허공을 친다"로 보인다 — 2배 확대라 8 은 원본 4픽셀이고, 그 이상은 눈에 띈다.
const GAP_MAX := 8.0


# 그 몹을 치려면 서야 할 자리 — 몹 몸통 바로 바깥이다.
func _strike_spot(foe: Foe) -> float:
	var gap := foe.body_half() + BODY_HALF
	return _clear_spot(foe.position.x + (-gap if foe.position.x > hero_x else gap), foe)


# 표적 **아닌** 몹의 몸통 안에는 안 선다. _strike_spot 은 표적 한 마리와의 거리만
# 맞추므로 반대편 칸에 서 있는 몹은 계산에 안 들어가고, 영웅이 그 위로 대시해
# 들어간다(--gaps 로 최대 53px 겹침 확인).
#
# **표적에게 못 닿는 자리로는 안 민다.** 밀어낸 자리가 사거리 밖이면 공격이 통째로
# 멈춘다 — 방금 그 버그를 겪었다. 1차원이라 양쪽이 꽉 차면 밀 데가 없는데, 그때는
# 겹친 채로 두는 게 안 때리는 것보다 낫다.
func _clear_spot(x: float, target: Foe) -> float:
	if not is_instance_valid(target) or not is_inside_tree():
		return x
	for f in get_tree().get_nodes_in_group("foes"):
		if f == target or not _foe_arrived(f):
			continue
		var need: float = f.body_half() + BODY_HALF
		var d: float = x - f.position.x
		if absf(d) >= need:
			continue
		var pushed: float = f.position.x + (need if d >= 0.0 else -need)
		if _stand_ok(target, pushed):
			x = pushed
	return x


# 표적 앞 **제 자리**인가. 위쪽만 보면 몹 몸통 **안**에 서 있어도 "닿는다"가 되어
# 그 자리에서 멈춘다 — 표적이 바뀌는 순간(앞의 몹이 죽고 뒤가 표적이 됨) 영웅이
# 이미 그 몹 안에 있으면 그대로 겹쳐 서서 팼다(--gaps 로 -58px 확인).
const STAND_TOL := 6.0


func _stand_ok(foe: Foe, x: float) -> bool:
	var gap: float = absf(foe.position.x - x) - foe.body_half()
	return gap >= BODY_HALF - STAND_TOL 		and gap <= maxf(_front_reach(), BODY_HALF) + 1.0


# 전진. 영웅은 화면 고정이므로 **세상을 왼쪽으로 민다** — 그게 곧 전진이다.
# 몹·배경이 같은 이동량을 쓰므로 셋이 어긋날 수가 없다(PARALLAX 주석 참고).
#
# `stop_x` 도 함께 민다: 둘이 늘 같아야 몹이 제 자리를 벗어나지 않는다(Foe 는 스스로
# 걷지 않는다). 죽는 중인 놈도 민다 — 시체만 제자리에 남으면 배경에서 미끄러진다.
func _advance_world(dx: float) -> void:
	if not is_inside_tree() or is_zero_approx(dx):
		return
	# **시체도 민다**(Foe._die 가 "corpses" 에 넣어 준다). 시체를 "foes" 에서
	# 빼는 건 표적 선정 때문이지 세상에서 빼려는 게 아니었다 — 아래 장판 주석이
	# 말하는 그 문제가 시체에도 그대로 났다. 실측(2026-08-27): 시체 10구 전부
	# 죽은 뒤 흐른 거리 0.0px, 그동안 배경은 200px/s 로 흘렀다.
	# `notify_pushed` 는 시체에 무해하다 — 걷기 분기가 `not dying` 을 요구한다.
	for f in get_tree().get_nodes_in_group("foes") \
			+ get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(f):
			continue
		f.position.x -= dx
		f.stop_x -= dx
		f.notify_pushed()   # 밀리는 동안만 걷기 모션이 돈다(Foe._draw)
	# **바닥에 놓인 것도 같이 밀린다.** 장판(진)은 화면이 아니라 **땅의 한 자리**다 —
	# 안 밀면 세상이 흐르는데 문양만 화면에 붙어 지면 위를 미끄러진다.
	for n in get_tree().get_nodes_in_group(WORLD_FX_GROUP):
		if is_instance_valid(n):
			n.position.x -= dx
	# **고정된 진은 안 민다**(RULES.screen / RULES.fixed). 밀면 전진하는 동안 왼쪽으로
	# 흘러 나가서, 문양은 저 뒤에 남고 몹은 눈앞에 있는 그림이 된다(2026-08-11 사장님).
	# 그림도 WORLD_FX_GROUP 에 안 넣으므로 위 반복문도 안 탄다 — **둘 중 하나만 하면
	# 그림과 판정이 갈린다.**
	#
	# 대가: 지면에 깔리는 웅덩이는 전진하는 동안 땅 위를 미끄러진다. 문양이 뒤로
	# 밀려나 안 맞는 것보다 이쪽이 낫다는 판단이다.
	if not _field_fixed:
		_field_x -= dx
	_scroll += dx * PARALLAX
	_apply_scroll()


# 전열에 들어온 놈이 있는가. 전진을 멈추고 싸울 근거이자, 다시 달릴 근거다.
func _foe_at_front(foes: Array) -> bool:
	for f in foes:
		if is_instance_valid(f) and not f.dying and f.position.x <= FRONT_X + 1.0:
			return true
	return false


func _tick_hero_state(delta: float) -> void:
	if _hero_dead:
		_revive_t -= delta
		if _revive_t <= 0.0:
			# 그 자리에서 되살아나지 않는다. 쓰러졌으면 그 구간을 못 넘은 것이라
			# 시간 초과와 같은 길로 보내 구간을 처음부터 다시 한다.
			# 미궁에서 쓰러지면 **본편으로 나온다** — 층 기록은 그대로 남는다.
			if dungeon_on:
				_dungeon_exit("미궁에서 쓰러짐")
				return
			if raid_on == "boss":
				_boss_exit("쓰러짐")
				return
			if raid_on == "trial":
				_trial_exit("쓰러짐")
				return
			# 재화 던전도 마찬가지 — 표는 이미 썼고, 빈손으로 나온다.
			if raid_on != "":
				_raid_exit("던전에서 쓰러짐 — 빈손")
				return
			_restart_stage("쓰러짐")
		return
	if _hero_flash_t > 0.0:
		_hero_flash_t -= delta
		if _hero_flash_t <= 0.0:
			_set_hero_flash(0.0)
	# **버프가 도는 동안 영웅이 붉게 물든다**(RULES.tint — 피의 제단). 칼만 따로는
	# 못 물들인다: 영웅이 스프라이트 한 장이라 부위를 못 가른다. 몸 전체가 붉어지면
	# "피를 뒤집어썼다"로 읽혀서 오히려 맞는다.
	#
	# `modulate` 를 쓴다 — 피격 번쩍임은 `self_modulate` 라 서로 안 덮는다(둘은 곱해진다).
	var was_buffed := _summon_t > 0.0
	_summon_t = maxf(0.0, _summon_t - delta)
	if _summon_tint > 0.0 and _hero != null:
		if _summon_t > 0.0:
			var g := 1.0 - _summon_tint
			_hero.modulate = Color(1.0, g, g)
		elif was_buffed:
			_hero.modulate = Color.WHITE
			_summon_tint = 0.0
	# 광역 평타는 **버프가 끝나면 같이 끝난다.** 안 지우면 다음에 다른 가호를 걸었을 때
	# 그 버프에 검기가 따라붙는다 — `_summon_t` 만 보고 이름을 안 비우면 그렇게 샌다.
	if _summon_t <= 0.0 and _summon_cleave != "":
		_summon_cleave = ""
	hero_hp = minf(max_hp(), hero_hp + regen_per_sec() * delta)


# 쿨다운이 찬 스킬을 **장착 순서대로 전부**. 순서가 곧 발동 우선순위다.
func _ready_skills() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in skill_equipped:
		# **패시브는 시전 목록에 안 든다.** 효과는 `_passive_ward_bonus` 가 상시로
		# 준다 — 여기 남겨 두면 쿨마다 모션까지 나가서 "패시브"가 아니게 된다.
		if bool(SkillDefs.rule_of(str(key)).get("passive", false)):
			continue
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
	data["power"] = SkillDefs.power(key, lv) * (1.0 + _skill_combo_bonus(key)) \
		* _trait_mult("skill")
	data["fx"] = SkillDefs.fx_of(key)
	# 피격 이펙트를 스킬이 끌 수 있다(RULES.no_hit_fx) — 웅덩이는 틱마다 24장이 떠서
	# 정작 웅덩이가 안 보였다.
	data["hit_fx"] = "" if bool(SkillDefs.rule_of(key).get("no_hit_fx", false)) \
		else SkillDefs.hit_fx_of(key)
	# 가호는 피해가 0이라 위 power 로는 등급이 안 갈린다. 배수·지속을 따로 얹는다 —
	# 안 하면 레전더리 가호와 커먼 가호가 글자만 다른 같은 스킬이 된다.
	# **동작이 버프면** 배수·지속을 얹는다 — 형태가 아니다. 피의 제단은 진(field)인데
	# 버프로 동작하므로(RULES.as = ward) 여기서 형태를 보면 값이 안 붙는다.
	if SkillDefs.behavior_of(key) == "ward":
		data["bonus"] = SkillDefs.ward_bonus(key)
		data["duration"] = SkillDefs.ward_duration(key, lv)
	# **동작이 곧 대상 규칙이다** — 형태가 아니다. 스킬이 형태를 덮어쓰면(RULES.as)
	# 조준 규칙도 같이 따라가야 한다. 표에 target 을 또 적으면 둘이 어긋난다.
	data["act"] = SkillDefs.behavior_of(key)
	data["target"] = {"strike": "melee", "wave": "area", "field": "area",
		"ward": "self"}[str(data["act"])]
	return data


# 조합 버프. 같은 형태를 모으거나 네 형태를 다 펼치거나 — 둘 다 이득이다.
func _skill_combo_bonus(key: String) -> float:
	var same: Dictionary = SkillDefs.combo_power(skill_equipped)
	return float(same.get(SkillDefs.split(key)[0], 0.0)) \
		+ SkillDefs.combo_spread(skill_equipped)


# 슬롯을 비워 두면 그만큼 손해다. 방치형에서 매번 고르게 하면 방치가 아니라서
# 자동으로 채운다 — 형태를 골고루 먼저 채우고 남은 칸을 센 것부터 메운다.
# ── 프리셋 ────────────────────────────────────────────────────────────────
#
# 저장본이 짧거나 길거나 엉뚱한 타입이어도 **PRESETS 칸으로 맞춘다.** 옛 저장본
# 에는 이 키가 아예 없고, 칸 수를 나중에 늘릴 수도 있다 — 화면이 인덱스로
# 접근하므로 길이가 어긋나면 그 자리에서 터진다.
func _preset_load(raw: Variant, empty: Variant) -> Array:
	var out: Array = []
	var src: Array = raw if raw is Array else []
	for i in PRESETS:
		var v: Variant = src[i] if i < src.size() else null
		if typeof(v) != typeof(empty):
			v = (empty as Variant).duplicate()
		out.append(v)
	return out


# 지금 장착을 n 번 칸에 담는다.
func _preset_save(kind: String, n: int) -> void:
	if n < 0 or n >= PRESETS:
		return
	if n >= (skill_presets.size() if kind == "skill" else gear_presets.size()):
		return
	if kind == "skill":
		skill_presets[n] = skill_equipped.duplicate()
	else:
		# **장비 dict 가 아니라 inventory_key 만** 담는다. 통째로 담으면 레벨을
		# 올렸을 때 프리셋이 옛 수치로 굳어 되돌리는 순간 능력치가 깎인다.
		var row := {}
		for slot in equipped.keys():
			var k := str((equipped[slot] as Dictionary).get("inventory_key", ""))
			if k != "":
				row[str(slot)] = k
		gear_presets[n] = row
	_save_game()


# n 번 칸을 꺼내 낀다. **없어진 것은 조용히 건너뛴다** — 팔았거나 조합에 쓴
# 장비, 아직 안 뽑은 스킬이 프리셋에 남아 있는 것은 정상이다. 거기서 터지면
# 프리셋을 한 번 저장한 뒤로는 장비를 못 판다.
func _preset_apply(kind: String, n: int) -> bool:
	if n < 0 or n >= PRESETS:
		return false
	if n >= (skill_presets.size() if kind == "skill" else gear_presets.size()):
		return false
	if kind == "skill":
		var want: Array = skill_presets[n]
		var keep: Array[String] = []
		for k in want:
			if skill_owned.has(str(k)) and not keep.has(str(k)) \
					and keep.size() < _equip_cap():
				keep.append(str(k))
		if keep.is_empty():
			return false
		# **프리셋을 고르면 자동 장착이 꺼진다**(사장님 확정). 안 끄면 다음
		# 레벨업·뽑기에서 _auto_equip_skills 가 덮어써서 고른 것이 사라진다.
		skill_auto_equip = false
		skill_equipped = keep
		_refresh_skills()
		_save_game()
		return true
	var row: Dictionary = gear_presets[n]
	var old_max := max_hp()
	var hit := false
	for slot in row.keys():
		var key := str(row[slot])
		if not gear_inventory.has(key):
			continue
		var item: Dictionary = (gear_inventory[key] as Dictionary).duplicate(true)
		item["inventory_key"] = key
		equipped[str(slot)] = item
		hit = true
	if not hit:
		return false
	_apply_hp_growth(old_max)
	_refresh_gear_slots()
	_refresh_gear_inventory()
	_refresh_hud()
	_save_game()
	return true


# 그 칸이 비었나 — 화면이 "저장 안 됨"으로 흐리게 그린다.
func _preset_empty(kind: String, n: int) -> bool:
	# **배열 크기까지 본다.** 화면은 _load_game 보다 먼저 그려질 수 있고 그때는
	# 배열이 비어 있다 — PRESETS 만 보고 들어가면 인덱스가 튄다(실측).
	var src: Array = skill_presets if kind == "skill" else gear_presets
	if n < 0 or n >= PRESETS or n >= src.size():
		return true
	return (skill_presets[n] as Array).is_empty() if kind == "skill" \
		else (gear_presets[n] as Dictionary).is_empty()


# 프리셋 줄 하나. **스킬·장비가 같은 줄을 쓴다** — 두 화면에서 문법이
# 달라지면 어느 쪽이 저장인지 매번 헷갈린다.
#
#   [저장]  [1] [2] [3]
#
# 저장이 꺼져 있으면 번호 = 꺼내기, 켜져 있으면 번호 = 담기. 담고 나면 저장이
# 자동으로 꺼진다 — 켠 채로 두면 다음에 꺼내려다 덮어쓴다.
func _preset_row(parent: Control, kind: String, y: float) -> void:
	var wbtn := Ui.button("저장", Vector2(PAD, y), Vector2(96.0, 34.0),
		Type.SIZE_SMALL)
	wbtn.toggle_mode = true
	wbtn.pressed.connect(func() -> void:
		_preset_write[kind] = not bool(_preset_write[kind])
		_refresh_presets(kind))
	parent.add_child(wbtn)
	_preset_write_btns[kind] = wbtn
	var bw := (CONTENT_W - 96.0 - 12.0 * 3.0) / 3.0
	var row: Array = []
	for i in PRESETS:
		var n := i
		var b := Ui.button(str(n + 1),
			Vector2(PAD + 96.0 + 12.0 + float(i) * (bw + 12.0), y),
			Vector2(bw, 34.0), Type.SIZE_SMALL)
		b.pressed.connect(func() -> void: _preset_tap(kind, n))
		parent.add_child(b)
		row.append(b)
	_preset_btns[kind] = row


func _preset_tap(kind: String, n: int) -> void:
	if bool(_preset_write[kind]):
		_preset_save(kind, n)
		# 담고 나면 저장을 끈다 — 켠 채로 두면 다음에 꺼내려다 덮어쓴다.
		_preset_write[kind] = false
	else:
		# 빈 칸은 꺼내기 모드에서 아예 못 누르게 해 두므로, 여기 오면
		# 담긴 게 다 없어진 경우다(판 장비·안 가진 스킬). 조용히 넘긴다 —
		# 알림 장치를 새로 만들 만한 일이 아니다.
		_preset_apply(kind, n)
	_refresh_presets(kind)


func _refresh_presets(kind: String) -> void:
	var wbtn: Variant = _preset_write_btns.get(kind)
	if wbtn == null:
		return
	var on := bool(_preset_write[kind])
	(wbtn as Button).set_pressed_no_signal(on)
	(wbtn as Button).text = "저장할 칸" if on else "저장"
	for i in (_preset_btns[kind] as Array).size():
		var b: Button = (_preset_btns[kind] as Array)[i]
		# 빈 칸은 흐리게 — 눌러 보기 전에 어디가 찼는지 보여야 한다.
		var empty := _preset_empty(kind, i)
		b.modulate = Color(0.62, 0.62, 0.68) if empty else Color.WHITE
		# **빈 칸은 꺼내기 모드에서 못 누른다.** 눌러도 아무 일이 없으면
		# 고장으로 읽히는데, 못 누르게 하면 알림 장치가 아예 필요 없다.
		b.disabled = empty and not on


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
		if picked.size() >= _equip_cap():
			break
		if not picked.has(str(key)):
			picked.append(str(key))
	skill_equipped = picked.slice(0, mini(picked.size(), _equip_cap()))


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
	_skill_hit_t = _impact_time(str(skill["motion"]), SKILL_DUR)
	_skill_impact_sent = false
	_skill_cd[_skill_action] = float(skill["cooldown"])
	_skill_target = target
	_play(str(skill["motion"]), SKILL_DUR)


# 스킬은 **제 표적을 보고 쏜다.** hero_face 는 기본공격이 표적을 잡을 때만 갱신돼서,
# 반대편 몹에게 스킬이 나가면 투사체가 등 뒤로 날아갔다(사장님 지적). 몸도 같이
# 돌려야 "저쪽을 보고 쐈다"가 되고, 안 그러면 뒤통수로 쏘는 그림이 된다.
func _face_toward(target: Foe) -> void:
	if target == null or not is_instance_valid(target):
		return
	# hero_face 만 바꾸면 된다 — 그림 뒤집기는 _tick_dash 가 매 프레임 이 값으로 한다.
	hero_face = 1 if target.position.x >= hero_x else -1


# 지금 살아서 제 자리에 선 몹 중 가장 가까운 놈. 광역 스킬이 어느 쪽을 보고
# 터질지 정하는 데 쓴다 — 여섯 마리가 양쪽에 있어도 방향은 하나여야 한다.
func _nearest_foe() -> Foe:
	var best: Foe = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("foes"):
		if not _foe_arrived(f):
			continue
		var d: float = absf(f.position.x - hero_x)
		if d < best_d:
			best_d = d
			best = f
	return best


# 장판(진). 바닥에 깔아 두고 **지속시간 동안 초당 tick_rate 번**, 그때 문양 위에 서
# 있는 놈을 때린다. 우리 유일한 다단히트 스킬이다.
#
# **판정이 화면이 아니라 진의 자리다.** 다른 광역은 "화면 안"으로 잡지만(`_aoe_targets`)
# 장판은 땅의 한 자리라 그 자리에 있는 놈만 맞아야 한다 — 그래야 "서 있으면 맞는다"가
# 규칙이 되고, 영웅이 전진해 지나가면 뒤에 남는다.
#
# **판정 폭은 아트 폭에서 안 나온다**(2026-08-06 에 바꿨다). 원래는 그림 폭 = 판정 폭
# 이었고 그게 정직하긴 했지만 64px 문양이 160px 간격을 못 덮어 **한 번에 한 마리**였다.
# 넓은 한 장(384px)을 세 번 뽑아 봤고 셋 다 못 썼다: 첫 판은 돌바닥 타일이 딸려 왔고,
# 피만 그린 판은 가운데만 진해서 **둘째 몹 자리 잉크가 1%** 였다(실측). 생성기는
# 주제를 가운데로 모으므로 폭을 고르게 채운 문양은 안 나온다.
#
# 그래서 **맞는 놈마다 문양을 하나씩 깐다.** 혈우(`wave_rare`)가 이미 그 방식이고
# 사장님이 광역으로 읽히는 건 그것뿐이라고 했다. 피해가 들어가는 자리에는 항상 그림이
# 있으니, 판정 폭을 그림보다 넓혀도 "안 보이는 데서 때리기"가 생기지 않는다 —
# 아트 폭 결합을 뗀 대가를 대상마다 그리는 것으로 치른다.
#
# 왜 Area2D 가 아닌가: 도형을 세우면 크기를 이펙트와 따로 관리해야 하고 둘이 조용히
# 갈린다(이번에 겪은 `fx_y` 문제와 같은 종류). 지금은 숫자 하나(FIELD_REACH)뿐이다.
# ponytail: 세로 축이나 비원형 범위가 생기면 Area2D 로 올린다.
#
# **틱마다 표적을 다시 고른다.** 깔 때의 목록을 들고 있으면 죽은 놈에게 계속 넣거나
# freed 된 놈을 잡는다. `_defer_stage_advance` 로 한 틱을 묶어 구간 넘김이 틱 도중에
# 끼어드는 것을 막는다.
const WORLD_FX_GROUP := "world_fx"
# 진의 판정 반폭 = **몹 두 칸**(FOE_GAP 160 기준으로 0 과 +160 을 덮고 +320 은 못 덮는다).
# 세 칸까지 늘리면 커먼 광역 하나가 화면에 보이는 몹을 전부 쓸어서 평타가 할 일이 없다.
const FIELD_REACH := 180.0
var _field_x := 0.0        # 진의 중심 x. _advance_world 가 같이 민다
# 이번 진의 판정 반폭. 기본은 FIELD_REACH 이고 `screen` 규칙이면 화면 폭이다.
# **상수를 직접 읽지 않고 이 값을 읽는다** — 두 군데가 각자 상수를 보면 규칙을 얹는
# 순간 그림과 판정이 갈린다(이 저장소가 여러 번 밟은 부류다).
var _field_reach := FIELD_REACH
# 이번 진이 **화면에 고정**인가(RULES.screen). 그러면 `_advance_world` 가 중심을
# 안 밀고 그림도 월드 그룹에 안 들어간다 — 둘 중 하나만 하면 그림과 판정이 갈린다.
var _field_fixed := false
var _field_gen := 0        # 구간이 바뀌면 올라간다. 지난 구간의 틱을 끊는 표


func _start_field(fx: String, fps: float, scale: float, style: String, echo: int,
		skew: float, per_tick: float, ticks: int, gap: float,
		skill: Dictionary) -> void:
	var rule := SkillDefs.rule_of(str(skill.get("key", "")))
	var puddle := float(rule.get("puddle", 0.0))
	var cap := int(rule.get("max_targets", 0))
	var pit := bool(rule.get("pit_kill", false))
	var exec_at := float(rule.get("execute", 0.0))   # 처형 문턱 (최대 체력 비율)
	if exec_at > 0.0:
		exec_at += _exec_bonus()   # 군림 II — 왕의 선고
		exec_at += _oath_val("exec")   # 왕좌의 명령 — 계약 버프
	# 갈라진 대지 — **바닥이 흔들린다**(사장님). 깔릴 때 크게, 틱마다 잔진동.
	# SHAKE_MIN_GAP 이 겹침을 걸러 주므로 틱마다 불러도 화면이 안 얼어붙는다.
	var quake := float(rule.get("quake", 0.0))
	if quake > 0.0:
		_shake_combat(quake)
	# 진의 중심은 **첫 표적 자리**다. 아무도 없으면 영웅 앞에.
	# 웅덩이(비명의 흔적)는 몹마다가 아니라 **무리 가운데**다(사장님: 발밑에 안 놓아도
	# 된다, 화면 몹 무리의 반~3분의 1 폭 하나).
	# **화면 하나짜리 진**(RULES.screen — 감시의 눈). 몹을 안 따라가고 화면 가운데에
	# 뜨며, 판정도 화면 전부다. 눈은 땅에 놓이는 문양이 아니라 떠서 내려다보는
	# 것이라 자리를 몹에게 맞출 이유가 없다 — 사장님: "화면 중앙쯤에 나오고 화면에
	# 나와 있는 몬스터".
	# `_on_screen` 이 오른쪽 끝을 이미 잘라 주므로 반폭은 화면 폭이면 충분하다.
	# **두 규칙을 갈라 둔다.** `screen` 은 "가운데에 뜨고 화면 전부를 때린다"이고
	# `fixed` 는 "안 밀린다"만이다. 비명의 흔적은 몹 발밑에 깔리는 웅덩이라 자리는
	# 그대로 두고 고정만 필요하다(2026-08-11 사장님). 하나로 묶었으면 웅덩이가
	# 화면 가운데로 끌려 나갔을 것이다.
	var screen := bool(rule.get("screen", false))
	# `behind` — **영웅 뒤에 세운다**(피의 왕좌). 몹 자리에 깔면 몹·영웅과 그림이
	# 겹쳐서 지저분하다(2026-08-11 사장님: "캐릭터랑 이미지 겹치는 건 좀 짜치네").
	# 왕좌는 왕 뒤에 서 있는 물건이다.
	#
	# 자리를 뒤로 뺐으므로 **판정 폭은 화면 전부로 넓힌다.** 안 넓히면 반폭 180 이
	# 뒤에서부터 재어져 앞줄 몹이 빠진다 — 그림만 옮기고 판정을 두면 "그림 없는
	# 자리에서 피해가 나간다"의 반대쪽 고장이 난다.
	# `aura` — **그림을 땅에 안 깐다.** 영웅 머리 위에 표식 하나가 떠서 "지금 이
	# 스킬이 돌고 있다"만 알린다(2026-08-11 사장님: 기존 이펙트는 안 나오게 하고
	# 오오라만). 판정은 화면 전부다 — 왕의 권한에는 자리가 없다.
	var aura := bool(rule.get("aura", false))
	_field_reach = float(Grid.BG.x) if (screen or aura) else FIELD_REACH
	_field_fixed = screen or aura or bool(rule.get("fixed", false))
	var at := _aoe_targets()
	if aura:
		_field_x = hero_x
	elif screen:
		_field_x = float(Grid.BG.x) * 0.5
	elif puddle > 0.0 and not at.is_empty():
		# **가장 가까운 몹 발밑**(2026-08-10 사장님). 무리 한가운데로 잡았더니 몹이
		# 둘 이상일 때 아무도 없는 몹과 몹 사이에 떴다.
		#
		# 판정 중심(`_field_x`)도 같이 옮긴다 — 그림만 옮기면 그림 없는 자리에서
		# 피해가 나간다. 그 대가로 판정 창이 영웅 쪽으로 당겨져서, 줄 맨 뒤 놈이
		# 사거리(FIELD_REACH)를 벗어날 수 있다. 그게 맞는 그림이다: 앞에 깔린 장판이
		# 저 뒤까지 닿을 이유가 없다.
		var near_f: Foe = at[0]
		for f in at:
			if absf(f.position.x - hero_x) < absf(near_f.position.x - hero_x):
				near_f = f
		_field_x = near_f.position.x
	else:
		_field_x = at[0].position.x if not at.is_empty() \
			else hero_x + float(hero_face) * (_motion_reach("attack") + 48.0)
	# **자리 계산과 그리기가 같은 배율을 봐야 한다.** 가운데 하나로 깔 때는 배율에
	# puddle 이 곱해지는데 자리만 원래 배율로 잡으면, 아래끝을 지면에 붙이는 스타일
	# (rise·hold)이 그만큼 뜨거나 파묻힌다. `hold` 는 세로가 길 폭으로 눌려 우연히
	# 안 어긋났지만 `rise`(제단·왕좌)는 그대로 드러난다.
	var draw := scale * maxf(1.0, puddle)
	var cy := _fx_anchor_y(style, fx, draw, ground_y - float(Grid.SPRITE), 0.0)
	if aura:
		# 영웅 정수리 위. 영웅은 32px 도트를 2배로 그리므로 키가 화면 64px 이다.
		cy = ground_y - float(Grid.SPRITE) * 2.0 - 12.0
	elif screen:
		# **몹 머리 위 하늘에 뜬다.** 몸통 높이(기본값)에 두면 130px 짜리 눈이 전투를
		# 통째로 가린다 — 이펙트가 플레이 화면을 가리면 안 된다는 원칙은 크기를 키운
		# 순간 가장 먼저 깨진다. 아래끝을 머리선에 맞추면 위로는 전투 띠 천장
		# (VIEW_TOP 96)까지 거의 딱 찬다.
		var eframes: Array = Assets.frames("res://assets/anim/%s" % fx)
		var eh := 64.0 if eframes.is_empty() \
			else float((eframes[0] as Texture2D).get_height()) * draw
		cy = ground_y - float(Grid.SPRITE) * 2.0 - eh * 0.5
	# **맞는 놈마다 하나씩**, 단 **시전 때 한 번만**. 틱마다 또 깔면 2마리 x 6틱 = 12장이
	# 전투 화면을 덮는다. 그림 수명은 지속시간과 같게 맞춰 뒀다(SkillDefs 의 fx_fps).
	# 아무도 없으면 영웅 앞에 하나 — 쿨다운을 썼는데 화면에 아무 일도 없으면
	# "안 나갔다"로 보인다.
	var spots := _field_targets()
	# 틱마다 붉게 맥동시킬 문양. 하나짜리일 때만 잡는다 — 여러 장이면 어느 것을
	# 흔들지 정할 수 없고, 여러 장이 동시에 번쩍이면 그게 곧 화면을 가린다.
	var beat: AnimatedSprite2D = null
	if puddle > 0.0 or screen or aura or spots.is_empty():
		beat = _anim_fx(fx, Vector2(_field_x, cy), fps, draw,
			style, echo, 1.0, hero_face, skew, not _field_fixed)
	else:
		# **하나씩 소환된다**(RULES.stagger). 감시의 눈은 눈이 차례로 뜨는 연출이라
		# (2026-08-10 사장님) 대상마다 조금씩 늦게 깐다 — 한꺼번에 뜨면 그냥 세 개가
		# 동시에 나타난 그림이다. 새 아트가 필요 없다: 진은 이미 맞는 놈마다 하나씩
		# 깔리므로, **시간차가 곧 소환 연출**이다.
		var stagger := float(rule.get("stagger", 0.0))
		var n := 0
		for f in spots:
			var at_x := f.position.x
			if stagger <= 0.0 or n == 0:
				_anim_fx(fx, Vector2(at_x, cy), fps, scale, style, echo, 1.0,
					hero_face, skew, true)
			else:
				# 늦게 뜨는 문양은 **그 사이 세상이 움직인 만큼** 어긋난다. 땅에
				# 놓이는 것이라 몹을 다시 찾지 않고 그때의 몹 자리를 그대로 쓴다.
				var who := f
				var t2 := create_tween()
				t2.tween_interval(stagger * float(n))
				t2.tween_callback(func() -> void:
					if not is_inside_tree() or not is_instance_valid(who):
						return
					_anim_fx(fx, Vector2(who.position.x, cy), fps, scale, style,
						echo, 1.0, hero_face, skew, true))
			n += 1
	# **소환이 끝난 뒤에 때린다.** 시간차로 까는 동안 피해가 먼저 들어가면 아직 문양이
	# 없는 자리에서 피해가 나간다 — `tests/AoeCheck` 의 "맞는 놈보다 문양이 적다"가
	# 그걸 잡았다. 사장님 지시도 "소환되는 연출 **뒤** 3번 다단히트"다.
	var lead := float(rule.get("stagger", 0.0)) * float(maxi(0, spots.size() - 1))
	var gen := _field_gen
	for i in ticks:
		var t := create_tween()
		t.tween_interval(lead + gap * float(i))
		t.tween_callback(func() -> void:
			# **phase 는 안 본다.** 문양은 땅에 있는 것이라 영웅이 다음 놈에게 달려가는
			# 동안에도 남아 있어야 한다 — phase 를 보게 뒀더니 전진 구간에서 모든 틱이
			# 빠져나가 피해가 0 번 들어갔다(실측). 끊는 조건은 사망과 구간 교체뿐이다.
			if not is_inside_tree() or _hero_dead or gen != _field_gen:
				return
			if quake > 0.0:
				_shake_combat(quake * 0.6)
			# **문양이 틱마다 한 번 붉게 맥동한다**(2026-08-11 사장님). 3초를 가만히
			# 서 있기만 하면 "저것 때문에 깎인다"가 안 읽힌다. 색조만 흔드는 것이라
			# 자산도 크기도 안 건드린다 — 커지면 그게 곧 화면을 가린다.
			if is_instance_valid(beat):
				beat.modulate = Color(1.6, 0.65, 0.6)
				var bt := create_tween()
				bt.tween_property(beat, "modulate", Color(1, 1, 1), 0.22) \
					.set_trans(Tween.TRANS_QUAD)
			var live := _field_targets()
			if live.is_empty():
				return
			# 웅덩이는 **가까운 놈부터 상한까지만** 때린다(비명의 흔적: 4마리).
			if cap > 0 and live.size() > cap:
				live.sort_custom(func(a: Foe, b: Foe) -> bool:
					return absf(a.position.x - _field_x) < absf(b.position.x - _field_x))
				live = live.slice(0, cap)
			_defer_stage_advance = true
			for f in live:
				# 갈라진 대지 — 이 틱으로 죽을 놈은 **밑으로 꺼져** 죽는다(Foe.pit_fall).
				# take_damage 는 출처를 모르므로 죽기 직전에 표시만 얹는다.
				if pit and f.hp <= per_tick:
					f.pit_fall = true
				# **처형**(RULES.execute — 피의 왕좌). 문양 안에서 체력이 그 비율
				# 아래로 떨어진 놈은 남은 체력에 상관없이 죽는다. 피해로는 못 만드는
				# 결과라 "전설"이 붙을 자격이 있다 — 숫자를 키우는 것과 다르다.
				#
				# **보스는 제외한다.** 보스 체력은 구간 시간을 맞추려고 따로 설계돼
				# 있어서(Balance), 마지막 15%를 건너뛰면 그 설계가 통째로 무너진다.
				if exec_at > 0.0 and not f.is_boss and not f.is_midboss \
						and f.hp <= f.max_hp * exec_at:
					# **선고 -> 집행.** 왕관이 머리 위에 한 번 터지고(그림 하나),
					# 몸은 무릎 꿇듯 접히며 붉게 물든다(Foe.exec_fall — 자산 0).
					# 피격 이펙트를 전부 꺼 둔 화면이라(HIT_FX_ON) 이것만 뜬다 —
					# 처형은 체력 15% 아래일 때만이라 드물게 터진다.
					f.exec_fall = true
					# **fps 가 곧 수명이다** — 왕관은 한 장짜리라 10fps 면 0.1초 만에
					# 사라진다(실측: 검사에서 0장으로 잡혔다). 2.2fps = 0.45초.
					# **머리 위 왕관(권한)과 색을 갈라 놓는다**(2026-08-11 사장님).
					# 같은 그림이라 뜻은 이어지되, 이쪽은 **하얗게 타오른다** —
					# 3초 내내 떠 있는 오오라와 달리 0.45초짜리 선고라 튀어야 한다.
					# 새 자산을 안 뽑는다: `modulate` 한 줄이면 된다.
					var mark := _anim_fx("fx_exec_crown",
						Vector2(f.position.x, f.head_y() - 12.0),
						2.2, 1.3, "burst", 0, 1.0, 1, 0.0)
					if mark != null:
						mark.modulate = Color(2.6, 2.3, 2.1)
					f.take_damage(f.hp)
					continue
				f.take_damage(per_tick)
				_skill_hit_fx(skill, f)
			_defer_stage_advance = false
			if _c_kill_clear():
				_advance_stage())


# 진 안에 서 있는 놈. **화면 안까지다** — `_aoe_targets` 와 같은 이유로 같은 함수를 쓴다.
#
# 매 틱 다시 골라도 시전 때와 같은 집합이다: 몹은 스스로 걷지 않고 문양도 세상과 같은
# 양으로 밀리므로(`_advance_world`) 둘의 **상대 거리가 변하지 않는다**. 그래서 새로
# 흘러 들어오는 놈은 없고 죽은 놈만 빠진다 — 문양 없는 자리에서 피해가 날 일이 없다.
func _field_targets() -> Array[Foe]:
	var out: Array[Foe] = []
	if not is_inside_tree():
		return out
	for f in get_tree().get_nodes_in_group("foes"):
		if not is_instance_valid(f) or f.dying or not _on_screen(f):
			continue
		if absf(f.position.x - _field_x) <= _field_reach + f.body_half():
			out.append(f)
	return out


# 광역이 닿는 범위. **화면 안까지다.**
#
# 예전엔 `_foe_arrived` 만 봤다. 웨이브 모델에서는 그게 곧 "칸에 서 있다"라 화면 안과
# 같은 뜻이었는데, 찾아가는 모델로 바꾼 뒤 몹이 전부 제 자리에 서 있으므로(스스로 걷지
# 않는다) 줄 맨 뒤 화면 밖 놈들까지 판정에 들었다 — 6마리면 **800px 를 때리는데 화면에
# 보이는 건 2마리(160px)** 였다(실측). 안 보이는 곳에서 피해가 나가고, 처치 수만 올라간다.
#
# 오른쪽 끝은 화면 폭에서 몸통 절반을 빼 준다: 몸이 반쯤 걸친 놈은 보이는 놈이다.
func _on_screen(f: Foe) -> bool:
	return f.position.x - f.body_half() <= float(Grid.BG.x)


# 격 한 타. 연타(RULES.hits)가 같은 것을 여러 번 부른다 — 늦게 도는 타는 그 사이에
# 표적이 죽었을 수 있으므로 **매번 살아 있는지 다시 본다.**
func _strike_once(who: Foe, dmg: float, skill: Dictionary, fx: String, fx_y: float,
		fx_fps: float, fx_style: String, fx_scale: float, fx_echo: int,
		fx_skew: float, fx_flip: int, fx_flip_v: int, fx_rot: float) -> void:
	if not is_instance_valid(who) or who.dying:
		return
	who.take_damage(dmg)
	# 스킬 흡혈(피해의 20%)은 뺐다 — 혈액은 배급으로만 들어온다(요구 4).
	# 처치 혈액의 0.02~0.6% 라 곡선 영향은 없었지만, 남겨 두면 "전투가 돈을 준다"
	# 는 예외가 하나 남아 규칙이 흐려진다.
	_anim_fx(fx, Vector2(who.position.x,
		_fx_anchor_y(fx_style, fx, fx_scale, who.body_mid_y(), fx_y)),
		fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew,
		false, fx_flip, fx_flip_v, fx_rot)
	_skill_hit_fx(skill, who)


# 파 한 타. 다단히트(RULES.ticks)가 같은 것을 여러 번 부른다 — 늦게 도는 타는
# 그 사이 표적이 죽었을 수 있으므로 **매번 살아 있는지 다시 본다**(`_strike_once` 와 같다).
func _wave_hit(targets: Array[Foe], dmg: float, pit: bool, skill: Dictionary) -> void:
	for f in targets:
		if not is_instance_valid(f) or f.dying:
			continue
		# 이 타로 죽을 놈은 **밑으로 꺼져** 죽는다(갈라진 대지).
		if pit and f.hp <= dmg:
			f.pit_fall = true
		f.take_damage(dmg)
		_skill_hit_fx(skill, f)


func _aoe_targets() -> Array[Foe]:
	var out: Array[Foe] = []
	if not is_inside_tree():
		return out
	for f in get_tree().get_nodes_in_group("foes"):
		if not _foe_arrived(f):
			continue
		if not _on_screen(f):
			continue
		out.append(f)
	return out


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
	# 그림이 왼쪽을 향해 그려졌으면 -1. **그림만 뒤집고 진행 방향은 안 건드린다** —
	# 둘을 묶었더니 sweep 이 등 뒤로 날아갔다(_anim_fx 주석).
	var fx_flip := int(signf(float(p["flip"])))
	var fx_flip_v := int(signf(float(p["flip_v"])))
	var fx_rot := float(p["rot"])
	# 등급이 높을수록 화면이 더 흔들린다. 레전더리가 커먼과 같은 무게로 터지면 안 된다.
	if float(p["shake"]) > 0.0:
		_shake_combat(float(p["shake"]))
	var hit := _combat_damage() * Balance.skill_hit_mult(attack_interval(), SKILL_DUR) \
		* float(skill["power"]) / SkillDefs.POWER_NORM
	# **쏘기 전에 표적 쪽으로 돈다.** 가호(ward)는 제 몸에 두르는 것이라 방향이 없다.
	# 형태가 아니라 **동작**을 본다 — 스킬이 형태를 덮어썼으면 조준도 따라가야 한다.
	var act := str(skill["act"])
	if act == "strike":
		_face_toward(_skill_target)
	elif act != "ward":
		_face_toward(_nearest_foe())
	match act:
		"strike":
			if _can_hit_foe(_skill_target, str(skill["motion"])):
				# **연타는 총 피해를 나눠 넣는다**(RULES.hits). 위력을 그대로 여러 번
				# 넣으면 등급 사다리가 뒤집힌다 — 사혈 발톱(레어) 하나가 에픽보다 세진다.
				var hits := maxi(1, int(SkillDefs.rule_of(key).get("hits", 1)))
				var gap := float(SkillDefs.rule_of(key).get("hit_gap", 0.15))
				var each := hit / float(hits)
				for i in hits:
					if i == 0:
						_strike_once(_skill_target, each, skill, fx, fx_y, fx_fps,
							fx_style, fx_scale, fx_echo, fx_skew, fx_flip, fx_flip_v, fx_rot)
						continue
					# 남은 타는 조금씩 늦게 — 같은 프레임에 겹치면 한 번으로 보인다.
					var t := create_tween()
					var who := _skill_target
					t.tween_interval(gap * float(i))
					t.tween_callback(func() -> void:
						if is_inside_tree() and not _hero_dead:
							_strike_once(who, each, skill, fx, fx_y, fx_fps,
								fx_style, fx_scale, fx_echo, fx_skew,
								fx_flip, fx_flip_v, fx_rot))
		"field":
			# **다단히트.** 깔아 두고 지속시간 동안 초당 tick_rate 번, 그때 장판 안에
			# 서 있는 놈에게 넣는다 — 들어오는 순간에만 발화하는 `body_entered` 식이
			# 아니라 "지금 겹친 놈들"을 매 틱 다시 본다(Godot 커뮤니티 표준 패턴).
			# 이펙트는 이미 머무는 그림이라 한 번만 띄우고 그대로 둔다.
			# 틱 수는 `SkillDefs.ticks_of` 하나만 본다 — 규칙(one_shot·ticks)을
			# 여기서 다시 얹으면 검사와 갈린다.
			var ticks := SkillDefs.ticks_of(key)
			# **간격은 지속시간에서 나온다.** `1/tick_rate` 로 고정하면 틱 수를 바꾼
			# 스킬(감시의 눈 3틱)이 절반 시간에 끝나고 그림만 남는다 — 그림이 있는데
			# 피해가 없는 구간은 이미 한 번 고친 부류다(3-5).
			_start_field(fx, fx_fps, fx_scale, fx_style, fx_echo, fx_skew,
				hit / float(ticks), ticks,
				float(skill["duration"]) / float(ticks), skill)
			if _c_kill_clear():
				_advance_stage()
		"wave":
			# 튀는 피 — **표창처럼 튕긴다**(RULES.bounce). 전부 동시에 맞으면 광역과
			# 구분이 안 되므로 한 박자씩 늦춰 순서대로 맞는다. 순서가 곧 "튕겼다"다.
			var bounce := int(SkillDefs.rule_of(key).get("bounce", 0))
			if bounce > 0:
				_start_bounce(skill, hit, bounce, p)
				return
			# **상한과 흔들림·구덩이는 파에도 붙는다**(RULES). 갈라진 대지가 장판에서
			# 파로 옮겨 오면서 필요해졌다 — 규칙이 형태에 묶여 있으면 `as` 로 옮긴
			# 순간 규칙이 조용히 사라진다.
			var wrule := SkillDefs.rule_of(key)
			var wcap := int(wrule.get("max_targets", 0))
			var wquake := float(wrule.get("quake", 0.0))
			var wpit := bool(wrule.get("pit_kill", false))
			if wquake > 0.0:
				_shake_combat(wquake)
			_defer_stage_advance = true
			var struck := _aoe_targets()
			# 가까운 놈부터 상한까지만. 안 자르면 "3명"이 화면 전부가 된다.
			if wcap > 0 and struck.size() > wcap:
				struck.sort_custom(func(a: Foe, b: Foe) -> bool:
					return absf(a.position.x - hero_x) < absf(b.position.x - hero_x))
				struck = struck.slice(0, wcap)
			# **파도 다단히트를 한다**(RULES.ticks — 뱀의 무리). 머리가 하나씩 나와
			# 무는 그림이라 한 방으로 끝나면 그림과 규칙이 어긋난다.
			# **총 피해는 그대로다** — 틱 수로 나눠 넣는다. 안 나누면 위력이 곱해져서
			# 등급 사다리가 뒤집힌다(RULES.hits 주석과 같은 이유).
			# 틱 수는 `SkillDefs.ticks_of` 하나만 본다 — 진(field)과 같은 자를 쓴다.
			var wticks := SkillDefs.ticks_of(key)
			var each := hit / float(wticks)
			for i in wticks:
				if i == 0:
					_wave_hit(struck, each, wpit, skill)
					continue
				# 늦게 도는 타는 그 사이 죽은 놈을 거른다(`_wave_hit` 안에서).
				var t := create_tween()
				t.tween_interval(float(i) * 0.12)
				t.tween_callback(func() -> void:
					if is_inside_tree() and not _hero_dead:
						_wave_hit(struck, each, wpit, skill))
			_defer_stage_advance = false
			# **맞는 놈마다 하나씩 띄운다.** 예전엔 fall(혈우)만 그렇게 했고 나머지
			# 19종은 영웅 앞 한 자리에 64px 하나였다 — 800px 를 때리면서 64px 를
			# 보여 주니(때리는 폭의 8%) 광역이 아니라 아이콘이 튀는 그림이었다.
			# 사장님이 혈우만 괜찮다고 한 이유가 이것이고, 새 아트 없이 고쳐진다.
			#
			# 나눠 뜰 때는 잔상(echo)을 끈다 — 잔상은 **하나짜리 이펙트를 크게 보이게**
			# 하는 장치라, 이미 여러 개가 떠 있으면 화면만 두꺼워진다. 등급은 크기로 읽힌다.
			#
			# 아무도 없으면 영웅 앞에 한 번 띄운다: 쿨다운을 썼는데 화면에 아무 일도
			# 안 일어나면 "안 나갔다"로 보인다.
			#
			# 관통(피의 손길)은 **하나만** 띄운다 — 손바닥 하나가 날아가며 전부를
			# 꿰뚫는 그림이라, 맞는 놈마다 손바닥이 뜨면 손이 여러 개가 된다.
			# sweep 전진(190px)이 곧 관통의 몸이다. 피해는 그대로 전부에게 들어갔다.
			#
			# **웅덩이(RULES.puddle)는 무리 가운데 하나로 크게 깐다** — 사장님:
			# "각 몬스터 밑에 있으면 너무 지저분해보임". 넓은 그림일수록 그렇다.
			# 이 규칙이 장판 쪽에만 있어서 갈라진 대지를 파로 옮기자 못 쓰게 됐다 —
			# `as` 로 옮길 수 있는 규칙은 두 길에 다 있어야 한다.
			var wpud := float(SkillDefs.rule_of(key).get("puddle", 0.0))
			if bool(SkillDefs.rule_of(key).get("pierce", false)) or struck.is_empty():
				var ahead := hero_x \
					+ float(hero_face) * (_motion_reach("attack") + 48.0)
				_anim_fx(fx, Vector2(ahead,
					_fx_anchor_y(fx_style, fx, fx_scale,
						ground_y - float(Grid.SPRITE), fx_y)),
					fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew, false, fx_flip, fx_flip_v)
			elif wpud > 0.0:
				# **가장 가까운 몹 발밑**(2026-08-10 사장님). 무리 한가운데로 잡으면
				# 몹 사이 빈 자리에 뜬다. 파는 판정이 `_aoe_targets`(화면 안 전부)라
				# 그림 자리를 옮겨도 맞는 놈이 안 바뀐다 — 진 쪽과 다른 점이다.
				var near_x := struck[0].position.x
				for f in struck:
					if absf(f.position.x - hero_x) < absf(near_x - hero_x):
						near_x = f.position.x
				# **몹 너머로 민다**(RULES.push). 임팩트 순간 영웅과 몹은 59px 밖에
				# 안 떨어져 있어서(몹 잉크 29 + BODY_HALF 30) 몹에 정확히 놓아도
				# 폭이 크면 영웅을 덮는다. 간격 자체는 못 벌린다 — 벌리면 영웅이
				# 그만큼 따라 나가 때리므로 화면상 거리는 그대로고 왕복만 생긴다.
				near_x += float(SkillDefs.rule_of(key).get("push", 0.0)) \
					* float(signi(hero_face))
				_anim_fx(fx, Vector2(near_x,
					_fx_anchor_y(fx_style, fx, fx_scale * wpud,
						ground_y - float(Grid.SPRITE), fx_y)),
					fx_fps, fx_scale * wpud, fx_style, fx_echo, 1.0, hero_face,
					fx_skew, false, fx_flip, fx_flip_v)
			else:
				for f in struck:
					_anim_fx(fx, Vector2(f.position.x,
						_fx_anchor_y(fx_style, fx, fx_scale,
							f.body_mid_y(), fx_y)),
						fx_fps, fx_scale, fx_style, 0, 1.0, hero_face, fx_skew, false, fx_flip, fx_flip_v)
			if _c_kill_clear():
				_advance_stage()
		"ward":
			_summon_t = float(skill["duration"])
			_summon_bonus = float(skill.get("bonus", 0.0))
			# 물들이는 정도도 **시전 순간에 잡아 둔다** — 배수와 같은 이유다(장비를
			# 바꿔도 버프가 안 흔들린다). 0 이면 안 물든다(기존 가호 4종).
			_summon_tint = float(SkillDefs.rule_of(key).get("tint", 0.0))
			_summon_cleave = str(SkillDefs.rule_of(key).get("cleave", ""))
			if _summon_tint <= 0.0 and _hero != null:
				_hero.modulate = Color.WHITE
			_anim_fx(fx, Vector2(hero_x,
				_fx_anchor_y(fx_style, fx, fx_scale,
					ground_y - float(Grid.SPRITE), fx_y)),
				fx_fps, fx_scale, fx_style, fx_echo, 1.0, hero_face, fx_skew, false, fx_flip, fx_flip_v)


# 튀는 피의 튕김 간격. 이펙트 수명(0.56초)보다 짧아야 앞 타격의 그림이 남아 있는
# 동안 다음이 떠서 "이어졌다"로 읽힌다.
const BOUNCE_GAP := 0.13


# 표창식 순차 타격. 가까운 놈부터, 이미 맞은 놈은 건너뛰고 최대 n 명.
#
# **상태를 사전 하나에 담는다.** GDScript 람다는 지역 float 을 값으로 캡처하므로
# 콜백 안에서 from 을 바꿔도 다음 콜백에는 안 보인다 — 사전(참조)이라야 이어진다.
# 표적은 튕기는 순간마다 다시 고른다. 시전 때 목록을 굳히면 그 사이 죽은 놈에게
# 튕긴다(_start_field 의 틱과 같은 이유).
func _start_bounce(skill: Dictionary, hit: float, count: int, p: Dictionary) -> void:
	var state := {"from": hero_x, "struck": {}}
	for i in count:
		var t := create_tween()
		t.tween_interval(maxf(0.01, BOUNCE_GAP * float(i)))
		t.tween_callback(_bounce_hit.bind(skill, hit, state, p))


func _bounce_hit(skill: Dictionary, hit: float, state: Dictionary, p: Dictionary) -> void:
	if not is_inside_tree() or _hero_dead:
		return
	# **phase 를 안 본다**(`_aoe_targets` 를 안 쓰는 이유). 첫 튕김이 몹을 죽이면
	# 영웅은 그 즉시 `advance` 로 넘어가는데, fight 전용 목록을 쓰면 남은 튕김이
	# 전부 허공에서 사라진다 — 실측: 3연타 설계가 매번 1타로 끝났다. 표창은 이미
	# 날아가는 것이라 영웅이 걷기 시작해도 계속 튕겨야 한다(진의 틱과 같은 이유).
	var target: Foe = null
	var best := INF
	for f in get_tree().get_nodes_in_group("foes"):
		if not is_instance_valid(f) or f.dying or not _on_screen(f):
			continue
		if state["struck"].has(f.get_instance_id()):
			continue
		var d: float = absf(f.position.x - float(state["from"]))
		if d < best:
			best = d
			target = f
	# 튕길 곳이 없으면 조용히 끝난다 — 표창이 떨어진 것이다.
	if target == null:
		return
	state["struck"][target.get_instance_id()] = true
	state["from"] = target.position.x
	_defer_stage_advance = true
	target.take_damage(hit)
	_skill_hit_fx(skill, target)
	_defer_stage_advance = false
	_anim_fx(str(p["fx"]), Vector2(target.position.x,
		_fx_anchor_y(str(p["style"]), str(p["fx"]), float(p["scale"]),
			target.body_mid_y(), float(p["y"]))),
		float(p["fps"]), float(p["scale"]), str(p["style"]), 0, 1.0,
		hero_face, float(p["skew"]), false,
		int(signf(float(p["flip"]))), int(signf(float(p["flip_v"]))))
	if _c_kill_clear():
		_advance_stage()


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
# 흔들림은 히트스톱보다 **자주** 돈다. 예전엔 둘이 같은 관문을 써서, 히트스톱을
# 아끼려고 건 0.14초 간격에 흔들림까지 묶여 타격 대부분이 아무 반응이 없었다.
# 히트스톱은 게임을 실제로 멈추니까 아껴야 하지만, 흔들림은 아낄 이유가 없다.
const SHAKE_MIN_GAP := 0.055
const HIT_SHAKE := 5.5      # 기본 타격. 2.0 은 "밀렸다" 정도라 맞은 느낌이 없었다
var _shake_cd := 0.0
var _hitstop_cd := 0.0
var _hitstop_frame := -1

# ── 일일 수집물 "핏방울" ───────────────────────────────────────────────────
# 전투 띠에 가끔 핏방울이 떨어지고 **탭하면 줍는다** (사장님 2026-08-24,
# 방치형 레퍼런스 비교 ② "줍는 재미"). 임무·상자와 달리 "화면을 보고
# 있어야 생기는" 보상이라 방치와 접속 사이를 메운다. 하루 20개 —
# 다 주우면 보석 40(일일 임무 75의 반)이라 수급 곡선을 안 흔든다.
const DROP_PER_DAY := 20
const DROP_GEM := 2.0
const DROP_LIFE := 25.0           # 안 주우면 사라진다 — 다음 방울이 곧 온다
var drop_date := ""
var drop_got := 0
var _drop: Sprite2D = null
var _drop_t := 12.0               # 첫 방울은 켜고 조금 있다가
var _drop_life := 0.0


func _drop_roll_day() -> void:
	var today := Time.get_date_string_from_system()
	if drop_date != today:
		drop_date = today
		drop_got = 0


func _drop_tick(delta: float) -> void:
	if _drop != null:
		_drop_life -= delta
		if _drop_life <= 0.0:
			_drop_gone()
		return
	# 전면 판이 덮었거나 던전 안이면 안 떨어뜨린다 — 줍지 못할 방울은 없다.
	if _tab in FULL_TABS or _in_raid():
		return
	_drop_roll_day()
	if drop_got >= DROP_PER_DAY:
		return
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_spawn()


func _drop_spawn() -> void:
	_drop = Sprite2D.new()
	_drop.texture = Assets.tex("res://assets/ui/res_blood.png")
	_drop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drop.scale = Vector2(1.5, 1.5)
	_drop.position = Vector2(randf_range(60.0, float(Grid.BG.x) - 60.0),
		ground_y - 200.0)
	_drop.z_index = 4
	add_child(_drop)
	_drop_life = DROP_LIFE
	var tw := _drop.create_tween()
	tw.tween_property(_drop, "position:y", ground_y - 20.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	# 착지 후 반짝임 — "저건 눌리는 것"이라는 신호는 이것 하나다.
	var pulse := _drop.create_tween().set_loops()
	pulse.tween_interval(0.5)
	pulse.tween_property(_drop, "modulate", Color(1.6, 1.6, 1.6), 0.45)
	pulse.tween_property(_drop, "modulate", Color(1, 1, 1), 0.45)


# 수명이 다했다 — 조용히 사라진다. 놓친 걸 벌하지 않는다(다음 방울이 온다).
func _drop_gone() -> void:
	var d := _drop
	_drop = null
	_drop_t = randf_range(35.0, 75.0)
	var tw := d.create_tween()
	tw.tween_property(d, "modulate:a", 0.0, 0.4)
	tw.tween_callback(d.queue_free)


func _drop_take() -> void:
	var d := _drop
	_drop = null
	drop_got += 1
	_drop_t = randf_range(35.0, 75.0)
	gem += DROP_GEM
	# 혈액은 덤 — 지금 벌이의 2분치. 시세를 따로 두면 이 방울이 경제의
	# 딴 주머니가 된다(시간 왜곡과 같은 원칙: 배급의 앞당김만 판다).
	gold += blood_per_sec() * 120.0
	_pop_number("+보석 %d" % int(DROP_GEM), d.position.x, d.position.y - 40.0,
		Color(0.88, 0.66, 0.98), false, 1.0)
	var tw := d.create_tween()
	tw.set_parallel()
	tw.tween_property(d, "scale", Vector2(2.4, 2.4), 0.22)
	tw.tween_property(d, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(d.queue_free)
	_refresh_hud()
	_save_game()


func _unhandled_input(event: InputEvent) -> void:
	# 핏방울 줍기 — HUD 가 안 먹은 클릭만 여기로 내려온다(터치는 마우스로
	# 에뮬레이션되므로 마우스 하나만 본다).
	var mb := event as InputEventMouseButton
	if _drop == null or mb == null or not mb.pressed \
			or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.position.distance_to(_drop.position) < 48.0:
		_drop_take()


# ── 피해 숫자 ──────────────────────────────────────────────────────────────
# **치명타 표시는 없다.** 치명타는 확률을 굴리지 않고 기댓값을 곱하는 결정론 축이라
# (`Balance.crit_mult`) "터진 순간"이 존재하지 않는다. 굴리게 바꾸면 오프라인 보상을
# 같은 공식으로 못 계산한다(DESIGN 1장) — 숫자 연출 때문에 그걸 깨지 않는다.
#
# 대신 **그 몹 최대 체력 대비 몇 할인가**로 색과 크기를 나눈다. 출처(평타/스킬)로
# 나누려면 `Foe.take_damage` 까지 인자를 끌고 와야 하는데, 화면에서 정작 궁금한 건
# "얼마나 아팠나"다 — 그건 `on_foe_hit` 이 이미 받는 두 값으로 나온다.
const DMG_POP_RISE := 34.0
const DMG_POP_DUR := 0.55
# 동시 표시 상한. 광역기가 여섯을 때려도 화면이 숫자로 막히면 안 된다
# (이펙트가 플레이 화면을 가리면 안 된다 — 사장님).
const DMG_POP_MAX := 8
# 가운데 정렬용 상자 폭. 글자 폭을 재는 것보다 싸다.
# 글자를 33px 로 키우면서 같이 넓혔다 — 120 이면 "999.9t"(6자)가 상자를 넘쳐서
# 가운데 정렬이 어긋난다. 상자는 안 보이므로 넉넉히 잡는 쪽이 안전하다.
const DMG_POP_W := 200.0
var _dmg_pops := 0


func _pop_damage(foe: Foe, damage: float) -> void:
	if not is_instance_valid(foe):
		return
	var bite := damage / maxf(1.0, foe.max_hp)
	var big := bite >= 0.5
	_pop_number(_n(damage), foe.position.x,
		foe.position.y - foe.body_half() * 2.2 - 20.0,
		Color(1.0, 0.55, 0.28) if big
			else (Color(1.0, 0.86, 0.45) if bite >= 0.15 else Color(1.0, 0.97, 0.92)),
		big, damage)


# 영웅이 맞은 피해. **붉은색으로 영웅 위에** 띄운다 — 레퍼런스도 그렇다(실측: 왼쪽에
# 붉은 `52.1K`). 몹이 받는 숫자와 색으로 갈리므로 누가 맞았는지 바로 읽힌다.
#
# 크기는 **최대 체력 대비**로 정한다. 몹 쪽과 같은 기준이다 — 화면에서 궁금한 건
# 절대값이 아니라 "얼마나 아팠나"고, 한 방에 반이 날아가면 그건 커야 한다.
func _set_hero_flash(v: float) -> void:
	if _hero and _hero.material is ShaderMaterial:
		(_hero.material as ShaderMaterial).set_shader_parameter("flash", v)


func _pop_hero_damage(damage: float) -> void:
	var bite := damage / maxf(1.0, max_hp())
	_pop_number(_n(damage), hero_x, ground_y - float(Grid.SPRITE) * HERO_DRAW_SCALE - 8.0,
		Color(1.0, 0.32, 0.30), bite >= 0.15, damage)


func _pop_number(text: String, at_x: float, at_y: float, col: Color,
		big: bool, damage: float) -> void:
	if _dmg_pops >= DMG_POP_MAX or damage <= 0.0:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Type.font())
	# **11의 배수만 쓴다** — 도트 폰트라 그 외 크기는 픽셀이 어긋나 뭉개진다(Type).
	#
	# 한 단계씩 올렸다(11/22 -> 22/33). 레퍼런스 영상에서 피해 숫자는 전투 띠 높이의
	# **8%** 인데 우리는 2.6~5% 였다 — 띠가 416px 이므로 8% 는 33px, 즉 SIZE_TITLE 이
	# 그대로 그 값이다. 때리는 맛은 숫자가 화면에서 차지하는 크기로 온다.
	l.add_theme_font_size_override("font_size",
		Type.SIZE_TITLE if big else Type.SIZE_BODY)
	l.add_theme_color_override("font_color", col)
	# 테두리. "깨어난 무덤"은 바닥이 밝은 흙색이라 흰 숫자가 그대로 묻힌다.
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.04))
	l.size = Vector2(DMG_POP_W, 26.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **몹에 붙이지 않는다.** 자식이면 죽는 순간 같이 사라져서, 정작 가장 보고 싶은
	# 마지막 한 방의 숫자가 안 뜬다. 영웅(3)·보스(2) 위로 올린다.
	l.z_index = 6
	l.position = Vector2(roundf(at_x - DMG_POP_W * 0.5), roundf(at_y))
	add_child(l)
	_dmg_pops += 1
	var y0 := l.position.y
	var t := create_tween()
	t.set_parallel(true)
	# **좌표를 정수로 굳힌다.** 그냥 position:y 를 트윈하면 소수점 좌표에 도트 폰트가
	# 걸려 글자가 흐려진다(Grid 주석과 같은 이유).
	t.tween_method(func(v: float) -> void:
		l.position.y = roundf(y0 - v), 0.0, DMG_POP_RISE, DMG_POP_DUR) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(l, "modulate:a", 0.0, DMG_POP_DUR * 0.55) \
		.set_delay(DMG_POP_DUR * 0.45)
	t.chain().tween_callback(func() -> void:
		_dmg_pops -= 1
		l.queue_free())


func on_foe_hit(_foe: Foe, _damage: float) -> void:
	# 주간 보스는 **못 죽여도 성과가 남는다** — 넣은 피해가 그 주 기록에 쌓인다.
	if raid_on == "boss":
		boss_dmg += _damage
	# **숫자는 프레임 관문보다 먼저.** 아래 관문은 흔들림·히트스톱을 아끼려고 광역
	# 타격을 한 번으로 접는 건데, 숫자는 맞은 놈마다 떠야 "여섯을 같이 때렸다"가 읽힌다.
	_pop_damage(_foe, _damage)
	var frame := Engine.get_process_frames()
	if frame == _hitstop_frame:
		return          # 같은 프레임의 광역 타격은 한 번으로 친다
	_hitstop_frame = frame
	# 흔들림 먼저. 히트스톱이 쉬는 동안에도 타격은 손에 잡혀야 한다.
	if _shake_cd <= 0.0:
		_shake_cd = SHAKE_MIN_GAP
		_shake_combat(HIT_SHAKE)
	if _hitstop_cd > 0.0:
		return          # 너무 잦으면 건너뛴다
	_hitstop_cd = HITSTOP_MIN_GAP
	_visual_hitstop_t = maxf(_visual_hitstop_t, HITSTOP_DUR)
	if is_inside_tree():
		for f in get_tree().get_nodes_in_group("foes"):
			if is_instance_valid(f):
				f.set_visual_frozen(true)


# Foe가 자기 attack 애니의 네 번째 프레임에 호출한다.
# 몹은 **영웅이 뭘 하든** 제 쿨다운으로 친다. 영웅이 때리는 중이어도, 다른 몹이
# 이미 때리는 중이어도 막지 않는다 — 그래야 좌우에서 동시에 얻어맞는 난전이 된다.
# 대신 닿는지는 **임팩트 순간에** 본다. 대시로 빠져나갔으면 헛친다.
func on_foe_attack(_foe: Foe) -> void:
	if _hero_dead or _phase != "fight":
		return
	if _foe.special_swing:
		_foe_slam_fx(_foe)
	if absf(_foe.position.x - hero_x) > _foe.reach():
		return
	# 특수 패턴은 훨씬 아프다. 대신 예고 원 밖으로 나가면(대시) 위 사거리 검사에서
	# 통째로 빗나가므로, 예고를 보고 빠지는 것이 곧 회피다.
	var incoming := Balance.foe_damage(_c_enemy_power()) * _foe.attack_mult() \
		* _trait_mult("guard") \
		* (1.0 - clampf(_oath_val("armor"), 0.0, 0.9))
	hero_hp = maxf(0.0, hero_hp - incoming)
	# 피의 여왕 — 특수로 벤 만큼 제 피를 채운다(가한 피해의 절반). 표에 축을
	# 늘리지 않고 여기 한 줄이다: 흡혈 보스는 하나뿐이고, 둘째가 생기면 그때
	# 표로 올린다. 주간 보스는 누적 피해 콘텐츠라 회복이 벽이 되지 않는다.
	if _foe.key == "blood_queen" and _foe.special_swing:
		_foe.hp = minf(_foe.max_hp, _foe.hp + incoming * 0.5)
	_pop_hero_damage(incoming)
	_hero_flash_t = 0.10
	_set_hero_flash(Foe.FLASH_MOB)
	_play("hurt", 0.10)
	# **때린 놈 반대쪽으로 민다.** 피가 줄고 몸이 붉게 번쩍이는 것만으로는 맞았다는 게
	# 잘 안 읽힌다 — 자리가 움직여야 몸으로 읽힌다. 대시가 곧 다시 파고들므로
	# 밀렸다 돌아오는 왕복이 된다.
	_knock_vx = KNOCK_SPEED * (-1.0 if _foe.position.x > hero_x else 1.0)
	if hero_hp <= 0.0:
		_kill_hero()


# 특수 패턴 착지 연출 — 발밑 얼음 충격파 + 착탄 범위 양끝의 크리스탈 가시.
# **빗나가도 뜬다**(on_foe_attack 의 사거리 검사보다 앞) — 이건 몹의 공격 연출이지
# 명중 연출이 아니다. 헛친 내려찍기가 조용하면 피한 보람도 화면에 없다.
# **자산이 아니라 코드로 그린다**(사장님 ③, 2026-08-20). 스프라이트 이펙트는
# 크기가 고정이라 착탄 범위(reach)와 안 맞았다 — 첫 판은 충격파가 몸을 감싸는
# "번쩍"이 됐다(실측 캡처). 코드는 판정 반경을 그대로 그리므로
# **보이는 범위 = 맞는 범위**가 항등이다. 그림: 바닥에 낮게 깔린 섬광이
# 착탄 반경까지 퍼지고, 전선이 지나간 자리마다 크리스탈 가시가 솟는다.
# 가시 높이 26px — 바닥 근처에만 그려서 전투 화면을 안 가린다(VFX 원칙).
var _slam_demo := ""   # [개발 도구] --slam=<key>
var _slam_demo_t := 0.0


# 타격점에 뜨는 구조(검기·피보라·X참격·촉수)는 몹 발밑이 아니라 **영웅 쪽**에
# 그린다 — 원거리 촉수가 보스 발밑에서 터지면 "누가 맞았는지"가 안 보인다.
func _foe_slam_fx(f: Foe) -> void:
	_slam_wave(_slam_at_x(str(FoeTiers.slam_theme(f.key)[0]), f.position.x),
		f.reach(), f.key, signf(f.position.x - hero_x))


# 착지 그림이 뜨는 자리. **--slam 데모와 실전이 같은 함수를 본다** — 갈라져
# 있던 동안 데모가 보스를 hero_x+170 에 놓고 그려서, 실전(간격 59px)보다
# 훨씬 벌어진 그림을 보고 판단할 뻔했다.
func _slam_at_x(style: String, boss_x: float) -> float:
	if style in ["lash", "spray", "cross", "arc"]:
		return hero_x + (boss_x - hero_x) * 0.25
	return boss_x


# **보스 사망 — 제 픽셀로 흩어진다.** 몸 그림을 격자로 쪼개 칸마다 그 색의
# 조각 하나를 만들고, 중심에서 밀어내며 떨어뜨린다. 터지는 첫 프레임에는
# 조각이 원래 그림 그대로라 **새 그림이 0장 든다**
# (docs/ATTACK_FX_RECIPE.md 7장).
#
# 디졸브(sprite_fx)는 픽셀을 **제자리에서 지우고** 이건 **날려 보낸다**.
# 잡몹은 디졸브, 보스는 이것 — 그래야 보스 죽음이 한 번 더 읽힌다.
#
# **파티클 셰이더로 하려다 접었다**(2026-08-27). 원본 기법은 process 셰이더가
# `texture(sprite, ...)` 로 제 색을 읽는 것인데, `gl_compatibility` 에서는 그
# 샘플이 알파 0 을 돌려줘 조각이 전부 죽었다 — 게이트를 빼고 단색으로 두면
# 그려진다는 것까지 실측으로 갈랐다(기본 GPUParticles2D 는 잘 그려지므로
# 파티클 자체의 문제가 아니다). 색을 CPU 에서 뽑으면 렌더러를 안 탄다.
const SHATTER_CELLS := 12          # 조각 한 변 = 몸 크기 / 이 값
const SHATTER_LIFE := 0.95
const SHATTER_BURST := 2.4         # 중심에서 밀어내는 배수
const SHATTER_RISE := 90.0
const SHATTER_GRAV := 300.0


func _shatter(f: Foe) -> void:
	if not is_instance_valid(f) or f._walk_frames.is_empty():
		return
	var img := (f._walk_frames[0] as Texture2D).get_image()
	var sz: float = f._size()
	var n := SHATTER_CELLS
	var cell := sz / float(n)
	# [시작 오프셋, 속도, 색] — 빈 칸은 아예 안 담는다.
	var bits: Array = []
	for iy in n:
		for ix in n:
			var u := int((float(ix) + 0.5) / float(n) * float(img.get_width()))
			var v := int((float(iy) + 0.5) / float(n) * float(img.get_height()))
			var c := img.get_pixel(mini(u, img.get_width() - 1),
				mini(v, img.get_height() - 1))
			if c.a <= 0.35:
				continue
			var off := Vector2((float(ix) + 0.5) / float(n) - 0.5,
				(float(iy) + 0.5) / float(n) - 0.5) * sz
			bits.append([off, off * SHATTER_BURST - Vector2(0.0, SHATTER_RISE),
				Color(c.r, c.g, c.b)])
	if bits.is_empty():
		return
	var node := Node2D.new()
	node.position = Vector2(f.position.x, ground_y - sz * 0.5)
	node.z_index = 3
	add_child(node)
	# 세상이 흐르면 같이 밀린다 — 장판·시체와 같은 길.
	node.add_to_group(WORLD_FX_GROUP)
	var st := {"t": 0.0}
	node.draw.connect(func() -> void:
		var t: float = st["t"]
		var a := clampf((1.0 - t / SHATTER_LIFE) * 2.2, 0.0, 1.0)
		for b in bits:
			var p: Vector2 = b[0] + b[1] * t \
				+ Vector2(0.0, 0.5 * SHATTER_GRAV * t * t)
			var col: Color = b[2]
			node.draw_rect(Rect2(p - Vector2(cell, cell) * 0.5,
				Vector2(cell, cell)), Color(col.r, col.g, col.b, a)))
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		st["t"] = v
		if is_instance_valid(node):
			node.queue_redraw(), 0.0, SHATTER_LIFE, SHATTER_LIFE)
	tw.tween_callback(node.queue_free)


# 대시 잔상 — 지나온 자리에 반투명 몸이 남았다 사라진다. 텍스처는 걷기 첫
# 프레임(몸의 기본형)이고 색은 그 보스의 파동 심 색이다.
func _dash_ghost(f: Foe) -> void:
	if not is_instance_valid(f) or f._walk_frames.is_empty():
		return
	var tex: Texture2D = f._walk_frames[0]
	var g := Sprite2D.new()
	g.texture = tex
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sz := f._size()
	# centered 라 반전은 scale 부호 하나로 끝난다 — 원점 보정이 필요 없다.
	g.scale = Vector2(-float(f.face) * sz / float(tex.get_width()),
		sz / float(tex.get_height()))
	g.position = Vector2(f.position.x, ground_y - sz * 0.5)
	var c: Color = FoeTiers.slam_theme(f.key)[1]
	g.modulate = Color(c.r, c.g, c.b, 0.45)
	g.z_index = 1
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.30)
	tw.tween_callback(g.queue_free)


# 메테오(가고일) — 캐스팅이 끝나면 **그 순간의 영웅 자리**에 화염구가 떨어진다.
# 낙하 0.6초가 곧 회피 창이다: 떨어지는 동안 영웅이 대시로 빠지면 빗나간다.
# 착탄 판정은 발사 때 박아 둔 자리 기준 — 유도탄이면 회피 창이 거짓말이 된다.
func on_foe_meteor(f: Foe) -> void:
	if _hero_dead or _phase != "fight":
		return
	var tx := hero_x
	var ball := _anim_fx(FoeTiers.meteor_art(f.key),
		Vector2(tx + 40.0, ground_y - 380.0), 12.0, 1.6, "burst")
	if ball == null:
		return
	ball.rotation_degrees = 115.0   # 낙하 방향으로 눕힌다 — 원본이 옆을 본다
	var tw := ball.create_tween()
	tw.tween_property(ball, "position",
		Vector2(tx, ground_y - 16.0), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ball):
			ball.queue_free()
		if _hero_dead or _phase != "fight" or not is_instance_valid(f):
			return
		_slam_wave(tx, f.reach(), f.key)
		_shake_combat(4.0)
		if absf(hero_x - tx) > f.reach():
			return   # 낙하 중에 빠져나갔다 — 그게 회피다
		var incoming := Balance.foe_damage(_c_enemy_power()) * f.attack_mult() \
			* _trait_mult("guard") \
			* (1.0 - clampf(_oath_val("armor"), 0.0, 0.9))
		hero_hp = maxf(0.0, hero_hp - incoming)
		_pop_hero_damage(incoming)
		_hero_flash_t = 0.10
		_set_hero_flash(Foe.FLASH_MOB)
		_play("hurt", 0.10)
		if hero_hp <= 0.0:
			_kill_hero())


# 착지 이펙트 3차 (2026-08-20, 사장님: "vfx 디자인 참고해서 다시").
# 코드 도트 두 판의 교훈: draw_rect 로는 이펙트의 형태 언어(큰 실루엣·방사형
# 광선·밝기 그라데이션)가 안 나온다 — 픽셀 뿌리기로 보였다. **그림은 창고의
# 전문 이펙트(vfx_*)가 그리고, 코드는 조합·배치·시차·틴트만 맡는다.**
#
# [애니 폴더, x오프셋, y오프셋(지면 기준), 배율, fps, 틴트(null=원색), 시차 초]
# 시차가 조합을 "연출"로 만든다 — 폭발이 먼저, 파편·불기둥이 반 박자 뒤.
const SLAM_FX := {
	"wraith_knight": [
		["fx_slam_wraith_knight", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"gargoyle": [
		["fx_slam_gargoyle", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"sanctum_guardian": [
		["fx_slam_sanctum_guardian", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"frost_golem": [
		["fx_slam_frost_golem", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"eye_mass": [
		["fx_slam_eye_mass", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"dark_knight": [
		["fx_slam_dark_knight", 0.0, 0.0, 2.2, 18.0, null, 0.0]],
	"blood_queen": [
		["fx_slam_blood_queen", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"bone_choir": [
		["fx_slam_bone_choir", 0.0, -12.0, 2.2, 18.0, null, 0.0]],
	"butcher": [
		["fx_slam_butcher", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"plague_hag": [
		["fx_slam_plague_hag", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
	"ruin_warden": [
		["fx_slam_ruin_warden", 0.0, 0.0, 2.0, 18.0, null, 0.0]],
}
# 표에 없는 보스·중간보스 — 중립 파편 + 충격파.
const SLAM_FX_DEFAULT := [
	["vfx_boom_05", 0.0, -18.0, 1.5, 14.0, null, 0.0],
	["fx_rocks", 0.0, -8.0, 1.1, 12.0, null, 0.06]]


# `dir` 은 보스가 있는 쪽(+1 = 오른쪽). 기본 +1 은 보스가 대개 오른쪽이라
# 그렇고, --slam 데모도 그 자리에서 쏜다.
func _slam_wave(at_x: float, r: float, key: String, dir := 1.0) -> void:
	var recipe: Array = SLAM_FX.get(key, SLAM_FX_DEFAULT)
	for e in recipe:
		var delay: float = float(e[6])
		if delay <= 0.0:
			_slam_fx_one(at_x, e)
		else:
			# 값만 바인드한다 — 노드 참조가 없어서 몹이 먼저 죽어도 안전하다.
			var t := create_tween()
			t.tween_interval(delay)
			t.tween_callback(_slam_fx_one.bind(at_x, e))
	_slam_echo(at_x, key, dir)
	_reach_trail(at_x, r, key, dir)
	_shake_combat(4.0)


# **착지는 한 박자가 아니다.** 같은 그림을 반 박자 뒤에 작게 한 번 더 얹으면
# "터짐이 한꺼번에 오지 않아서" 폭발로 읽힌다 — Penusbmic 의 방법이 정확히
# 이것이다(작은 원소를 시차·위치로 어긋나게 복사한다,
# docs/ATTACK_FX_RECIPE.md 8장). 레시피의 시차 칸이 그 자리인데 열한 보스 중
# 열이 한 줄짜리라 원리를 적어만 두고 안 쓰고 있었다.
#
# **하나만 얹는다.** 촉수에서 둘을 세웠다가 바닥이 너무 차서 하나로 줄였다
# (2026-08-27 사장님) — 같은 자로 여기도 하나다.
const SLAM_ECHO_DELAY := 0.07
const SLAM_ECHO_SCALE := 0.62
const SLAM_ECHO_DX := 26.0


func _slam_echo(at_x: float, key: String, dir: float) -> void:
	var recipe: Array = SLAM_FX.get(key, SLAM_FX_DEFAULT)
	if recipe.is_empty():
		return
	var head: Array = recipe[0]
	# 뒤엣것이라 작고 늦다. 틴트는 안 건다 — 그림이 이미 제 색을 갖고 있고
	# 곱하면 계조가 눌린다(같은 문서 4장).
	var e := [head[0], float(head[1]) + dir * SLAM_ECHO_DX, float(head[2]) - 6.0,
		float(head[3]) * SLAM_ECHO_SCALE, head[4], null, 0.0]
	var t := create_tween()
	t.tween_interval(SLAM_ECHO_DELAY)
	t.tween_callback(_slam_fx_one.bind(at_x, e))


# **사거리를 그림이 말하게 한다.**
#
# `SPECIAL_KIND` 의 사거리 배수는 보스마다 1.7~3.2 로 갈리는데 착지 그림은
# 전부 같은 크기였다(이 함수 전까지 `_slam_wave` 의 `r` 은 서명에만 있고 본문에서
# 안 쓰는 죽은 인자였다). 촉수는 2.8 배라 그림보다 훨씬 멀리까지 때린다 —
# 플레이어는 얼마나 위험한지 볼 방법이 없었다.
#
# **덩치로 말하면 안 된다.** 2.8 배로 키우면 전투 화면을 덮는다(우리 원칙).
# 사거리는 **가로로 뻗어서** 읽혀야 한다 — 같은 크기의 덩굴을 보스 쪽으로
# 몇 개 더 세운다. "저 사이가 전부 위험하다"가 곧 사거리다.
# (docs/ATTACK_FX_RECIPE.md 1장 — 그림이 히트박스를 덮는다)
#
# 뒤로 갈수록 작고 어둡고 늦다: 등급 색표의 테두리 색(`SLAM_THEME` 셋째)을
# 써서 심-테두리 두 톤을 만든다. 한 색이면 그냥 복사본으로 보인다(같은 문서 4장).
#
# **어느 쪽으로 뻗는지는 스타일이 정한다.** 값은 `dir`(보스가 있는 쪽)에 곱하는
# 부호다. 표에 없는 스타일은 안 탄다.
#   lash  촉수 — 영웅 발밑에서 터져 **보스 쪽 지면**까지 덩굴이 이어진다 (+)
#
# **음파(sonic)는 넣었다가 뺐다**(2026-08-27). 영웅 쪽(-)으로 뻗게 했더니
# 영웅을 덮었다. 원인은 전제가 틀렸던 것이다: `reach()` 는 **맞는 반경**이지
# 떨어져서 때리는 거리가 아니다. 실측하면 영웅-보스 간격은 중간값 **59px**
# 인데(표본 716) 특수 사거리는 412~464px 다 — 배수가 큰 건 "멀리서 때린다"가
# 아니라 **"물러나도 못 피한다"** 는 뜻이다. 그래서 음파는 지금도 이미
# 영웅에게 닿아 있고, 더 뻗으면 지나쳐 가릴 뿐 새로 말해 주는 게 없다.
const REACH_TRAIL := {"lash": 1.0}
const LASH_TRAIL_SPAN := 0.60   # 사거리의 몇 할까지 늘어놓나
const LASH_TRAIL_MAX := 150.0   # ponytail: 화면을 못 덮게 박은 천장. 사거리가
								# 더 늘면 칸을 늘리는 게 아니라 이 값을 다시 잰다.


func _reach_trail(at_x: float, r: float, key: String, dir: float) -> void:
	var theme: Array = FoeTiers.slam_theme(key)
	var sign_: float = float(REACH_TRAIL.get(str(theme[0]), 0.0))
	if sign_ == 0.0:
		return
	dir *= sign_
	var recipe: Array = SLAM_FX.get(key, SLAM_FX_DEFAULT)
	if recipe.is_empty():
		return
	var span: float = minf(r * LASH_TRAIL_SPAN, LASH_TRAIL_MAX)
	var head: Array = recipe[0]
	# **하나만 세운다**(2026-08-27 사장님: "덩굴 하나로 줄여줘"). 둘이면 바닥이
	# 너무 찬다 — 사거리를 말하는 데는 하나로 족하고, 적을수록 안 가린다.
	# 끝점에 놓는다: 작고 반 박자 늦어서 "저 끝까지"가 읽힌다.
	#
	# **틴트는 안 건다**(null = 원본 색). 처음엔 테두리 색을 곱해 어둡게 했는데,
	# 촉수 그림은 이미 거의 새까맣다(밝기 중앙 3 · 최대 61, 실측) — 거기에
	# 0.22 를 곱하면 안이 안 보이는 검은 실루엣이 된다. 그림이 이미 두 톤을
	# 갖고 있으므로 곱하는 순간 그 부피가 사라진다(ATTACK_FX_RECIPE 4장).
	# 뒤엣것이라는 건 크기와 박자로 말한다.
	var e := [head[0], float(head[1]) + dir * span, head[2],
		float(head[3]) * 0.72, head[4], null, 0.0]
	var t := create_tween()
	t.tween_interval(0.045)
	t.tween_callback(_slam_fx_one.bind(at_x, e))


func _slam_fx_one(at_x: float, e: Array) -> void:
	var n := _anim_fx(str(e[0]), Vector2(at_x + float(e[1]),
		ground_y + float(e[2])), float(e[4]), float(e[3]), "burst")
	if n == null:
		return
	# **원점을 잉크 아래끝에 앉힌다** — 가운데 원점이면 burst 가 크기를
	# 키웠다 줄일 때마다 밑단이 오르내려서, 잉크가 아래쪽에 몰린 그림(촉수)
	# 은 지면을 뚫었다(사장님이 빨간 줄로 잡았다). offset 은 로컬 좌표라
	# 스케일이 뭘 하든 밑단은 ground_y 에 박힌다 — _anim_fx 의 rise/fall
	# 이 쓰는 그 문법이다.
	n.offset = Vector2(0.0, -32.0
		+ Assets.bottom_pad("res://assets/anim/%s" % str(e[0])))
	if e[5] != null:
		n.modulate = e[5]


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
	_set_hero_flash(0.0)
	_anim_fx("fx_death_blood", Vector2(hero_x, ground_y - 42.0), 18.0, 2.0)
	# **쓰러져 눕는 걸 보여준다.** 예전엔 위로 띄우면서(-32) 0.55초에 페이드아웃해
	# 넘어지는 그림이 있어도 안 보였다 — 사장님: "쓰러지는것도 아예 눕거나".
	# 비루프 모션이라 _play 가 마지막 프레임(누운 자세)을 물고 있어 준다.
	# hold 를 부활 시간만큼 줘서 그 사이 idle 로 돌아가지 않게 한다.
	_play("death", REVIVE_TIME)
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	# 떠오르지 않는다. 누운 자세를 보여주고 **부활 직전에만** 사라진다.
	_death_tween = create_tween()
	_death_tween.tween_interval(maxf(0.0, REVIVE_TIME - DEATH_FADE_TIME))
	_death_tween.tween_property(_hero, "modulate:a", 0.0, DEATH_FADE_TIME)
	_death_tween.finished.connect(func() -> void:
		if _hero_dead:
			_hero.visible = false)
	_save_game()


# 구간 시작 자세. **보스 구간만 화면 왼쪽 밖에서 걸어 들어온다**(사장님: "보스
# 스테이지만 왼쪽에서 캐릭터가 나와서 보스 만나서 싸우는 느낌으로"). 잡몹 구간은
# 서서 맞이하므로 앵커에 세운다.
#
# **암전 뒤에서 부른다** — 그래야 자리 이동이 순간이동으로 안 보인다.
func _begin_stage_pose() -> void:
	# 지난 구간에 깔린 장판의 틱을 끊는다. 구간이 바뀌면 그 땅은 없어진 것이다 —
	# 안 끊으면 새 구간의 몹이 이전 구간 문양에 맞는다(`_start_field` 의 gen 검사).
	_field_gen += 1
	_combo = 0     # 구간은 늘 1연격부터 시작한다
	_boss_entry = _c_is_boss()
	hero_x = -float(Grid.SPRITE) if _boss_entry else HERO_X
	_dash_to = HERO_X
	hero_face = 1
	_knock_vx = 0.0
	if _hero != null:
		_hero.position.x = hero_x
	_play("walk" if _boss_entry else "idle")


func _revive_hero() -> void:
	_hero_dead = false
	hero_hp = max_hp()
	hero_x = HERO_X
	_dash_to = HERO_X
	hero_face = 1
	_hero.visible = true
	_hero.position = Vector2(HERO_X, ground_y - float(Grid.SPRITE))
	_hero.modulate = Color.WHITE
	_set_hero_flash(0.0)
	_attack_t = 0.0
	_play("idle")
	_save_game()


# 서서 맞이하다가, 보스 구간에서만 걸어 들어간다.
#
# **"걷다가 무리를 만나고 치우면 또 걷는다"를 접었다**(2026-08-06, 사장님). 영웅은
# 화면 고정이라 그 걷기가 화면에서는 제자리 걷기였고(실측 95%), 배경만 흘러서
# 어긋났다. 걸어 들어가는 연출은 **보스 구간에만** 남긴다 — 모든 구간에 있으면
# 흔해지고, 보스에만 있으면 등장이 사건이 된다.
func _tick_advance(delta: float, foes: Array) -> void:
	if _phase == "fight":
		# 줄이 짧아지면 **바로** 뒤에 세운다. 몹은 스스로 걸어오지 않으니 미리 서
		# 있어야 하고, 다음 놈이 없으면 전진할 대상도 없다.
		_refill_queue(foes)
		# **전열이 비었으면 다시 달린다.** 예전엔 무리를 다 치워야 전진했는데,
		# 찾아가는 모델에서는 다음 놈까지 달리는 것이 곧 전투 사이의 리듬이다.
		# 사망 연출이 끝나기를 기다린다 — 시체를 두고 뛰면 "처치했다"가 안 읽힌다.
		# **시전이 끝나기 전에는 안 넘어간다.** `_resolve_skill` 은 첫 줄에서
		# `_phase != "fight"` 면 통째로 빠져나가는데, 임팩트는 시전보다 0.35~0.66초
		# 늦게 온다 — 전열 한 놈을 잡는 순간 넘어가 버리면 파·진·가호가 **쿨다운만
		# 먹고 화면에는 아무 일도 안 일어난다**(가호는 최대 23초짜리다).
		# 실측(2026-08-27): 스킬 임팩트 14회 중 5회(36%)가 여기서 사라졌다.
		#
		# 가드를 떼는 대신 국면을 잠깐 붙잡는다 — 떼면 아래 `_play("dash")` 가
		# 스킬 모션을 덮어써서 "달리는데 전설 이펙트가 터진다" 가 된다.
		# 갇히지 않는다: `_skill_action_t` 는 `_tick_skills` 에서 국면과 무관하게
		# 줄어드니 `SKILL_DUR`(0.70초) 안에 반드시 풀린다.
		if not _foe_at_front(foes) and _skill_action == "":
			_phase = "advance"
		return

	# 보스 구간은 영웅이 **화면 왼쪽 밖에서** 걸어 들어온다(`_begin_stage_pose`).
	# 자리에 들어오기 전에는 전진도 전투도 없다 — 그래야 "찾아가서 만난다"가 된다.
	# 이 구간의 배경은 `_tick_dash` 가 영웅의 화면 이동량만큼 흘린다.
	if _boss_entry:
		hero_face = 1              # 전진 방향. 이걸 안 잡으면 직전 전투 방향이 남는다
		_play("walk" if absf(_dash_to - hero_x) > 1.0 else "idle")
		if absf(hero_x - HERO_X) <= 1.0:
			_boss_entry = false
		return
	# **전열에 들어온 놈이 있으면 멈춰 서서 싸운다.**
	if _foe_at_front(foes):
		_phase = "fight"
		return
	# 없으면 달린다. 영웅은 화면 고정이라 세상이 흐르고(`_advance_world`), 몹은
	# 사냥터에 서 있으니 앞의 놈이 다가오는 것으로 보인다.
	hero_face = 1
	_play("dash")
	_advance_world(TRAVEL_SPEED * delta)


# 다음 무리를 부르고 그쪽으로 걷기 시작한다. 무리를 미리 내보내야 배경과 같은
# 속도로 밀려 들어와 "다가간다"로 읽힌다 — 다 걷고 나서 부르면 허공에 튀어나온다.
func _start_advance() -> void:
	_phase = "advance"
	_spawn_wave()


# 동시에 살아 있는 몹 수. **스폰·보충·오프라인 판정이 같은 값을 봐야 한다** —
# 세 군데에 같은 식을 적어 두면 하나만 고쳤을 때 화면과 계산이 조용히 갈린다.
#
# **이제 처리량 상한이 아니다.** 몹이 서 있고 영웅이 한 마리씩 찾아가므로, 여섯이
# 줄 서 있어도 처치 속도는 "한 마리당 달리는 시간 + 처치 시간"으로 정해진다
# (`FOE_GAP` / `TRAVEL_SPEED`). 그냥 **저 앞에 몇 마리가 보이는가**다.
func _wave_size(_at_stage: int) -> int:
	# 물량·버티기 던전은 더 많이 세운다 — 간격이 넓으면 100마리가 곧
	# **달리기 100번**이 된다(사장님: "몬스터 줜나 나오게").
	if raid_on != "" and raid_on != "boss" and raid_on != "trial":
		return RaidDefs.wave_size(raid_on, MAX_FOES)
	return MAX_FOES


# 줄 간격. 물량 던전만 좁힌다 — 여기서만 "한 마리당 달리는 시간"이 판정이다.
func _c_foe_gap() -> float:
	if raid_on != "" and raid_on != "boss" and raid_on != "trial":
		return RaidDefs.foe_gap(raid_on, FOE_GAP)
	return FOE_GAP


# 줄 맨 뒤 몹의 x. 새 몹은 그보다 FOE_GAP 만큼 더 뒤에 선다.
func _queue_tail_x(foes: Array) -> float:
	var tail := -INF
	for f in foes:
		if is_instance_valid(f):
			tail = maxf(tail, f.position.x)
	return tail


# 줄이 짧아지면 뒤에 세운다. 몹은 스스로 걸어오지 않으니 **미리 서 있어야** 하고,
# 다음 놈이 없으면 영웅이 전진할 대상도 없다.
# 보스·중간보스 구간은 한 마리로 끝나므로 보충하지 않는다.
func _refill_queue(foes: Array) -> void:
	# **본편 구간이 아니라 지금 판을 봐야 한다.** StageDefs 로만 재면 던전·미궁·
	# 주간 보스 안에서는 늘 "보스 구간이 아니다"가 되어, 수호자를 잡자마자 다음
	# 놈을 세우고 등장 컷신이 또 돈다(사장님 실측: "보스 잡으면 또 나온다").
	if _walk_only or _c_is_boss() or _c_is_midboss():
		return
	var live := 0
	for f in foes:
		if is_instance_valid(f) and not f.dying:
			live += 1
	# 한 프레임에 한 마리만. 몰아 세우면 같은 프레임에 같은 자리를 두 번 계산한다.
	if live < _wave_size(stage):
		_spawn_foe()


func _apply_scroll() -> void:
	# 되돌아오는 주기는 화면 폭이 아니라 배경 폭(1536 = 화면의 2.6배)이다.
	# 화면 폭으로 감으면 몇 초마다 같은 나무가 지나가 걷는 느낌이 죽는다.
	var w := float(Grid.BG_SRC.x * 2)
	var off := fmod(_scroll, w)
	_bg.position.x = -off
	_bg2.position.x = w - off


# 구간을 열 때 사냥터에 몹을 세워 둔다. **줄이지 이 아니라 줄이다** — 앞의 놈이
# 전열 근처에, 뒤로 FOE_GAP 씩 물러서서. 영웅이 달리면 그 줄이 차례로 다가온다.
# ── 전투가 읽는 "지금 어디인가" — 분기는 여기 한 곳뿐이다 ────────────────────
# 본편이면 StageDefs, 미궁이면 DungeonDefs 를 본다. 호출부마다 if 를 심으면
# 하나를 빠뜨린 자리가 조용히 본편 값을 읽는다 — 이 저장소가 여러 번 밟은 부류라
# (틱 수·판정 폭·자리) 갈래를 이 여덟 함수로 모은다.
# **오프라인·도감·경험치는 일부러 본편 기준 그대로다** — 미궁은 기록만 남긴다.
func _c_is_boss() -> bool:
	if raid_on == "boss":
		return true      # 주간 보스 — 한 마리로 판을 채운다(체력 바·마크가 같이 붙는다)
	if raid_on == "trial":
		return true      # 시련도 한 마리 보스 판이다
	if raid_on != "":
		# **성소의 수호자도 그 판의 보스다** — 이 한 줄로 웨이브가 한 마리가 되고
		# 상단 체력 바·등장 컷신까지 따라온다. 안 그러면 수호자가 여럿 서 있어서
		# "보스가 두 마리 나온다"가 된다(사장님 실측 2026-08-14).
		return RaidDefs.goal(raid_on) == "slay"
	return DungeonDefs.is_boss_floor(dungeon_floor) if dungeon_on \
		else StageDefs.is_boss_stage(stage)


func _c_is_midboss() -> bool:
	if raid_on != "":
		return false
	return DungeonDefs.is_midboss_floor(dungeon_floor) if dungeon_on \
		else StageDefs.is_midboss_stage(stage)


# 처치로 판이 끝나는가. **0 은 "한 마리면 끝"이 아니라 "처치가 판정이 아님"**
# 이다(버티기 던전 — 시계가 판정이다). 그걸 `kills >= 0` 으로 물으면 늘 참이라
# 첫 처치에 끝난다.
func _c_kill_clear() -> bool:
	var need := _c_kills_needed()
	return need > 0 and kills >= need


func _c_kills_needed() -> int:
	if raid_on == "boss" or raid_on == "trial":
		return 1
	if raid_on != "":
		# 던전마다 목표가 다르다 — 버티기(제단)는 처치가 판정이 아니다.
		return RaidDefs.kills_needed(raid_on)
	return DungeonDefs.kills_needed(dungeon_floor) if dungeon_on \
		else StageDefs.kills_needed(stage)


func _c_time_limit() -> float:
	if raid_on == "boss":
		return EventDefs.TIME_LIMIT
	if raid_on == "trial":
		return TrialDefs.TIME_LIMIT
	if raid_on != "":
		return RaidDefs.time_limit(raid_on)
	return DungeonDefs.time_limit(dungeon_floor) if dungeon_on \
		else StageDefs.time_limit(stage)


func _c_enemy_power() -> float:
	if raid_on == "boss":
		return StageDefs.enemy_power(best_stage)
	if raid_on == "trial":
		return StageDefs.enemy_power(TrialDefs.eq_stage(trial_stage + 1))
	if raid_on != "":
		return StageDefs.enemy_power(
			RaidDefs.eq_stage(_raid_stage(), raid_on, best_stage))
	return StageDefs.enemy_power(DungeonDefs.eq_stage(dungeon_floor)) if dungeon_on \
		else StageDefs.enemy_power(stage)


func _c_act_data() -> Dictionary:
	if raid_on == "boss":
		return StageDefs.act_data(best_stage)
	if raid_on == "trial":
		# 그 막의 보스가 시련의 얼굴이다 — 배경은 wide_raid_trial 이 따로 맡는다.
		return StageDefs.act_data(TrialDefs.eq_stage(trial_stage + 1))
	if raid_on != "":
		return StageDefs.act_data(
			RaidDefs.eq_stage(_raid_stage(), raid_on, best_stage))
	if dungeon_on:
		# **층마다 얼굴이 바뀐다** (사장님 2026-08-25: "보스 돌아가면서").
		# 등가 구간으로 고르면 같은 막이 여러 층 이어져 "또 저놈"이 된다 —
		# 층 번호로 막을 직접 돌린다. 세기는 _c_enemy_power 가 따로 잰다.
		var ai := (maxi(1, dungeon_floor) - 1) % StageDefs.ACTS.size()
		return StageDefs.act_data(ai * StageDefs.STEPS_PER_STAGE + 1)
	return StageDefs.act_data(stage)


func _c_gold_per_kill() -> float:
	# 미궁·재화 던전 처치도 혈액은 **본편 시세**다. 등가 구간(더 깊은 곳) 시세로 주면
	# 던전이 본편보다 나은 혈액 사냥터가 되어 재화 격리(EXPANSION 6장)가 깨진다.
	# 재화 던전의 진짜 보상은 격파 뭉치(RaidDefs.reward)다.
	return StageDefs.gold_per_kill(stage)


func _c_label() -> String:
	if raid_on == "boss":
		return str(EventDefs.boss_of(_boss_week_index())["name"])
	if raid_on == "trial":
		return "시련 %d단계" % (trial_stage + 1)
	if raid_on != "":
		return RaidDefs.label(raid_on, _raid_stage())
	return DungeonDefs.label(dungeon_floor) if dungeon_on else StageDefs.label(stage)


func _c_midboss_prefix() -> String:
	return "미궁 " if dungeon_on else StageDefs.midboss_prefix(stage)


# ── 재화 던전 (RaidDefs) — 입장·이탈·하루 표 ────────────────────────────────
var raid_on := ""                              # "" | "blood" | "pact" | "hunt"
var raid_best := {"blood": 0, "forge": 0, "pact": 0, "hunt": 0}   # 최고 클리어 단계
var raid_date := ""
# kind -> 오늘 남은 판. **클리어할 때만 깎인다**(사장님) — 못 깨고 나온 판은
# 세지 않으므로, 실패가 손해가 아니라서 "될까?" 싶을 때 눌러 볼 수 있다.
var raid_left := {}


# ── 주간 보스 (EventDefs) ───────────────────────────────────────────────────
# 재화 던전과 같은 틀을 쓴다: 들어가면 raid_on 이 켜지고, 래퍼가 값을 갈아
# 끼우고, 나오면 본편 그 자리. 다른 것은 **못 죽여도 성과가 남는다**는 점뿐이다.
var boss_week := ""
var boss_tries := 0        # 오늘 남은 도전(날마다 리셋)
var boss_dmg := 0.0        # 이번 주 누적 피해
var boss_got := {}         # 받은 마일스톤 (i -> true)
var boss_date := ""
# 이번 누적을 쌓을 때 쓴 화력의 **최고치**. 이정표 요구치의 분모다.
# 저장한다 — 안 하면 재시작 때 0 이 되고, milestone_damage 의 maxf(1.0, dps)
# 때문에 요구치가 30 까지 내려앉아 알림점이 영영 켜져 있었다.
# 내려가지 않는 이유는 회귀다: _prestige_do 가 lv 를 비우면 화력이 바닥나는데
# 누적 피해는 그대로라, 분모가 같이 내려가면 이정표 넷이 통째로 공짜가 된다.
# 누적(boss_dmg)이 0 이 되는 자리(주 바뀜·단계 상승)에서 같이 0 이 된다.
var boss_dps := 0.0
# 주간 보스 단계. 이정표 넷을 다 받으면 오르고 누적이 0 에서 다시 시작한다 —
# 주가 바뀌어도 남는다(재화 던전의 도전 단계와 같은 사다리다).
var boss_tier := 1


# [개발 도구] --boss=4 : 순환을 무시하고 그 보스를 띄운다. 8종이 되면서 특정
# 보스를 화면에서 보려면 몇 주를 기다려야 하는데, 그건 검수 방법이 아니다.
var _dev_boss := -1
# [개발 도구] --flash[=N] : 번쩍임을 고정한다. -1 이면 각자 기본값, 0~1 이면 그 값.
var _dev_flash := -2.0
# [개발 도구] --dying=N : 사망 진행도를 그 지점에 얼린다.
var _dev_dying := -1.0
# [개발 도구] --shatter : 첫 몹을 보스로 세워 터뜨린다.
var _dev_shatter := false
var _shatter_demo_t := 0.0


func _boss_week_index() -> int:
	if _dev_boss >= 0:
		return _dev_boss
	# 주 열쇠(월요일 날짜)에서 순환 번호를 만든다. 날짜 문자열의 일수만 쓰면
	# 월이 바뀔 때 순서가 튀어서, 유닉스 주 수를 그대로 센다.
	return int(Time.get_unix_time_from_datetime_string(quest_week + "T00:00:00")) \
		/ 604800


func _boss_roll() -> void:
	_quest_roll_day()   # 주 열쇠(quest_week)를 공유한다 — 주간 임무와 같은 월요일
	if boss_week != quest_week:
		boss_week = quest_week
		boss_dmg = 0.0
		boss_dps = 0.0
		boss_got = {}
	var today := Time.get_date_string_from_system()
	if boss_date != today:
		boss_date = today
		boss_tries = EventDefs.TRIES_PER_DAY


# 이정표 요구치. 세 곳(판 화면·알림점·수령)이 각자 계산하다 서로 어긋났다.
# 판 밖에서는 지금 화력으로 미리 보여 준다 — 안 그러면 도전 전에 칸이 텅 비어서
# 얼마나 남았는지 감이 안 온다. 다만 **이미 쌓은 화력 아래로는 안 내려간다**.
func _boss_need(i: int) -> float:
	var base := boss_dps if raid_on == "boss" else maxf(boss_dps, dps())
	return EventDefs.milestone_damage(i, base, boss_tier)


func _boss_enter() -> void:
	if raid_on != "" or dungeon_on or _fade_t > 0.0:
		return
	_boss_roll()
	if boss_tries <= 0:
		return
	boss_tries -= 1
	boss_dps = maxf(boss_dps, dps())
	raid_on = "boss"
	_restart_stage("주간 보스 도전", true)
	_enter_battle_view()
	_battle_only(true)
	_refresh_dungeon()
	_save_game()


# 주간 보스에서 나온다. 성과(누적 피해)는 이미 쌓여 있으므로 여기서는 알리고
# 본편으로 돌려보내기만 한다 — 재화 던전과 달리 "빈손"이 없다.
func _boss_exit(reason: String) -> void:
	if raid_on != "boss" or _fade_t > 0.0:
		return
	raid_on = ""
	_show_clear("도전 종료", "이번 주 누적 피해 %s" % _n(boss_dmg))
	var go_boss := func() -> void:
		_restart_stage(reason, true)
		_refresh_currency_visibility()
		_refresh_dungeon()
		_return_gate("boss")
		_save_game()
	if is_inside_tree():
		get_tree().create_timer(CLEAR_HOLD).timeout.connect(go_boss)
	else:
		go_boss.call()


# 계약 도감 — 12종을 줄로 세운다. 딴 것은 등급색·레벨·효과가 보이고, 못 딴
# 것은 이름을 감춘다("???"). 각인 6종은 아래 한 줄로 요약한다.
var _oath_codex_rows: Array = []
var _oath_codex_head: Label


func _oath_codex_build(root: Control) -> void:
	_oath_codex_head = _panel_label(root, Vector2(PAD, CODEX_TAB_Y + 42.0),
		Type.SIZE_SMALL, Color(0.98, 0.82, 0.46), CODEX_W, 18.0)
	var sc := Ui.scroll(Vector2(PAD, CODEX_TAB_Y + 68.0),
		Vector2(CODEX_W, 340.0))
	root.add_child(sc)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(CODEX_W - Ui.SCROLL_W,
		float(OathDefs.CONTRACTS.size()) * 44.0 + 60.0)
	sc.add_child(inner)
	for i in OathDefs.CONTRACTS.size():
		var c: Dictionary = OathDefs.CONTRACTS[i]
		var y := float(i) * 44.0
		var chip := ColorRect.new()
		chip.color = _oath_rcol(str(c["rarity"]))
		chip.position = Vector2(0.0, y + 6.0)
		chip.size = Vector2(6.0, 32.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(chip)
		var nm := _panel_label(inner, Vector2(16.0, y + 4.0), Type.SIZE_SMALL,
			Color(0.96, 0.92, 0.88), 200.0, 18.0)
		var ef := _panel_label(inner, Vector2(16.0, y + 24.0), Type.SIZE_SMALL,
			Color(0.74, 0.72, 0.78), CODEX_W - 60.0, 16.0)
		var lv := _panel_label(inner, Vector2(CODEX_W - 110.0, y + 12.0),
			Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), 80.0, 18.0)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_oath_codex_rows.append({"id": str(c["id"]), "chip": chip, "name": nm,
			"eff": ef, "lv": lv})
	var eng := _panel_label(inner,
		Vector2(0.0, float(OathDefs.CONTRACTS.size()) * 44.0 + 8.0),
		Type.SIZE_SMALL, Color(0.72, 0.70, 0.76), CODEX_W - Ui.SCROLL_W, 44.0)
	eng.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var parts := PackedStringArray()
	for e in OathDefs.ENGRAVES:
		parts.append(str(e["name"]))
	eng.text = "각인 6종 — " + " · ".join(parts)


func _refresh_oath_codex() -> void:
	if _oath_codex_rows.is_empty():
		return
	var got := 0
	for r in _oath_codex_rows:
		var lv := int(oath_lv.get(str(r["id"]), 0))
		var c := OathDefs.of(str(r["id"]))
		if lv > 0:
			got += 1
		(r["name"] as Label).text = str(c["name"]) if lv > 0 else "???"
		(r["eff"] as Label).text = _oath_eff_text(c) if lv > 0 else "아직 맺지 않은 계약"
		(r["lv"] as Label).text = "Lv%d" % lv if lv > 0 else ""
		(r["chip"] as CanvasItem).modulate = Color(1, 1, 1) if lv > 0 \
			else Color(0.32, 0.30, 0.34)
	_oath_codex_head.text = "계약 %d / %d 종  ·  중복이 레벨이 된다(최대 %d)" \
		% [got, OathDefs.CONTRACTS.size(), OathDefs.LV_MAX]


# 계약 판 — 임무판과 같은 자리의 모달. 카드 뒷면·서약 토글·천장 게이지 둘·
# 발동/구매 버튼. 공개 연출(_oath_play)은 판 위 전용 층에서 5막으로 돈다.
func _build_oath_view() -> void:
	_oath_view = Control.new()
	_oath_view.size = Vector2(Grid.BG)
	_oath_view.visible = false
	_oath_view.z_index = 55
	_hud_root.add_child(_oath_view)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.80)
	dim.size = Vector2(Grid.BG)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_oath_view.add_child(dim)
	# **전용 세트**(oath — 검은 철판에 핏자국). 판마다 결이 달라야 한다는
	# 규칙 그대로(둥지·양피지·가죽책과 한 벌).
	_oath_view.add_child(Ui.set_body(OATH, OATH_PANEL.position, OATH_PANEL.size))
	var x := OATH_PANEL.position.x + 20.0
	var w := OATH_PANEL.size.x - 40.0
	var top := OATH_PANEL.position.y
	# 제목 띠 — 긴 띠 조각 위에 글자. 좌우에 핏방울 아이콘을 세워 균형을 잡는다.
	_oath_view.add_child(Ui.set_card(OATH, Vector2(x, top + 12.0),
		Vector2(w, 46.0)))
	_oath_view.add_child(Ui.icon("res://assets/ui/res_blood.png",
		Vector2(x + 14.0, top + 22.0), 26.0))
	_oath_view.add_child(Ui.icon("res://assets/ui/res_blood.png",
		Vector2(x + w - 40.0, top + 22.0), 26.0))
	var title := _panel_label(_oath_view, Vector2(x, top + 22.0),
		Type.SIZE_MID, OATH_RED, w, 26.0)
	title.text = "핏 빛  계 약"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(title, 8)
	var close_art := Ui.set_row(OATH, Vector2(x + w - 88.0, top + 64.0),
		Vector2(88.0, 32.0))
	_oath_view.add_child(close_art)
	var clbl := _panel_label(_oath_view, Vector2(x + w - 88.0, top + 72.0),
		Type.SIZE_SMALL, OATH_INK, 88.0, 18.0)
	clbl.text = "닫기"
	clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := Ui.button("", Vector2(x + w - 88.0, top + 64.0),
		Vector2(88.0, 32.0), Type.SIZE_SMALL)
	close.modulate = Color(1, 1, 1, 0)
	close.pressed.connect(func() -> void: _oath_view.visible = false)
	_oath_view.add_child(close)
	_pet_hover(close, close_art)
	# 소탭 [계약][수집] — 수집 격자를 밑에 욱여넣던 걸 제 탭으로(사장님).
	_oath_main = Control.new()
	_oath_view.add_child(_oath_main)
	_oath_col = Control.new()
	_oath_col.visible = false
	_oath_view.add_child(_oath_col)
	var tabs := [["main", "계약"], ["col", "수집"]]
	for ti in tabs.size():
		var tmode: String = tabs[ti][0]
		var tp := Vector2(x + float(ti) * 94.0, top + 64.0)
		var t_on := Ui.set_tab(OATH, true, tp, Vector2(88.0, 32.0))
		var t_off := Ui.set_tab(OATH, false, tp, Vector2(88.0, 32.0))
		_oath_view.add_child(t_off)
		_oath_view.add_child(t_on)
		var tl := _panel_label(_oath_view, tp + Vector2(0.0, 8.0),
			Type.SIZE_SMALL, OATH_INK, 88.0, 18.0)
		tl.text = str(tabs[ti][1])
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tb := Ui.button("", tp, Vector2(88.0, 32.0), Type.SIZE_SMALL)
		tb.modulate = Color(1, 1, 1, 0)
		tb.pressed.connect(func() -> void: _oath_set_tab(tmode))
		_oath_view.add_child(tb)
		_pet_hover(tb, t_off)
		_oath_ui["tab_on_" + tmode] = t_on
		_oath_ui["tab_lbl_" + tmode] = tl
	# 수집 탭 알림점 — 받을 이정표가 있으면 켠다.
	var cdot := ColorRect.new()
	cdot.color = Color(0.92, 0.22, 0.20)
	cdot.position = Vector2(x + 94.0 + 76.0, top + 62.0)
	cdot.size = Vector2(8.0, 8.0)
	cdot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oath_view.add_child(cdot)
	_oath_ui["col_dot"] = cdot
	_oath_set_tab("main")
	# 제단 — 카드가 놓이는 자리. 뒤에 붉은 후광을 깔아 카드가 떠 보이게 한다.
	var halo := ColorRect.new()
	halo.color = Color(0.62, 0.10, 0.14, 0.16)
	halo.size = Vector2(168.0, 168.0)
	halo.position = Vector2(x + (w - 168.0) * 0.5, top + 92.0)
	halo.pivot_offset = halo.size * 0.5
	halo.rotation_degrees = 45.0
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oath_main.add_child(halo)
	_oath_ui["halo"] = halo
	_oath_ui["card"] = Ui.image("res://assets/ui/oath_card.png",
		Vector2(x + (w - 126.0) * 0.5, top + 88.0), Vector2(126.0, 168.0))
	_oath_main.add_child(_oath_ui["card"])
	# 보유 줄 — 알약 셋(카드·황금·충전). 숫자가 흩어져 있으면 안 읽힌다.
	var pw := (w - 16.0) / 3.0
	for i in 3:
		var pp := Vector2(x + float(i) * (pw + 8.0), top + 272.0)
		_oath_main.add_child(Ui.set_pill(OATH, pp, Vector2(pw, 32.0)))
		var pl := _panel_label(_oath_main, pp + Vector2(0.0, 8.0),
			Type.SIZE_SMALL, OATH_INK, pw, 18.0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(pl, 5)
		_oath_ui["p%d" % i] = pl
	# 등급 띠 — 무엇을 노리는지가 색으로 보인다(운빨의 지도).
	var rar := [["커먼", Color(0.63, 0.63, 0.66)], ["언커먼", Color(0.45, 0.75, 0.45)],
		["레어", Color(0.45, 0.55, 0.9)], ["에픽", Color(0.75, 0.45, 0.9)],
		["만월", Color(0.95, 0.78, 0.35)]]
	var rw := (w - 16.0) / 5.0
	for i in rar.size():
		var rp := Vector2(x + float(i) * (rw + 4.0), top + 316.0)
		var bar := ColorRect.new()
		bar.color = Color(rar[i][1])
		bar.color.a = 0.75
		bar.position = rp
		bar.size = Vector2(rw, 5.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_main.add_child(bar)
		var rl := _panel_label(_oath_main, rp + Vector2(0.0, 7.0),
			Type.SIZE_SMALL, Color(rar[i][1]), rw, 16.0)
		rl.text = str(rar[i][0])
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(rl, 4)
	# 천장 게이지 둘 — 띠 조각 안에 넣어 판의 일부로 읽히게.
	for row in [["pity", "만월까지", 0.0], ["gpity", "황금 천장", 36.0]]:
		var y := top + 348.0 + float(row[2])
		_oath_main.add_child(Ui.set_row(OATH, Vector2(x, y), Vector2(w, 32.0)))
		var lb := _panel_label(_oath_main, Vector2(x + 14.0, y + 8.0),
			Type.SIZE_SMALL, OATH_DIM, 120.0, 16.0)
		lb.text = str(row[1])
		var track := ColorRect.new()
		track.color = Color(0.08, 0.06, 0.09)
		track.position = Vector2(x + 118.0, y + 12.0)
		track.size = Vector2(w - 236.0, 9.0)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_main.add_child(track)
		var fill := ColorRect.new()
		fill.color = Color(0.90, 0.32, 0.30) if row[0] == "pity" \
			else Color(0.92, 0.74, 0.32)
		fill.position = track.position
		fill.size = Vector2(0.0, 9.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_main.add_child(fill)
		var num := _panel_label(_oath_main, Vector2(x + w - 108.0, y + 8.0),
			Type.SIZE_SMALL, OATH_INK, 96.0, 16.0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_oath_ui[str(row[0]) + "_fill"] = fill
		_oath_ui[str(row[0]) + "_w"] = track.size.x
		_oath_ui[str(row[0]) + "_num"] = num
	# 피의 서약 — 판 위의 도박 스위치. 켜지면 줄이 붉게 달아오른다.
	var vow_art := Ui.set_row(OATH, Vector2(x, top + 424.0), Vector2(w, 36.0))
	_oath_main.add_child(vow_art)
	var vlbl := _panel_label(_oath_main, Vector2(x, top + 433.0),
		Type.SIZE_SMALL, OATH_INK, w, 18.0)
	vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(vlbl, 5)
	var vow := Ui.button("", Vector2(x, top + 424.0), Vector2(w, 36.0),
		Type.SIZE_SMALL)
	vow.modulate = Color(1, 1, 1, 0)
	vow.pressed.connect(func() -> void:
		oath_vow = not oath_vow
		_refresh_oath())
	_oath_main.add_child(vow)
	_pet_hover(vow, vow_art)
	_oath_ui["vow"] = vlbl
	_oath_ui["vow_art"] = vow_art
	# 발동·구매 네 버튼 — 전용 판 조각 + 투명 판정(호버·눌림은 그림이 받는다).
	var bw := (w - 12.0) * 0.5
	for spec in [["roll", 0.0, 0.0, 44.0], ["groll", 1.0, 0.0, 44.0],
			["buy", 0.0, 50.0, 36.0], ["gbuy", 1.0, 50.0, 36.0]]:
		var bp := Vector2(x + float(spec[1]) * (bw + 12.0),
			top + 472.0 + float(spec[2]))
		var bsz := Vector2(bw, float(spec[3]))
		var art := Ui.set_row(OATH, bp, bsz)
		_oath_main.add_child(art)
		var bl := _panel_label(_oath_main, bp + Vector2(0.0, bsz.y * 0.5 - 10.0),
			Type.SIZE_SMALL, OATH_INK, bw, 20.0)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(bl, 6)
		var btn := Ui.button("", bp, bsz, Type.SIZE_SMALL)
		btn.modulate = Color(1, 1, 1, 0)
		_oath_main.add_child(btn)
		_pet_hover(btn, art)
		_oath_ui[str(spec[0])] = btn
		_oath_ui[str(spec[0]) + "_lbl"] = bl
		_oath_ui[str(spec[0]) + "_art"] = art
	# 10회 뽑기 — 한 번에 열 장 굴리고 **그중 하나를 골라** 건다(사장님).
	# 황금도 같은 줄에 선다: 황금은 등급이 한 칸 위에서 시작하므로 열 장이면
	# 고를 것이 훨씬 좋다. 위 [즉시 충전] 줄과 겹치던 자리를 내렸다.
	for spec in [["ten", 0.0], ["gten", 1.0]]:
		var tp := Vector2(x + float(spec[1]) * (bw + 12.0), top + 566.0)
		var tsz := Vector2(bw, 34.0)
		var t_art := Ui.set_row(OATH, tp, tsz)
		_oath_main.add_child(t_art)
		var t_lbl := _panel_label(_oath_main, tp + Vector2(0.0, 8.0),
			Type.SIZE_SMALL, OATH_INK, bw, 20.0)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(t_lbl, 6)
		var t_btn := Ui.button("", tp, tsz, Type.SIZE_SMALL)
		t_btn.modulate = Color(1, 1, 1, 0)
		_oath_main.add_child(t_btn)
		_pet_hover(t_btn, t_art)
		_oath_ui[str(spec[0])] = t_btn
		_oath_ui[str(spec[0]) + "_lbl"] = t_lbl
		_oath_ui[str(spec[0]) + "_art"] = t_art
	_oath_ui["ten"].pressed.connect(func() -> void: _oath_play10(false))
	_oath_ui["gten"].pressed.connect(func() -> void: _oath_play10(true))
	_oath_ui["roll"].pressed.connect(func() -> void: _oath_play(false))
	_oath_ui["groll"].pressed.connect(func() -> void: _oath_play(true))
	_oath_ui["buy"].pressed.connect(func() -> void:
		# **공용 함수를 본다.** raw CARD_CAP(3)을 보던 동안 화면은 "3 / 5장"
		# 이라 적어 놓고 3장에서 충전 버튼이 꺼졌다 — 혈세가 사 준 4·5번째
		# 칸은 자연 충전으로만 찼다(2026-08-27).
		if gem >= OathDefs.RECHARGE_GEM \
			and oath_cards < OathDefs.card_cap(_oath_member()):
			gem -= OathDefs.RECHARGE_GEM
			oath_cards += 1
			_save_game()
			_refresh_oath())
	_oath_ui["gbuy"].pressed.connect(func() -> void:
		if gem >= OathDefs.GOLD_GEM:
			gem -= OathDefs.GOLD_GEM
			oath_gold += 1
			_save_game()
			_refresh_oath())
	# 광고 자리 — SDK 가 오면 개통한다(RaidDefs.AD_BONUS_TRIES 와 같은 원칙:
	# 붙일 SDK 가 없으면 **자리만** 만들고 눌리지 않게 둔다).
	var ad_art := Ui.set_row(OATH, Vector2(x, top + 608.0), Vector2(w, 34.0))
	ad_art.modulate = Color(0.55, 0.52, 0.54)
	_oath_main.add_child(ad_art)
	var ad := _panel_label(_oath_main, Vector2(x, top + 616.0), Type.SIZE_SMALL,
		Color(0.66, 0.62, 0.66), w, 18.0)
	ad.text = "[광고] 카드 1장  ·  하루 3회 — 준비 중"
	ad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ── 수집 탭 — 카드 4×3 진열 + 수집 보상 이정표 한 줄 ──────────────────
	var ghead := _panel_label(_oath_col, Vector2(x, top + 108.0),
		Type.SIZE_SMALL, Color(0.98, 0.82, 0.46), w, 18.0)
	ghead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oath_ui["col_head"] = ghead
	_oath_ui["collect"] = []
	var gx := x + (w - 4.0 * 96.0 - 3.0 * 12.0) * 0.5
	for i in OathDefs.CONTRACTS.size():
		var c: Dictionary = OathDefs.CONTRACTS[i]
		var cp := Vector2(gx + float(i % 4) * 108.0,
			top + 136.0 + float(i / 4) * 158.0)
		var mini := Ui.image(OathDefs.card_face(str(c["id"])),
			cp, Vector2(96.0, 128.0))
		mini.modulate = Color(0.28, 0.25, 0.30)
		_oath_col.add_child(mini)
		var cell := ColorRect.new()      # 바닥 띠 — 등급색, 이름과 같은 폭
		cell.color = Color(0.16, 0.13, 0.18)
		cell.position = cp + Vector2(-4.0, 130.0)
		cell.size = Vector2(104.0, 20.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_col.add_child(cell)
		var nm := _panel_label(_oath_col, cp + Vector2(-4.0, 132.0),
			Type.SIZE_SMALL, Color(0.94, 0.92, 0.96), 104.0, 16.0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(nm, 5)     # 검은 테 — 띠 밖으로 삐져도 읽힌다(사장님)
		var chip := ColorRect.new()
		chip.color = Color(0.0, 0.0, 0.0, 0.62)
		chip.position = cp + Vector2(2.0, 2.0)
		chip.size = Vector2(30.0, 13.0)
		chip.visible = false
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_col.add_child(chip)
		var lvl := _panel_label(_oath_col, cp + Vector2(2.0, 3.0),
			Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), 30.0, 12.0)
		lvl.add_theme_font_size_override("font_size", 10)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(_oath_ui["collect"] as Array).append({"id": str(c["id"]),
			"rarity": str(c["rarity"]), "cell": cell, "lvl": lvl,
			"mini": mini, "name": nm, "chip": chip})
	# 수집 보상 — 다음 이정표 하나만 보여주고, 차면 받는다.
	var rw_art := Ui.set_row(OATH, Vector2(x, top + 616.0), Vector2(w, 40.0))
	_oath_col.add_child(rw_art)
	_oath_ui["col_rw_art"] = rw_art
	var rw_lbl := _panel_label(_oath_col, Vector2(x + 12.0, top + 627.0),
		Type.SIZE_SMALL, OATH_INK, w - 130.0, 18.0)
	_oath_ui["col_rw_lbl"] = rw_lbl
	var rw_btn := Ui.button("", Vector2(x + w - 110.0, top + 620.0),
		Vector2(100.0, 32.0), Type.SIZE_SMALL)
	rw_btn.modulate = Color(1, 1, 1, 0)
	rw_btn.pressed.connect(_oath_col_claim)
	_oath_col.add_child(rw_btn)
	var rw_bl := _panel_label(_oath_col, Vector2(x + w - 110.0, top + 627.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), 100.0, 18.0)
	rw_bl.text = "받기"
	rw_bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oath_ui["col_rw_btn"] = rw_btn
	_oath_ui["col_rw_bl"] = rw_bl
	# 공개 연출 층.
	_oath_reveal = Control.new()
	_oath_reveal.size = Vector2(Grid.BG)
	_oath_reveal.z_index = 80          # 컷신·배너보다 위
	_oath_reveal.visible = false
	_oath_view.add_child(_oath_reveal)
	# 전투 화면의 활성 버프 한 줄.
	_build_oath_hud()
	_oath_buff_lbl = _mk_label(Vector2(0.0, 66.0), Type.SIZE_SMALL,
		Color(0.98, 0.72, 0.66))
	_oath_buff_lbl.size = Vector2(Grid.BG.x, 18.0)
	_oath_buff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oath_buff_lbl.visible = false
	_refresh_oath()


func _refresh_oath() -> void:
	if _oath_hud:
		_oath_hud.visible = oath_fx_t > 0.0 and _battle_visible()
		if _oath_hud.visible:
			var face := OathDefs.card_face(oath_fx_id)
			if _oath_hud_face.texture != Assets.tex(face):
				_oath_hud_face.texture = Assets.tex(face)
				_oath_glow(_oath_hud_neon, _oath_rcol(oath_fx_rarity))
			var left := int(ceil(oath_fx_t))
			_oath_hud_time.text = "%d:%02d" % [left / 60, left % 60] \
				if left >= 60 else "%d초" % left
			_oath_hud_time.add_theme_color_override("font_color",
				Color(1.0, 0.45, 0.42) if oath_fx_t <= 10.0
				else Color(0.98, 0.86, 0.56))
		elif _oath_hud_tip and is_instance_valid(_oath_hud_tip):
			_oath_hud_tip.queue_free()   # 끝난 버프의 설명을 남겨 두지 않는다
			_oath_hud_tip = null
	if _oath_buff_lbl:
		_oath_buff_lbl.visible = false   # 카드 위젯이 대신한다(사장님 자리 지정)
		if oath_fx_t > 0.0:
			var parts := PackedStringArray()
			for k in oath_fx:
				parts.append(_oath_fx_short(str(k), float(oath_fx[k])))
			var left := int(ceil(oath_fx_t))
			var clock := "%d:%02d" % [left / 60, left % 60] if left >= 60 				else "%d초" % left
			_oath_buff_lbl.text = "◈ %s  ·  %s  ·  %s" 				% [oath_fx_name, " ".join(parts), clock]
			# 10초 남으면 붉게 — 끝나는 걸 눈으로 알아야 다음 장을 준비한다.
			_oath_buff_lbl.add_theme_color_override("font_color",
				Color(1.0, 0.45, 0.42) if oath_fx_t <= 10.0
				else Color(0.98, 0.82, 0.52))
	# 아이콘 고동 — 카드가 차 있을 때만(판을 열고 있으면 조용히).
	if _oath_icon and _oath_view and not _oath_view.visible \
			and (oath_cards > 0 or not _oath_col_next().is_empty()
			and _oath_col_count() >= int(_oath_col_next().get("need", 99))) \
			and is_inside_tree():
		_oath_icon.pivot_offset = _oath_icon.size * 0.5
		var hb := create_tween()
		hb.tween_property(_oath_icon, "scale", Vector2(1.12, 1.12), 0.12)
		hb.tween_property(_oath_icon, "scale", Vector2.ONE, 0.30)
	if _oath_ui.is_empty() or not _oath_view.visible:
		return
	# 제단 후광 — 굴릴 수 있으면 살아 움직인다.
	var can := oath_cards > 0 or oath_gold > 0
	(_oath_ui["halo"] as ColorRect).color.a = 0.30 if can else 0.10
	if can and is_inside_tree():
		var ht := create_tween()
		ht.tween_property(_oath_ui["halo"], "scale", Vector2(1.08, 1.08), 0.6)
		ht.tween_property(_oath_ui["halo"], "scale", Vector2.ONE, 0.6)
	var mins := OathDefs.CHARGE_MIN - oath_charge
	_oath_ui["p0"].text = "카드 %d / %d" \
		% [oath_cards, OathDefs.card_cap(_oath_member())]
	_oath_ui["p1"].text = "황금 %d" % oath_gold
	_oath_ui["p2"].text = "충전 %d분" % int(ceil(mins))
	(_oath_ui["pity_fill"] as ColorRect).size.x = float(_oath_ui["pity_w"]) \
		* clampf(float(oath_pity) / float(OathDefs.PITY_LEGEND), 0.0, 1.0)
	_oath_ui["pity_num"].text = "%d / %d" % [oath_pity, OathDefs.PITY_LEGEND]
	(_oath_ui["gpity_fill"] as ColorRect).size.x = float(_oath_ui["gpity_w"]) \
		* clampf(float(oath_gold_pity) / float(OathDefs.PITY_GOLD), 0.0, 1.0)
	_oath_ui["gpity_num"].text = "%d / %d" % [oath_gold_pity, OathDefs.PITY_GOLD]
	_oath_ui["vow"].text = "피의 서약  %s   혈액 10%% 를 걸고 등급을 민다" \
		% ("● 켬" if oath_vow else "○ 끔")
	_oath_ui["vow"].add_theme_color_override("font_color",
		OATH_RED if oath_vow else OATH_DIM)
	_art_set_base(_oath_ui["vow_art"] as Control,
		Color(1.25, 0.85, 0.85) if oath_vow else Color(1, 1, 1))
	_oath_ui["ten_lbl"].text = "10회 뽑기  %d / 10" % oath_cards
	_oath_dim("ten", oath_cards >= 10)
	_oath_ui["gten_lbl"].text = "황금 10회  %d / 10" % oath_gold
	_oath_dim("gten", oath_gold >= 10)
	_oath_ui["roll_lbl"].text = "계약 발동  %d장" % oath_cards
	_oath_ui["groll_lbl"].text = "황금 발동  %d장" % oath_gold
	_oath_ui["buy_lbl"].text = "즉시 충전 · 보석 %d" % int(OathDefs.RECHARGE_GEM)
	_oath_ui["gbuy_lbl"].text = "황금 구매 · 보석 %d" % int(OathDefs.GOLD_GEM)
	for pair in [["roll", oath_cards > 0], ["groll", oath_gold > 0],
			["buy", gem >= OathDefs.RECHARGE_GEM
				and oath_cards < OathDefs.card_cap(_oath_member())],
			["gbuy", gem >= OathDefs.GOLD_GEM]]:
		_oath_dim(str(pair[0]), bool(pair[1]))
	_refresh_oath_codex()
	for e in (_oath_ui["collect"] as Array):
		var lv := int(oath_lv.get(str(e["id"]), 0))
		var col := _oath_rcol(str(e["rarity"]))
		(e["cell"] as ColorRect).color = Color(col.r * 0.55, col.g * 0.55,
			col.b * 0.55) if lv > 0 else Color(0.16, 0.13, 0.18)
		if e.has("mini"):
			(e["mini"] as CanvasItem).modulate = Color(1, 1, 1) if lv > 0 \
				else Color(0.35, 0.32, 0.36)
		(e["lvl"] as Label).text = "Lv%d" % lv if lv > 0 else ""
		if e.has("chip"):
			(e["chip"] as CanvasItem).visible = lv > 0
		(e["name"] as Label).text = str(OathDefs.of(str(e["id"]))["name"]) \
			if lv > 0 else "???"
	# 수집 보상 줄 + 소탭 알림점.
	var have := _oath_col_count()
	_oath_ui["col_head"].text = "계약 %d / %d 종  ·  중복이 레벨이 된다" \
		% [have, OathDefs.CONTRACTS.size()]
	var nx := _oath_col_next()
	var ready := not nx.is_empty() and have >= int(nx["need"])
	if nx.is_empty():
		_oath_ui["col_rw_lbl"].text = "수집 보상 — 전부 받았다"
	else:
		var rr: Dictionary = nx["reward"]
		_oath_ui["col_rw_lbl"].text = "수집 보상 — %d종: %s %s" % [int(nx["need"]),
			_reward_name(str(rr["kind"])), _n(float(rr["amount"]))]
	(_oath_ui["col_rw_btn"] as Button).disabled = not ready
	_art_set_base(_oath_ui["col_rw_art"] as Control,
		Color(1, 1, 1) if ready else Color(0.55, 0.52, 0.54))
	(_oath_ui["col_rw_bl"] as Label).modulate = Color(1, 1, 1) if ready \
		else Color(0.55, 0.52, 0.54)
	(_oath_ui["col_dot"] as CanvasItem).visible = ready


var _oath_main: Control
var _oath_col: Control


func _oath_set_tab(mode: String) -> void:
	_oath_main.visible = mode == "main"
	_oath_col.visible = mode == "col"
	for m in ["main", "col"]:
		(_oath_ui["tab_on_" + m] as CanvasItem).visible = m == mode
		(_oath_ui["tab_lbl_" + m] as Label).add_theme_color_override(
			"font_color", Color(0.98, 0.86, 0.56) if m == mode else OATH_INK)
	_refresh_oath()


func _oath_col_count() -> int:
	var n := 0
	for c in OathDefs.CONTRACTS:
		if int(oath_lv.get(str(c["id"]), 0)) > 0:
			n += 1
	return n


# 다음 이정표. 다 받았으면 빈 사전.
func _oath_col_next() -> Dictionary:
	if oath_col_got >= OathDefs.COLLECT_REWARDS.size():
		return {}
	var row: Array = OathDefs.COLLECT_REWARDS[oath_col_got]
	return {"need": int(row[0]), "reward": row[1]}


func _oath_col_claim() -> void:
	var nx := _oath_col_next()
	if nx.is_empty() or _oath_col_count() < int(nx["need"]):
		return
	oath_col_got += 1
	var r: Dictionary = nx["reward"]
	_grant_reward(str(r["kind"]), float(r["amount"]))
	_show_reward("수집 보상 — %d종 달성" % int(nx["need"]),
		[{"icon": "res://assets/ui/%s.png" % _reward_icon(str(r["kind"])),
		"label": "%s +%s" % [_reward_name(str(r["kind"])), _n(float(r["amount"]))]}])
	_save_game()
	_refresh_oath()


# 못 누르는 버튼은 그림과 글자를 같이 죽인다(펫 판과 같은 규칙).
func _oath_dim(key: String, on: bool) -> void:
	(_oath_ui[key] as Button).disabled = not on
	_art_set_base(_oath_ui[key + "_art"] as Control,
		Color(1, 1, 1) if on else Color(0.5, 0.46, 0.48))
	(_oath_ui[key + "_lbl"] as CanvasItem).modulate = Color(1, 1, 1, 1.0 if on \
		else 0.45)


# 공개 연출 5막 (설계 7.5) — 소환진 → 릴(니어미스) → 개봉 → 만월 → 진혈.
# 전부 코드 연출이고 아트는 마법진·만월 두 장뿐이다.
func _oath_play(golden: bool) -> void:
	var r := _oath_roll(golden, false)
	if r.is_empty():
		return
	_oath_reveal_play(r, golden, [])


# 공개 연출 몸통. pick 이 비어 있지 않으면 **10회 뽑기**라, 개봉 끝에서 결과창
# 대신 고르는 격자를 편다(사장님: 10연차도 1회와 같은 느낌이어야 한다).
func _oath_reveal_play(r: Dictionary, golden: bool, pick: Array) -> void:
	_boss_cut_clear()
	for ch in _oath_reveal.get_children():
		ch.queue_free()
	_oath_reveal.visible = true
	_oath_reveal.position = Vector2.ZERO
	var rarity := str(r["rarity"])
	var rcol := _oath_rcol(rarity)
	var mid := Vector2(Grid.BG) * 0.5 - Vector2(0.0, 60.0)
	# 0막 — 화면을 덮는다. 판이 비치면 도박판이 아니라 창이 된다.
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.01, 0.0)
	shade.size = Vector2(Grid.BG)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_oath_reveal.add_child(shade)
	# 1막 — 소환진이 돌며 차오른다. 두 겹이 반대로 돌아 "장치"처럼 보인다.
	var ring := Ui.image("res://assets/ui/oath_circle.png",
		mid - Vector2(150.0, 150.0), Vector2(300.0, 300.0))
	ring.pivot_offset = Vector2(150.0, 150.0)
	ring.modulate = Color(1, 1, 1, 0)
	_oath_reveal.add_child(ring)
	var ring2 := Ui.image("res://assets/ui/oath_circle.png",
		mid - Vector2(96.0, 96.0), Vector2(192.0, 192.0))
	ring2.pivot_offset = Vector2(96.0, 96.0)
	ring2.modulate = Color(1, 1, 1, 0)
	_oath_reveal.add_child(ring2)
	var t := shade.create_tween().set_parallel()
	t.tween_property(shade, "color:a", 0.93, 0.30)
	t.tween_property(ring, "modulate:a", 0.85, 0.30)
	t.tween_property(ring, "rotation_degrees", 220.0, 2.4).from(0.0)
	t.tween_property(ring, "scale", Vector2.ONE, 0.45).from(Vector2(0.35, 0.35)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ring2, "modulate:a", 0.65, 0.30).set_delay(0.10)
	t.tween_property(ring2, "rotation_degrees", -260.0, 2.4).from(0.0)
	# 카드 — 뒷면이 솟아오른다.
	var card := Ui.image("res://assets/ui/%s.png"
		% ("oath_card_gold" if golden else "oath_card"),
		mid - Vector2(66.0, 88.0), Vector2(132.0, 176.0))
	card.pivot_offset = Vector2(66.0, 88.0)
	card.modulate = Color(1, 1, 1, 0)
	# 10연차는 **뭉치**로 보인다 — 뒤에 두 장을 어긋나게 깔아 두께를 준다.
	if not pick.is_empty():
		for k in [2, 1]:
			var back := Ui.image("res://assets/ui/oath_card.png",
				card.position + Vector2(float(k) * 9.0, float(k) * -7.0),
				Vector2(132.0, 176.0))
			back.pivot_offset = Vector2(66.0, 88.0)
			back.rotation_degrees = float(k) * 4.0
			back.modulate = Color(0.72, 0.68, 0.72, 0)
			_oath_reveal.add_child(back)
			var bkt := back.create_tween()
			bkt.tween_interval(0.25)
			bkt.tween_property(back, "modulate:a", 0.9, 0.3)
	_oath_reveal.add_child(card)
	t.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(0.25)
	t.tween_property(card, "position:y", card.position.y, 0.45) \
		.from(card.position.y + 40.0).set_delay(0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2막 — 릴. 카드 테두리가 등급색을 훑는다. 마지막 세 칸이 느려지고
	# 레전 색을 한 번 스친다(니어미스) — "아깝다"가 다음 장을 부른다.
	var rim := Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# [패드, 선 폭, 알파] — 안쪽은 얇고 선명, 바깥으로 두껍고 옅게 = 네온.
	for spec in [[2.0, 4.0, 0.90], [8.0, 6.0, 0.35], [16.0, 10.0, 0.12]]:
		var pad: float = spec[0]
		var layer := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(int(spec[1]))
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0.5, 0.5, 0.5, 0.0)
		layer.add_theme_stylebox_override("panel", sb)
		layer.position = card.position - Vector2(pad, pad)
		layer.size = Vector2(132.0 + pad * 2.0, 176.0 + pad * 2.0)
		layer.set_meta("glow_sb", sb)
		layer.set_meta("glow_a", spec[2])
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.add_child(layer)
	_oath_reveal.add_child(rim)
	_oath_reveal.move_child(rim, card.get_index())   # 카드 **뒤**
	var cols := [Color(0.63, 0.63, 0.66), Color(0.45, 0.75, 0.45),
		Color(0.45, 0.55, 0.9), Color(0.75, 0.45, 0.9), Color(0.95, 0.78, 0.35)]
	var seq := card.create_tween()
	seq.tween_interval(0.55)
	var steps := 14
	for i in steps:
		var dt := 0.055 + 0.13 * float(maxi(0, i - steps + 4))
		var c: Color = cols[(i + 1) % cols.size()]
		if i == steps - 2:
			c = cols[4]                     # 레전 색을 스치고…
		elif i == steps - 1:
			c = rcol                        # …실제 등급에서 멎는다
		seq.tween_callback(func() -> void:
			_oath_glow(rim, c)
			card.scale = Vector2(1.04, 1.04))
		seq.tween_interval(dt * 0.5)
		seq.tween_callback(func() -> void: card.scale = Vector2.ONE)
		seq.tween_interval(dt * 0.5)
	seq.tween_callback(func() -> void:
		_oath_burst(card, rim, ring, ring2, rcol, rarity, r, pick))
	_refresh_oath()


# 3~5막 — 개봉. 등급이 높을수록 화면이 크게 반응하고, 레전·진혈은 만월이 뜬다.
func _oath_burst(card: Control, rim: Control, ring: Control, ring2: Control,
		rcol: Color, rarity: String, r: Dictionary, pick: Array = []) -> void:
	if not is_inside_tree() or not is_instance_valid(card) 			or not is_instance_valid(rim):
		return
	var big := rarity in ["rare", "epic", "legend", "trueblood"]
	var mid := Vector2(Grid.BG) * 0.5 - Vector2(0.0, 60.0)
	# 소환진은 개봉과 함께 확 퍼지며 사라진다.
	var rt := ring.create_tween().set_parallel()
	for n in [ring, ring2]:
		rt.tween_property(n, "scale", (n as Control).scale * 1.6, 0.5)
		rt.tween_property(n, "modulate:a", 0.0, 0.5)
	# 섬광.
	var flash := ColorRect.new()
	flash.color = Color(rcol.r, rcol.g, rcol.b, 0.0)
	flash.size = Vector2(Grid.BG)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oath_reveal.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.60 if big else 0.35, 0.08)
	ft.tween_property(flash, "color:a", 0.0, 0.40)
	# 파편 — 등급색 조각이 사방으로 튄다. 등급이 높을수록 많고 멀리 간다.
	var shard_n := {"common": 8, "uncommon": 12, "rare": 20, "epic": 28,
		"legend": 40, "trueblood": 56}
	var n_shards := int(shard_n.get(rarity, 8))
	for i in n_shards:
		var sh := ColorRect.new()
		sh.color = rcol
		sh.size = Vector2(randf_range(3.0, 7.0), randf_range(3.0, 9.0))
		sh.position = mid
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_reveal.add_child(sh)
		var ang := randf() * TAU
		var dist := randf_range(90.0, 300.0)
		var st := sh.create_tween().set_parallel()
		st.tween_property(sh, "position",
			mid + Vector2(cos(ang), sin(ang)) * dist, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(sh, "modulate:a", 0.0, 0.7)
		st.tween_property(sh, "rotation_degrees", randf_range(-540.0, 540.0), 0.7)
	# 진동 — 등급이 높을수록 거칠게.
	var amps := {"common": 3.0, "uncommon": 5.0, "rare": 9.0, "epic": 14.0,
		"legend": 20.0, "trueblood": 28.0}
	var amp := float(amps.get(rarity, 3.0))
	var shake := create_tween()
	for i in 8:
		shake.tween_property(_oath_reveal, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	shake.tween_property(_oath_reveal, "position", Vector2.ZERO, 0.08)
	# 등급 파동 — 소환진을 등급색으로 물들여 한 번 크게 퍼뜨린다.
	# 커먼도 "뭔가 터졌다"가 보이게 하는 최소 장치다.
	var wave := Ui.image("res://assets/ui/oath_circle.png",
		mid - Vector2(110.0, 110.0), Vector2(220.0, 220.0))
	wave.pivot_offset = Vector2(110.0, 110.0)
	wave.modulate = Color(rcol.r, rcol.g, rcol.b, 0.9)
	_oath_reveal.add_child(wave)
	_oath_reveal.move_child(wave, 1)
	var wt := wave.create_tween().set_parallel()
	wt.tween_property(wave, "scale", Vector2(2.6, 2.6), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wt.tween_property(wave, "modulate:a", 0.0, 0.55)
	wt.tween_property(wave, "rotation_degrees", 60.0, 0.55)
	# 레어 이상 — 화면 가장자리가 등급색으로 물든다(비네트 네 줄).
	if big:
		for i in 4:
			var edge := ColorRect.new()
			edge.color = Color(rcol.r, rcol.g, rcol.b, 0.0)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var thick := 90.0
			if i == 0:
				edge.position = Vector2.ZERO
				edge.size = Vector2(Grid.BG.x, thick)
			elif i == 1:
				edge.position = Vector2(0.0, Grid.BG.y - thick)
				edge.size = Vector2(Grid.BG.x, thick)
			elif i == 2:
				edge.position = Vector2.ZERO
				edge.size = Vector2(thick, Grid.BG.y)
			else:
				edge.position = Vector2(Grid.BG.x - thick, 0.0)
				edge.size = Vector2(thick, Grid.BG.y)
			_oath_reveal.add_child(edge)
			var et := edge.create_tween()
			et.tween_property(edge, "color:a", 0.30, 0.18)
			et.tween_property(edge, "color:a", 0.0, 0.75)
	# 에픽 — 보랏빛 낙뢰가 카드로 내리꽂힌다(설계 3막).
	if rarity == "epic" or rarity == "trueblood":
		for i in 5:
			var bolt := ColorRect.new()
			bolt.color = Color(0.85, 0.55, 1.0, 0.0) if rarity == "epic" \
				else Color(1.0, 0.92, 0.6, 0.0)
			bolt.size = Vector2(randf_range(3.0, 6.0), randf_range(200.0, 340.0))
			bolt.position = Vector2(mid.x + randf_range(-150.0, 150.0), -20.0)
			bolt.rotation_degrees = randf_range(-14.0, 14.0)
			bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_oath_reveal.add_child(bolt)
			var bt := bolt.create_tween()
			bt.tween_interval(0.03 * float(i))
			bt.tween_property(bolt, "color:a", 0.9, 0.05)
			bt.tween_property(bolt, "color:a", 0.0, 0.28)
	# 4·5막 — 만월. 레전은 핏빛, 진혈은 황금으로 물든다.
	if rarity == "legend" or rarity == "trueblood":
		var gold_moon := rarity == "trueblood"
		var moon := Ui.image("res://assets/ui/oath_moon.png",
			mid - Vector2(210.0, 210.0), Vector2(420.0, 420.0))
		moon.pivot_offset = Vector2(210.0, 210.0)
		moon.modulate = Color(1.6, 1.35, 0.55, 0.0) if gold_moon \
			else Color(1, 1, 1, 0)
		_oath_reveal.add_child(moon)
		_oath_reveal.move_child(moon, 1)     # 카드 뒤
		var mt := moon.create_tween().set_parallel()
		mt.tween_property(moon, "modulate:a", 0.9, 0.9)
		mt.tween_property(moon, "scale", Vector2.ONE, 1.1) \
			.from(Vector2(0.25, 0.25)).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		# 핏빛 비 — 위에서 아래로 긋는 선들(진혈은 금빛).
		for i in (26 if gold_moon else 18):
			var drop := ColorRect.new()
			drop.color = Color(1.0, 0.86, 0.45) if gold_moon \
				else Color(0.85, 0.16, 0.20)
			drop.size = Vector2(2.0, randf_range(14.0, 30.0))
			drop.position = Vector2(randf() * Grid.BG.x, -40.0)
			drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_oath_reveal.add_child(drop)
			var dt2 := drop.create_tween()
			dt2.tween_interval(randf() * 0.5)
			dt2.tween_property(drop, "position:y", Grid.BG.y, randf_range(0.7, 1.3))
			dt2.parallel().tween_property(drop, "modulate:a", 0.0, 1.2)
		# 카드가 커지며 앞으로 나온다.
		var ct := card.create_tween()
		ct.tween_property(card, "scale", Vector2(1.35, 1.35), 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 카드 뒤집기 — 뒷면이 좁아졌다가 **앞면**으로 펼쳐진다. 계약마다 그림이
	# 다르므로 여기서 비로소 "무엇을 뽑았는지"가 그림으로 읽힌다.
	var face := OathDefs.card_face(str(r["contract"]["id"]))
	var flip := card.create_tween()
	flip.tween_property(card, "scale", Vector2(0.05, 1.06), 0.16) \
		.set_trans(Tween.TRANS_SINE)
	flip.tween_callback(func() -> void:
		(card as TextureRect).texture = Assets.tex(face))
	flip.tween_property(card, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.modulate = Color(1.5, 1.4, 1.3)
	create_tween().tween_property(card, "modulate", Color.WHITE, 0.6)
	if pick.is_empty():
		_oath_result(rcol, rarity, r)
	else:
		# 뭉치가 흩어지듯 — 개봉을 **끝까지 보여주고** 격자를 편다. 만월이
		# 차오르는 중에 덮으면 열 장을 굴린 보람이 사라진다(사장님).
		var waits := {"common": 1.1, "uncommon": 1.2, "rare": 1.5, "epic": 1.8,
			"legend": 2.6, "trueblood": 3.0}
		var gt := card.create_tween()
		gt.tween_interval(float(waits.get(rarity, 1.2)))
		# 카드가 화면 밖으로 날아가며 격자에 자리를 내준다.
		gt.tween_property(card, "scale", Vector2(0.2, 0.2), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		gt.parallel().tween_property(card, "modulate:a", 0.0, 0.25)
		gt.tween_callback(func() -> void: _oath_show_pick(pick, rcol))


func _oath_rcol(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.45, 0.75, 0.45)
		"rare": return Color(0.45, 0.55, 0.9)
		"epic": return Color(0.75, 0.45, 0.9)
		"legend": return Color(0.95, 0.78, 0.35)
		"trueblood": return Color(1.0, 0.92, 0.6)
	return Color(0.63, 0.63, 0.66)


# 결과 판 — 계약명·효과·각인·공명·레벨 + 다시 굴리기.
# 네온 테두리 한 벌. pads 는 [패드, 선 폭, 알파] 세 겹이다. 1회 뽑기의 릴
# 글로우와 같은 문법이라 10연차도 같은 결로 빛난다(사장님).
func _oath_neon(parent: Control, at: Vector2, size: Vector2, col: Color,
		pads := [[2.0, 4.0, 0.90], [8.0, 6.0, 0.35], [16.0, 10.0, 0.12]]) -> Control:
	var rim := Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in pads:
		var pad: float = spec[0]
		var layer := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(int(spec[1]))
		sb.set_corner_radius_all(6)
		sb.border_color = Color(col.r, col.g, col.b, float(spec[2]))
		layer.add_theme_stylebox_override("panel", sb)
		layer.position = at - Vector2(pad, pad)
		layer.size = size + Vector2(pad, pad) * 2.0
		layer.set_meta("glow_sb", sb)
		layer.set_meta("glow_a", spec[2])
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.add_child(layer)
	parent.add_child(rim)
	return rim


# 글로우 3겹에 등급색을 입힌다 — 겹마다 제 알파(meta)로 옅어진다.
func _oath_glow(rim: Control, c: Color) -> void:
	for ch in rim.get_children():
		(ch.get_meta("glow_sb") as StyleBoxFlat).border_color = Color(c.r, c.g,
			c.b, float(ch.get_meta("glow_a", 0.5)))


# 10회 뽑기 — 열 장을 **먼저 다 굴리고**(수집·레벨·천장은 그때 다 반영된다),
# 격자로 펼친 뒤 하나만 골라 건다. 나머지는 수집으로 남는다.
func _oath_play10(golden := false) -> void:
	if _oath_reveal == null:
		return
	if (oath_gold if golden else oath_cards) < 10:
		return
	var got: Array = []
	for i in 10:
		var r := _oath_roll(golden, false)
		if r.is_empty():
			break
		got.append(r)
	if got.is_empty():
		return
	_refresh_oath()
	# 릴은 **가장 높은 등급**에서 멎는다 — 열 장의 결과를 한 번에 말해 준다.
	var best: Dictionary = got[0]
	for g in got:
		if _oath_rank(str(g["rarity"])) > _oath_rank(str(best["rarity"])):
			best = g
	_oath_reveal_play(best, golden, got)


# 등급 순위 — 표 순서를 숫자로. 진혈은 표 밖이라 맨 위.
func _oath_rank(rarity: String) -> int:
	if rarity == "trueblood":
		return 99
	return ["common", "uncommon", "rare", "epic", "legend"].find(rarity)


# 뽑은 것들을 펼쳐 고르게 한다. 1회 뽑기의 결과창과 같은 층을 쓴다.
func _oath_show_pick(got: Array, back_col := Color(0.9, 0.3, 0.3)) -> void:
	_boss_cut_clear()
	for ch in _oath_reveal.get_children():
		ch.queue_free()
	_oath_reveal.visible = true
	_oath_reveal.position = Vector2.ZERO
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.01, 0.0)
	shade.size = Vector2(Grid.BG)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_oath_reveal.add_child(shade)
	shade.create_tween().tween_property(shade, "color:a", 0.94, 0.25)
	# 소환진이 뒤에 남아 계속 돈다 — 격자가 맨바닥에 뜨면 연출이 끊긴다.
	var back := Ui.image("res://assets/ui/oath_circle.png",
		Vector2(Grid.BG.x * 0.5 - 300.0, 150.0), Vector2(600.0, 600.0))
	back.pivot_offset = Vector2(300.0, 300.0)
	back.modulate = Color(back_col.r, back_col.g, back_col.b, 0.0)
	_oath_reveal.add_child(back)
	var bt := back.create_tween()
	bt.tween_property(back, "modulate:a", 0.16, 0.5)
	var bspin := back.create_tween().set_loops()
	bspin.tween_property(back, "rotation_degrees", 360.0, 60.0).from(0.0)
	var head := _panel_label(_oath_reveal, Vector2(0.0, 40.0), Type.SIZE_MID,
		Color(0.98, 0.82, 0.46), Grid.BG.x, 28.0)
	head.text = "%d장을 뽑았다 — 하나를 골라 건다" % got.size()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(head, 8)
	if oath_fx_t > 0.0:
		var cur := _panel_label(_oath_reveal, Vector2(0.0, 72.0),
			Type.SIZE_SMALL, Color(0.72, 0.86, 0.72), Grid.BG.x, 18.0)
		cur.text = "지금: %s  %d초 남음  →  고르면 바뀐다" \
			% [oath_fx_name, int(oath_fx_t)]
		cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 5 x 2 격자. 카드마다 **셀 하나에 묶는다** — 그림·테두리·글자가 따로 놀면
	# 호버가 각자 움직여 어색하다(사장님). 셀 하나가 통째로 커지고 밝아진다.
	var cw := 96.0
	var ch2 := 128.0
	var gap := 12.0
	var pad := 8.0
	var gx := (Grid.BG.x - 5.0 * cw - 4.0 * gap) * 0.5
	for i in got.size():
		var r: Dictionary = got[i]
		var c: Dictionary = r["contract"]
		var rcol := _oath_rcol(str(r["rarity"]))
		var at := Vector2(gx + float(i % 5) * (cw + gap),
			104.0 + float(i / 5) * (ch2 + 84.0))
		var cell := Control.new()
		cell.position = at - Vector2(pad, pad)
		cell.size = Vector2(cw + pad * 2.0, ch2 + pad * 2.0 + 60.0)
		cell.pivot_offset = Vector2(cell.size.x * 0.5, ch2 * 0.5 + pad)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_oath_reveal.add_child(cell)
		var in_at := Vector2(pad, pad)      # 셀 안 좌표
		# 격자도 같은 네온 — 작은 칸이라 두 겹만 쓴다.
		_oath_neon(cell, in_at, Vector2(cw, ch2), rcol,
			[[2.0, 3.0, 0.90], [7.0, 5.0, 0.28]])
		cell.add_child(Ui.image(OathDefs.card_face(str(c["id"])), in_at,
			Vector2(cw, ch2)))
		var chip := ColorRect.new()
		chip.color = Color(0.0, 0.0, 0.0, 0.62)
		chip.position = in_at + Vector2(2.0, 2.0)
		chip.size = Vector2(30.0, 13.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(chip)
		var lvl := _panel_label(cell, in_at + Vector2(2.0, 3.0),
			Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), 30.0, 12.0)
		lvl.add_theme_font_size_override("font_size", 10)
		lvl.text = "Lv%d" % int(r["lv"])
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var nm := _panel_label(cell, in_at + Vector2(0.0, ch2 + 4.0),
			Type.SIZE_SMALL, rcol, cw, 16.0)
		nm.text = str(c["name"])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		_shop_outline(nm, 5)
		var ef := _panel_label(cell, in_at + Vector2(0.0, ch2 + 22.0),
			Type.SIZE_SMALL, Color(0.86, 0.84, 0.88), cw, 40.0)
		ef.text = _oath_eff_text(c)
		ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(ef, 4)
		var pick := Ui.button("", at - Vector2(pad, pad),
			Vector2(cw + pad * 2.0, ch2 + pad * 2.0), Type.SIZE_SMALL)
		pick.modulate = Color(1, 1, 1, 0)
		# 고르면 **바로 걸지 않는다** — 지금 것과 견줘 보고 정한다(사장님).
		pick.pressed.connect(func() -> void: _oath_confirm_pick(r, got))
		_oath_reveal.add_child(pick)
		_pet_hover(pick, cell)
		# 등장 — 한 장씩 0.06초 간격으로 셀째 튀어나온다.
		cell.modulate.a = 0.0
		var pt := cell.create_tween()
		pt.tween_interval(0.06 * float(i))
		pt.tween_property(cell, "modulate:a", 1.0, 0.18)
		var sc := cell.create_tween()
		sc.tween_interval(0.06 * float(i))
		sc.tween_property(cell, "scale", Vector2.ONE, 0.22) 			.from(Vector2(0.4, 0.4)).set_trans(Tween.TRANS_BACK) 			.set_ease(Tween.EASE_OUT)
	# 아무것도 안 걸고 닫기 — 뽑은 것은 이미 수집에 들어갔다.
	var sk_art := Ui.set_row(OATH, Vector2(88.0, Grid.BG.y - 150.0),
		Vector2(Grid.BG.x - 176.0, 44.0))
	_oath_reveal.add_child(sk_art)
	var sk_lbl := _panel_label(_oath_reveal, Vector2(88.0, Grid.BG.y - 137.0),
		Type.SIZE_SMALL, OATH_INK, Grid.BG.x - 176.0, 20.0)
	sk_lbl.text = "안 걸고 닫기 — 수집에는 이미 남았다"
	sk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var skip := Ui.button("", Vector2(88.0, Grid.BG.y - 150.0),
		Vector2(Grid.BG.x - 176.0, 44.0), Type.SIZE_SMALL)
	skip.modulate = Color(1, 1, 1, 0)
	skip.pressed.connect(func() -> void:
		_oath_reveal.visible = false
		_refresh_oath())   # 판은 남긴다 — 결과를 보고 이어 굴린다
	_oath_reveal.add_child(skip)
	_pet_hover(skip, sk_art)


# 격자에서 하나를 고른 뒤 — 지금 도는 계약과 견주고 정한다(사장님).
# 1회 뽑기 결과창의 [교체]/[유지]와 같은 규칙이다.
func _oath_confirm_pick(r: Dictionary, got: Array) -> void:
	var c: Dictionary = r["contract"]
	var rcol := _oath_rcol(str(r["rarity"]))
	var layer := Control.new()
	layer.size = Vector2(Grid.BG)
	_oath_reveal.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.01, 0.0)
	dim.size = Vector2(Grid.BG)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.86, 0.18)
	var mid := Vector2(Grid.BG) * 0.5
	# 카드 뒤 후광 — 결과창과 같은 빔(사장님: 10회 뽑기도 이렇게).
	_oath_rays(layer, mid - Vector2(0.0, 54.0), rcol)
	# 고른 카드를 크게.
	var big := Ui.image(OathDefs.card_face(str(c["id"])),
		mid - Vector2(72.0, 150.0), Vector2(144.0, 192.0))
	big.pivot_offset = Vector2(72.0, 96.0)
	layer.add_child(big)
	_oath_neon(layer, big.position, big.size, rcol)
	var bt := big.create_tween()
	bt.tween_property(big, "scale", Vector2.ONE, 0.25).from(Vector2(0.7, 0.7)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var nm := _panel_label(layer, Vector2(0.0, mid.y + 54.0), Type.SIZE_MID,
		rcol, Grid.BG.x, 28.0)
	nm.text = "%s  Lv%d" % [str(c["name"]), int(r["lv"])]
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(nm, 8)
	var ef := _panel_label(layer, Vector2(24.0, mid.y + 86.0), Type.SIZE_SMALL,
		Color(0.94, 0.92, 0.94), Grid.BG.x - 48.0, 20.0)
	ef.text = _oath_eff_text(c)
	ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(ef, 5)
	var live := oath_fx_t > 0.0
	if live:
		var cur := _panel_label(layer, Vector2(24.0, mid.y + 110.0),
			Type.SIZE_SMALL, Color(0.72, 0.86, 0.72), Grid.BG.x - 48.0, 18.0)
		cur.text = "지금: %s  %d초 남음  →  바꾸면 사라진다" \
			% [oath_fx_name, int(oath_fx_t)]
		cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(cur, 5)
	# 버튼 둘 — [교체/발동] · [다시 고르기].
	var by := mid.y + 146.0
	var bw2 := (Grid.BG.x - 72.0 - 12.0) * 0.5
	var yes_art := Ui.set_row(OATH, Vector2(36.0, by), Vector2(bw2, 46.0))
	yes_art.modulate = Color(1.25, 1.05, 0.85)
	layer.add_child(yes_art)
	var yes_lbl := _panel_label(layer, Vector2(36.0, by + 14.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), bw2, 18.0)
	yes_lbl.text = "이걸로 교체" if live else "이 계약을 건다"
	yes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var yes := Ui.button("", Vector2(36.0, by), Vector2(bw2, 46.0),
		Type.SIZE_SMALL)
	yes.modulate = Color(1, 1, 1, 0)
	yes.pressed.connect(func() -> void:
		_oath_use(r)
		_oath_reveal.visible = false
		_refresh_oath())   # 판은 남긴다 — 결과를 보고 이어 굴린다
	layer.add_child(yes)
	_pet_hover(yes, yes_art)
	var no_art := Ui.set_row(OATH, Vector2(48.0 + bw2, by), Vector2(bw2, 46.0))
	layer.add_child(no_art)
	var no_lbl := _panel_label(layer, Vector2(48.0 + bw2, by + 14.0),
		Type.SIZE_SMALL, OATH_INK, bw2, 18.0)
	no_lbl.text = "다시 고르기"
	no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var no := Ui.button("", Vector2(48.0 + bw2, by), Vector2(bw2, 46.0),
		Type.SIZE_SMALL)
	no.modulate = Color(1, 1, 1, 0)
	no.pressed.connect(func() -> void: layer.queue_free())
	layer.add_child(no)
	_pet_hover(no, no_art)


# 카드 뒤 후광 — 방사 빔 두 겹 + 잔불. 결과창과 10연차 확인 판이 같이 쓴다
# (사장님: 10회 뽑기도 뒤에 이 이펙트를). parent 는 층, mid 는 카드 중심이다.
func _oath_rays(parent: Control, mid: Vector2, rcol: Color) -> void:
	# 후광 — 부드러운 방사 빔 두 겹이 서로 반대로 천천히 돈다(사장님
	# "부드럽고 고급지게"). 빔은 방사형 그라데이션이라 가로·세로 모두
	# 사그라든다 — 각진 모서리가 없다. 속도 차가 은은한 간섭무늬를 만든다.
	var lit := Color(rcol.r, rcol.g, rcol.b).lerp(Color(1, 1, 1), 0.45)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(lit.r, lit.g, lit.b, 0.28),
		Color(lit.r, lit.g, lit.b, 0.10), Color(lit.r, lit.g, lit.b, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 1.0)   # 밑동(카드 중심)에서 사방으로 사라진다
	gtex.fill_to = Vector2(0.5, 0.0)
	var layers: Array[Control] = []
	for li in 2:
		var rays := Control.new()
		rays.position = mid
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rays)
		parent.move_child(rays, 1)     # 카드·만월 뒤
		var count := 7 if li == 0 else 5
		for i in count:
			var ray := TextureRect.new()
			ray.texture = gtex
			ray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ray.stretch_mode = TextureRect.STRETCH_SCALE
			var rw2 := randf_range(34.0, 60.0) if li == 0 				else randf_range(60.0, 96.0)
			var rl := randf_range(250.0, 340.0)
			ray.size = Vector2(rw2, rl)
			ray.position = Vector2(-rw2 * 0.5, -rl)
			ray.pivot_offset = Vector2(rw2 * 0.5, rl)
			ray.rotation_degrees = float(i) * (360.0 / float(count)) 				+ randf_range(-14.0, 14.0)
			ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rays.add_child(ray)
		# 겹마다 반대 방향·다른 속도 — 같이 돌면 기계, 어긋나야 살아 있다.
		var spin := rays.create_tween().set_loops()
		spin.tween_property(rays, "rotation_degrees",
			360.0 if li == 0 else -360.0, 30.0 if li == 0 else 44.0).from(0.0)
		var breathe := rays.create_tween().set_loops()
		breathe.tween_property(rays, "scale", Vector2(1.06, 1.06), 1.6) 			.set_trans(Tween.TRANS_SINE)
		breathe.tween_property(rays, "scale", Vector2.ONE, 1.6) 			.set_trans(Tween.TRANS_SINE)
		layers.append(rays)
	# 잔불 — 등급색 불티가 카드 곁에서 떠올라 사그라든다.
	for i in 10:
		var spark := ColorRect.new()
		var ss := randf_range(2.0, 4.0)
		spark.size = Vector2(ss, ss)
		spark.color = Color(lit.r, lit.g, lit.b, 0.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(spark)
		var sx := mid.x + randf_range(-130.0, 130.0)
		var sy := mid.y + randf_range(-40.0, 140.0)
		spark.position = Vector2(sx, sy)
		var st2 := spark.create_tween().set_loops()
		st2.tween_interval(randf() * 1.8)
		st2.tween_callback(func() -> void:
			spark.position = Vector2(mid.x + randf_range(-130.0, 130.0),
				mid.y + randf_range(-40.0, 140.0)))
		st2.tween_property(spark, "color:a", 0.75, 0.5)
		st2.parallel().tween_property(spark, "position:y", sy - 26.0, 1.6)
		st2.tween_property(spark, "color:a", 0.0, 1.1)

# 전투 화면 왼쪽 세로 띠의 활성 계약 카드(사장님이 짚은 자리). 카드 그림 +
# 등급 네온 + 남은 시간이고, 누르면 말풍선으로 무슨 효과인지 적어 준다.
const OATH_HUD_AT := Vector2(14.0, 104.0)
const OATH_HUD_CARD := Vector2(52.0, 70.0)
var _oath_hud: Control
var _oath_hud_face: TextureRect
var _oath_hud_neon: Control
var _oath_hud_time: Label
var _oath_hud_tip: Control


func _build_oath_hud() -> void:
	_oath_hud = Control.new()
	_oath_hud.position = OATH_HUD_AT
	_oath_hud.size = Vector2(OATH_HUD_CARD.x, OATH_HUD_CARD.y + 20.0)
	_oath_hud.visible = false
	_oath_hud.z_index = 12
	_hud_root.add_child(_oath_hud)
	_oath_hud_neon = _oath_neon(_oath_hud, Vector2.ZERO, OATH_HUD_CARD,
		Color(0.9, 0.3, 0.3), [[1.0, 2.0, 0.90], [5.0, 4.0, 0.26]])
	_oath_hud_face = Ui.image("res://assets/ui/oath_card.png", Vector2.ZERO,
		OATH_HUD_CARD)
	_oath_hud.add_child(_oath_hud_face)
	_oath_hud_time = _panel_label(_oath_hud, Vector2(-6.0, OATH_HUD_CARD.y + 2.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), OATH_HUD_CARD.x + 12.0, 16.0)
	_oath_hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(_oath_hud_time, 5)
	var hit := Ui.button("", Vector2.ZERO, OATH_HUD_CARD, Type.SIZE_SMALL)
	hit.modulate = Color(1, 1, 1, 0)
	hit.pressed.connect(_oath_hud_toggle)
	_oath_hud.add_child(hit)
	_pet_hover(hit, _oath_hud_face)


# 말풍선 — 카드 오른쪽에 뜨고, 다시 누르거나 버프가 끝나면 사라진다.
func _oath_hud_toggle() -> void:
	if _oath_hud_tip and is_instance_valid(_oath_hud_tip):
		_oath_hud_tip.queue_free()
		_oath_hud_tip = null
		return
	if oath_fx_t <= 0.0:
		return
	var tip := Control.new()
	tip.position = OATH_HUD_AT + Vector2(OATH_HUD_CARD.x + 10.0, 0.0)
	tip.z_index = 13
	_hud_root.add_child(tip)
	_oath_hud_tip = tip
	var rows := PackedStringArray()
	for k in oath_fx:
		rows.append(_oath_fx_long(str(k), float(oath_fx[k])))
	var w := 186.0
	var h := 30.0 + float(rows.size()) * 18.0
	var body := ColorRect.new()
	body.color = Color(0.06, 0.03, 0.06, 0.92)
	body.size = Vector2(w, h)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(body)
	var rcol := _oath_rcol(oath_fx_rarity)
	_oath_neon(tip, Vector2.ZERO, Vector2(w, h), rcol,
		[[0.0, 2.0, 0.85], [4.0, 4.0, 0.22]])
	# 말머리 — 카드 쪽을 가리키는 작은 세모(마름모를 반만 보이게).
	var beak := ColorRect.new()
	beak.color = Color(rcol.r, rcol.g, rcol.b, 0.85)
	beak.size = Vector2(10.0, 10.0)
	beak.position = Vector2(-5.0, 22.0)
	beak.rotation_degrees = 45.0
	beak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(beak)
	var head := _panel_label(tip, Vector2(8.0, 5.0), Type.SIZE_SMALL, rcol,
		w - 16.0, 18.0)
	head.text = oath_fx_name
	_shop_outline(head, 5)
	for i in rows.size():
		var ln := _panel_label(tip, Vector2(8.0, 26.0 + float(i) * 18.0),
			Type.SIZE_SMALL, Color(0.92, 0.90, 0.94), w - 16.0, 16.0)
		ln.text = "· " + str(rows[i])
		_shop_outline(ln, 4)
	tip.modulate.a = 0.0
	tip.create_tween().tween_property(tip, "modulate:a", 1.0, 0.12)


# 말풍선용 긴 이름 — 전투 줄의 축약(_oath_fx_short)과 달리 문장으로 적는다.
func _oath_fx_long(k: String, v: float) -> String:
	match k:
		"attack": return "공격력 +%d%%" % int(v * 100.0)
		"speed": return "공격 속도 +%d%%" % int(v * 100.0)
		"armor": return "받는 피해 -%d%%" % int(v * 100.0)
		"regen": return "회복량 +%d%%" % int(v * 100.0)
		"regen_max": return "초당 최대체력 %d%% 회복" % int(v * 100.0)
		"critdmg": return "치명 피해 +%d%%" % int(v * 100.0)
		"crit": return "치명 확률 +%d%%p" % int(v)
		"cleave": return "평타가 광역이 된다"
		"exec": return "처형 문턱 +%d%%p" % int(v * 100.0)
	return k


# 결과창 — 맨바닥에 글자만 띄우던 걸 판으로(사장님 "결과창도 꾸며줘").
# 카드 뒤에 등급색 광선이 돌고, 아래는 전용 세트 판 + 등급 리본 + 세 줄.
func _oath_result(rcol: Color, rarity: String, r: Dictionary) -> void:
	var c: Dictionary = r["contract"]
	var e: Dictionary = r["engrave"]
	var mid := Vector2(Grid.BG) * 0.5 - Vector2(0.0, 60.0)
	_oath_rays(_oath_reveal, mid, rcol)
	# 결과 판 — 전용 세트. 아래에서 떠오른다.
	var panel := Control.new()
	panel.position = Vector2(0.0, 20.0)
	_oath_reveal.add_child(panel)
	var px := 36.0
	var pw := Grid.BG.x - 72.0
	var py := 596.0
	panel.add_child(Ui.set_card(OATH, Vector2(px, py), Vector2(pw, 158.0)))
	# 등급 리본 — 판 상단 중앙에 등급색 pill.
	var rn := {"common": "커  먼", "uncommon": "언 커 먼", "rare": "레  어",
		"epic": "에  픽", "legend": "만  월", "trueblood": "진  혈"}
	var pill := Ui.set_pill(OATH, Vector2(px + pw * 0.5 - 70.0, py - 14.0),
		Vector2(140.0, 28.0))
	pill.modulate = Color(rcol.r * 1.2, rcol.g * 1.2, rcol.b * 1.2)
	panel.add_child(pill)
	var rlab := _panel_label(panel, Vector2(px + pw * 0.5 - 70.0, py - 9.0),
		Type.SIZE_SMALL, Color(rcol.r, rcol.g, rcol.b).lerp(Color(1, 1, 1), 0.55),
		140.0, 18.0)
	rlab.text = str(rn.get(rarity, rarity))
	rlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(rlab, 5)
	# 이름 — 등급색 큰 글씨. 좌우 핏방울로 눈을 모은다.
	var name := _panel_label(panel, Vector2(px, py + 26.0), Type.SIZE_TITLE,
		rcol, pw, 34.0)
	name.text = str(c["name"])
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(name, 8)
	panel.add_child(Ui.icon("res://assets/ui/res_blood.png",
		Vector2(px + 16.0, py + 30.0), 24.0))
	panel.add_child(Ui.icon("res://assets/ui/res_blood.png",
		Vector2(px + pw - 40.0, py + 30.0), 24.0))
	# 구분선 — 등급색 가는 줄.
	var sep := ColorRect.new()
	sep.color = Color(rcol.r, rcol.g, rcol.b, 0.55)
	sep.position = Vector2(px + 40.0, py + 68.0)
	sep.size = Vector2(pw - 80.0, 2.0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)
	var eff := _panel_label(panel, Vector2(px, py + 80.0), Type.SIZE_SMALL,
		Color(0.96, 0.92, 0.90), pw, 18.0)
	eff.text = "Lv%d  ·  %s" % [int(r["lv"]), _oath_eff_text(c)]
	eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(eff, 5)
	var sub := _panel_label(panel, Vector2(px, py + 106.0), Type.SIZE_SMALL,
		Color(0.80, 0.68, 0.92), pw, 18.0)
	sub.text = "각인: %s%s" % [str(e["name"]),
		"   ·   공명! x%.1f" % OathDefs.RESONANCE_MULT if bool(r["resonance"]) \
		else ""]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(sub, 5)
	# 지금 도는 계약 — 무엇을 잃고 무엇을 얻는지 나란히 봐야 고를 수 있다.
	if oath_fx_t > 0.0:
		var cur := _panel_label(panel, Vector2(px, py + 128.0), Type.SIZE_SMALL,
			Color(0.72, 0.86, 0.72), pw, 16.0)
		cur.text = "지금: %s  %d초 남음  →  바꾸면 사라진다" 			% [oath_fx_name, int(oath_fx_t)]
		cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 서약 정산 줄 — 걸었으면 결과가 보여야 도박이다.
	if bool(r.get("vow", false)):
		var vw := _panel_label(panel, Vector2(px, py + 146.0), Type.SIZE_SMALL,
			OATH_RED, pw, 16.0)
		vw.text = "피의 서약 — 판돈이 등급을 밀었다"
		vw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 버튼 둘 — 전용 세트 줄 + 투명 판정(판의 버튼 문법 그대로).
	var by := py + 168.0
	var bw := (pw - 12.0) * 0.5
	var again_art := Ui.set_row(OATH, Vector2(px, by), Vector2(bw, 46.0))
	panel.add_child(again_art)
	var again_lbl := _panel_label(panel, Vector2(px, by + 14.0),
		Type.SIZE_SMALL, OATH_INK, bw, 18.0)
	again_lbl.text = "다시 굴리기 · 보석 %d" % int(OathDefs.REROLL_GEM)
	again_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := Ui.button("", Vector2(px, by), Vector2(bw, 46.0),
		Type.SIZE_SMALL)
	again.modulate = Color(1, 1, 1, 0)
	again.disabled = gem < OathDefs.REROLL_GEM
	if again.disabled:
		_art_set_base(again_art, Color(0.5, 0.46, 0.48))
	again.pressed.connect(func() -> void:
		if gem < OathDefs.REROLL_GEM:
			return
		gem -= OathDefs.REROLL_GEM
		oath_cards += 1          # 카드를 돌려주고 즉시 다시 굴린다
		_oath_play(false))
	panel.add_child(again)
	_pet_hover(again, again_art)
	var ok_art := Ui.set_row(OATH, Vector2(px + bw + 12.0, by),
		Vector2(bw, 46.0))
	ok_art.modulate = Color(1.25, 1.05, 0.85)     # 발동이 주인공이다
	panel.add_child(ok_art)
	var ok_lbl := _panel_label(panel, Vector2(px + bw + 12.0, by + 14.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), bw, 18.0)
	var live := oath_fx_t > 0.0
	ok_lbl.text = "이걸로 교체" if live else "계약 발동!"
	ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := Ui.button("", Vector2(px + bw + 12.0, by), Vector2(bw, 46.0),
		Type.SIZE_SMALL)
	ok.modulate = Color(1, 1, 1, 0)
	ok.pressed.connect(func() -> void:
		_oath_use(r)
		_oath_reveal.visible = false
		_refresh_oath())   # 판은 남긴다 — 결과를 보고 이어 굴린다
	panel.add_child(ok)
	_pet_hover(ok, ok_art)
	# 버프가 돌고 있을 때만 [지금 것 유지] — 뽑은 카드는 수집·레벨로 남는다.
	if live:
		var keep_art := Ui.set_row(OATH, Vector2(px, by + 54.0), Vector2(pw, 36.0))
		keep_art.modulate = Color(0.78, 0.78, 0.82)
		panel.add_child(keep_art)
		var keep_lbl := _panel_label(panel, Vector2(px, by + 63.0),
			Type.SIZE_SMALL, OATH_INK, pw, 18.0)
		keep_lbl.text = "지금 것 유지 — 뽑은 계약은 수집에 남는다"
		keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var keep := Ui.button("", Vector2(px, by + 54.0), Vector2(pw, 36.0),
			Type.SIZE_SMALL)
		keep.modulate = Color(1, 1, 1, 0)
		keep.pressed.connect(func() -> void:
			_oath_reveal.visible = false
			_refresh_oath())   # 판은 남긴다 — 결과를 보고 이어 굴린다
		panel.add_child(keep)
		_pet_hover(keep, keep_art)
	# 판이 아래에서 떠오르며 자리를 잡는다.
	var pt := panel.create_tween()
	pt.tween_property(panel, "position:y", 0.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.modulate.a = 0.0
	var pf := panel.create_tween()
	pf.tween_property(panel, "modulate:a", 1.0, 0.25)


func _oath_fx_short(k: String, v: float) -> String:
	match k:
		"attack": return "공%+d%%" % int(v * 100.0)
		"speed": return "속%+d%%" % int(v * 100.0)
		"armor": return "방%+d%%" % int(v * 100.0)
		"regen": return "회%+d%%" % int(v * 100.0)
		"regen_max": return "재생%d%%" % int(v * 100.0)
		"critdmg": return "치명%+d%%" % int(v * 100.0)
		"crit": return "치%+d" % int(v)
		"cleave": return "광역"
		"exec": return "처형%+d%%" % int(v * 100.0)
	return k


func _oath_eff_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	var fx: Dictionary = c["effects"]
	for k in fx:
		var v := float(fx[k])
		match str(k):
			"attack": parts.append("공격 +%d%%" % int(v * 100.0))
			"speed": parts.append("공속 +%d%%" % int(v * 100.0))
			"armor": parts.append("받는 피해 -%d%%" % int(v * 100.0))
			"regen": parts.append("회복 +%d%%" % int(v * 100.0))
			"regen_max": parts.append("초당 최대체력 %d%% 회복" % int(v * 100.0))
			"critdmg": parts.append("치명 피해 +%d%%" % int(v * 100.0))
			"crit": parts.append("치명 확률 +%d%%p" % int(v))
			"cleave": parts.append("평타가 광역이 된다")
			"time": parts.append("제한 시간 +%d초" % int(v))
			"exec": parts.append("처형 문턱 +%d%%p" % int(v * 100.0))
			"devour": parts.append("보스 체력 %d%% 즉시 흡수" % int(v * 100.0))
	if float(c.get("dur", 0.0)) > 0.0:
		parts.append("%d초" % int(c["dur"]))
	return "  ·  ".join(parts)


# ── 핏빛 계약 본체 (docs/OATH_DESIGN.md) ──────────────────────────────────
# 1초 틱 — 40분에 1장 충전(보관 3장), 버프 시계.
func _oath_member() -> bool:
	return IapDefs.sub_active(iap_subs, "blood_tax")


func _oath_tick() -> void:
	var member := _oath_member()
	if oath_cards < OathDefs.card_cap(member):
		oath_charge += 1.0 / 60.0
		if oath_charge >= OathDefs.charge_min(member):
			oath_charge = 0.0
			oath_cards += 1
	# 주간 황금 — 멤버십의 몫. 주 열쇠는 임무·보스와 같은 월요일을 쓴다.
	if member:
		_quest_roll_day()
		if oath_week != quest_week:
			oath_week = quest_week
			oath_gold += OathDefs.MEMBER_WEEKLY_GOLD
	if oath_fx_t > 0.0:
		oath_fx_t = maxf(0.0, oath_fx_t - 1.0)
		if oath_fx_t <= 0.0:
			oath_fx = {}
			oath_fx_name = ""
	_refresh_oath()


# 활성 버프 값 — 전투 훅들이 이 한 함수만 본다.
func _oath_val(k: String) -> float:
	return float(oath_fx.get(k, 0.0)) if oath_fx_t > 0.0 else 0.0


# 등급 룰렛 — GachaDefs 무게 그대로, 서약·일일 행운이 shift 만큼 위로 민다.
func _oath_rarity_roll(shift: int) -> String:
	var keys := ["common", "uncommon", "rare", "epic", "legend"]
	var total := 0.0
	for r in GachaDefs.RARITIES:
		if str(r["key"]) in keys:
			total += float(r["weight"])
	var pick := randf() * total
	var idx := 0
	for i in keys.size():
		for r in GachaDefs.RARITIES:
			if str(r["key"]) == keys[i]:
				pick -= float(r["weight"])
		if pick <= 0.0:
			idx = i
			break
	return keys[clampi(idx + shift, 0, keys.size() - 1)]


# 탭 한 번 = 룰렛 세 번. 반환은 공개 연출이 읽을 결과 묶음(빈 딕셔너리 = 실패).
# apply=false 면 **뽑기만** 한다(수집·레벨·천장·서약은 그대로). 실제 발동은
# 결과창에서 사장님이 고른 뒤 _oath_use 가 한다.
func _oath_roll(golden := false, apply := true) -> Dictionary:
	if golden:
		if oath_gold <= 0:
			return {}
		oath_gold -= 1
	else:
		if oath_cards <= 0:
			return {}
		oath_cards -= 1
	# 서약 — 혈액 10%를 걸고 등급을 한 단계 민다. 커먼이면 잃는다(정산은 아래).
	var vow := oath_vow and gold > 0.0
	var vow_cost := gold * OathDefs.VOW_RATE if vow else 0.0
	var shift := 0
	if vow:
		shift += 1
	# 일일 행운 — 매일 첫 카드는 공짜 서약.
	var today := Time.get_date_string_from_system()
	if oath_daily != today:
		oath_daily = today
		shift += 1
	if golden:
		shift += 1   # 황금 계약서 — 언커먼부터 시작
	# 천장 — 만월(100)은 드물어야 극적이다(사장님).
	var pity_hit := false
	if golden:
		oath_gold_pity += 1
		pity_hit = oath_gold_pity >= OathDefs.PITY_GOLD
	else:
		oath_pity += 1
		pity_hit = oath_pity >= OathDefs.PITY_LEGEND
	# 등급 확정 순서: 진혈(0.1%, 누구에게나) > 첫 카드 에픽 > 천장 > 룰렛.
	var rarity := ""
	if _dev_oath_force != "":
		rarity = _dev_oath_force        # [개발 도구] 연출 캡처
		_dev_oath_force = ""
	elif randf() < OathDefs.TRUEBLOOD:
		rarity = "trueblood"
	elif not oath_first:
		oath_first = true
		rarity = "epic"
	elif pity_hit:
		rarity = "legend"
	else:
		rarity = _oath_rarity_roll(shift)
	if rarity == "legend" or rarity == "trueblood":
		if golden:
			oath_gold_pity = 0
		else:
			oath_pity = 0
	# 계약 룰렛.
	var c: Dictionary
	if rarity == "trueblood":
		c = OathDefs.TRUEBLOOD_CONTRACT
		oath_cards += int(c.get("refund", 0))   # 잭팟 환급 — 상한 무시가 맛이다
	else:
		var pool := OathDefs.of_rarity(rarity)
		c = pool[randi() % pool.size()]
	# 중복 = 계약 레벨.
	var clv := clampi(int(oath_lv.get(str(c["id"]), 0)) + 1, 1, OathDefs.LV_MAX)
	oath_lv[str(c["id"])] = clv
	# 각인 룰렛.
	var e: Dictionary = OathDefs.ENGRAVES[randi() % OathDefs.ENGRAVES.size()]
	if str(e["kind"]) == "pity2":
		if golden:
			oath_gold_pity += 1
		else:
			oath_pity += 1
	# 공명 — 같은 등급 연속.
	var resonance := rarity == oath_last_rarity and rarity != "trueblood"
	oath_last_rarity = rarity
	# 서약 정산 — 커먼이면 건 혈액을 잃는다(가호 각인은 절반 보험).
	if vow and rarity == "common":
		gold -= vow_cost * (1.0 - (float(e["v"]) if str(e["kind"]) == "vow_back" 			else 0.0))
	oath_used += 1   # 계약의 서가 이 값으로 찬다
	_refresh_book()
	# 적용 + 환급 각인.
	if apply:
		_oath_apply(c, e, resonance, clv)
	if str(e["kind"]) == "refund" and randf() < float(e["v"]):
		oath_cards += 1
	_save_game()
	_refresh_oath()
	return {"contract": c, "engrave": e, "rarity": rarity,
		"resonance": resonance, "lv": clv, "vow": oath_vow}


# 버프 적용 — 레벨·공명·짙은 피가 주효과를 키우고, 즉발(시간·흡수)은 그 자리서.
# 결과 하나를 골라 발동한다. 굴림 결과 사전을 그대로 받는다.
func _oath_use(r: Dictionary) -> void:
	if r.is_empty():
		return
	_quest_bump("oath")   # 굴린 게 아니라 **쓴** 것을 센다
	_oath_apply(r["contract"], r["engrave"], bool(r["resonance"]), int(r["lv"]))
	_refresh_oath()


func _oath_apply(c: Dictionary, e: Dictionary, resonance: bool, clv: int) -> void:
	var amp := OathDefs.lv_mult(clv)
	if resonance:
		amp *= OathDefs.RESONANCE_MULT + (float(e["v"]) if str(e["kind"]) == "resonance" 			else 0.0)
	if str(e["kind"]) == "amp":
		amp *= 1.0 + float(e["v"])
	var dur := float(c.get("dur", 0.0))
	if str(e["kind"]) == "dur":
		dur *= 1.0 + float(e["v"])
	oath_fx = {}
	for k in (c["effects"] as Dictionary):
		var v := float(c["effects"][k]) * amp
		match str(k):
			"time":
				_boss_time += float(c["effects"][k])   # 시간은 증폭 안 받는다
			"devour":
				_oath_devour(minf(v, 1.0))
			_:
				oath_fx[str(k)] = v
	oath_fx_name = str(c["name"])
	oath_fx_id = str(c["id"])
	oath_fx_rarity = str(c["rarity"])
	oath_fx_t = dur if not oath_fx.is_empty() else 0.0


# 군주의 갈증·진혈 — 판의 우두머리 체력을 물어뜯고 내 체력을 채운다.
# 주간 보스는 비율이 아니라 **고정 피해**(dps x 30초) — 누적 이정표 인플레 방지.
func _oath_devour(frac: float) -> void:
	var best: Foe = null
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f) and (best == null or f.max_hp > best.max_hp):
			best = f
	if best != null:
		var dmg := dps() * 30.0 if raid_on == "boss" else best.max_hp * frac
		best.take_damage(dmg)
	hero_hp = max_hp()


# 시련 입장. 무제한이지만 미궁 층이 잠근다 — 못 여는 이유는 판이 말해 준다.
func _trial_enter() -> void:
	if raid_on != "" or dungeon_on or _fade_t > 0.0:
		return
	var n := trial_stage + 1
	if n > TrialDefs.max_stage() or dungeon_best < TrialDefs.floor_need(n):
		return
	raid_on = "trial"
	_restart_stage("시련 %d단계" % n, true)
	_enter_battle_view()
	_battle_only(true)
	_refresh_dungeon()


func _trial_exit(reason: String) -> void:
	if raid_on != "trial" or _fade_t > 0.0:
		return
	raid_on = ""
	_show_clear("클리어!", reason)
	# **여운** — 재화 던전·미궁과 같은 규칙(사장님 2026-08-25:
	# "유적도 클리어시 너무 빨리 화면을 돌아옴"). 쓰러지는 그림과
	# 방금 뜬 배너를 볼 시간이다.
	var go_trial := func() -> void:
		_restart_stage(reason, true)
		_refresh_currency_visibility()
		_refresh_dungeon()
		_return_gate("trial")
		_save_game()
	if is_inside_tree():
		get_tree().create_timer(CLEAR_HOLD).timeout.connect(go_trial)
	else:
		go_trial.call()


func _claim_milestone(i: int) -> void:
	_boss_roll()
	if boss_got.has(i) or boss_dmg < _boss_need(i):
		return
	boss_got[i] = true
	var m: Dictionary = EventDefs.MILESTONES[i]
	_grant_reward(str(m["reward"]), float(EventDefs.milestone_amount(i, boss_tier)))
	# **넷을 다 받으면 다음 단계**로 (사장님) — 재화 던전이 격파마다 세지는 것과
	# 같은 사다리다. 누적은 0 에서 다시 시작한다: 새 단계의 요구가 그만큼 커졌으므로
	# 옛 누적을 들고 가면 첫 이정표가 공짜로 열린다.
	if boss_got.size() >= EventDefs.MILESTONES.size():
		boss_tier += 1
		boss_got = {}
		boss_dmg = 0.0
		boss_dps = 0.0
	_refresh_currency_visibility()
	_save_game()
	_refresh_dungeon()


func _raid_stage() -> int:
	return int(raid_best.get(raid_on, 0)) + 1


func _raid_roll_day() -> void:
	var today := Time.get_date_string_from_system()
	if raid_date == today:
		return
	raid_date = today
	raid_left = {}
	# 혈세는 **하루 판을 하나 더** 준다 (설계서 5-2) — 표를 나눠 줄 때 얹는다.
	var per_day := RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(iap_subs)
	for k in RaidDefs.RAIDS:
		raid_left[k] = per_day
	# 하루가 바뀌었으니 구독의 오늘치도 이 자리에서 들어온다.
	_iap_daily_grant()


# 오늘 남은 판. 표에 없는 키(새 던전·옛 저장본)는 가득 찬 것으로 본다.
func _raid_left(kind: String) -> int:
	return int(raid_left.get(kind,
		RaidDefs.TRIES_PER_DAY + IapDefs.raid_bonus_tries(iap_subs)))


func _raid_enter(kind: String) -> void:
	# 미궁과 같은 규칙: 암전 중엔 안 들어가고, 두 모드는 겹치지 않는다.
	if raid_on != "" or dungeon_on or _fade_t > 0.0:
		return
	if best_stage < RaidDefs.open_stage(kind):
		return
	_raid_roll_day()
	if _raid_left(kind) <= 0:
		return
	# **여기서 안 깎는다.** 표는 격파할 때 깎인다(_advance_stage) — 실패에 표를
	# 물리면 도전 자체를 안 하게 된다(사장님 2026-08-12).
	raid_on = kind
	_restart_stage("%s 입장" % str(RaidDefs.RAIDS[kind]["name"]), true)
	_enter_battle_view()
	_battle_only(true)
	_refresh_dungeon()
	_save_game()


# 던전·미궁·보스에 **들어가면 전투가 보여야 한다**. 이 셋의 탭이 전면 판이
# 되면서(2026-08-13) 입장해도 판이 화면을 덮고 있어 "들어갔는데 아무 일도
# 안 일어난 것"처럼 보였다(사장님 버그 신고). 반판 탭으로 옮겨 전투를 연다.
func _enter_battle_view() -> void:
	if _tab in FULL_TABS:
		_select_tab("growth")
	_refresh_currency_visibility()   # 상단 소품이 레이드 규칙으로 바뀐다


# 던전·시련 전투는 **기본 화면만** (사장님, 레퍼런스) — 하단 탭·판을 걷고
# 중단 버튼 하나만 남긴다. 복구는 _return_gate 가 _select_tab 으로 한다.
func _nav_hover(btn: BaseButton, art: Control) -> void:
	if art.pivot_offset == Vector2.ZERO:
		art.pivot_offset = art.size * 0.5
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled and is_inside_tree():
			create_tween().tween_property(art, "scale",
				Vector2(1.06, 1.06), 0.08))
	btn.mouse_exited.connect(func() -> void:
		if is_inside_tree():
			create_tween().tween_property(art, "scale", Vector2.ONE, 0.08))
	btn.button_down.connect(func() -> void:
		if is_inside_tree():
			create_tween().tween_property(art, "scale",
				Vector2(0.94, 0.94), 0.05))
	btn.button_up.connect(func() -> void:
		if is_inside_tree():
			create_tween().tween_property(art, "scale",
				Vector2(1.06, 1.06), 0.08))


func _battle_only(on: bool) -> void:
	if _nav_root:
		_nav_root.visible = not on
	if _board:
		_board.visible = on or _tab == "home"
		if _board.visible:
			_refresh_board()
	if on:
		for key in _panels.keys():
			_panels[key].visible = false
		_panel_bg.visible = false
		_panel_bg_full.visible = false
		_goal_widget.visible = false
		if _side_root:
			_side_root.visible = false


# 전장 게시판 갱신 — 1초 틱(_tick_titles)이 부른다. 스킬 쿨다운·지표·버튼.
func _refresh_board() -> void:
	if _board == null or not _board.visible or _board_cells.is_empty():
		return
	for i in 7:
		var c: Dictionary = _board_cells[i]
		var key := str(skill_equipped[i]) if i < skill_equipped.size() else ""
		var live := key != ""
		for n in ["frame", "icon", "shade", "num"]:
			(c[n] as CanvasItem).visible = live
		if not live:
			continue
		(c["icon"] as TextureRect).texture = Assets.tex(SkillDefs.icon_path(key))
		var cd := float(_skill_cd.get(key, 0.0))
		var total := maxf(1.0, float(SkillDefs.shape_of(key).get("cooldown", 1.0)))
		(c["shade"] as ColorRect).size.y = 54.0 * clampf(cd / total, 0.0, 1.0)
		(c["num"] as Label).text = str(int(ceil(cd))) if cd > 0.4 else ""
		# 시전 감지 — 쿨다운이 만땅으로 튀는 순간 금빛 번쩍. 하단과 전투가 이어진다.
		if cd > float(_board_prev_cd.get(key, 0.0)) + 0.5 and is_inside_tree():
			var fr := c["frame"] as CanvasItem
			fr.modulate = Color(1.6, 1.35, 0.7)
			create_tween().tween_property(fr, "modulate", Color.WHITE, 0.45)
		_board_prev_cd[key] = cd
	var gate := _in_raid() or dungeon_on
	_board_pills[0].text = "피해  %s /초" % _n(dps())
	if dungeon_on:
		_board_pills[1].text = "혈정 +%s" % _n(DungeonDefs.first_clear_reward(
			dungeon_floor)) if dungeon_floor > dungeon_best else "기록 갱신 없음"
		_board_pills[2].text = "최고 %d층" % dungeon_best
	elif raid_on == "boss":
		_board_pills[1].text = "누적 %s" % _n(boss_dmg)
		_board_pills[2].text = "오늘 %d / %d판" % [boss_tries, EventDefs.TRIES_PER_DAY]
	elif raid_on == "trial":
		_board_pills[1].text = "격파 시 +%d%%" % int(round(
			TrialDefs.BONUS_PER * 100.0 * float(trial_stage + 1)))
		_board_pills[2].text = "도전 무제한"
	elif raid_on != "":
		_board_pills[1].text = "%s +%s" % [str(RaidDefs.RAIDS[raid_on]["currency"]),
			_n(_raid_gain(raid_on, _raid_stage()))]
		_board_pills[2].text = "오늘 %d판 · %s" % [_raid_left(raid_on),
			"연속" if _raid_repeat else "한 판"]
	else:
		_board_pills[1].text = "혈액  %s /분" % _n(_income_per_min)
		_board_pills[2].text = "전투력  %s" % _n(Balance.combat_power(dps(),
			max_hp(), regen_per_sec()))
	_board_btn.text = "중단" if gate \
		else ("방치 상자  %s" % _n(chest_gold) if chest_gold > 0.0 else "방치 상자")


# 액자 초상 한 벌 — 어두운 속바탕 + 넘치게 그린 초상(창이 잘라냄) + 액자.
# 초상 원본마다 여백이 달라서(여왕은 여백 크고 파수꾼은 꽉 참) 창 크기로 정직하게
# 그리면 작은 놈은 허공에 뜬다(사장님 실측) — 과감히 키우고 창으로 자른다.
func _framed_portrait(parent: Control, at: Vector2, fsize := 52.0) -> TextureRect:
	# 한 덩어리(초상+액자)를 왼쪽·위로 6px — 판 홈에 딱 앉게(사장님 조정 x2).
	at += Vector2(-6.0, -6.0)
	# 창 = 액자와 **같은 사각형** — 초상이 테두리 밑까지 깔린다. 재조립 테두리
	# 안쪽에 잔여물이 몇 픽셀 남든, 틈이 어디 뚫려 있든 그 밑은 초상이라
	# **공백이 구조적으로 불가능하다**(사장님: 아직도 빈 곳 — 창 좌표 계산으로는
	# 액자 그림의 비대칭을 못 쫓아간다는 결론).
	# 단, 액자 그림 바깥의 투명 여백(원본 0~2px) 밑으로는 초상이 비치면 안 되니
	# 그 두께만큼만 창을 안으로 문다.
	var m := fsize * 3.0 / 64.0
	var win := Control.new()
	win.position = at + Vector2(m, m)
	win.size = Vector2(fsize - m * 2.0, fsize - m * 2.0)
	win.clip_contents = true
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(win)
	var back := ColorRect.new()
	back.color = Color(0.085, 0.07, 0.10)
	back.size = win.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(back)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 꽉 채운다(사장님) — 초상 원본을 피사체 기준으로 재단해 뒀으므로(빌드 스크립트)
	# 여기서는 살짝만 키워 가장자리 어중간한 여백을 무는 정도면 된다.
	art.size = win.size * 1.05
	art.position = -win.size * 0.025
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(art)
	parent.add_child(Ui.image("res://assets/ui/frame_portrait.png",
		at, Vector2(fsize, fsize)))
	return art


func _gate_exit_pressed() -> void:
	_raid_repeat = false
	_raid_again = ""
	if dungeon_on:
		_dungeon_exit("미궁 중단")
	elif raid_on == "boss":
		_boss_exit("도전 중단")
	elif raid_on == "trial":
		_trial_exit("도전 중단")
	elif raid_on != "":
		_raid_exit("던전 중단 — 빈손")


# 나오면 **들어온 그 페이지**로 돌려보낸다 (사장님, 레퍼런스 문법).
func _return_gate(mode: String) -> void:
	_battle_only(false)
	_select_tab("raid")
	_raid_set_mode(mode)


func _raid_exit(reason: String) -> void:
	if raid_on == "" or _fade_t > 0.0:
		return
	raid_on = ""
	# `stage` 는 건드린 적이 없으므로 재시작만 하면 본편 그 자리다(미궁과 동일).
	_restart_stage(reason, true)
	_refresh_currency_visibility()
	_refresh_dungeon()
	_return_gate("raid")


# ── 미궁 입장·이탈 ──────────────────────────────────────────────────────────
func _dungeon_enter() -> void:
	if dungeon_on or _fade_t > 0.0:
		return
	var open := DungeonDefs.open_floors(best_stage)
	if open <= 0:
		return
	dungeon_on = true
	# 늘 최고 기록 다음 층에 도전한다. 개방 상한에 닿았으면 상한 층을 다시 돈다 —
	# 지금은 기록만 남지만 2단계에서 소탕 기준층이 되므로 도는 것 자체는 무의미하지 않다.
	dungeon_floor = clampi(dungeon_best + 1, 1, open)
	_restart_stage("미궁 입장", true)
	_enter_battle_view()
	_battle_only(true)
	_refresh_dungeon()


func _dungeon_exit(reason: String) -> void:
	# **암전 중엔 안 나간다.** 깃발만 내리면 `_restart_stage` 가 조용히 빠져서(아래),
	# 미궁 몹이 서 있는데 래퍼는 본편 값을 읽는 반쪽 상태가 된다 — 깃발과 재시작은
	# 한 몸으로만 움직여야 한다.
	if not dungeon_on or _fade_t > 0.0:
		return
	dungeon_on = false
	# `stage` 는 건드린 적이 없으므로 재시작만 하면 본편 그 자리다.
	_restart_stage(reason, true)
	_refresh_currency_visibility()
	_refresh_dungeon()
	_return_gate("maze")


func _spawn_wave() -> void:
	if _walk_only:
		return
	if _c_is_boss() or _c_is_midboss():
		_spawn_foe()
		return
	for _i in _wave_size(stage):
		_spawn_foe()


# 몹이 사라질 때 Main 이 프레임을 넘겨 들고 있던 참조를 놓는다. 셋이 있다:
# `_engaged`(교전 대상) · `_pending_target`(임팩트 프레임에 때릴 놈) ·
# `_skill_target`(스킬이 겨눈 놈).
#
# **함수 안의 is_instance_valid 로는 못 막는다.** 인자가 `Foe` 로 타입 지정돼 있으면
# 해제된 객체는 **호출 자체가** 거부된다("previously freed is not a subclass") —
# 가드가 있는 함수 본문에 들어가지도 못한다. 실제로 `_face_toward(_skill_target)` 이
# 그렇게 터졌다. 호출부마다 가드를 덧대는 대신 **참조를 놓는 한 곳**을 둔다:
# 세 참조 전부와 앞으로 생길 참조까지 여기서 끊긴다.
func _forget_foe(f: Foe) -> void:
	if _engaged == f:
		_engaged = null
	if _pending_target == f:
		_pending_target = null
	if _skill_target == f:
		_skill_target = null


# 사냥터에 한 마리 세운다. **줄 맨 뒤에** 선다 — 첫 마리는 전열 바로 뒤(FRONT_X),
# 그 뒤로 FOE_GAP 씩 물러난다. 영웅이 전진하면 이 줄이 차례로 다가온다.
func _spawn_foe() -> void:
	var act: Dictionary = _c_act_data()
	var boss := _c_is_boss()
	var midboss := _c_is_midboss()
	var key: String = str(act["boss"]) if boss else \
		str((act["roster"] as Array)[randi() % (act["roster"] as Array).size()])
	var tier := FoeTiers.get_tier(key)
	if raid_on == "boss":
		var eb := EventDefs.boss_of(_boss_week_index())
		tier = FoeTiers.get_tier(str(eb["key"]))
		tier["name"] = str(eb["name"])
		tier["anim_key"] = str(eb["anim"])
	elif raid_on != "" and RaidDefs.goal(raid_on) == "slay":
		# 성소 수호자도 전용 보스다(사장님 2026-08-20) — 여기만 본편 막 보스를
		# 빌려 쓰고 있었다("또 저놈"). 시련·주간 보스와 같은 규칙으로 맞춘다.
		tier = FoeTiers.get_tier("sanctum_guardian")
		tier["anim_key"] = "sanctum_guardian"
	elif raid_on == "trial":
		# 전용 보스 — 막 보스를 빌리면 "또 저놈"이 된다(주간 보스와 같은 규칙).
		tier = FoeTiers.get_tier("ruin_warden")
		tier["anim_key"] = "ruin_warden"
	elif boss and dungeon_on:
		# 미궁은 **제 보스 표**를 쓴다(DungeonDefs.MAZE_BOSSES) — 막 보스 다섯만
		# 돌리면 6층부터 얼굴이 반복된다. 체력 배수는 얼굴과 무관하게 고정이다.
		var mb := DungeonDefs.boss_of(dungeon_floor)
		tier = FoeTiers.get_tier(str(mb["key"]))
		tier["name"] = str(mb["name"])
		tier["anim_key"] = str(mb["anim"])
		tier["hp_mult"] = DungeonDefs.MAZE_BOSS_HP
	elif boss:
		tier["name"] = str(act["boss_name"])
		tier["anim_key"] = str(act["boss_anim"])
	elif midboss:
		tier["midboss"] = true
		tier["name_prefix"] = _c_midboss_prefix() + " "
	# 성소는 **수호자 한 마리**가 판이다 — 이름으로도 그게 읽혀야 한다.
	if raid_on != "" and raid_on != "boss" and raid_on != "trial" \
			and RaidDefs.goal(raid_on) == "slay":
		tier["name_prefix"] = "수호자 "
	var f := Foe.new()
	# 혈액은 **배급으로만** 들어온다(2026-08-20, 사장님 요구 4: 던전+방치).
	# 처치가 돈을 떨구면 소득이 DPS 지수를 그대로 타서 비용을 지수로 묶어야 하고,
	# 그러면 레벨을 많이 못 판다 — 요구 1·2가 요구 4에 딸려 있는 이유다.
	f.setup(tier, _c_enemy_power(), 0.0, boss)
	if raid_on == "boss":
		# 체력만 갈아 끼운다 — 40초에 못 눕히는 게 정상이고, 성과는 누적 피해다.
		f.max_hp = EventDefs.boss_hp(boss_dps, boss_tier)
		f.hp = f.max_hp
	elif raid_on != "" and raid_on != "trial":
		# 성소의 **수호자 한 마리**는 웨이브 몫을 혼자 짊어진다(hp_mult).
		# 다른 던전은 배수가 1 이라 이 줄이 아무것도 안 한다.
		var mult := RaidDefs.hp_mult(raid_on)
		if mult != 1.0:
			f.max_hp *= mult
			f.hp = f.max_hp
	# **미궁 보스는 배수를 눌러 준다.** 층마다 보스로 바꾼 뒤(2026-08-25)
	# BOSS_HP_MULT(35) 를 그대로 두면 잡몹 다섯(5)의 일곱 배라 한 층이 통째로
	# 벽이 된다. 다섯 마리 몫보다 조금 더 무겁게만 둔다.
	if dungeon_on and boss:
		f.max_hp *= DungeonDefs.BOSS_HP_SCALE
		f.hp = f.max_hp
	# 미궁 몹은 깊이만큼 어둡고 붉다 — 배경을 새로 뽑지 않고 "깊어졌다"를 읽힌다.
	if dungeon_on:
		f.modulate = DungeonDefs.depth_tint(dungeon_floor)
	# 줄 맨 뒤. 빈 사냥터면 전열에, 아니면 마지막 놈에서 FOE_GAP 뒤에 선다.
	# **화면 밖까지 나가도 된다** — 그게 "저 앞에 더 있다"이고, 영웅이 달려가 만난다.
	var tail := _queue_tail_x(get_tree().get_nodes_in_group("foes")) \
		if is_inside_tree() else -INF
	var at := FRONT_X if tail == -INF else maxf(tail + _c_foe_gap(), FRONT_X)
	# 보스·중간보스는 한 마리뿐이라 화면 밖에서 걸어 들어오는 그림이 필요하다.
	if boss or midboss:
		at = SPAWN_X
	f.position = Vector2(at, ground_y)
	f.stop_x = at
	# 사라질 때 **들고 있던 참조를 놓는다.** tree_exiting 은 실제 해제 **전에** 오므로
	# 이 시점의 f 는 아직 멀쩡하다 — _forget_foe 참고.
	f.tree_exiting.connect(_forget_foe.bind(f))
	add_child(f)
	if _dev_dying >= 0.0:
		# [개발 도구] 죽는 도중에 얼린다 — 디졸브를 눈으로 고르려면 필요하다.
		f.die_freeze = _dev_dying
		f._die()
	if _dev_flash > -2.0:
		# [개발 도구] 번쩍임 고정 — 0.1초짜리라 그냥 찍으면 안 잡힌다.
		f.flash_hold = _dev_flash if _dev_flash >= 0.0 else (
			Foe.FLASH_BOSS if (boss or f.is_midboss) else Foe.FLASH_MOB)
		f._set_flash(f.flash_hold)
	if boss:
		# 보스는 **컷신**이다 — 카메라가 가고(팬) 이름이 크게 뜬다(레퍼런스).
		_boss_pan(f)
		_boss_cut(f.display_name)
	elif midboss:
		_announce_elite(f.display_name)


func _announce_elite(name: String) -> void:
	# 중간보스는 배너 한 줄로 족하다 — 이름을 크게 띄우는 건 보스 몫이다.
	_shake_combat(4.0)


# ── 보스 등장 연출 (사장님 2026-08-14, 레퍼런스: 카메라가 보스로 가고 이름이
# 뜬 뒤 돌아온다) ─────────────────────────────────────────────────────────────
# 레퍼런스는 3D 카메라를 실제로 옮기지만 우리는 옆보기 고정 화면이다. 같은
# 인상을 **레터박스 + 큰 이름**으로 낸다: 위아래가 좁혀지면 "지금은 컷신"이
# 읽히고, 카메라 팬(_boss_pan)이 이미 보스를 화면 가운데로 데려온다.
var _boss_shade: ColorRect     # 전투 뷰만 덮는 암전 — 걷히는 게 등장이다
var _boss_cut_name: Label          # 암전 위 작은 이름(사장님: 다시, 대신 작게)


func _build_boss_cut() -> void:
	_boss_shade = ColorRect.new()
	_boss_shade.color = Color(0.02, 0.01, 0.03, 0.0)
	_boss_shade.size = Vector2(Grid.BG.x, VIEW_BOTTOM)
	_boss_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_shade.z_index = 60
	_boss_shade.visible = false
	_hud_root.add_child(_boss_shade)
	_boss_cut_name = _mk_label(Vector2(0.0, VIEW_BOTTOM * 0.40), Type.SIZE_MID,
		Color(1.0, 0.92, 0.86))
	_boss_cut_name.size = Vector2(Grid.BG.x, 30.0)
	_boss_cut_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_cut_name.add_theme_constant_override("outline_size", 8)
	_boss_cut_name.add_theme_color_override("font_outline_color",
		Color(0.28, 0.0, 0.04))
	_boss_cut_name.z_index = 61
	_boss_cut_name.modulate.a = 0.0


# 컷신을 **즉시 걷는다**. 연출 도중 판이 끝나거나 탭을 옮기면 트윈이 멈춰
# 암전이 화면에 남는다 — 끄는 것까지가 연출이다.
func _boss_cut_clear() -> void:
	if _boss_shade == null:
		return
	if _boss_cut_tw and _boss_cut_tw.is_valid():
		_boss_cut_tw.kill()
	_boss_shade.visible = false
	_boss_shade.color.a = 0.0
	_boss_cut_name.modulate.a = 0.0


var _boss_cut_tw: Tween


# 판(모달)이 하나라도 떠 있으면 컷신을 안 튼다 — 전투 화면 연출이라 판 위에
# 뜨면 남의 화면을 덮는다(사장님 실측: 계약 판 위에 보스 이름이 떴다).
func _modal_open() -> bool:
	for v in [_quest_view, _codex_view, _oath_view, _reward_view, _info_view,
			_confirm_view]:
		if v != null and v.visible:
			return true
	return false


# 컷신은 **전투 화면이 실제로 보일 때만** 튼다(사장님 2차 지적: 모달 몇 개만
# 막았더니 펫·상점 같은 전면 탭 위로 여전히 떴다). 조건을 거꾸로 세운다 —
# "가리는 게 있나"가 아니라 "사냥터가 화면에 있나". 성장·장비·사냥은 판이
# 화면 일부만 덮어 사냥터가 늘 보이므로 셋 다 허용(사장님 3차 확정) —
# 즉 전면 판(FULL_TABS)이 아니면 보인다.
func _battle_visible() -> bool:
	return (_tab not in FULL_TABS or raid_on != "" or dungeon_on) 		and not _modal_open()


# 등장 = 전투 뷰가 훅 어두워졌다가 걷힌다. 띠도 큰 이름도 없다(사장님:
# 글자가 UI 를 넘쳤다 — 이름은 상단 보스 게이지가 이미 적는다).
func _boss_cut(name: String) -> void:
	if _boss_shade == null or not _battle_visible():
		return
	_boss_cut_clear()
	_boss_shade.visible = true
	_boss_cut_name.text = name
	var t := create_tween().set_parallel()
	_boss_cut_tw = t
	t.tween_property(_boss_shade, "color:a", 0.80, 0.18)
	t.tween_property(_boss_cut_name, "modulate:a", 1.0, 0.22).set_delay(0.10)
	var out := 0.43
	t.tween_property(_boss_shade, "color:a", 0.0, 0.8 + BOSS_PAN_HOLD) 		.set_delay(out).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_boss_cut_name, "modulate:a", 0.0, 0.45).set_delay(out + 0.25)
	t.finished.connect(_boss_cut_clear)


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
	position.y = 0.0   # 흔들림이 중간에 끊겼으면 세로가 남아 있다
	# 보스를 화면 가운데로. 왼쪽(양수)으로는 안 민다 — 영웅 뒤엔 볼 게 없다.
	var dx := clampf(float(Grid.BG.x) * 0.5 - boss.position.x, -260.0, 0.0)
	_boss_pan_t = 0.45 + BOSS_PAN_HOLD + 0.5
	var t := create_tween()
	t.tween_property(self, "position:x", dx, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_interval(BOSS_PAN_HOLD)
	t.tween_property(self, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_combat_shake = t


# 한 번 밀었다 돌아오는 게 아니라 **줄어들며 두 번 더 떤다.** 1왕복은 "밀렸다"로
# 읽히고, 감쇠 왕복이라야 "맞았다"로 읽힌다.
# 세로도 같이 흔든다 — 가로만 흔들면 카메라가 미끄러진 것처럼 보이고, 세로가
# 섞여야 "쿵"이 된다. 세로는 가로의 절반 이하로 둔다(넘으면 화면이 튄다).
func _shake_combat(amount: float) -> void:
	if not is_inside_tree() or _boss_pan_t > 0.0:
		return
	if _combat_shake and _combat_shake.is_valid():
		_combat_shake.kill()
	position = Vector2.ZERO
	_combat_shake = create_tween()
	var steps := [
		Vector2(-amount, amount * 0.42),
		Vector2(amount * 0.68, -amount * 0.28),
		Vector2(-amount * 0.32, amount * 0.14),
		Vector2.ZERO,
	]
	var spans := [0.035, 0.045, 0.04, 0.035]
	for i in steps.size():
		_combat_shake.tween_property(self, "position", steps[i], float(spans[i]))


func on_foe_killed(f: Foe) -> void:
	gold += f.gold
	_income_acc += f.gold   # 분당 수입 표시(사냥 수입만 — 임무·던전 뭉치는 안 센다)
	kills += 1
	_quest_bump("kills")
	var prev_kills := int(codex.get(f.key, 0))
	codex[f.key] = prev_kills + 1
	if prev_kills == 0:
		codex_found += 1
	# 지식 레벨이 오른 순간에만 합계를 갱신하고 보상을 확인한다.
	var gained := FoeTiers.codex_level(prev_kills + 1) - FoeTiers.codex_level(prev_kills)
	if gained > 0:
		codex_knowledge += gained
		# 숙련 단계 상승 — 순간을 알린다(칭호 배너와 같은 줄). 알리지 않으면
		# 있는 기능이 없는 기능이 된다.
		_claim_codex_reward()
	_gain_exp(Balance.exp_per_kill(StageDefs.major_stage(stage)))
	# 가이드 버튼의 "받을 개수"는 여기서만 갱신한다. _refresh_hud 는 매 프레임이라
	# 거기 얹으면 초당 60번 라벨을 다시 쓴다.
	_refresh_goal_widget()
	# 전투 드랍은 없앴다(2026-08-04). 장비가 나오는 곳은 **소환 하나**다 —
	# 드랍이 알아서 장착까지 해 주면 소환으로 뽑은 장비를 고를 이유가 사라지고,
	# 보관함에서 하는 선택이 전부 무의미해진다.
	if not _defer_stage_advance and _c_kill_clear():
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
	var extra := FoeTiers.codex_extra(r)
	if not extra.is_empty():
		_grant_reward(str(extra["kind"]), float(extra["amount"]))


func _gain_exp(amount: float) -> void:
	hero_exp += amount
	while hero_exp >= Balance.exp_need(hero_lv):
		hero_exp -= Balance.exp_need(hero_lv)
		hero_lv += 1


func _advance_stage() -> void:
	_flash_roll_later()
	if _fade_t > 0.0:
		return
	_clear_foes()
	_phase = "advance"
	# ── 주간 보스를 실제로 눕혔다 — 드문 일이다(체력이 40초 x20 이다) ──────
	if raid_on == "boss":
		_boss_exit("주간 보스 격파")
		return
	# ── 시련: 단계 보스를 눕혔다 — 영구 보너스가 한 계단 오른다 ─────────────
	if raid_on == "trial":
		var old_max := max_hp()
		trial_stage += 1
		_apply_hp_growth(old_max)
		_trial_exit("시련 %d단계 격파 — 공격·체력 +%d%%" % [trial_stage,
			int(round(TrialDefs.BONUS_PER * 100.0 * float(trial_stage)))])
		return
	# ── 재화 던전: 한 판이 끝났다 — 뭉치를 주고 본편으로 돌아간다 ──────────
	if raid_on != "":
		var kind := raid_on
		var n := _raid_stage()
		var amount := _raid_gain(kind, n)
		raid_best[kind] = n
		raid_left[kind] = maxi(0, _raid_left(kind) - 1)   # 표는 격파에만 깎인다
		match kind:
			"blood": gold += amount
			"pact": sigil += amount
			"hunt": feed += amount
			"forge": whet += amount
		_show_clear("클리어!", "%s  ·  %s +%s"
			% [RaidDefs.label(kind, n),
			str(RaidDefs.RAIDS[kind]["currency"]), _n(amount)])
		raid_on = ""
		_quest_bump("raid")   # 주간 임무(재화 던전 격파)가 센다
		_boss_cut_clear()     # 수호자 판이면 컷신 띠가 떠 있을 수 있다
		# 연속 도전 — 표가 남아 있으면 같은 던전에 다시 들어간다. 재입장은
		# **암전이 끝난 뒤**여야 한다(_raid_enter 는 페이드 중엔 조용히 빠진다).
		var again := _raid_repeat and _raid_left(kind) > 0
		# **여운.** 예전엔 마지막 놈이 쓰러지는 그 프레임에 암전이 시작돼서
		# 사망 연출도, 방금 뜬 보상 배너도 못 보고 판이 끊겼다(사장님
		# 2026-08-25: "던전이 끝나면 그냥 갑자기 확 끝나버리네").
		# 상태(raid_on·표·보상)는 이미 위에서 정리했으니 이 사이에 두 번
		# 격파되지 않는다 — 화면만 조금 더 머문다.
		var finish := func() -> void: _fade(func() -> void:
			kills = 0
			# **새 판은 늘 만피로 시작한다**(사장님 2026-08-12). 죽지 않고 넘어온 판이라도
			# 회복은 여기서 한 번 — 안 그러면 앞 구간에서 깎인 체력이 그대로 넘어와
			# "한 대 더 맞으면 죽는 구간"이 이어진다.
			hero_hp = max_hp()
			_boss_time = _c_time_limit()
			_begin_stage_pose()
			_start_advance()
			_apply_stage_bg()
			# 연속 도전은 **암전이 걷힌 뒤**에 들어간다. 이 콜백은 화면이 아직
			# 검을 때(_fade_t > 0) 도는 자리라, 여기서 부르면 _raid_enter 의
			# 가드에 걸려 조용히 빠진다(실측: 다시 안 들어갔다). 깃발만 세운다.
			if again:
				_raid_again = kind)
		if is_inside_tree():
			get_tree().create_timer(CLEAR_HOLD).timeout.connect(finish)
		else:
			finish.call()
		_refresh_dungeon()
		if not again:
			_return_gate("raid")   # 연속이 아니면 들어온 페이지로 (사장님)
		_save_game()
		return
	# ── 미궁: 층을 하나 오른다. 본편(stage)은 안 건드린다 ──────────────────
	if dungeon_on:
		# 재화 던전과 같은 여운 — 쓰러지는 그림과 클리어 연출을 볼 시간이다.
		_show_clear("클리어!", "%s 돌파" % DungeonDefs.label(dungeon_floor))
		var finish_maze := func() -> void: _fade(func() -> void:
			kills = 0
			# **새 판은 늘 만피로 시작한다**(사장님 2026-08-12). 죽지 않고 넘어온 판이라도
			# 회복은 여기서 한 번 — 안 그러면 앞 구간에서 깎인 체력이 그대로 넘어와
			# "한 대 더 맞으면 죽는 구간"이 이어진다.
			hero_hp = max_hp()
			# **첫 돌파에만 혈정이 나온다.** 같은 층을 다시 돌면(개방 상한에 닿아
			# 제자리를 돌 때) 기록 비교가 거짓이라 안 준다 — 도는 것의 값은
			# 소탕 시급이 이미 치르고 있다.
			if dungeon_floor > dungeon_best:
				var reward := DungeonDefs.first_clear_reward(dungeon_floor)
				crystal += reward
			dungeon_best = maxi(dungeon_best, dungeon_floor)
		# (연출은 암전 **전에** 이미 떴다 — 아래 _show_clear 참고)
			_claim_promo_reward()
			_quest_bump("dungeon")
			var open := DungeonDefs.open_floors(best_stage)
			if dungeon_floor >= open:
				# 개방 상한까지 다 올랐다 — 본편을 밀어야 다음 층이 열린다
				# (EXPANSION 7장의 교차 잠금). 나가는 길은 재시작과 같다.
				dungeon_on = false
				_return_gate("maze")
			else:
				dungeon_floor += 1
			_boss_time = _c_time_limit()
			_begin_stage_pose()
			_start_advance()
			_apply_stage_bg())
		if is_inside_tree():
			get_tree().create_timer(CLEAR_HOLD).timeout.connect(finish_maze)
		else:
			finish_maze.call()
		_refresh_dungeon()
		_save_game()
		return
	# 배경과 몹이 **암전 뒤에서** 바뀐다. 그냥 갈아 끼우면 화면이 휙 튄다.
	_fade(func() -> void:
		kills = 0
		# **새 판은 늘 만피로 시작한다**(사장님 2026-08-12). 죽지 않고 넘어온 판이라도
		# 회복은 여기서 한 번 — 안 그러면 앞 구간에서 깎인 체력이 그대로 넘어와
		# "한 대 더 맞으면 죽는 구간"이 이어진다.
		hero_hp = max_hp()
		var next_stage := mini(stage + 1, StageDefs.total_stages())
		if next_stage > best_stage:
			if StageDefs.is_boss_stage(stage):
				gem += GachaDefs.COST
			# 군림 — 돌파가 해금 문턱을 넘는 순간 배너로 알린다. 자동 해금은
			# 알리지 않으면 없는 기능과 같다.
			var mastery0 := MasteryDefs.unlocked_count(best_stage)
			best_stage = next_stage
			if MasteryDefs.unlocked_count(best_stage) > mastery0:
				var r: Dictionary = MasteryDefs.RANKS[mastery0]
		stage = next_stage
		_quest_bump("stage")
		_boss_time = StageDefs.time_limit(stage)
		_begin_stage_pose()   # stage 가 정해진 뒤에 부른다 — 보스인지 여기서 갈린다
		_start_advance()
		_apply_stage_bg())


# 제한 시간은 **보스·중간보스 구간에만** 돈다. 시간을 넘기면 그 구간을 처음부터
# 다시 한다. 일반 구간은 StageDefs.time_limit 이 0 이라 _boss_time 이 0 으로 들어오고,
# 아래 첫 줄에서 그대로 빠져나간다 — 처치 수만 채우면 넘어간다.
# 전환 중(_fade_t > 0)에는 세지 않는다 — 화면이 검은데 시계가 도는 건 손해다.
func _tick_boss_timer(delta: float) -> bool:
	if _boss_time <= 0.0 or _fade_t > 0.0 or _hero_dead:
		return false
	_boss_time -= delta
	if _boss_time > 0.0:
		return false
	# 미궁에서 시간을 넘기면 그 층을 다시 도는 게 아니라 **본편으로 나온다** —
	# 미궁은 실패 페널티가 없는 대신 재도전은 다시 들어와서 한다(EXPANSION 7장).
	if dungeon_on:
		_dungeon_exit("미궁 시간 초과")
		return true
	if raid_on == "boss":
		_boss_exit("도전 종료")
		return true
	if raid_on == "trial":
		_trial_exit("시간 초과")
		return true
	if raid_on != "":
		# **버티기 던전은 시계가 성공 조건이다** (사장님 2026-08-14: 던전마다
		# 테마가 달라야 한다). 끝까지 살아 있으면 그게 격파다 — 다른 던전은
		# 시간이 가면 빈손으로 나온다.
		if RaidDefs.goal(raid_on) == "endure":
			_advance_stage()
		else:
			_raid_exit("시간 초과 — 빈손")
		return true
	_restart_stage("시간 초과")
	return true


# 구간을 처음부터. 죽었을 때와 시간을 넘겼을 때 **같은 길**을 지난다 —
# 둘 다 "이 구간을 못 넘었다"라서 결과가 달라야 할 이유가 없다.
func _restart_stage(reason: String, full := false) -> void:
	if _fade_t > 0.0:
		return
	_clear_foes()
	_skill_action = ""
	_skill_target = null
	_phase = "advance"
	_fade(func() -> void:
		kills = 0
		_boss_time = _c_time_limit()
		hero_hp = max_hp()
		_hero_dead = false
		_revive_t = 0.0
		_revive_hero()
		_begin_stage_pose()   # _revive_hero 가 앵커에 세운 뒤에 부른다(보스면 왼쪽 밖)
		_start_advance()
		# 같은 구간 재시작이면 같은 그림이 다시 깔릴 뿐이지만, 미궁 입장·이탈은
		# 이 길로 배경이 바뀐다 — 여기서 안 갈면 미궁에 본편 배경이 남는다.
		_apply_stage_bg(), _fade_full_rect if full else _fade_rect)


func _clear_foes() -> void:
	for f in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(f):
			f.remove_from_group("foes")
			f.queue_free()


# 전투 띠만 덮는 암전. 화면 전체를 덮으면 20킬마다 UI 까지 깜빡여서 성가시다.
# 바뀌는 건 전투 띠뿐이라 거기만 가린다.
# 판이 끝나고 암전이 시작되기까지의 여운. 쓰러지는 그림과 보상 배너를 볼
# 시간이다 — 0 이면 "이겼다"가 화면에서 통째로 사라진다(사장님 2026-08-25).
const CLEAR_HOLD := 1.8

const FADE_OUT := 0.28
const FADE_HOLD := 0.14
const FADE_IN := 0.4


func _fade(action: Callable, rect: ColorRect = null) -> void:
	if rect == null:
		rect = _fade_rect
	_fade_t = FADE_OUT + FADE_HOLD + FADE_IN
	rect.visible = true
	rect.color.a = 0.0
	var t := create_tween()
	t.tween_property(rect, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_callback(action)
	t.tween_interval(FADE_HOLD)
	t.tween_property(rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: rect.visible = false)


func _apply_stage_bg() -> void:
	var act: Dictionary = _c_act_data()
	# 막이 바뀌면 그 막이 쓸 애니를 줄에 세운다(데우는 것은 _warm_step).
	_warm_enqueue_act()
	# 전용 배경 (사장님 선택: 심층 M1 · 혈액 동굴 C2 · 정수 성소 S2, 2026-08-12).
	var bg_path := str(act["bg"])
	if raid_on != "":
		bg_path = "res://assets/bg/wide_raid_%s.png" % raid_on
	elif dungeon_on:
		# 50층부터 심층 — 100층 탑의 뒷 절반. 같은 미궁이 깊어진 티를 그림이 낸다.
		bg_path = "res://assets/bg/wide_maze_deep.png" if dungeon_floor >= 50 \
			else "res://assets/bg/wide_maze.png"
	var t := Assets.tex(bg_path)
	if t == null:
		t = Assets.tex(str(act["bg"]))
	_bg.texture = t
	_bg2.texture = t
	_bg2.visible = t != null
	# **배경은 화면 맨 위에 붙인다.** 그림 높이가 208x2 = 416 = 전투 띠 그대로라
	# 밀 여유가 없다. 조금이라도 밀면 반대쪽에 빈 자리가 생기고, 예전엔 그 자리를
	# 하늘 그라데이션과 담 잇기로 메우다 판때기 같은 띠가 됐다(사장님 지적).
	#
	# 대신 **지면 높이가 막마다 다르다.** 예전엔 지면을 늘 290 에 맞추려고 배경을
	# 밀었는데, 이제는 그림이 정한 자리에 캐릭터가 선다. 위젯이 캐릭터를 안 덮는
	# 것만 지키면 되고(WIDGET_BAND), 그건 CombatRulesTest 가 막마다 잰다.
	var bg_top := VIEW_BOTTOM - float(Grid.BG_SRC.y) * 2.0
	_bg.position.y = bg_top
	_bg2.position.y = bg_top
	ground_y = bg_top + float(StageDefs.GROUND_ROW) * 2.0
	_hero.position.y = ground_y - float(Grid.SPRITE)
	for f in get_tree().get_nodes_in_group("foes"):
		f.position.y = ground_y
	# 위아래로 1~2px 틈이 생길 수 있어 화면 바탕을 막 색으로 깔아 둔다.
	# 미궁은 막 색이 아니라 미궁 배경(wide_maze) 맨 아랫줄의 최빈색이다 —
	# BACKDROP 과 같은 방법으로 실측한 값(33,33,29).
	RenderingServer.set_default_clear_color(Color(0.129, 0.129, 0.114) if dungeon_on \
		else BACKDROP[StageDefs.act_of(stage) % BACKDROP.size()])
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
# 이펙트가 그려질 세로 자리. **그림 높이를 보고 정한다.**
#
# `fx_y` 만으로는 등급이 올라 배율이 커질 때(1.0 -> 1.6) 아래끝이 지면 밑으로
# 가라앉는다 — 오프셋을 배율 1.0 에서 맞춰 놨기 때문이다. 실측(2026-08-06):
# `field` 18~37px · `strike_legend` 35px · `wave_legend` 15px 묻힘. 등급이 높을수록
# 심하니, 뽑은 보람이 가장 커야 할 쪽이 가장 어긋나 있었다.
#
# 스타일이 곧 "무엇에 붙는가"다:
#   바닥에 깔리는 것(hold·fall·rise)  아래끝을 지면에 붙인다
#   몸에 터지는 것(burst·sweep)       몸통 가운데에 맞춘다
#   몸에 두르는 것(pulse·orbit)       영웅 몸통 가운데 (지금도 그렇다)
#
# `fx_y` 는 그 기준선에서의 **미세 조정**으로 남는다. 배율이 바뀌어도 기준선은
# 안 움직이므로 크기를 키워도 같은 자리에 커진다.
# **기준은 지면선(ground_y) 하나다** (2026-08-10 사장님: "딱 저 초록선에 딱 맞게").
# 예전엔 6px 띄우기(FX_GROUND_LIFT)에 스킬별 묻기(drop)까지 겹쳐 기준이 여럿이었고,
# 그래서 스킬마다 뜨거나 묻히는 게 제각각이었다 — 손잡이를 전부 걷어냈다.
# **길(밝은 흙 띠)의 세로 폭 58px** — 배경 wide_graveyard 의 y117~145(29줄)를 2배로
# 그린 값이고 실측이다. 그 위는 나무·담이 서 있는 어두운 구역이다.
#
# 바닥에 깔리는 문양(hold)은 그림이 64줄이라 길을 12px 넘어서, 위쪽 균열이 나무
# 밑동 구역까지 올라가 "땅에 깔린 것"이 아니라 "허공에 뜬 것"으로 보였다.
const ROAD_H := 58.0
# 바닥에 서는 이펙트를 지면선보다 **더 묻는 양**(화면 px). 자산별로 다르다.
#
# 갈라진 대지는 덩어리 아래로 핏방울이 흩뿌려져 있어서, 덩어리를 선에 맞추면 그
# 방울들이 선 밑에 떠 있는 그림이 된다(사장님: "저 밑에까지 방울이 그려져 있어서").
# 방울과 덩어리를 코드로는 못 가르므로 그림마다 값을 적는다 — 값이 0이면 안 묻는다.
const FX_SINK := {
	"fx_sk_uncommon_field": 20.0,
}


# 바닥 문양의 세로 배율. **등급은 가로만 넓히고 세로는 길에 맞춘다** — 등급이 높다고
# 문양이 나무까지 자라면 땅에 깔렸다는 게 깨진다. 그림 높이가 다르면 배율도 달라야
# 하므로 여기서 한 번만 계산하고, 자리 계산(`_fx_anchor_y`)과 그리기(`_anim_fx`)가
# 같은 값을 쓴다 — 둘이 갈리면 문양이 지면에서 뜨거나 파묻힌다.
func _ground_scale_y(fx_name: String, draw_scale: float) -> float:
	var frames: Array = Assets.frames("res://assets/anim/%s" % fx_name)
	if frames.is_empty():
		return draw_scale
	return minf(draw_scale, ROAD_H / float(frames[0].get_height()))


func _fx_anchor_y(style: String, fx_name: String, draw_scale: float,
		body_mid: float, nudge: float) -> float:
	var frames: Array = Assets.frames("res://assets/anim/%s" % fx_name)
	if frames.is_empty():
		return body_mid + nudge
	var tex: Texture2D = frames[0]
	var h := float(tex.get_height()) * draw_scale
	# **바닥 문양(hold)은 그림자와 같은 자리에 눕는다** — 중심이 지면선이다.
	# `_shadow()` 가 `Vector2(foe.position.x, ground_y)` 에 그리는 그 자리다.
	# (아래끝을 지면에 붙이면 중심이 발밑에서 32px 위, 몹 허리 높이에 뜬다 — 눕는
	# 그림은 발이 아니라 몸통이 땅에 닿는다.)
	if style == "hold":
		return ground_y
	# 솟아오르는 것(rise)·떨어지는 것(fall)은 **원점이 곧 잉크 아래끝**이다
	# (`_anim_fx` 가 offset 으로 옮겨 둔다). 그래서 여기서는 지면선을 그대로 준다 —
	# 높이·배율이 안 들어간다. 크기가 어떻게 변하든 밑단이 이 선에 못박힌다.
	#
	# `FX_SINK` 만큼 더 묻는다. 그림에 흩뿌린 방울이 덩어리 **아래**까지 그려져 있으면
	# 덩어리를 선에 맞춰도 방울이 선 밑에 떠 있는 것처럼 읽힌다 — 코드는 어디까지가
	# 방울이고 어디부터가 덩어리인지 알 수 없다(문턱을 20% 로 올려도 남는다).
	# 그래서 자산별로 몇 px 묻을지 여기 적는다. **호출부에 매개변수를 안 늘린다** —
	# 여덟 군데를 꿰면 한쪽만 고쳤을 때 또 갈린다(이 세션에 그 부류를 여러 번 겪었다).
	if style == "fall" or style == "rise":
		return ground_y + float(FX_SINK.get(fx_name, 0.0))
	return body_mid + nudge


# in_world = 바닥에 놓이는 것. `_advance_world` 가 영웅 전진량만큼 같이 밀어 준다 —
# 안 밀면 세상이 흐르는데 그림만 화면에 붙어 지면 위를 미끄러진다.
# `face` 는 **나아가는 쪽**(영웅이 보는 방향), `art_flip` 은 **그림이 그려진 쪽**이다.
# 둘을 한 값으로 묶으면 안 된다 — 왼쪽으로 그려진 이펙트를 뒤집으려고 face 를 뒤집었더니
# `sweep` 의 진행 방향까지 같이 뒤집혀 등 뒤로 날아갔다(2026-08-06, 렌더로 잡음).
func _anim_fx(name: String, at: Vector2, fps: float, draw_scale: float,
		style := "burst", echo := 0, alpha := 1.0, face := 1, skew_mul := 1.0,
		in_world := false, art_flip := 1, art_flip_v := 1,
		rot_deg := 0.0) -> AnimatedSprite2D:
	# 만든 노드를 돌려준다 — 부르는 쪽이 나중에 손댈 일이 있을 때만 쓴다
	# (왕좌: 틱마다 붉게 맥동). 대부분의 호출부는 값을 안 받는다.
	# 잔상: 같은 이펙트를 조금 늦게·작게·흐리게 다시 띄운다. 앞의 것이 아직 남아
	# 있는 동안 뒤엣것이 뜨므로 "빠르게 지나갔다"가 된다. 새 자산이 필요 없다.
	#
	# **바닥에 놓이는 것(hold·rise·fall)은 잔상을 안 띄운다**(2026-08-10). 잔상은
	# 같은 중심에 0.87배로 뜨므로 아래끝이 ~8px **떠서**, 본체가 사라진 마지막
	# 0.045초 동안 그 뜬 복사본만 남는다 — 화면에서는 "끝 프레임에 이펙트가
	# 올라간다"로 보였다(사장님이 잡았다). 서 있는 물건의 잔상은 유령 분신으로도
	# 읽힌다(왕좌 잔상 4개 = 왕좌 5개). 등급은 크기·흔들림으로 이미 읽힌다.
	if style == "hold" or style == "rise" or style == "fall":
		echo = 0
	for i in echo:
		var delay := 0.045 * float(i + 1)
		var shrink := 1.0 - 0.13 * float(i + 1)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_inside_tree():
				_anim_fx(name, at, fps, draw_scale * shrink, style, 0,
					alpha * (0.55 - 0.1 * float(i)), face, skew_mul,
						false, art_flip, art_flip_v, rot_deg))
	# 정지 아이콘이 아니라 보유한 프레임 전체를 재생한다. 기본공격과 사망 모두
	# 같은 작은 도우미를 써서 프레임 수가 달라도 마지막에 정확히 정리된다.
	var textures := Assets.frames("res://assets/anim/%s" % name)
	if textures.is_empty():
		return null
	# 바닥 문양만 세로를 길에 맞춘다. 나머지는 가로세로 같은 배율이다.
	# 세로 반전(내리꽂는 창)도 부호 하나로 — full 이 이 값을 그대로 쓰므로 곡선이 따라온다.
	var draw_y := _ground_scale_y(name, draw_scale) if style == "hold" else draw_scale
	draw_y *= float(signi(art_flip_v))
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("play")
	sprite_frames.set_animation_loop("play", false)
	sprite_frames.set_animation_speed("play", fps)
	for texture in textures:
		sprite_frames.add_frame("play", texture)
	var fx := AnimatedSprite2D.new()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite_frames = sprite_frames
	# **바닥에 서는 것은 원점을 잉크 아래끝에 둔다** (2026-08-10 사장님: "뜨지 않게").
	#
	# 가운데 원점이면 밑단이 `중심 + 높이/2` 라 **크기가 변할 때마다 밑단이 움직인다.**
	# 그래서 지금까지 자리 계산·트윈·잔상마다 "절반만큼 올리고 내리는" 보정을 따로
	# 넣었고, 하나 고칠 때마다 다른 데서 떴다(띄우기 상수 -> 묻기 값 -> BACK 이징 ->
	# 잔상). 원점을 밑단에 두면 **배율이 뭘 하든 밑단은 안 움직인다** — 보정이 필요
	# 없어지므로 뜰 방법 자체가 사라진다.
	#
	# `offset` 은 스프라이트 로컬 좌표라 scale 이 그대로 곱해진다: 위로 h/2 올리고
	# 잉크 여백(bottom_pad)만큼 다시 내리면 원점이 정확히 잉크 아래끝이다.
	# `centered` 는 안 끈다 — 껐다가는 좌우 반전(scale.x 부호)이 그림을 옆으로 밀어낸다.
	var foot := style == "rise" or style == "fall"
	if foot:
		var tex0: Texture2D = textures[0]
		fx.offset = Vector2(0.0, -float(tex0.get_height()) * 0.5
			+ Assets.bottom_pad("res://assets/anim/%s" % name))
	fx.position = at
	# **좌우 반전은 scale.x 부호 하나로 끝낸다.** 아래 스타일들이 전부 `full` 에서
	# 크기를 뽑으므로, 여기서 부호를 넣어 두면 모든 연출이 저절로 따라 뒤집힌다.
	fx.scale = Vector2(draw_scale * float(signi(face) * signi(art_flip)), draw_y)
	# **표적 쪽으로 돌린다.** 부호를 보는 쪽에 묶어야 왼쪽을 볼 때 반대로 안 기운다.
	# `orbit` 은 스스로 회전을 트윈으로 돌리므로 건드리지 않는다.
	if not is_zero_approx(rot_deg) and style != "orbit":
		fx.rotation = deg_to_rad(rot_deg * float(signi(face)))
	fx.modulate.a = alpha
	# 잔상은 본체 뒤에 깔린다. 위에 오면 본체가 흐려 보인다.
	#
	# **몸에 두르는 것(pulse·orbit)은 영웅 뒤에 깔린다.** 앞에 오면 방패·성배·심장처럼
	# 꽉 찬 그림이 영웅을 통째로 가려서 "버프가 걸렸다"가 아니라 "캐릭터가 사라졌다"로
	# 보인다. 뒤에 두면 영웅이 그 앞에 선 것이 되어 후광으로 읽힌다. (영웅은 z=3)
	#
	# **바닥에 깔리는 것(hold)은 그 위에 선 놈 아래로 간다**(2026-08-10). 지금까지
	# 문양이 z=5 로 몹(z=1) 위에 그려져서, 밟고 선 놈의 다리를 덮고 있었다 — 땅에
	# 놓인 그림이 사람을 가리면 "땅"으로 안 읽힌다. 갈라진 대지를 불투명 70% 짜리
	# 균열로 바꾸면서 이게 눈에 띄게 커졌다(기존 문양은 27~49%).
	# 배경은 z=-20 이라 그 위, 몹은 z=1 이라 그 아래다.
	var wraps_hero := style == "pulse" or style == "orbit"
	if style == "hold":
		fx.z_index = 0 if alpha >= 1.0 else -1
	elif wraps_hero:
		fx.z_index = 2 if alpha >= 1.0 else 1
	else:
		fx.z_index = 5 if alpha >= 1.0 else 4
	add_child(fx)
	if in_world:
		fx.add_to_group(WORLD_FX_GROUP)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("play")
	if style.is_empty() or not fx.is_inside_tree():
		return fx
	var life := float(textures.size()) / maxf(1.0, fps)
	var full := Vector2(draw_scale * float(signi(face) * signi(art_flip)), draw_y)
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
			# **넘겼다 돌아오는 건 가로만.** 세로는 길 폭에 맞춰 둔 값이라 12% 라도
			# 넘기면 그 순간 균열이 나무 구역으로 올라간다. 바닥에 퍼지는 그림은
			# 옆으로 벌어지는 것만으로 튕김이 읽힌다.
			t.tween_property(fx, "scale", Vector2(full.x * 1.12, full.y), life * 0.38) \
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
			# **땅에서 밀고 올라온다**(제단·왕좌·갈라진 대지). 원점이 잉크 아래끝이라
			# (`_anim_fx` 위쪽 offset) **위치를 아예 안 건드린다** — 세로로만 자라면
			# 밑단은 그 자리에 박힌 채 위로 솟는다.
			#
			# 예전엔 원점이 가운데라 "커지는 만큼 올렸다 내리는" 보정을 했고, 그 보정이
			# 어긋날 때마다 그림이 떴다(높이를 32로 박음 -> BACK 이징이 지나침 ->
			# 잔상이 작게 떠서 남음). 보정을 없애니 뜰 방법이 사라진다.
			fx.scale = Vector2(full.x * 0.75, full.y * 0.2)
			t.tween_property(fx, "scale", full, life * 0.42) \
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
	return fx


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
	_power_band_show(now, _power_gain)


# 전투력 띠 — 참고작 문법(가운데 유리 띠에 큰 숫자, 사장님 레퍼런스).
# 아트는 안 뽑았다: 반투명 판 + 금빛 네온 테두리로 같은 결이 난다.
const POWER_BAND := Rect2(96.0, 146.0, 384.0, 46.0)
var _power_band: Control
var _power_num: Label
var _power_up: Label


func _build_power_band() -> void:
	_power_band = Control.new()
	_power_band.position = POWER_BAND.position
	_power_band.size = POWER_BAND.size
	_power_band.pivot_offset = POWER_BAND.size * 0.5
	_power_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_band.visible = false
	_power_band.z_index = 14
	_hud_root.add_child(_power_band)
	# 전용 판 그림(band_power) — 크레딧이 차서 실제 아트로 갈아 끼웠다.
	# 9-슬라이스라 폭을 바꿔도 모서리 장식이 안 뭉개진다.
	var art := NinePatchRect.new()
	art.texture = Assets.tex("res://assets/ui/band_power.png")
	art.patch_margin_left = 18
	art.patch_margin_right = 18
	art.patch_margin_top = 12
	art.patch_margin_bottom = 12
	art.size = POWER_BAND.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_band.add_child(art)
	_oath_neon(_power_band, Vector2(2.0, 2.0), POWER_BAND.size - Vector2(4.0, 4.0),
		Color(1.0, 0.82, 0.42), [[0.0, 2.0, 0.45]])
	_power_band.add_child(Ui.icon("res://assets/ui/icon_power.png",
		Vector2(16.0, 13.0), 20.0))
	# 숫자는 크게 — 이 줄의 주인공이다.
	_power_num = _panel_label(_power_band, Vector2(44.0, 8.0), Type.SIZE_MID,
		Color(1, 1, 1), 200.0, 30.0)
	_shop_outline(_power_num, 8)
	_power_up = _panel_label(_power_band, Vector2(240.0, 13.0),
		Type.SIZE_SMALL, Color(0.62, 0.98, 0.66), 128.0, 20.0)
	_power_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop_outline(_power_up, 6)
	# 옛 라벨은 검사·다른 알림이 참조하므로 남기되 화면에는 안 쓴다.
	_power_toast = _mk_label(Vector2(TOP_PAD, VIEW_TOP + 36.0), Type.SIZE_SMALL,
		Color(1.0, 0.82, 0.42))
	_power_toast.visible = false


# 띠를 띄운다. 이미 떠 있으면 숫자만 갈고 한 번 튕긴다(연속 상승이 보인다).
func _power_band_show(now: float, gain: float) -> void:
	if _power_band == null:
		return
	_power_num.text = _n(now)
	_power_up.text = "▲ %s" % _n(gain) if gain > 0.0 else ""
	var fresh := not _power_band.visible
	_power_band.visible = true
	var t := _power_band.create_tween()
	if fresh:
		_power_band.modulate.a = 0.0
		t.tween_property(_power_band, "modulate:a", 1.0, 0.15)
		t.parallel().tween_property(_power_band, "position:y",
			POWER_BAND.position.y, 0.25) \
			.from(POWER_BAND.position.y + 14.0) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(_power_band, "scale", Vector2(1.05, 1.05), 0.08)
		t.tween_property(_power_band, "scale", Vector2.ONE, 0.14)


# 재화 해금 (DESIGN 13-1). 첫 화면에 재화가 3개 있으면 뭐가 중요한지 모른다 —
# 1단계에서 쓸 수 있는 건 피뿐인데 정수 0 · 보석 0 이 나란히 놓여 있으면
# "저건 언제 쓰나"가 계속 걸린다. **한 번이라도 얻으면 그때부터 계속 보인다** —
# 다 쓰고 0이 됐다고 다시 사라지면 그게 더 이상하다.
var _currency_seen := {"gem": false}
var _currency_pills: Array[Panel] = []
# 레이드(재화 던전·미궁·보스)에서 감추는 상단 소품 — 초상화 묶음이 여기 담긴다.
var _hud_raid_hide: Array[CanvasItem] = []


# 지금이 레이드 화면인가. 상단 소품과 재화 알약이 이걸 보고 숨는다.
func _in_raid() -> bool:
	return raid_on != "" or dungeon_on


# 잠긴 재화는 알약째로 숨기고, 남은 것을 **오른쪽 끝부터** 다시 붙인다.
# 자리를 고정해 두면 가운데가 잠겼을 때 그 자리가 빈 구멍으로 남는다.
func _refresh_currency_visibility() -> void:
	if _currency_pills.size() < 2:
		return
	# 레이드에서는 **상단이 통째로 빈다**(레퍼런스). 재화는 그 화면에서 쓸 일이
	# 없고, 보스 이름·타이머·체력만 남아야 한판이 무엇인지가 곧바로 읽힌다.
	var raid := _in_raid()
	for n in _hud_raid_hide:
		n.visible = not raid
	if _lbl_income:
		_lbl_income.visible = _lbl_income.visible and not raid
	# 전투 화면에 떠 있는 소품들도 같이 빠진다 — 가이드는 본편 진도를 재는 것이고
	# 방치 상자·바로가기는 레이드 안에서 누를 일이 없다(레퍼런스: 보스전은 비어 있다).
	if _goal_widget:
		_goal_widget.visible = not raid and _tab not in FULL_TABS
	if _side_root:
		_side_root.visible = not raid and _tab not in FULL_TABS
	_refresh_chest()
	_currency_seen["gem"] = _currency_seen["gem"] or gem > 0.0
	var open := [not raid, bool(_currency_seen["gem"]) and not raid]
	var x := float(Grid.BG.x) - 8.0
	for i in range(_currency_pills.size() - 1, -1, -1):
		_currency_pills[i].visible = open[i]
		if not open[i]:
			continue
		x -= PILL_W
		_currency_pills[i].position.x = x
		x -= PILL_GAP


# 보스 구간에 서 있는 **한 마리**. 그 구간은 몹이 하나뿐이라 이름·체력을 그대로
# 상단 바에 쓴다. 전진 중이면 아직 없다.
func _lone_foe() -> Foe:
	for f in get_tree().get_nodes_in_group("foes"):
		return f as Foe
	return null


# 진행 문구. 폰트 칸 폭 검사(GearTest)가 실제 문자열을 재려고 부르므로 static 이다.
# 보스 구간은 몹이 나온 뒤로는 이 문구 대신 보스 이름이 뜬다.
static func stage_progress_text(at_stage: int, done: int, need: int) -> String:
	if StageDefs.is_boss_stage(at_stage):
		return "보스"
	if StageDefs.is_midboss_stage(at_stage):
		return "중간보스"
	return "처치 %d / %d" % [done, need]


func _refresh_hud() -> void:
	var act: Dictionary = _c_act_data()
	# 레퍼런스의 "미궁 54층-4" 자리. 미궁에서는 "미궁 N층"이 그대로 그 자리다.
	# 레이드에서는 **거기가 어디인지**를 적는다(레퍼런스 "필드보스 20단계") —
	# 본편 구간 번호는 그 안에서 아무 뜻이 없다.
	if raid_on == "boss":
		_lbl_stage.text = "%s  %d단계" % [
			str(EventDefs.boss_of(_boss_week_index())["name"]), boss_tier]
	elif raid_on == "trial":
		_lbl_stage.text = "시련 %d단계" % (trial_stage + 1)
	elif raid_on != "":
		_lbl_stage.text = "%s  %d단계" % [str(RaidDefs.RAIDS[raid_on]["name"]),
			int(raid_best.get(raid_on, 0)) + 1]
	elif dungeon_on:
		_lbl_stage.text = _c_label()
	else:
		_lbl_stage.text = "스테이지 %s" % StageDefs.label(stage)
	var need := _c_kills_needed()
	# 보스 구간은 처치 수가 0 아니면 1이라 진행바가 끝까지 비어 있다가 갑자기 찼다.
	# **남은 체력을 대신 보여 준다** — 그게 이 구간의 진행도다.
	var boss_stage := _c_is_boss() or _c_is_midboss()
	var lone := _lone_foe() if boss_stage else null
	var ratio := clampf(float(kills) / maxf(1.0, float(need)), 0.0, 1.0)
	if boss_stage:
		ratio = clampf(lone.hp / maxf(1.0, lone.max_hp), 0.0, 1.0) if lone else 1.0
	# 초는 **타이머 바로 옮겼다.** 진행바에 같이 적으면 한 줄에 두 가지를 재게 된다.
	# 미궁은 static 진행 문구 함수(본편 구간을 본다)를 못 쓰므로 여기서 가른다.
	var prog := ("보스" if _c_is_boss() else "중간보스" if _c_is_midboss()
		else "처치 %d / %d" % [kills, need]) if dungeon_on \
		else stage_progress_text(stage, kills, need)
	# 재화 던전은 **목표가 던전마다 다르다** — 진행 문구도 거기에 맞춘다.
	# 버티기는 셀 처치가 없으니 시계가 진행도고, 진행바는 그동안 가득 차 있다.
	if raid_on != "" and raid_on != "boss":
		match RaidDefs.goal(raid_on):
			"endure":
				prog = "버티는 중"
				ratio = 1.0
			"slay": prog = "수호자 %d / %d" % [kills, need]
			_: prog = "처치 %d / %d" % [kills, need]
	_lbl_prog.text = lone.display_name if lone else prog
	# 제한 시간이 없는 일반 구간에서는 **시계를 아예 감춘다.** 0초로 멈춰 있으면
	# 고장으로 보이고, 채워진 채로 두면 곧 줄어들 것처럼 거짓 신호를 준다.
	var limit := _c_time_limit()
	var timed := limit > 0.0
	var left := maxf(0.0, _boss_time)
	var low := left <= 5.0
	# **제한 시간이 빠진 자리를 교전 몹 체력이 쓴다**(레퍼런스는 상단에 큰 체력 바가
	# 있다). 지금 싸우는 놈의 체력이 머리 위 5px 바에만 있어서, 화면을 훑는 눈에는
	# "얼마나 남았나"가 안 걸렸다. 자리를 새로 만들지 않고 시계 위젯을 그대로 쓴다 —
	# 둘은 **동시에 뜰 일이 없다**(시계는 보스·중간보스에만 있다).
	# **죽는 중인 놈도 계속 띄운다.** `_tick_engage` 는 사망 연출(DIE_DUR 0.42초)이
	# 끝날 때까지 `_engaged` 를 넘기지 않는다 — 죽었다고 감추면 한 마리마다 0.42초
	# 꺼졌다 0.6초 켜지기를 반복해서 바가 깜빡인다. 0 으로 비는 편이 "잡았다"로 읽힌다.
	var foe: Foe = _engaged if is_instance_valid(_engaged) else null
	var show_foe := not timed and foe != null
	var slot := timed or show_foe
	var fill := clampf(left / maxf(1.0, limit), 0.0, 1.0) if timed \
		else (clampf(foe.hp / maxf(1.0, foe.max_hp), 0.0, 1.0) if show_foe else 0.0)
	if _timer_frame:
		_timer_frame.visible = slot
	if _timer_bar:
		_timer_bar.visible = slot
		_timer_bar.size.x = _timer_bar_width * fill
		_timer_bar.color = (TIMER_LOW_COL if low else TIMER_BAR_COL) if timed else FOE_BAR_COL
	if _lbl_time:
		_lbl_time.visible = slot
		# 몹 쪽은 **이름만** 적는다. 숫자를 넣으면 바가 이미 말하는 것을 두 번 말하고,
		# 후반 체력은 자릿수가 길어 260px 칸에서 잘린다.
		_lbl_time.text = "%d초" % int(ceil(left)) if timed \
			else (foe.display_name if show_foe else "")
		# 남은 시간이 얼마 없으면 붉게. 숫자를 안 보고 있어도 색이 먼저 눈에 들어온다.
		_lbl_time.add_theme_color_override("font_color",
			Color(1.0, 0.55, 0.5) if timed and low else Color(0.90, 0.95, 1.0))
	if _stage_bar:
		# **바 폭으로 잰다.** 화면 폭(576)을 쓰고 있어서 실제 홈통(324)보다 훨씬
		# 길게 차올랐다 — 56% 만 잡아도 바가 꽉 찬 것처럼 보였다.
		_stage_bar.size.x = _stage_bar_width * ratio
		_stage_bar.color = BOSS_BAR_COL if boss_stage else STAGE_BAR_COL
	if _stage_icon:
		# **몹 얼굴이 아니라 고정 마크다.** 얼굴을 띄웠더니 바로 뒤에 서 있는 그 보스와
		# 겹쳐서 하나로 뭉개졌다 — 마크는 "지금 보스 구간"이라는 신호지 초상화가 아니다.
		_stage_icon.visible = boss_stage
	_lbl_hero.text = "레벨 %d" % hero_lv
	# **아이콘만 두고 이름은 뺐다.** 알약 안쪽이 96px 인데 "혈액 999.9t"는 108px 이라
	# 잘렸다(GearTest 가 잡았다). 아이콘이 바로 왼쪽에 있어서 이름은 중복이다 —
	# 레퍼런스 방치형들도 아이콘 + 숫자만 쓴다.
	_lbl_gold.text = _n(gold)
	_lbl_gem.text = _n(gem)
	_refresh_currency_visibility()
	var power := Balance.combat_power(dps(), max_hp(), regen_per_sec())
	_lbl_power.text = _n(power)
	_notify_power(power)
	# **HP 숫자는 안 띄운다.** 영웅 발밑 체력 바로 이미 보이고, 전투 화면 위에
	# 숫자가 하나 더 떠 있으면 그만큼 화면이 가려진다. 쓰러졌을 때만 남는다.
	if _lbl_name != null:
		_lbl_name.text = _hero_name()
	_lbl_life.visible = _hero_dead
	if _hero_dead:
		_lbl_life.text = "부활 %.1f초" % maxf(0.0, _revive_t)
		_lbl_life.add_theme_color_override("font_color", Color(0.95, 0.48, 0.48))
	_refresh_tab_dots()
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
# 초기화 뒤에는 저장이 전부 무효다 — 지운 파일을 어느 갱신 경로가 되살리면
# 반쪽 초기화가 된다. 재시작(reload)까지의 짧은 틈을 이 깃발이 막는다.
var _wiped := false


# 진행 초기화 (테스트용, 능력치 창 버튼). 저장 파일을 지우고 씬을 새로 연다 —
# 상태 변수를 하나하나 되돌리는 방식은 변수가 늘 때마다 빠뜨린다.
func _wipe_save() -> void:
	_wiped = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# 트리 밖에서 불리면(테스트의 _init 시점) 재시작만 건너뛴다 — 파일은 지워졌다.
	var tree := get_tree()
	if tree:
		tree.reload_current_scene()


# 시뮬레이션(PaceProbe)이 켠다 — 펫 뽑기·강화가 판마다 저장을 부르는데,
# 90일 x 12후보 모의에서 그 파일 쓰기가 전체 시간을 먹는다(실측 10분 초과).
var save_muted := false


func _save_game() -> void:
	if save_muted:
		return
	var _ps := Time.get_ticks_usec()
	_save_game_inner()
	_perf_mark("저장", _ps)


func _save_game_inner() -> void:
	if _wiped:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("run", "stage", stage)
	cfg.set_value("run", "kills", kills)
	cfg.set_value("run", "gold", gold)
	cfg.set_value("wallet", "gem", gem)
	cfg.set_value("wallet", "crystal", crystal)
	cfg.set_value("wallet", "sigil", sigil)
	cfg.set_value("wallet", "whet", whet)
	cfg.set_value("wallet", "tickets", tickets)
	cfg.set_value("run", "relics", relics)
	cfg.set_value("run", "title_ms", title_ms_got)
	cfg.set_value("run", "promo_got", promo_got)
	cfg.set_value("run", "pact_lv", pact_lv)
	cfg.set_value("wallet", "mileage", mileage)
	cfg.set_value("trial", "stage", trial_stage)
	cfg.set_value("wallet", "mile_fill", mile_fill)
	cfg.set_value("wallet", "mile_lv", mile_lv)
	cfg.set_value("oath", "cards", oath_cards)
	cfg.set_value("oath", "gold", oath_gold)
	cfg.set_value("oath", "charge", oath_charge)
	cfg.set_value("oath", "pity", oath_pity)
	cfg.set_value("oath", "gold_pity", oath_gold_pity)
	cfg.set_value("oath", "lv", oath_lv)
	cfg.set_value("oath", "first", oath_first)
	cfg.set_value("oath", "daily", oath_daily)
	cfg.set_value("oath", "used", oath_used)
	cfg.set_value("oath", "book_free", oath_book_free)
	cfg.set_value("oath", "book_paid", oath_book_paid)
	cfg.set_value("oath", "week", oath_week)
	cfg.set_value("oath", "col_got", oath_col_got)
	cfg.set_value("record", "play_sec", int(play_sec))
	cfg.set_value("iap", "subs", iap_subs)
	cfg.set_value("iap", "bought", iap_bought)
	cfg.set_value("iap", "first_buy", iap_first_buy)
	cfg.set_value("iap", "daily_date", iap_daily_date)
	cfg.set_value("pass", "points", pass_points)
	cfg.set_value("pass", "free", pass_free_got)
	cfg.set_value("pass", "paid", pass_paid_got)
	cfg.set_value("prestige", "marks", prestige_marks)
	cfg.set_value("prestige", "count", prestige_count)
	cfg.set_value("prestige", "peak", prestige_peak)
	cfg.set_value("wallet", "seen", _currency_seen)
	cfg.set_value("run", "best_stage", best_stage)
	cfg.set_value("run", "dungeon_best", dungeon_best)
	cfg.set_value("run", "traits", traits)
	cfg.set_value("run", "skin", skin)
	cfg.set_value("run", "skins", skins_owned)
	cfg.set_value("run", "name", hero_name)
	cfg.set_value("run", "titles", titles_got)
	cfg.set_value("run", "titles_new", titles_new)
	cfg.set_value("run", "title_worn", title_worn)
	cfg.set_value("run", "hero_lv", hero_lv)
	cfg.set_value("run", "hero_exp", hero_exp)
	cfg.set_value("run", "hero_hp", hero_hp)
	cfg.set_value("up", "lv", lv)
	cfg.set_value("up", "split15", true)
	cfg.set_value("run", "blood15", true)
	cfg.set_value("run", "achieve", achieve_got)
	cfg.set_value("pass", "season", pass_season)
	cfg.set_value("iap", "flash_open", flash_open)
	cfg.set_value("iap", "flash_bought", flash_bought)
	cfg.set_value("up", "buy_step", buy_step)
	cfg.set_value("gear", "equipped", equipped)
	cfg.set_value("gear", "inventory", gear_inventory)
	cfg.set_value("gear", "presets", gear_presets)
	cfg.set_value("gacha", "pity", gacha_pity)
	cfg.set_value("gacha", "pulls", gacha_pulls)
	cfg.set_value("gacha", "owned", gacha_owned)
	cfg.set_value("gacha", "shards", gacha_shards)
	cfg.set_value("gacha", "fuse_pity", fuse_pity)
	cfg.set_value("gacha", "free_date", free_pull_date)
	cfg.set_value("pet", "got", pets_got)
	cfg.set_value("pet", "lv", pet_lv)
	cfg.set_value("pet", "gear", pet_gear_got)
	cfg.set_value("pet", "gearworn", pet_gear_worn)
	cfg.set_value("pet", "feed", feed)
	cfg.set_value("pet", "bank", pet_bank)
	cfg.set_value("pet", "worn", pet_worn)
	cfg.set_value("pet", "at", pet_at)
	cfg.set_value("pet", "trip", pet_trip)
	cfg.set_value("codex", "gear_seen", gear_seen)
	cfg.set_value("attend", "got", attend_got)
	cfg.set_value("attend", "date", attend_date)
	cfg.set_value("quest", "date", quest_date)
	cfg.set_value("quest", "prog", quest_prog)
	cfg.set_value("quest", "got", quest_got)
	cfg.set_value("quest", "week", quest_week)
	cfg.set_value("quest", "wprog", quest_wprog)
	cfg.set_value("quest", "wgot", quest_wgot)
	cfg.set_value("shop", "date", shop_date)
	cfg.set_value("shop", "used", shop_used)
	cfg.set_value("drop", "date", drop_date)
	cfg.set_value("drop", "got", drop_got)
	cfg.set_value("raid", "best", raid_best)
	cfg.set_value("raid", "date", raid_date)
	cfg.set_value("raid", "left", raid_left)
	cfg.set_value("boss", "week", boss_week)
	cfg.set_value("boss", "date", boss_date)
	cfg.set_value("boss", "tries", boss_tries)
	cfg.set_value("boss", "dmg", boss_dmg)
	cfg.set_value("boss", "got", boss_got)
	cfg.set_value("boss", "tier", boss_tier)
	cfg.set_value("boss", "dps", boss_dps)
	cfg.set_value("skill", "owned", skill_owned)
	cfg.set_value("skill", "equipped", skill_equipped)
	cfg.set_value("skill", "auto", skill_auto_equip)
	cfg.set_value("skill", "presets", skill_presets)
	cfg.set_value("codex", "kills", codex)
	cfg.set_value("goal", "index", goal_index)
	cfg.set_value("chest", "gold", chest_gold)
	cfg.set_value("chest", "minutes", chest_minutes)
	cfg.set_value("meta", "left_at", Time.get_unix_time_from_system())
	cfg.save(SAVE_PATH)


func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stage = clampi(int(cfg.get_value("run", "stage", 1)), 1, StageDefs.total_stages())
	kills = int(cfg.get_value("run", "kills", 0))
	gold = float(cfg.get_value("run", "gold", 0.0))
	# ── 혈액 눈금 이관 (2026-08-20, 한 번만) ──────────────────────────────
	# 눈금이 15배가 됐으니 지갑도 옮긴다. 안 옮기면 지갑만 1/15 로 쪼그라든다.
	# **15분할 환급(아래)보다 먼저** 해야 한다 — 그 환급은 새 단위로 나온다.
	achieve_got = cfg.get_value("run", "achieve", {})
	pass_season = int(cfg.get_value("pass", "season", -1))
	flash_open = cfg.get_value("iap", "flash_open", {})
	flash_bought = cfg.get_value("iap", "flash_bought", {})
	var blood15: bool = cfg.has_section_key("run", "blood15")
	if not blood15:
		gold *= Balance.BLOOD_UNIT
	gem = maxf(0.0, float(cfg.get_value("wallet", "gem", 0.0)))
	crystal = maxf(0.0, float(cfg.get_value("wallet", "crystal", 0.0)))
	sigil = maxf(0.0, float(cfg.get_value("wallet", "sigil", 0.0)))
	whet = maxf(0.0, float(cfg.get_value("wallet", "whet", 0.0)))
	tickets = cfg.get_value("wallet", "tickets", {})
	relics = cfg.get_value("run", "relics", {})
	title_ms_got = cfg.get_value("run", "title_ms", {})
	promo_got = cfg.get_value("run", "promo_got", {})
	pact_lv = clampi(int(cfg.get_value("run", "pact_lv", 0)), 0, PactDefs.level_cap())
	mileage = maxi(0, int(cfg.get_value("wallet", "mileage", 0)))
	trial_stage = maxi(0, int(cfg.get_value("trial", "stage", 0)))
	mile_fill = maxi(0, int(cfg.get_value("wallet", "mile_fill", 0)))
	mile_lv = maxi(0, int(cfg.get_value("wallet", "mile_lv", 0)))
	oath_cards = maxi(0, int(cfg.get_value("oath", "cards", 1)))
	oath_gold = maxi(0, int(cfg.get_value("oath", "gold", 0)))
	oath_charge = maxf(0.0, float(cfg.get_value("oath", "charge", 0.0)))
	oath_pity = maxi(0, int(cfg.get_value("oath", "pity", 0)))
	oath_gold_pity = maxi(0, int(cfg.get_value("oath", "gold_pity", 0)))
	oath_lv = cfg.get_value("oath", "lv", {})
	oath_first = bool(cfg.get_value("oath", "first", false))
	oath_daily = str(cfg.get_value("oath", "daily", ""))
	oath_used = maxi(0, int(cfg.get_value("oath", "used", 0)))
	oath_book_free = cfg.get_value("oath", "book_free", {})
	oath_book_paid = cfg.get_value("oath", "book_paid", {})
	oath_week = str(cfg.get_value("oath", "week", ""))
	oath_col_got = maxi(0, int(cfg.get_value("oath", "col_got", 0)))
	play_sec = float(maxi(0, int(cfg.get_value("record", "play_sec", 0))))
	iap_subs = cfg.get_value("iap", "subs", {})
	iap_bought = cfg.get_value("iap", "bought", {})
	iap_first_buy = bool(cfg.get_value("iap", "first_buy", false))
	iap_daily_date = str(cfg.get_value("iap", "daily_date", ""))
	pass_points = maxi(0, int(cfg.get_value("pass", "points", 0)))
	pass_free_got = cfg.get_value("pass", "free", {})
	pass_paid_got = cfg.get_value("pass", "paid", {})
	prestige_marks = maxi(0, int(cfg.get_value("prestige", "marks", 0)))
	prestige_count = maxi(0, int(cfg.get_value("prestige", "count", 0)))
	prestige_peak = maxi(0, int(cfg.get_value("prestige", "peak", 0)))
	# 키가 없는 옛 저장본은 잔액으로 되살린다 — 이미 쓰던 재화가 갑자기 사라지면 안 된다.
	var seen: Dictionary = cfg.get_value("wallet", "seen", {})
	_currency_seen["gem"] = bool(seen.get("gem", gem > 0.0))
	best_stage = clampi(int(cfg.get_value("run", "best_stage", stage)), stage,
		StageDefs.total_stages())
	dungeon_best = clampi(int(cfg.get_value("run", "dungeon_best", 0)), 0,
		DungeonDefs.FLOOR_CAP)
	# 없는 노드 id 는 버린다 — 표가 바뀐 옛 저장본이 유령 배수를 들고 오면 안 된다.
	# **값을 그대로 실어 나른다.** true 로 뭉개면 level_of 가 그걸 만렙으로 읽어서
	# (TraitDefs.level_of) 1레벨만 산 노드가 껐다 켜면 10레벨로 부활했다 — 혈맥
	# 완주 비용이 222,930 이 아니라 그 1/10 이 되던 구멍이다.
	# 옛 bool 저장본은 level_of 가 이미 만렙으로 읽어 준다.
	traits = {}
	var saved_traits: Dictionary = cfg.get_value("run", "traits", {})
	for id in saved_traits:
		if not TraitDefs.node(str(id)).is_empty():
			traits[str(id)] = saved_traits[id]
	titles_got = {}
	title_worn = str(cfg.get_value("run", "title_worn", ""))
	var saved_titles: Dictionary = cfg.get_value("run", "titles", {})
	for id in saved_titles:
		if not TitleDefs.title(str(id)).is_empty():
			titles_got[str(id)] = true
	titles_new = cfg.get_value("run", "titles_new", {})
	skins_owned = cfg.get_value("run", "skins", {})
	# 저장본도 사람이 고칠 수 있는 파일이다 — 읽을 때도 같은 자로 잰다.
	hero_name = _clean_name(str(cfg.get_value("run", "name", "")))
	skin = str(cfg.get_value("run", "skin", "valentino_1"))
	if SkinDefs.of(skin).is_empty():
		skin = "valentino_1"      # 표에서 빠진 스킨을 입고 있으면 평상복으로
	_motion = ""
	_play("idle")
	hero_lv = int(cfg.get_value("run", "hero_lv", 1))
	hero_exp = float(cfg.get_value("run", "hero_exp", 0.0))
	buy_step = int(cfg.get_value("up", "buy_step", 1))
	lv = cfg.get_value("up", "lv", {})
	# ── 15분할 이관 (2026-08-20, 한 번만) ─────────────────────────────────
	# 레벨과 효과가 **같이** 환산되므로 로드 직후 전투력이 소수점까지 같다.
	# 두 번 돌면 레벨이 225배가 되고 안 돌면 1/15 로 붕괴하는데 둘 다 크래시가
	# 안 난다 — 이 플래그가 유일한 방어선이다.
	if not cfg.has_section_key("up", "split15"):
		# 흡혈량은 사라진 스탯이라 **쪼개기 전에** 옛 곡선 값으로 환급한다.
		# n 은 새 레벨 단위로 넘긴다(buy_cost 가 새 단위를 센다).
		var gone := maxi(1, int(lv.get("gold", 1)))
		if gone > 1:
			gold += Balance.buy_cost(1, Balance.SPLIT * (gone - 1), 14.0, 1.16)
		lv.erase("gold")
		for k in lv:
			lv[k] = 1 + Balance.SPLIT * (maxi(1, int(lv[k])) - 1)
		# 표 밖으로 나간 죽은 키 청소(옛 저장에 남은 것들).
		for k in lv.keys():
			if StatDefs.of(str(k)).is_empty():
				lv.erase(k)
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
	fuse_pity = cfg.get_value("gacha", "fuse_pity", {})
	# 2026-08-25 이전 저장본은 키가 "gear:도끼"·"skill:ward_common" 이었다.
	# 등급 통으로 바뀌었으니 그 줄은 버린다 — 남겨 두면 안 쓰이는 쓰레기다.
	for k in fuse_pity.keys():
		if ":" in str(k):
			fuse_pity.erase(k)
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
	pets_got = cfg.get_value("pet", "got", {})
	pet_lv = cfg.get_value("pet", "lv", {})
	pet_gear_got = cfg.get_value("pet", "gear", {})
	pet_gear_worn = cfg.get_value("pet", "gearworn", {})
	feed = maxf(0.0, float(cfg.get_value("pet", "feed", 0.0)))
	# **읽기를 초기화보다 먼저 한다.** pet_bank 를 아래 루프 뒤에 읽던 탓에
	# 초기화가 도로 덮였다 — 사라진 펫의 곳간이 살아남던 구멍이다.
	pet_bank = cfg.get_value("pet", "bank", {})
	pet_worn = str(cfg.get_value("pet", "worn", ""))
	pet_at = float(cfg.get_value("pet", "at", 0.0))
	pet_trip = cfg.get_value("pet", "trip", {})
	# v1 이전 — 몹 재활용 6종의 저장본은 새 로스터와 id 가 안 맞는다. 출시 전이라
	# 통째로 초기화한다(펫에 쓴 재화가 없던 시절이라 환급할 것도 없다).
	for k in pets_got.keys():
		if PetDefs.of(str(k)).is_empty():
			pets_got = {}
			pet_lv = {}
			pet_bank = {}
			pet_worn = ""
			pet_gear_worn = {}
			pet_trip = {}
			break
	# 표에서 사라진 펫의 원정은 버린다 — 안 그러면 없는 id 의 유령 조각이 쌓인다.
	for k in pet_trip.keys():
		if not pets_got.has(str(k)):
			pet_trip.erase(k)
	gear_seen = cfg.get_value("codex", "gear_seen", {})
	attend_got = maxi(0, int(cfg.get_value("attend", "got", 0)))
	attend_date = str(cfg.get_value("attend", "date", ""))
	quest_date = str(cfg.get_value("quest", "date", ""))
	quest_prog = cfg.get_value("quest", "prog", {})
	quest_got = cfg.get_value("quest", "got", {})
	quest_week = str(cfg.get_value("quest", "week", ""))
	quest_wprog = cfg.get_value("quest", "wprog", {})
	quest_wgot = cfg.get_value("quest", "wgot", {})
	# 어제 저장본이면 여기서 새 날(그리고 새 주)이 열린다 (접속 임무가 찬다).
	_quest_roll_day()
	raid_best = cfg.get_value("raid", "best", {"blood": 0})
	raid_date = str(cfg.get_value("raid", "date", ""))
	raid_left = cfg.get_value("raid", "left", {})
	_raid_roll_day()
	shop_date = str(cfg.get_value("shop", "date", ""))
	shop_used = cfg.get_value("shop", "used", {})
	drop_date = str(cfg.get_value("drop", "date", ""))
	drop_got = int(cfg.get_value("drop", "got", 0))
	_shop_roll_day()
	boss_week = str(cfg.get_value("boss", "week", ""))
	boss_date = str(cfg.get_value("boss", "date", ""))
	boss_tries = int(cfg.get_value("boss", "tries", EventDefs.TRIES_PER_DAY))
	boss_dmg = maxf(0.0, float(cfg.get_value("boss", "dmg", 0.0)))
	boss_got = cfg.get_value("boss", "got", {})
	boss_tier = maxi(1, int(cfg.get_value("boss", "tier", 1)))
	boss_dps = maxf(0.0, float(cfg.get_value("boss", "dps", 0.0)))
	_boss_roll()
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
	skill_presets = _preset_load(cfg.get_value("skill", "presets", []), [])
	gear_presets = _preset_load(cfg.get_value("gear", "presets", []), {})
	if skill_equipped.is_empty():
		_auto_equip_skills()
	codex = cfg.get_value("codex", "kills", {})
	# 가이드가 트랙 6개 병렬에서 한 줄로 바뀌었다(2026-08-05). 옛 저장본은 트랙별
	# 단계를 사전으로 갖고 있으니 **합쳐서** 번호로 옮긴다 — 그냥 0으로 두면
	# 이미 깬 가이드를 처음부터 다시 깨야 한다.
	goal_index = int(cfg.get_value("goal", "index", -1))
	if goal_index < 0:
		goal_index = 0
		var old: Variant = cfg.get_value("goal", "step", {})
		if old is Dictionary:
			for k in old:
				goal_index += int(old[k])
	chest_gold = float(cfg.get_value("chest", "gold", 0.0))
	if not blood15:
		chest_gold *= Balance.BLOOD_UNIT   # 상자도 같은 눈금
	chest_minutes = float(cfg.get_value("chest", "minutes", 0.0))
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
	# **순차 교전이라 동시 타격은 언제나 1이다.** 기다리는 몹은 공격하지 않는다
	# (Foe.engaged 게이트). 무리 크기를 쓰면 받는 피해를 몇 배로 과대평가한다.
	var count := 1
	return {
		"hp": FoeTiers.foe_hp(hp_mult, StageDefs.enemy_power(at_stage), boss, midboss),
		"count": count,
		# 보스·중간보스는 세 번에 한 번 특수 패턴으로 훨씬 아프게 친다. 평타 기준으로만
		# 계산하면 오프라인이 실제보다 무르게 보고 "깼다"고 판정한다.
		"damage": Balance.foe_damage(StageDefs.enemy_power(at_stage))
			* Foe.avg_attack_mult(boss, midboss,
				str(act["boss"]) if boss else ""),
		"interval": Balance.foe_attack_interval(hp_mult),
	}


# 그 구간을 미는 데 실제로 걸릴 시간.
#
# **처리량 상한(칸 수 / 걷는 시간)이 없어졌다**(2026-08-06). 몹이 서 있고 영웅이 한
# 마리씩 찾아가므로, 여섯이 줄 서 있어도 한 마리당 "달리는 시간(FOE_GAP /
# TRAVEL_SPEED) + 처치 시간"이 직렬로 든다 — 그 고정비가 곧
# `Balance.APPROACH_SECONDS` 다. 동시 마릿수는 처리량에 영향이 없다.
func _offline_stage_seconds(at_stage: int, remaining_kills: int) -> float:
	var p := _offline_profile(at_stage)
	# **공격 간격을 같이 넘긴다.** 안 넘기면 모델이 피해를 연속으로 봐서, 한 대에
	# 죽는 몹을 0.2초에 잡는 것으로 센다(실제는 스윙 한 번 0.6초). 그 차이가 곧
	# 방치 수익 과지급이다 — `Balance.push_seconds` 주석에 실측이 있다.
	return StageDefs.WAVE_WALK_SECONDS \
		+ Balance.stage_seconds(remaining_kills, float(p["hp"]), dps(), attack_interval())


func _offline_can_clear(at_stage: int, remaining_kills: int) -> bool:
	var p := _offline_profile(at_stage)
	# **일반 구간은 제한 시간이 없다**(StageDefs.time_limit 이 0) — 생존만 보면 된다.
	# 시계로 막히는 건 보스·중간보스뿐이고, 그쪽은 걸어 들어오는 시간을 예산에서
	# 먼저 뺀다(실시간에서도 그 시간에 시계가 돈다).
	var limit := StageDefs.time_limit(at_stage)
	var budget := 0.0
	if limit > 0.0:
		budget = limit - StageDefs.WAVE_WALK_SECONDS
		if budget <= 0.0:
			return false
	return Balance.can_clear_stage(max_hp(), regen_per_sec(), dps(), remaining_kills,
		float(p["hp"]), int(p["count"]), float(p["damage"]), float(p["interval"]),
		budget, attack_interval())


# 껐던 시간만큼 보상을 준다. 먼저 생존 공식으로 밀 수 있는 최고 단계까지 올리고,
# 그 자리에서 남은 시간 동안 피를 모은 것으로 계산한다. 난수 없는 실시간 수치와
# 같은 HP/DPS/공격주기를 쓰므로 껐다 켜도 결과가 뒤집히지 않는다.
func _grant_offline(left_at: float) -> void:
	if left_at <= 0.0:
		return
	var away := Time.get_unix_time_from_system() - left_at
	if away < 60.0:
		return
	# 상한 = 기본 8시간 + 혈맥 긴 잠 + 군림 IV. 그 이상은 접속할 이유가 사라진다.
	away = minf(away, _offline_cap_hours() * 3600.0)
	# **한 구간에 걸린 시간을 예산에서 뺀다.** 일반 구간의 제한 시간이 없어진 뒤로는
	# "넘을 수 있나"만 보면 1분만 비워도 생존이 버티는 한 끝없이 올라간다 — 예전엔
	# 100초 제한이 우연히 그 상한 역할을 했다. 실제로는 한 구간에 몇십 초씩 걸리므로
	# 그 값을(실시간과 같은 처리량 모델로) 물린다.
	var budget := away
	var climbed := 0
	while stage < StageDefs.total_stages():
		var need := maxi(0, StageDefs.kills_needed(stage) - kills) if climbed == 0 \
			else StageDefs.kills_needed(stage)
		if not _offline_can_clear(stage, need):
			break
		var cost := _offline_stage_seconds(stage, need)
		if cost > budget:
			break
		budget -= cost
		stage += 1
		kills = 0
		climbed += 1
	# 접속 배급(blood_per_sec)과 **같은 식**을 쓴다 — 요율이 같아야 "방치가 이득"
	# 도 "접속이 이득"도 아니게 된다(2026-08-20). 옛 0.5 는 접속이 1.0 이던 시절의
	# 균형추였고, 지금은 양쪽 다 5/9 다.
	var earned := blood_per_sec() * away
	# **지갑이 아니라 상자에 담는다.** 눌러서 여는 게 방치 보상의 보상이다.
	chest_gold += earned
	chest_minutes += away / 60.0
	# 소탕도 같은 원칙으로 절반 효율 — 방치가 접속보다 이득이면 게임을 안 켠다.
	# 혈정은 상자에 안 담는다: 상자는 혈액 그릇이고, 혈정은 미궁 기록의 배당이라
	# 조용히 지갑에 쌓이는 쪽이 맞다(접속 중 소탕과 같은 길).
	if dungeon_best > 0:
		crystal += (away / 3600.0) * _sweep_per_hour() * 0.5
	hero_hp = max_hp()
	_refresh_chest()


# [개발 도구] 검수 상태로 한 방에 — 명령줄 --god 과 게임 안 F8 이 같이 쓴다.
# 세이브를 덮으므로 검수 전용이다.
# 해금만 — 재화·스탯은 안 건드린다. 자기 화력 그대로 콘텐츠를 연다.
# 주의: best_stage 는 저장되므로 주간 보스·시련 세기도 그 구간을 따라간다
# (Ctrl+G 와 같은 속성 — 검수용 저장에서 쓸 것).
func _dev_unlock(want: int) -> void:
	best_stage = maxi(best_stage, clampi(want, 1, StageDefs.total_stages()))
	# 미궁은 개방 상한 안에서 최고 기록을 세워 둔다 — 혈맥·소탕이 열린다.
	dungeon_best = maxi(dungeon_best,
		maxi(0, DungeonDefs.open_floors(best_stage) - 1))
	_refresh_hud()
	_save_game()


func _dev_god(want: int) -> void:
	_dev_unlock(want)
	stage = best_stage
	gold = 1e12
	whet = 1e9
	gem = 1e6
	crystal = 1e9
	sigil = 1e9
	for tk in TicketDefs.KINDS:
		tickets[tk] = 99
	for tk in TicketDefs.PET_KINDS:
		tickets[tk] = 99
	feed = 1e6
	# 장비는 **가장 높은 등급으로 한 벌** — 굴리면 등급이 들쭉날쭉해서
	# "최신 장비로 잰다"가 안 된다.
	var top: Dictionary = GearDefs.RARITY[GearDefs.RARITY.size() - 1]
	for slot in GearDefs.SLOTS:
		var item := GearDefs.make(str(slot), best_stage, top)
		if item.is_empty():
			continue
		var ikey := str(item["icon"])
		item["inventory_key"] = ikey
		gear_inventory[ikey] = item
		equipped[slot] = item.duplicate(true)
	# 스킬은 전종을 높은 레벨로 — 무작위 보유로는 매번 다른 게 열려
	# 어느 스킬이 어떤 판에 맞는지 비교가 안 된다.
	for sk in SkillDefs.all_keys():
		skill_owned[str(sk)] = 3
	_auto_equip_skills()
	# 스탯은 상한까지, 유물은 몇 개만 — 곱연산 축이 만렙이면 곡선 검수가
	# 무의미해진다.
	# **표를 돈다** — lv 는 올린 적 있는 스탯만 갖고 있어서, 그걸 돌면
	# 새 저장본에서 아무것도 안 오른다(실측: 전부 1레벨).
	var cap := StatDefs.train_cap(dungeon_best, best_stage)
	for st in StatDefs.STATS:
		if bool(st.get("impl", false)):
			lv[str(st["key"])] = cap
	for i in mini(6, RelicDefs.RELICS.size()):
		relics[str(RelicDefs.RELICS[i]["id"])] = 2
	hero_hp = max_hp()
	_apply_stage_bg()
	_refresh_currency_visibility()
	_refresh_hud()
	_save_game()

# ── 도감 소탭: 장비 · 스킬 · 연대기 (LoreDefs) ─────────────────────────────
#
# 장비 72종 · 스킬 20종은 **격자**로 편다. 몬스터처럼 목록+상세로 하면 72줄을
# 스크롤해야 해서 "얼마나 모았나"가 한눈에 안 들어온다 — 수집판의 값은
# 빈 칸이 보이는 데 있다.
func _lore_build(root: Control, kind: String) -> void:
	# 요약은 머리 두 줄이 쥔다(_codex_head_text) — 여기 또 적으면 두 곳이
	# 같은 값을 따로 세다가 하나가 낡는다.
	# **스크롤에 넣는다.** 장비는 72칸이라 9줄이고, 반판 높이(358)로는 4줄만
	# 들어간다 — 그냥 깔면 나머지가 판 밖으로 넘어간다(실측 캡처).
	var y0 := CODEX_TAB_Y + 46.0
	var span := LORE_CELL + LORE_GAP
	var keys := _lore_keys(kind)
	var rows := int(ceil(float(keys.size()) / float(LORE_COLS)))
	var sc := _codex_thin_bar(Ui.scroll(Vector2(PAD, y0),
		Vector2(CODEX_W - 16.0, CODEX_BOTTOM - y0)))
	root.add_child(sc)
	var pane := Control.new()
	pane.custom_minimum_size = Vector2(CODEX_W - 16.0 - CODEX_BAR_W,
		float(rows) * span)
	sc.add_child(pane)
	var x0 := (CODEX_W - 16.0 - CODEX_BAR_W
		- (span * float(LORE_COLS) - LORE_GAP)) * 0.5
	var cells: Array = []
	for i in keys.size():
		var cx := x0 + float(i % LORE_COLS) * span
		var cy := float(i / LORE_COLS) * span
		pane.add_child(Ui.set_row(TOME, Vector2(cx, cy),
			Vector2(LORE_CELL, LORE_CELL)))
		var ico := Ui.icon(_lore_icon(kind, i),
			Vector2(cx + (LORE_CELL - 34.0) * 0.5, cy + 13.0), 34.0)
		pane.add_child(ico)
		cells.append(ico)
	_lore_cells[kind] = cells


# 그 갈래의 열쇠 목록. 장비는 슬롯·등급 순으로 펴고(카탈로그 순서 그대로),
# 스킬은 형태 x 등급 스무 칸이다.
func _lore_keys(kind: String) -> Array:
	var out: Array = []
	if kind == "skill":
		for k in SkillDefs.all_keys():
			out.append(str(k))
		return out
	for slot in GearDefs.SLOTS:
		for r in GearDefs.RARITY:
			for spec in GearDefs.items_of(str(slot), str(r["key"])):
				out.append(str(spec[0]))
	return out


func _lore_icon(kind: String, index: int) -> String:
	var keys := _lore_keys(kind)
	if index < 0 or index >= keys.size():
		return ""
	if kind == "skill":
		return SkillDefs.icon_path(str(keys[index]))
	return "res://assets/items/%s.png" % str(keys[index])


func _lore_got(kind: String) -> int:
	var n := 0
	for k in _lore_keys(kind):
		if (skill_owned.has(str(k)) if kind == "skill" else gear_seen.has(str(k))):
			n += 1
	return n


func _refresh_lore(kind: String) -> void:
	if not _lore_cells.has(kind):
		return
	var keys := _lore_keys(kind)
	var cells: Array = _lore_cells[kind]
	for i in cells.size():
		var got: bool = skill_owned.has(str(keys[i])) if kind == "skill" \
			else gear_seen.has(str(keys[i]))
		# 못 얻은 칸은 **까맣게 눌러 실루엣만** 남긴다 — 빈 칸이 보여야 모으고 싶다.
		cells[i].modulate = Color(1, 1, 1, 1) if got \
			else Color(0.10, 0.09, 0.11, 0.85)
	# 종수·이정표·받는 것은 머리 두 줄이 쥔다(_codex_head_text) — 두 곳이
	# 같은 값을 따로 세면 하나는 반드시 낡는다.


# 연대기 — 막마다 한 줄. **밟은 막만 읽힌다**(기록이지 수집이 아니다).
func _act_build(root: Control) -> void:
	var y0 := CODEX_TAB_Y + 46.0
	for i in StageDefs.ACTS.size():
		var ry := y0 + float(i) * 84.0
		root.add_child(Ui.set_card(TOME, Vector2(PAD, ry),
			Vector2(CODEX_W, 76.0)))
		var nm := _panel_label(root, Vector2(PAD + 16.0, ry + 8.0),
			Type.SIZE_SMALL, Color(0.96, 0.86, 0.62), CODEX_W - 32.0, 16.0)
		var tx := _panel_label(root, Vector2(PAD + 16.0, ry + 30.0),
			Type.SIZE_SMALL, Color(0.80, 0.78, 0.76), CODEX_W - 32.0, 0.0)
		# **줄바꿈을 켠다.** 기록 한 줄이 카드 폭에 안 들어가 마지막 글자가
		# 잘렸다(실측 캡처: "기억했"). _panel_label 은 폭을 주면 clip 을 켜므로
		# 여기서 되돌리고 두 줄을 허용한다 — 카드도 그만큼 키웠다.
		tx.clip_text = false
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.size = Vector2(CODEX_W - 32.0, 40.0)
		_act_rows.append({"name": nm, "text": tx})


func _refresh_act() -> void:
	if _act_rows.is_empty():
		return
	var reached := StageDefs.act_of(best_stage)
	for i in _act_rows.size():
		var act: Dictionary = StageDefs.ACTS[i]
		var open := i <= reached
		_act_rows[i]["name"].text = "%d막  %s" % [i + 1,
			str(act["name"]) if open else "???"]
		_act_rows[i]["text"].text = LoreDefs.act_text(i) if open \
			else "아직 발을 들이지 않았다"



# 머리 두 줄을 소탭에 맞춰 채운다. **여기가 "이 도감이 뭘 주나"의 단일 출처다** —
# 소탭마다 다른 표를 보므로, 한 곳에 모아 두지 않으면 어느 소탭은 조용히 빈다.
func _codex_head_text(mode: String) -> Array:
	match mode:
		"foe":
			var parts := PackedStringArray()
			parts.append("도감 %d / %d" % [codex_found, FoeTiers.all_keys().size()])
			parts.append("지식 %d" % codex_knowledge)
			for r in FoeTiers.CODEX_REWARDS:
				if codex_knowledge < int(r["need"]):
					parts.append("다음 %d" % (int(r["need"]) - codex_knowledge))
					break
			return [" · ".join(parts), _gain_text(
				FoeTiers.codex_bonus(codex_knowledge, "damage"),
				FoeTiers.codex_bonus(codex_knowledge, "hp"),
				FoeTiers.codex_bonus(codex_knowledge, "crit"))]
		"gear", "skill":
			var marks: Array = LoreDefs.SKILL_MARKS if mode == "skill" 				else LoreDefs.GEAR_MARKS
			var got := _lore_got(mode)
			var total := _lore_keys(mode).size()
			var left := LoreDefs.to_next(marks, got)
			var head := "%s %d / %d 종" % ["스킬" if mode == "skill" else "장비",
				got, total]
			if left > 0:
				head += "  ·  다음 이정표까지 %d종" % left
			return [head, _gain_text(LoreDefs.bonus(marks, got, "damage"),
				LoreDefs.bonus(marks, got, "hp"),
				LoreDefs.bonus(marks, got, "crit"))]
		"title":
			# 칭호는 배율이 아니라 **훈련 공짜 레벨**을 준다(TitleDefs).
			var lv := 0
			for t in TitleDefs.TITLES:
				if titles_got.has(str(t["id"])):
					lv += int(t.get("amount", 0))
			return ["칭호 %d / %d" % [titles_got.size(), TitleDefs.TITLES.size()],
				"지금 받는 것: 훈련 +%d레벨" % lv if lv > 0 else "아직 딴 칭호가 없다"]
		"act":
			var reached := StageDefs.act_of(best_stage)
			return ["연대기 %d / %d 막" % [reached + 1, StageDefs.ACTS.size()],
				_gain_text(LoreDefs.act_bonus(reached, "damage"),
					LoreDefs.act_bonus(reached, "hp"), 0.0)]
	return ["", ""]


# "지금 받는 것: 공격 +12% · 체력 +8%" — 0 인 항목은 안 적는다(빈 줄이 낫다).
func _gain_text(dmg: float, hp: float, crit: float) -> String:
	var parts := PackedStringArray()
	if dmg > 0.0:
		parts.append("공격 +%d%%" % int(round(dmg * 100.0)))
	if hp > 0.0:
		parts.append("체력 +%d%%" % int(round(hp * 100.0)))
	if crit > 0.0:
		parts.append("치명 확률 +%d%%" % int(round(crit * 100.0)))
	return "아직 받는 게 없다" if parts.is_empty() 		else "지금 받는 것: " + " · ".join(parts)

func _codex_set_mode(mode: String) -> void:
	_codex_mode = mode
	for key in _codex_roots:
		_codex_roots[key].visible = key == mode
	for key in _codex_tab_art:
		var art: Dictionary = _codex_tab_art[key]
		art["on"].visible = key == mode
		art["lbl"].add_theme_color_override("font_color",
			Color(0.98, 0.86, 0.56) if key == mode else Color(0.72, 0.70, 0.68))
	var ht := _codex_head_text(mode)
	_codex_summary.text = str(ht[0])
	_codex_gain.text = str(ht[1])
	if mode == "foe":
		_refresh_codex()
	elif mode == "title":
		if not titles_new.is_empty():
			titles_new.clear()
			_save_game()
		if _codex_dot:
			_codex_dot.visible = false
		_refresh_titles()
	elif mode == "oath":
		_refresh_oath_codex()
	_refresh_lore("gear")
	_refresh_lore("skill")
	_refresh_act()


# 펫 전면 판 — 달의 제단 문법 (PET_DESIGN v2 2단계, 사장님 2026-08-18).
#
# 소탭 다섯: 보유·장비·강화·소환·장비소환. 헤더 그림과 소탭 세트는 전부
# 전용이다: 둥지 헤더(head_pet) + 둥지 세트(nest_*, 2026-08-18 아트 배치).
# 연출(소환 애니·강화 이펙트)은 5단계다. 여기는 다섯 판이 실제로 도는 것까지.
const PET_TABS := [["own", "보유"], ["gear", "장비"], ["feed", "강화"],
	["trip", "원정"], ["roll", "펫 소환"], ["rollgear", "장비 소환"]]
const PET_CELL := 96.0
const PET_GAP := 6.0
const PET_GRID_Y := 284.0
const PET_GRID_H := 236.0
const PET_DETAIL_Y := 532.0
var _pet_mode := "own"
var _pet_sel := ""              # 보유·강화·장착이 보는 펫
var _petgear_sel := ""          # 장비 판이 보는 장비
var _pet_roots := {}
var _pet_tab_btns := {}
var _pet_cells: Array[Dictionary] = []
var _petgear_cells: Array[Dictionary] = []
var _trip_cells: Array[Dictionary] = []
var _trip_ui := {}
var _trip_sel := ""
var _pet_detail := {}
var _petgear_detail := {}
var _pet_feed_ui := {}
var _pet_roll_ui := {}


# 세트 그림 버튼 — 둥지 줄 + 글자 + 투명 판정 (상점 문법).
# 판정 버튼이 투명이라 호버·눌림 반응은 **그림이** 받는다(사장님: 효과 필요) —
# 버튼에 걸면 아무 일도 안 보인다.
func _pet_btn(parent: Control, pos: Vector2, size: Vector2,
		text: String) -> Dictionary:
	var art := Ui.set_row(NEST, pos, size)
	parent.add_child(art)
	var l := _panel_label(parent, Vector2(pos.x, pos.y + size.y * 0.5 - 10.0),
		Type.SIZE_SMALL, Color(0.96, 0.92, 0.88), size.x, 20.0)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Ui.button("", pos, size, Type.SIZE_SMALL)
	btn.modulate = Color(1, 1, 1, 0)
	parent.add_child(btn)
	_pet_hover(btn, art)
	return {"btn": btn, "lbl": l, "art": art}


# 비활성이 안 보이면 "왜 안 눌리지"가 된다(사장님) — 판정 버튼이 투명이라
# 그림과 글자를 같이 죽여야 상태가 보인다.
func _pet_btn_enable(b: Dictionary, on: bool) -> void:
	b["btn"].disabled = not on
	_art_set_base(b["art"], Color(1, 1, 1) if on else Color(0.5, 0.46, 0.48))
	b["lbl"].modulate = Color(1, 1, 1, 1.0 if on else 0.45)


# 호버 = 밝아지고 살짝 커진다, 눌림 = 눌린다. 비활성 버튼은 반응하지 않는다 —
# 죽은 버튼이 살아 있는 척하면 "왜 안 눌리지"가 된다.
func _pet_hover(btn: Button, art: Control) -> void:
	art.pivot_offset = art.size * 0.5
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled:
			return
		art.modulate = _art_base(art) * Color(1.18, 1.14, 1.08)
		art.scale = Vector2(1.03, 1.03))
	btn.mouse_exited.connect(func() -> void:
		art.modulate = _art_base(art)
		art.scale = Vector2.ONE)
	btn.button_down.connect(func() -> void:
		if not btn.disabled:
			art.scale = Vector2(0.96, 0.96))
	btn.button_up.connect(func() -> void:
		art.scale = Vector2.ONE if btn.disabled or not btn.is_hovered() \
			else Vector2(1.03, 1.03))


# 그림의 **바탕색**. 비활성 회색을 여기 적어 두면 호버가 지우지 못한다
# (사장님 실측: 못 누르는 버튼을 훑고 나가면 멀쩡해 보였다).
func _art_base(art: Control) -> Color:
	return art.get_meta("base_mod", Color(1, 1, 1))


func _art_set_base(art: Control, col: Color) -> void:
	art.set_meta("base_mod", col)
	art.modulate = col


func _build_pet(root: Control) -> void:
	# 헤더 — 동행의 둥지 전용 그림(2026-08-18 아트 배치).
	var head := Control.new()
	head.position = Vector2(PAD, 12.0)
	head.size = Vector2(CONTENT_W, 210.0)
	head.clip_contents = true
	root.add_child(head)
	var ht := TextureRect.new()
	ht.texture = Assets.tex("res://assets/ui/head_pet.png")
	ht.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ht.size = Vector2(CONTENT_W, CONTENT_W * 224.0 / 576.0)
	ht.position = Vector2(0.0, -6.0)
	ht.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ht)
	var place := _panel_label(head, Vector2(16.0, 10.0), Type.SIZE_MID,
		Color(0.97, 0.92, 0.86), 220.0, 24.0)
	place.text = "동행의 둥지"
	_shop_outline(place, 8)
	var bub := _panel_label(head, Vector2(16.0, 44.0), Type.SIZE_SMALL,
		Color(0.90, 0.84, 0.80), 320.0, 18.0)
	bub.text = "먹이면 자라고, 데리고 다니면 힘이 된다"
	_shop_outline(bub, 4)
	# 소탭 다섯 — 자리표시(가죽책). 전용 세트는 아트 배치에서.
	# 칸 수를 PET_TABS 에서 센다 — 5 를 박아 두면 소탭을 늘릴 때 라벨이 잘린다.
	var tn := float(PET_TABS.size())
	var tw := (CONTENT_W - 8.0 * (tn - 1.0)) / tn
	for i in PET_TABS.size():
		var mode := str(PET_TABS[i][0])
		var tp := Vector2(PAD + float(i) * (tw + 8.0), 232.0)
		var off := Ui.set_tab(NEST, false, tp, Vector2(tw, 36.0))
		var on := Ui.set_tab(NEST, true, tp, Vector2(tw, 36.0))
		root.add_child(off)
		root.add_child(on)
		var tl := _panel_label(root, Vector2(tp.x, 241.0), Type.SIZE_SMALL,
			Color(0.96, 0.92, 0.88), tw, 20.0)
		tl.text = str(PET_TABS[i][1])
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_outline(tl, 5)
		var tb := Ui.button("", tp, Vector2(tw, 36.0), Type.SIZE_SMALL)
		tb.modulate = Color(1, 1, 1, 0)
		tb.pressed.connect(func() -> void: _pet_set_mode(mode))
		root.add_child(tb)
		_pet_hover(tb, off)
		_pet_tab_btns[mode] = {"on": on, "lbl": tl}
	for pair in PET_TABS:
		var r := Control.new()
		r.visible = false
		root.add_child(r)
		_pet_roots[str(pair[0])] = r
	_pet_build_own(_pet_roots["own"])
	_pet_build_gear(_pet_roots["gear"])
	_pet_build_feed(_pet_roots["feed"])
	_pet_build_trip(_pet_roots["trip"])
	_pet_build_roll(_pet_roots["roll"], "pet")
	_pet_build_roll(_pet_roots["rollgear"], "petgear")
	_pet_reveal = Control.new()
	_pet_reveal.visible = false
	_pet_reveal.z_index = 5
	root.add_child(_pet_reveal)
	_pet_set_mode("own")


func _pet_set_mode(mode: String) -> void:
	_pet_mode = mode
	for key in _pet_roots:
		_pet_roots[key].visible = key == mode
	for key in _pet_tab_btns:
		_pet_tab_btns[key]["on"].visible = key == mode
		_pet_tab_btns[key]["lbl"].add_theme_color_override("font_color",
			Color(0.98, 0.86, 0.56) if key == mode else Color(0.80, 0.76, 0.74))
	_refresh_pet()


# 5x5 격자 — 펫과 장비가 같은 문법을 쓴다. 칸에는 그림과 별만 두고 이름·효과는
# 아래 상세가 맡는다: 96px 칸에 이름까지 넣으면 글자가 잘린다.
func _pet_build_grid(root: Control, count: int, cells: Array[Dictionary],
		on_pick: Callable, art_of: Callable) -> void:
	var span := PET_CELL + PET_GAP
	var sc := _codex_thin_bar(Ui.scroll(Vector2(PAD, PET_GRID_Y),
		Vector2(CONTENT_W, PET_GRID_H)))
	root.add_child(sc)
	var pane := Control.new()
	pane.custom_minimum_size = Vector2(CONTENT_W - CODEX_BAR_W,
		ceil(float(count) / 5.0) * span)
	sc.add_child(pane)
	var x0 := (CONTENT_W - CODEX_BAR_W - (span * 5.0 - PET_GAP)) * 0.5
	for i in count:
		var cx := x0 + float(i % 5) * span
		var cy := float(i / 5) * span
		var cell_frame := Ui.set_row(NEST, Vector2(cx, cy),
			Vector2(PET_CELL, PET_CELL))
		pane.add_child(cell_frame)
		var art: Control = art_of.call(i)
		if art != null:
			art.position = Vector2(cx + (PET_CELL - art.size.x) * 0.5,
				cy + (PET_CELL - art.size.y) * 0.5 - 6.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pane.add_child(art)
		var star := _panel_label(pane, Vector2(cx, cy + PET_CELL - 24.0),
			Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), PET_CELL, 16.0)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# 장착중 표식(사장님) — 데리고 다니는 펫 / 어느 펫이 든 장비.
		var mark := _panel_label(pane, Vector2(cx, cy + 6.0), Type.SIZE_SMALL,
			Color(0.55, 0.95, 0.62), PET_CELL, 14.0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.visible = false
		var idx := i
		# 호버는 **액자를 직접 잡는다.** 자식 순서로 세다가 표식 라벨이 끼면서
		# 한 칸 밀려 펫 그림을 집었고, 호버가 끝날 때 그림의 실루엣 어둠을
		# 흰색으로 되돌려 못 만난 펫이 드러났다(사장님 실측).
		var btn := Ui.button("", Vector2(cx, cy), Vector2(PET_CELL, PET_CELL),
			Type.SIZE_SMALL)
		btn.modulate = Color(1, 1, 1, 0)
		btn.pressed.connect(func() -> void: on_pick.call(idx))
		pane.add_child(btn)
		_pet_hover(btn, cell_frame)
		cells.append({"art": art, "star": star, "mark": mark})


func _pet_art(i: int) -> Control:
	var frames := Assets.frames(PetDefs.icon_dir(str(PetDefs.PETS[i]["id"])))
	if frames.is_empty():
		return null
	var t := TextureRect.new()
	t.texture = frames[0]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size = Vector2(56.0, 56.0)
	return t


func _petgear_art(i: int) -> Control:
	# 전용 아이콘(2026-08-18 아트 배치) — 파일명이 id 규약이라 표에 경로가 없다.
	return Ui.icon("res://assets/items/petw_%s.png"
		% str(PetDefs.GEAR[i]["id"]), Vector2.ZERO, 40.0)


func _pet_build_own(root: Control) -> void:
	_pet_build_grid(root, PetDefs.PETS.size(), _pet_cells,
		func(i: int) -> void:
			_pet_sel = str(PetDefs.PETS[i]["id"])
			_refresh_pet(),
		_pet_art)
	root.add_child(Ui.set_card(NEST, Vector2(PAD, PET_DETAIL_Y),
		Vector2(CONTENT_W, 156.0)))
	_pet_detail["name"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 14.0),
		Type.SIZE_MID, Color(0.96, 0.92, 0.88), CONTENT_W - 240.0, 22.0)
	_pet_detail["desc"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 44.0),
		Type.SIZE_SMALL, Color(0.78, 0.74, 0.72), CONTENT_W - 240.0, 16.0)
	_pet_detail["buff"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 68.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), CONTENT_W - 240.0, 16.0)
	var track := ColorRect.new()
	track.color = Color(0.16, 0.12, 0.11)
	track.position = Vector2(PAD + 18.0, PET_DETAIL_Y + 96.0)
	track.size = Vector2(230.0, 10.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	var fill := ColorRect.new()
	fill.color = Color(0.72, 0.16, 0.20)
	fill.position = track.position
	fill.size = Vector2(0.0, 10.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	_pet_detail["fill"] = fill
	_pet_detail["amt"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 114.0),
		Type.SIZE_SMALL, Color(0.82, 0.78, 0.76), 260.0, 16.0)
	var take := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0, PET_DETAIL_Y + 18.0),
		Vector2(120.0, 40.0), "받기")
	take["btn"].pressed.connect(func() -> void: _pet_collect(_pet_sel))
	_pet_detail["take"] = take
	var wear := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0, PET_DETAIL_Y + 66.0),
		Vector2(120.0, 40.0), "데려가기")
	wear["btn"].pressed.connect(func() -> void:
		if _pet_star(_pet_sel) <= 0:
			return
		pet_worn = "" if pet_worn == _pet_sel else _pet_sel
		_save_game()
		_refresh_pet())
	_pet_detail["wear"] = wear
	# 모두 받기(사장님) — 펫마다 눌러 받는 건 스물다섯 번 일이다.
	var take_all := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0,
		PET_DETAIL_Y + 114.0), Vector2(120.0, 36.0), "모두 받기")
	take_all["btn"].pressed.connect(_pet_collect_all)
	_pet_detail["all"] = take_all


# 원정 판 — 보유 판과 같은 격자를 쓴다. 칸 표식이 남은 시간이고, 아래 상세가
# 무엇을 파 오는지와 보내기/받기를 맡는다.
func _pet_build_trip(root: Control) -> void:
	_pet_build_grid(root, PetDefs.PETS.size(), _trip_cells,
		func(i: int) -> void:
			_trip_sel = str(PetDefs.PETS[i]["id"])
			_refresh_pet(),
		_pet_trip_art)
	root.add_child(Ui.set_card(NEST, Vector2(PAD, PET_DETAIL_Y),
		Vector2(CONTENT_W, 156.0)))
	_trip_ui["name"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 14.0),
		Type.SIZE_MID, Color(0.96, 0.92, 0.88), CONTENT_W - 240.0, 22.0)
	_trip_ui["prize"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 44.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), CONTENT_W - 240.0, 16.0)
	_trip_ui["state"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 68.0),
		Type.SIZE_SMALL, Color(0.78, 0.74, 0.72), CONTENT_W - 240.0, 16.0)
	_trip_ui["slots"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 92.0),
		Type.SIZE_SMALL, Color(0.72, 0.70, 0.74), CONTENT_W - 240.0, 16.0)
	_trip_ui["hint"] = _panel_label(root, Vector2(PAD + 18.0, PET_DETAIL_Y + 114.0),
		Type.SIZE_SMALL, Color(0.66, 0.64, 0.68), CONTENT_W - 60.0, 16.0)
	var go := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0, PET_DETAIL_Y + 30.0),
		Vector2(120.0, 40.0), "보내기")
	go["btn"].pressed.connect(func() -> void: _trip_send(_trip_sel))
	_trip_ui["go"] = go
	var take := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0, PET_DETAIL_Y + 80.0),
		Vector2(120.0, 40.0), "받기")
	take["btn"].pressed.connect(func() -> void: _trip_claim(_trip_sel))
	_trip_ui["take"] = take


func _pet_trip_art(i: int) -> Control:
	return _pet_art(i)


func _refresh_pet_trip() -> void:
	if _trip_ui.is_empty():
		return
	if _trip_sel == "" or not pets_got.has(_trip_sel):
		_trip_sel = str(pets_got.keys()[0]) if not pets_got.is_empty() \
			else str(PetDefs.PETS[0]["id"])
	for i in _trip_cells.size():
		var id := str(PetDefs.PETS[i]["id"])
		var got := pets_got.has(id)
		if _trip_cells[i]["art"] != null:
			_trip_cells[i]["art"].modulate = Color(1, 1, 1, 1) if got \
				else Color(0.10, 0.09, 0.11, 0.9)
		var left := _trip_left(id)
		_trip_cells[i]["mark"].visible = left >= 0.0
		_trip_cells[i]["mark"].text = _trip_tag(left)
		_trip_cells[i]["mark"].add_theme_color_override("font_color",
			Color(0.55, 0.95, 0.62) if left <= 0.0 else Color(0.88, 0.82, 0.60))
		# 못 보내는 칸(5성인데 장비가 없거나 장비도 5성)은 별 자리에 이유를 쓴다.
		_trip_cells[i]["star"].text = "" if not got \
			else ("" if left >= 0.0 or not _trip_prize(id).is_empty() else "보낼 곳 없음")
	var sel := _trip_sel
	var p := PetDefs.of(sel)
	var left_sel := _trip_left(sel)
	var prize := _trip_prize(sel)
	_trip_ui["name"].text = str(p.get("name", sel))
	if not pets_got.has(sel):
		_trip_ui["prize"].text = "아직 못 만난 동행이다"
		_trip_ui["state"].text = ""
	elif left_sel >= 0.0:
		var row: Array = pet_trip.get(sel, [])
		var gid := str(row[1]).split(":")[1]
		var d: Dictionary = PetDefs.of(gid) if str(row[1]).begins_with("pet:") \
			else PetDefs.gear_of(gid)
		_trip_ui["prize"].text = "%s 조각 1개를 파는 중" % str(d.get("name", gid))
		_trip_ui["state"].text = "돌아오기까지 %s" % _trip_text(left_sel)
	elif prize.is_empty():
		_trip_ui["prize"].text = "보낼 곳이 없다"
		_trip_ui["state"].text = "5성이 된 동행은 제 장비의 조각을 판다 — 장비를 채워 주면 다시 나간다"
	else:
		_trip_ui["prize"].text = "%s 조각 1개" % str(prize["name"])
		_trip_ui["state"].text = "%.0f시간 걸린다" \
			% PetDefs.trip_hours(str(prize["rarity"]))
	var slots := PetDefs.trip_slots(pets_got.size())
	_trip_ui["slots"].text = "파견 %d / %d칸" % [pet_trip.size(), slots]
	_trip_ui["hint"].text = "원정 중인 동행은 둥지에서 안 긁는다"
	var can_go := pets_got.has(sel) and left_sel < 0.0 and not prize.is_empty() 		and pet_trip.size() < slots and best_stage >= PetDefs.TRIP_OPEN
	_pet_btn_enable(_trip_ui["go"], can_go)
	_pet_btn_enable(_trip_ui["take"], is_equal_approx(left_sel, 0.0))


func _pet_build_gear(root: Control) -> void:
	_pet_build_grid(root, PetDefs.GEAR.size(), _petgear_cells,
		func(i: int) -> void:
			_petgear_sel = str(PetDefs.GEAR[i]["id"])
			_refresh_pet(),
		_petgear_art)
	root.add_child(Ui.set_card(NEST, Vector2(PAD, PET_DETAIL_Y),
		Vector2(CONTENT_W, 156.0)))
	_petgear_detail["name"] = _panel_label(root,
		Vector2(PAD + 18.0, PET_DETAIL_Y + 14.0), Type.SIZE_MID,
		Color(0.96, 0.92, 0.88), CONTENT_W - 240.0, 22.0)
	_petgear_detail["info"] = _panel_label(root,
		Vector2(PAD + 18.0, PET_DETAIL_Y + 44.0), Type.SIZE_SMALL,
		Color(0.78, 0.74, 0.72), CONTENT_W - 240.0, 16.0)
	_petgear_detail["who"] = _panel_label(root,
		Vector2(PAD + 18.0, PET_DETAIL_Y + 68.0), Type.SIZE_SMALL,
		Color(0.98, 0.86, 0.56), CONTENT_W - 240.0, 16.0)
	# 장착 상대는 **보유 판에서 고른 펫**이다 — 데리고 다니는 펫과 수집 펫이
	# 다를 수 있어야 gather 장비가 뜻을 가진다.
	_petgear_detail["target"] = _panel_label(root,
		Vector2(PAD + 18.0, PET_DETAIL_Y + 96.0), Type.SIZE_SMALL,
		Color(0.72, 0.70, 0.74), CONTENT_W - 240.0, 16.0)
	var eq := _pet_btn(root, Vector2(PAD + CONTENT_W - 138.0, PET_DETAIL_Y + 42.0),
		Vector2(120.0, 40.0), "채우기")
	eq["btn"].pressed.connect(func() -> void:
		_pet_equip_gear(_pet_sel, _petgear_sel))
	_petgear_detail["equip"] = eq


func _pet_build_feed(root: Control) -> void:
	root.add_child(Ui.set_body(NEST, Vector2(PAD, PET_GRID_Y),
		Vector2(CONTENT_W, 404.0)))
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size = Vector2(96.0, 96.0)
	art.position = Vector2(PAD + (CONTENT_W - 96.0) * 0.5, PET_GRID_Y + 28.0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	_pet_feed_ui["art"] = art
	_pet_feed_ui["name"] = _panel_label(root, Vector2(PAD, PET_GRID_Y + 134.0),
		Type.SIZE_MID, Color(0.96, 0.92, 0.88), CONTENT_W, 22.0)
	_pet_feed_ui["name"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pet_feed_ui["stat"] = _panel_label(root, Vector2(PAD, PET_GRID_Y + 164.0),
		Type.SIZE_SMALL, Color(0.98, 0.86, 0.56), CONTENT_W, 16.0)
	_pet_feed_ui["stat"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 게이지 — 가진 먹이 대 다음 레벨 비용. 차면 버튼이 산다.
	var track := ColorRect.new()
	track.color = Color(0.16, 0.12, 0.11)
	track.position = Vector2(PAD + 64.0, PET_GRID_Y + 206.0)
	track.size = Vector2(CONTENT_W - 128.0, 14.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	var fill := ColorRect.new()
	fill.color = Color(0.62, 0.42, 0.14)
	fill.position = track.position
	fill.size = Vector2(0.0, 14.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	_pet_feed_ui["fill"] = fill
	_pet_feed_ui["cost"] = _panel_label(root, Vector2(PAD, PET_GRID_Y + 228.0),
		Type.SIZE_SMALL, Color(0.82, 0.78, 0.76), CONTENT_W, 16.0)
	_pet_feed_ui["cost"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var one := _pet_btn(root, Vector2(PAD + 64.0, PET_GRID_Y + 268.0),
		Vector2(190.0, 44.0), "강화 시도")
	one["btn"].pressed.connect(func() -> void: _pet_feed(_pet_sel))
	_pet_feed_ui["one"] = one
	var ten := _pet_btn(root,
		Vector2(PAD + CONTENT_W - 64.0 - 190.0, PET_GRID_Y + 268.0),
		Vector2(190.0, 44.0), "x10")
	ten["btn"].pressed.connect(func() -> void:
		for i in 10:
			if not _pet_feed(_pet_sel):
				break)
	_pet_feed_ui["ten"] = ten
	_pet_feed_ui["note"] = _panel_label(root, Vector2(PAD, PET_GRID_Y + 336.0),
		Type.SIZE_SMALL, Color(0.72, 0.70, 0.74), CONTENT_W, 16.0)
	_pet_feed_ui["note"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# 소환 판 — 펫권(kind="pet")과 장비권(kind="petgear")이 같은 문법을 쓴다.
func _pet_build_roll(root: Control, kind: String) -> void:
	root.add_child(Ui.set_body(NEST, Vector2(PAD, PET_GRID_Y),
		Vector2(CONTENT_W, 300.0)))
	var big := Ui.icon(TicketDefs.icon_of(kind),
		Vector2(PAD + (CONTENT_W - 72.0) * 0.5, PET_GRID_Y + 36.0), 72.0)
	root.add_child(big)
	var title := _panel_label(root, Vector2(PAD, PET_GRID_Y + 124.0),
		Type.SIZE_MID, Color(0.96, 0.92, 0.88), CONTENT_W, 22.0)
	title.text = "펫 소환" if kind == "pet" else "펫 장비 소환"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 확률 — GachaDefs 무게를 그대로 읽어 적는다(표를 두 곳에서 관리하지 않는다).
	var total := 0.0
	for r in GachaDefs.RARITIES:
		if str(r["key"]) in PetDefs.RARITY_KEYS:
			total += float(r["weight"])
	var parts := PackedStringArray()
	for r in GachaDefs.RARITIES:
		if str(r["key"]) in PetDefs.RARITY_KEYS:
			parts.append("%s %.1f%%" % [str(r["name"]),
				float(r["weight"]) / total * 100.0])
	var rates := _panel_label(root, Vector2(PAD + 20.0, PET_GRID_Y + 156.0),
		Type.SIZE_SMALL, Color(0.62, 0.82, 0.68), CONTENT_W - 40.0, 0.0)
	rates.text = "  ·  ".join(parts)
	rates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rates.size = Vector2(CONTENT_W - 40.0, 40.0)
	# 소환권 잔량 알약.
	var pp := Vector2(PAD + (CONTENT_W - 180.0) * 0.5, PET_GRID_Y + 320.0)
	root.add_child(Ui.set_pill(NEST, pp, Vector2(180.0, 34.0)))
	root.add_child(Ui.icon(TicketDefs.icon_of(kind), pp + Vector2(20.0, 7.0), 20.0))
	var cnt := _panel_label(root, Vector2(pp.x + 48.0, pp.y + 8.0),
		Type.SIZE_SMALL, Color(0.96, 0.92, 0.88), 120.0, 18.0)
	var one := _pet_btn(root, Vector2(PAD + 24.0, PET_GRID_Y + 372.0),
		Vector2(220.0, 52.0), "1회")
	var ten := _pet_btn(root, Vector2(PAD + CONTENT_W - 244.0, PET_GRID_Y + 372.0),
		Vector2(220.0, 52.0), "10연")
	# 남은 권 털기 — 2~9장일 때만 뜬다(장비 소환과 같은 규칙, 사장님 2026-08-25).
	var left := _pet_btn(root, Vector2(PAD + (CONTENT_W - 220.0) * 0.5,
		PET_GRID_Y + 432.0), Vector2(220.0, 52.0), "")
	if kind == "pet":
		one["btn"].pressed.connect(func() -> void: _pet_roll())
		ten["btn"].pressed.connect(func() -> void: _pet_roll_many(10))
		left["btn"].pressed.connect(func() -> void:
			_pet_roll_many(int(tickets.get("pet", 0))))
	else:
		one["btn"].pressed.connect(func() -> void: _petgear_roll())
		ten["btn"].pressed.connect(func() -> void: _petgear_roll_many(10))
		left["btn"].pressed.connect(func() -> void:
			_petgear_roll_many(int(tickets.get("petgear", 0))))
	# 값 옆에 뜨는 재화 아이콘(사장님) — 글자만 있으면 무슨 재화인지 한 번 더
	# 읽어야 한다. 자리는 _refresh_pet_roll 이 **글자 폭을 재서** 잡는다.
	var g1 := Ui.icon("res://assets/ui/res_gem.png",
		Vector2(PAD + 24.0, PET_GRID_Y + 372.0 + 15.0), 22.0)
	g1.visible = false
	root.add_child(g1)
	var g2 := Ui.icon("res://assets/ui/res_gem.png",
		Vector2(PAD + CONTENT_W - 244.0, PET_GRID_Y + 372.0 + 15.0), 22.0)
	g2.visible = false
	root.add_child(g2)
	var g3 := Ui.icon(TicketDefs.icon_of(kind),
		Vector2(PAD + (CONTENT_W - 220.0) * 0.5, PET_GRID_Y + 432.0 + 15.0), 22.0)
	g3.visible = false
	root.add_child(g3)
	_pet_roll_ui[kind] = {"cnt": cnt, "one": one, "ten": ten,
		"one_gem": g1, "ten_gem": g2, "left": left, "left_icon": g3}
	# 승급 문구가 있던 자리 — 문구는 뺐다(사장님 2026-08-18).
	_mile_strip(root, Vector2(PAD + (CONTENT_W - 300.0) * 0.5,
		PET_GRID_Y + 210.0), 300.0)


func _refresh_pet() -> void:
	if _pet_roots.is_empty():
		return
	_pet_tick()
	_refresh_pet_trip()
	if _pet_sel == "":
		_pet_sel = pet_worn if pet_worn != "" else str(PetDefs.PETS[0]["id"])
	if _petgear_sel == "":
		_petgear_sel = str(PetDefs.GEAR[0]["id"])
	# 격자 — 못 만난 것은 실루엣. 빈 칸이 보여야 데려오고 싶다.
	for i in _pet_cells.size():
		var id := str(PetDefs.PETS[i]["id"])
		var got := pets_got.has(id)
		if _pet_cells[i]["art"] != null:
			_pet_cells[i]["art"].modulate = Color(1, 1, 1, 1) if got \
				else Color(0.10, 0.09, 0.11, 0.9)
		_pet_cells[i]["star"].text = ("%d성" % _pet_star(id)) if got else ""
		_pet_cells[i]["mark"].visible = pet_worn == id
		_pet_cells[i]["mark"].text = "동행 중"
	for i in _petgear_cells.size():
		var gid := str(PetDefs.GEAR[i]["id"])
		var ggot := int(pet_gear_got.get(gid, 0)) > 0
		if _petgear_cells[i]["art"] != null:
			_petgear_cells[i]["art"].modulate = Color(1, 1, 1, 1) if ggot \
				else Color(0.10, 0.09, 0.11, 0.9)
		_petgear_cells[i]["star"].text = \
			("%d성" % int(pet_gear_got.get(gid, 0))) if ggot else ""
		var holder2 := ""
		for k in pet_gear_worn:
			if str(pet_gear_worn[k]) == gid:
				holder2 = str(PetDefs.of(str(k)).get("name", ""))
				break
		_petgear_cells[i]["mark"].visible = holder2 != ""
		_petgear_cells[i]["mark"].text = holder2
	_refresh_pet_own()
	_refresh_pet_gear()
	_refresh_pet_feed()
	_refresh_pet_roll()


func _refresh_pet_own() -> void:
	if _pet_detail.is_empty():
		return
	var d := PetDefs.of(_pet_sel)
	var got := pets_got.has(_pet_sel)
	var star := _pet_star(_pet_sel)
	var lv := _pet_lv(_pet_sel)
	var rar := GachaDefs.rarity(str(d["rarity"]))
	_pet_detail["name"].text = "%s  %d성 %d레벨" % [str(d["name"]), star, lv] \
		if got else "%s  ·  ???" % str(rar["name"])
	_pet_detail["name"].add_theme_color_override("font_color",
		rar["col"] if got else Color(0.60, 0.58, 0.62))
	_pet_detail["desc"].text = str(d["desc"]) if got else "소환에서 만난다"
	_pet_detail["buff"].text = "%s +%d%%  ·  %s을 물어온다" % [
		TitleDefs.stat_name(str(d["stat"])),
		int(round(PetDefs.bonus(_pet_sel, str(d["stat"]), lv, star) * 100.0)),
		_reward_name(str(d["gain"]))] if got else ""
	var have := float(pet_bank.get(_pet_sel, 0.0))
	var cap := PetDefs.cap(_pet_sel, lv, maxi(1, star))
	_pet_detail["fill"].size.x = 230.0 * (clampf(have / maxf(1.0, cap), 0.0, 1.0)
		if got else 0.0)
	_pet_detail["amt"].text = "그릇  %s / %s" % [_n(have), _n(cap)] if got else ""
	_pet_btn_enable(_pet_detail["take"], got and have >= 1.0)
	_pet_btn_enable(_pet_detail["wear"], got)
	var any_bank := false
	for pid in pets_got:
		if float(pet_bank.get(pid, 0.0)) >= 1.0:
			any_bank = true
			break
	_pet_btn_enable(_pet_detail["all"], any_bank)
	_pet_detail["wear"]["lbl"].text = "함께" if pet_worn == _pet_sel else "데려가기"


func _refresh_pet_gear() -> void:
	if _petgear_detail.is_empty():
		return
	var g := PetDefs.gear_of(_petgear_sel)
	var star := int(pet_gear_got.get(_petgear_sel, 0))
	var got := star > 0
	var rar := GachaDefs.rarity(str(g["rarity"]))
	_petgear_detail["name"].text = "%s  %d성" % [str(g["name"]), star] if got \
		else "%s  ·  ???" % str(rar["name"])
	_petgear_detail["name"].add_theme_color_override("font_color",
		rar["col"] if got else Color(0.60, 0.58, 0.62))
	var v := float(g["value"]) * PetDefs.star_mult(maxi(1, star))
	_petgear_detail["info"].text = (("수집 +%d%%" if str(g["kind"]) == "gather" \
		else "버프 증폭 +%d%%") % int(round(v * 100.0))) if got \
		else "장비 소환에서 나온다"
	var holder := ""
	for k in pet_gear_worn:
		if str(pet_gear_worn[k]) == _petgear_sel:
			holder = str(k)
			break
	_petgear_detail["who"].text = \
		("%s 이(가) 들고 있다" % str(PetDefs.of(holder).get("name", ""))) \
		if holder != "" else ("비어 있다" if got else "")
	_petgear_detail["target"].text = "채울 펫: %s (보유 판에서 고른다)" \
		% str(PetDefs.of(_pet_sel).get("name", "-"))
	_pet_btn_enable(_petgear_detail["equip"],
		got and _pet_star(_pet_sel) > 0)
	_petgear_detail["equip"]["lbl"].text = "벗기기" \
		if str(pet_gear_worn.get(_pet_sel, "")) == _petgear_sel else "채우기"


func _refresh_pet_feed() -> void:
	if _pet_feed_ui.is_empty():
		return
	var d := PetDefs.of(_pet_sel)
	var got := pets_got.has(_pet_sel)
	var star := _pet_star(_pet_sel)
	var lv := _pet_lv(_pet_sel)
	var frames := Assets.frames(PetDefs.icon_dir(_pet_sel))
	_pet_feed_ui["art"].texture = frames[0] if not frames.is_empty() else null
	_pet_feed_ui["art"].modulate = Color(1, 1, 1, 1) if got \
		else Color(0.10, 0.09, 0.11, 0.9)
	_pet_feed_ui["name"].text = "%s  %d성 %d레벨" % [str(d["name"]), star, lv] \
		if got else "보유 판에서 펫을 고른다"
	_pet_feed_ui["stat"].text = "%s +%d%%  ·  수집 x%.2f" % [
		TitleDefs.stat_name(str(d["stat"])),
		int(round(PetDefs.bonus(_pet_sel, str(d["stat"]), lv, star) * 100.0)),
		PetDefs.growth_mult(lv, maxi(1, star))] if got else ""
	var capped := got and lv >= PetDefs.lv_cap(star)
	var cost := PetDefs.feed_cost(lv)
	_pet_feed_ui["fill"].size.x = (CONTENT_W - 128.0) \
		* ((1.0 if capped else clampf(feed / maxf(1.0, cost), 0.0, 1.0)) \
		if got else 0.0)
	_pet_feed_ui["cost"].text = ("승급하면 더 클 수 있다" if capped \
		else "다음 레벨  먹이 %s  ·  성공 %d%%  ·  보유 %s" % [_n(cost, true),
		int(round(PetDefs.feed_chance(lv) * 100.0)), _n(feed)]) if got else ""
	_pet_btn_enable(_pet_feed_ui["one"], got and not capped and feed >= cost)
	_pet_btn_enable(_pet_feed_ui["ten"],
		not _pet_feed_ui["one"]["btn"].disabled)
	_pet_feed_ui["note"].text = "먹이는 야수 우리(%d구간)가 준다" \
		% RaidDefs.open_stage("hunt")


func _refresh_pet_roll() -> void:
	for kind in _pet_roll_ui:
		var ui: Dictionary = _pet_roll_ui[kind]
		var have := int(tickets.get(kind, 0))
		var open := best_stage >= PetDefs.PET_OPEN
		ui["cnt"].text = ("%d장" % have) if open \
			else "%d구간에 열린다" % PetDefs.PET_OPEN
		# 값을 버튼에 적는다 — 안 적으면 "왜 눌리지"가 된다.
		#
		# **10연은 값이 섞인다.** _pet_pay 가 한 장씩 치르므로 권 9장이면 아홉
		# 번은 권, 열 번째는 보석 30 이다(무기 소환과 같다). 그런데 화면에는
		# 권이 하나라도 있으면 "10연"이라고만 떴다 — 보석이 얼마 나가는지 모른
		# 채 누르게 된다(사장님 2026-08-20).
		#
		# 잠금도 1회 기준이었다: 권 1장 + 보석 0 이면 10연이 열리는데 실제로는
		# 한 번 뽑고 나머지 아홉 번이 조용히 실패했다. **낼 수 있는 만큼만 연다.**
		var ten_tk := mini(have, 10)
		var ten_gem := GachaDefs.COST * float(10 - ten_tk)
		var by_gem := open and have < 1
		ui["one"]["lbl"].text = "1회" if not by_gem 			else "1회 · %d" % int(GachaDefs.COST)
		if ten_tk >= 10:
			ui["ten"]["lbl"].text = "10연"
		elif ten_tk > 0:
			ui["ten"]["lbl"].text = "10연 권%d+보석%d" % [ten_tk, int(ten_gem)]
		else:
			ui["ten"]["lbl"].text = "10연 · %d" % int(ten_gem)
		# 1회는 권이 있으면 권, 없으면 보석 — 무엇이 나가는지가 아이콘으로 읽힌다.
		ui["one_gem"].visible = open
		ui["one_gem"].texture = Assets.tex(
			"res://assets/ui/res_gem.png" if by_gem else TicketDefs.icon_of(kind))
		ui["ten_gem"].visible = open
		ui["ten_gem"].texture = Assets.tex(
			TicketDefs.icon_of(kind) if ten_tk > 0 else "res://assets/ui/res_gem.png")
		_pet_btn_enable(ui["one"], open and _pet_can_pay(kind))
		_pet_btn_enable(ui["ten"], open and gem >= ten_gem)
		var odd := open and have >= 2 and have <= 9
		ui["left"]["art"].visible = odd
		ui["left"]["lbl"].visible = odd
		ui["left"]["btn"].visible = odd
		ui["left_icon"].visible = odd
		if odd:
			ui["left"]["lbl"].text = "권 %d장 뽑기" % have
			ui["left_icon"].texture = Assets.tex(TicketDefs.icon_of(kind))
			_pet_btn_enable(ui["left"], true)
		# **아이콘을 글자 바로 왼쪽에 붙인다.** 고정 x 면 값이 길어질 때 글자를
		# 파고든다(사장님 캡처: "10연 권5+보석150"에 아이콘이 겹쳤다).
		for pair in [[ui["one"], ui["one_gem"], 220.0],
				[ui["ten"], ui["ten_gem"], 220.0],
				[ui["left"], ui["left_icon"], 220.0]]:
			var b: Dictionary = pair[0]
			var ic: TextureRect = pair[1]
			var bwid: float = pair[2]
			var lb: Label = b["lbl"]
			var fw := lb.get_theme_font("font").get_string_size(lb.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				lb.get_theme_font_size("font_size")).x
			ic.position.x = lb.position.x + (bwid - fw) * 0.5 - 28.0


# ── 펫 로직 (PetDefs) ──────────────────────────────────────────────────────
#
# 시간이 얼마나 지났든 **한 번에 계산한다** — 초당 더하면 껐다 켠 사이가 비고
# 상한도 프레임마다 재게 된다. 방치 보상(_grant_offline)과 같은 문법이다.

# 데리고 다니는 펫을 영웅 뒤에 따라 붙인다.
#
# **뒤쪽 위에 둔다.** 앞이나 발밑에 서면 전투를 가리고, 그러면 예쁘라고 넣은
# 것이 방해가 된다(VFX 원칙과 같은 자리). 위아래로 살짝 흔들어 떠 있는 티를
# 낸다 — walk 프레임을 돌리면 걷는 시늉이 되는데, 공중에 뜬 박쥐에는 안 맞는다.
const PET_LAG := 46.0        # 영웅에서 뒤로 물러난 거리
const PET_LIFT := 54.0       # 지면에서 띄우는 높이
const PET_BOB := 5.0         # 위아래 흔들림


func _pet_follow(delta: float) -> void:
	if _pet_sprite == null:
		return
	var frames := Assets.frames(PetDefs.icon_dir(pet_worn))
	if pet_worn == "" or frames.is_empty():
		_pet_sprite.visible = false
		return
	_pet_anim_t += delta
	_pet_sprite.visible = true
	_pet_sprite.texture = frames[int(_pet_anim_t * 6.0) % frames.size()]
	_pet_sprite.flip_h = true
	_pet_sprite.position = Vector2(hero_x - PET_LAG,
		ground_y - PET_LIFT + sin(_pet_anim_t * 2.4) * PET_BOB)

func _pet_tick() -> void:
	var now := Time.get_unix_time_from_system()
	if pet_at <= 0.0:
		pet_at = now
		return
	var hours := (now - pet_at) / 3600.0
	if hours <= 0.0:
		return
	pet_at = now
	# **가진 펫 전부가 모은다.** 장착은 버프를 고르는 것이지 일을 시키는 게
	# 아니다 — 하나만 모으면 나머지를 데려올 이유가 없어진다.
	for id in pets_got:
		# 원정 나간 펫은 둥지에서 못 긁는다 — 내보내는 값이 그 시간이다.
		if pet_trip.has(id):
			continue
		pet_bank[id] = PetDefs.accrue(str(id), float(pet_bank.get(id, 0.0)),
			hours, _pet_lv(str(id)), _pet_star(str(id)),
			_pet_gear_value(str(id), "gather"))


# 펫 뽑기. 유물과 같은 문법이다 — **중복은 조각이 되고 조각이 차면 한 단계**.
# 빈손으로 돌려보내지 않는 게 이 문법의 값이다.

# 천장 상자 — 뽑기 자체가 재화다. 가득 차면 **차던 판의 소환권**을 돌려주고
# 상자가 한 단계 커진다. 보상 창은 공개 연출이 닫힌 뒤에 띄운다(_mile_pending):
# 카드 위에 창을 얹으면 방금 뽑은 것이 가려진다.
func _mile_add(kind: String, count: int) -> void:
	mileage += count
	mile_fill += count
	while mile_fill >= GachaDefs.mile_cap(mile_lv):
		mile_fill -= GachaDefs.mile_cap(mile_lv)
		mile_lv += 1
		if kind in TicketDefs.KINDS or kind in TicketDefs.PET_KINDS:
			tickets[kind] = int(tickets.get(kind, 0)) + GachaDefs.MILE_TICKETS
			_mile_pending.append({"icon": TicketDefs.icon_of(kind),
				"label": "%s +%d" % [TicketDefs.name_of(kind),
				GachaDefs.MILE_TICKETS]})
		else:
			gem += GachaDefs.MILE_GEM
			_mile_pending.append({"icon": "res://assets/ui/res_gem.png",
				"label": "보석 +%d" % GachaDefs.MILE_GEM})
	_refresh_mile()


func _mile_pop() -> void:
	if _mile_pending.is_empty():
		return
	var rows := _mile_pending.duplicate()
	_mile_pending = []
	_show_reward("천장 상자 개봉", rows)
	_save_game()


# 천장 게이지 — 소환 카드 **안** 빈 띠(사장님이 잡은 자리)에 두 줄로 접는다:
# 위에 글줄, 아래에 상자 아이콘 + 트랙. 상자는 하나라 어느 판이든 값이 같다.
func _mile_strip(root: Control, at: Vector2, w: float) -> void:
	var lbl := _panel_label(root, at, Type.SIZE_SMALL,
		Color(0.86, 0.82, 0.80), w, 18.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_outline(lbl, 5)
	root.add_child(Ui.icon("res://assets/ui/mile_chest.png",
		Vector2(at.x, at.y + 18.0), 26.0))
	var track := ColorRect.new()
	track.color = Color(0.10, 0.09, 0.12)
	track.position = Vector2(at.x + 34.0, at.y + 26.0)
	track.size = Vector2(w - 34.0, 10.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	var fill := ColorRect.new()
	fill.color = Color(0.88, 0.66, 0.30)
	fill.position = track.position
	fill.size = Vector2(0.0, 10.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	_mile_ui.append({"fill": fill, "lbl": lbl, "w": track.size.x})
	_refresh_mile()


func _refresh_mile() -> void:
	var cap := GachaDefs.mile_cap(mile_lv)
	for m in _mile_ui:
		m["fill"].size.x = float(m["w"]) \
			* clampf(float(mile_fill) / float(cap), 0.0, 1.0)
		m["lbl"].text = "천장 상자 %d단계  ·  %d/%d" % [mile_lv + 1, mile_fill, cap]


# 소환권 우선, 없으면 보석 — 본편 소환(_pull_gacha)과 같은 문법·같은 시세다.
# 시세를 따로 두면 "펫 뽑기는 왜 더 비싸냐"가 생긴다.
func _pet_pay(kind: String) -> bool:
	var have := int(tickets.get(kind, 0))
	if have >= 1:
		tickets[kind] = have - 1
		_mile_add(kind, 1)
		return true
	if gem < GachaDefs.COST:
		return false
	gem -= GachaDefs.COST
	_mile_add(kind, 1)
	return true


func _pet_can_pay(kind: String) -> bool:
	return int(tickets.get(kind, 0)) >= 1 or gem >= GachaDefs.COST

func _pet_roll(show := true) -> Dictionary:
	if best_stage < PetDefs.PET_OPEN or not _pet_pay("pet"):
		return {}
	# 등급을 굴리고 그 안에서 하나 — 유물과 같은 문법(_receive_gacha_relic).
	var pool := PetDefs.of_rarity(PetDefs.roll_rarity())
	var d: Dictionary = pool[randi() % pool.size()]
	var id := str(d["id"])
	var star := _pet_star(id)
	var sub := ""
	if star <= 0:
		pets_got[id] = 1
		pet_lv[id] = 1
		pet_bank[id] = 0.0
		if pet_worn == "":
			pet_worn = id          # 첫 펫은 자동으로 데리고 다닌다
		sub = "새 동행"
	elif star < PetDefs.MAX_STAR:
		# 중복은 조각, 조각이 차면 승급 — 빈손으로 돌려보내지 않는다.
		var key := "pet:" + id
		var sh := int(gacha_shards.get(key, 0)) + 1
		if sh >= PetDefs.SHARDS_PER_STAR:
			pets_got[id] = star + 1
			sh -= PetDefs.SHARDS_PER_STAR
			sub = "%d성이 되었다" % (star + 1)
		else:
			sub = "조각 %d / %d" % [sh, PetDefs.SHARDS_PER_STAR]
		gacha_shards[key] = sh
	else:
		sub = "이미 끝까지 컸다"
	var row := {"pet": true, "id": id, "name": str(d["name"]),
		"rarity": str(d["rarity"]), "star": _pet_star(id), "sub": sub}
	if show:
		_show_pet_results([row])
		_refresh_currency_visibility()
		_save_game()
		_refresh_pet()
	return row


# 펫 장비 뽑기 — 펫과 같은 문법. UI 는 전면 판(2단계)에서 온다.
func _petgear_roll(show := true) -> Dictionary:
	if best_stage < PetDefs.PET_OPEN or not _pet_pay("petgear"):
		return {}
	var pool := PetDefs.gear_of_rarity(PetDefs.roll_rarity())
	var d: Dictionary = pool[randi() % pool.size()]
	var id := str(d["id"])
	var star := clampi(int(pet_gear_got.get(id, 0)), 0, PetDefs.MAX_STAR)
	var sub := ""
	if star <= 0:
		pet_gear_got[id] = 1
		sub = "새 장비"
	elif star < PetDefs.MAX_STAR:
		var key := "petgear:" + id
		var sh := int(gacha_shards.get(key, 0)) + 1
		if sh >= PetDefs.SHARDS_PER_STAR:
			pet_gear_got[id] = star + 1
			sh -= PetDefs.SHARDS_PER_STAR
			sub = "%d성이 되었다" % (star + 1)
		else:
			sub = "조각 %d / %d" % [sh, PetDefs.SHARDS_PER_STAR]
		gacha_shards[key] = sh
	else:
		sub = "이미 끝까지 컸다"
	var row := {"pet": false, "id": id, "name": str(d["name"]),
		"rarity": str(d["rarity"]),
		"star": clampi(int(pet_gear_got.get(id, 0)), 0, PetDefs.MAX_STAR),
		"sub": sub}
	if show:
		_show_pet_results([row])
		_save_game()
		_refresh_pet()
	return row


# 먹이 강화 — 레벨 하나. 상한은 승급(별)이 연다.
# 조각 하나를 넣고 결과 문구를 돌려준다. 별이 차면 승급까지 한다.
# 펫 소환·장비 소환·원정 셋이 같은 문법이라 한 곳에 둔다 — 세 벌로 두면
# 승급 규칙을 고칠 때 한 곳을 빠뜨린다.
func _shard_add(key: String) -> String:
	var id := key.split(":")[1]
	var box: Dictionary = pets_got if key.begins_with("pet:") else pet_gear_got
	var star := clampi(int(box.get(id, 0)), 0, PetDefs.MAX_STAR)
	if star >= PetDefs.MAX_STAR:
		return "이미 끝까지 컸다"
	var sh := int(gacha_shards.get(key, 0)) + 1
	if sh >= PetDefs.SHARDS_PER_STAR:
		box[id] = star + 1
		sh -= PetDefs.SHARDS_PER_STAR
		gacha_shards[key] = sh
		return "%d성이 되었다" % (star + 1)
	gacha_shards[key] = sh
	return "조각 %d / %d" % [sh, PetDefs.SHARDS_PER_STAR]


# 이 펫이 파 올 조각. 5성이 되면 **제 장비**를 판다 — 5성 뒤에도 내보낼 데가
# 있어야 다 키운 펫이 놀지 않는다. 못 보내면 빈 딕셔너리.
func _trip_prize(id: String) -> Dictionary:
	if not pets_got.has(id):
		return {}
	if _pet_star(id) < PetDefs.MAX_STAR:
		var p := PetDefs.of(id)
		return {"key": "pet:" + id, "name": str(p.get("name", id)),
			"rarity": str(p.get("rarity", "common"))}
	var gid := str(pet_gear_worn.get(id, ""))
	if gid != "" and int(pet_gear_got.get(gid, 0)) < PetDefs.MAX_STAR:
		var g := PetDefs.gear_of(gid)
		return {"key": "petgear:" + gid, "name": str(g.get("name", gid)),
			"rarity": str(g.get("rarity", "common"))}
	# **다 완성한 펫은 심부름을 간다**(2026-08-27). 제 별도 장비도 끝났으면
	# 예전엔 빈손을 돌려줘 원정을 아예 못 갔다 — 제일 공들인 펫이 그 순간
	# 짐이 됐다. 대신 **보유 중 미완성 펫 가운데 제일 희귀한 놈**의 조각을
	# 파 온다. 전설 로스터의 자물쇠(중복 확률 0.18%, 기대 9,434연)를 완성한
	# 펫이 깎아 주는 자리다.
	#
	# 규칙은 안 늘었다: 시간은 여전히 "나올 조각의 등급"이 정하고(전설 조각
	# 심부름 = 16시간), 새 재화도 새 UI 도 없다(보상 라벨이 대상 이름을 이미
	# 보여 준다). **미보유 펫 조각은 안 준다** — 그건 소환을 우회하는 것이다.
	# 로스터 25종이 전부 5성이면 그때는 정말 빈손이다 — 시스템이 완성된 것이다.
	return _trip_errand(id)


# 심부름 대상 — 보유 중 미완성(별 < 5) 펫 가운데 제일 희귀한 놈. 같은 등급이
# 여럿이면 표 순서(PETS)라 결과가 흔들리지 않는다. 자기 자신은 위에서 이미
# 5성으로 걸러졌으니 다시 안 나온다.
func _trip_errand(_id: String) -> Dictionary:
	var best := {}
	var best_r := -1
	for p in PetDefs.PETS:
		var pid := str(p["id"])
		if not pets_got.has(pid) or _pet_star(pid) >= PetDefs.MAX_STAR:
			continue
		var r := PetDefs.RARITY_KEYS.find(str(p.get("rarity", "common")))
		if r > best_r:
			best_r = r
			best = p
	if best.is_empty():
		return {}
	return {"key": "pet:" + str(best["id"]), "name": str(best.get("name", "")),
		"rarity": str(best.get("rarity", "common"))}


# 남은 초. 안 나가 있으면 -1.
func _trip_left(id: String) -> float:
	var row: Array = pet_trip.get(id, [])
	if row.size() < 2:
		return -1.0
	return maxf(0.0, float(row[0]) - Time.get_unix_time_from_system())


# 칸 표식용 — 96px 칸에 "15시간 59분"은 안 들어간다. 정확한 값은 상세가 맡는다.
func _trip_tag(sec: float) -> String:
	if sec <= 0.0:
		return "도착"
	return "%d시간" % int(ceil(sec / 3600.0)) if sec >= 3600.0 		else "%d분" % maxi(1, int(ceil(sec / 60.0)))


func _trip_text(sec: float) -> String:
	if sec <= 0.0:
		return "도착"
	if sec < 3600.0:
		return "%d분" % maxi(1, int(ceil(sec / 60.0)))
	return "%d시간 %d분" % [int(sec / 3600.0), int(fmod(sec, 3600.0) / 60.0)]


func _trip_send(id: String) -> void:
	var prize := _trip_prize(id)
	if prize.is_empty() or pet_trip.has(id) or best_stage < PetDefs.TRIP_OPEN 			or pet_trip.size() >= PetDefs.trip_slots(pets_got.size()):
		return
	pet_trip[id] = [Time.get_unix_time_from_system()
		+ PetDefs.trip_hours(str(prize["rarity"])) * 3600.0, str(prize["key"])]
	_save_game()
	_refresh_pet()


func _trip_claim(id: String) -> void:
	var row: Array = pet_trip.get(id, [])
	if row.size() < 2 or _trip_left(id) > 0.0:
		return
	pet_trip.erase(id)
	var key := str(row[1])
	var sub := _shard_add(key)
	var gid := key.split(":")[1]
	var d: Dictionary = PetDefs.of(gid) if key.begins_with("pet:") \
		else PetDefs.gear_of(gid)
	_show_reward("원정에서 돌아왔다",
		[{"icon": "res://assets/ui/quest_summon.png",
		"label": "%s 조각 +1" % str(d.get("name", gid)), "sub": sub}])
	_save_game()
	_refresh_pet()


func _pet_feed(id: String) -> bool:
	var star := _pet_star(id)
	if star <= 0:
		return false
	var lv := _pet_lv(id)
	if lv >= PetDefs.lv_cap(star):
		return false
	var cost := PetDefs.feed_cost(lv)
	if feed < cost:
		return false
	feed -= cost
	# **확률**(사장님) — 실패해도 먹이는 소모된다. 반환은 "시도했는가"다:
	# x10 루프가 실패마다 멈추면 열 번 시도가 아니라 첫 실패까지가 된다.
	if randf() > PetDefs.feed_chance(lv):
		_pet_feed_fail_fx()
	else:
		pet_lv[id] = lv + 1
		_pet_feed_fx(lv + 1)
	_save_game()
	_refresh_pet()
	return true


# 장비를 펫에게. **한 장비는 한 펫만** 든다 — 같은 장비가 두 펫에 걸리면
# 증폭이 복제된다.
func _pet_equip_gear(pet_id: String, gear_id: String) -> void:
	if _pet_star(pet_id) <= 0 or int(pet_gear_got.get(gear_id, 0)) <= 0:
		return
	# 벗기기 판정은 회수 루프 **앞**에서 잰다 — 루프가 이 펫 것까지 걷어 가서
	# "다시 누르면 벗는다"가 늘 장착으로 굴렀다(사장님: 벗기기가 안 된다).
	var strip := str(pet_gear_worn.get(pet_id, "")) == gear_id
	for k in pet_gear_worn.keys():
		if str(pet_gear_worn[k]) == gear_id:
			pet_gear_worn.erase(k)
	if not strip:
		pet_gear_worn[pet_id] = gear_id
	_save_game()
	_refresh_pet()


# 모두 받기 — 통화별로 합쳐 한 창에 보여 준다. 스물다섯 창이 뜨면 안 된다.
func _pet_collect_all() -> void:
	_pet_tick()
	var got := {}
	for id in pets_got:
		var amt := float(pet_bank.get(id, 0.0))
		if amt < 1.0:
			continue
		var g := str(PetDefs.of(str(id))["gain"])
		got[g] = float(got.get(g, 0.0)) + amt
		pet_bank[id] = 0.0
	if got.is_empty():
		return
	_quest_bump("pet")
	var rows: Array = []
	for g in got:
		_grant_reward(str(g), float(got[g]))
		rows.append({"icon": "res://assets/ui/%s.png" % _reward_icon(str(g)),
			"label": "%s +%s" % [_reward_name(str(g)), _n(float(got[g]))]})
	_show_reward("둥지 정산", rows)
	_refresh_currency_visibility()
	_save_game()
	_refresh_pet()


func _pet_collect(id: String) -> void:
	_pet_tick()
	var amount := float(pet_bank.get(id, 0.0))
	if amount < 1.0:
		return
	_quest_bump("pet")
	var d := PetDefs.of(id)
	pet_bank[id] = 0.0
	_grant_reward(str(d["gain"]), amount)
	_show_reward(str(d["name"]),
		[{"icon": "res://assets/ui/%s.png" % _reward_icon(str(d["gain"])),
		"label": "%s +%s" % [_reward_name(str(d["gain"])), _n(amount)]}])
	_refresh_currency_visibility()
	_save_game()
	_refresh_pet()


# 데리고 다니는 펫이 그 능력치에 주는 몫. 배율 훅마다 한 줄로 붙는다.
func _pet_mult(stat: String) -> float:
	return PetDefs.bonus(pet_worn, stat, _pet_lv(pet_worn),
		_pet_star(pet_worn), _pet_gear_value(pet_worn, "amp"))


func _pet_star(id: String) -> int:
	return clampi(int(pets_got.get(id, 0)), 0, PetDefs.MAX_STAR)


func _pet_lv(id: String) -> int:
	return clampi(int(pet_lv.get(id, 1)), 1, PetDefs.lv_cap(maxi(1, _pet_star(id))))


# 그 펫이 든 장비의 갈래별 값. gather 는 수집에, amp 는 버프에 곱해진다.
func _pet_gear_value(pet_id: String, kind: String) -> float:
	var gid := str(pet_gear_worn.get(pet_id, ""))
	var g := PetDefs.gear_of(gid)
	if g.is_empty() or str(g["kind"]) != kind:
		return 0.0
	var star := clampi(int(pet_gear_got.get(gid, 0)), 1, PetDefs.MAX_STAR)
	return float(g["value"]) * PetDefs.star_mult(star)


# 10연 — 결과를 **한 창에 모아** 보여 준다. 한 번마다 창을 열면 열 번 닫아야 한다.
func _pet_roll_many(n: int) -> void:
	var rows: Array = []
	for i in n:
		var r := _pet_roll(false)
		if r.is_empty():
			break
		rows.append(r)
	if rows.is_empty():
		return
	_show_pet_results(rows)
	_refresh_currency_visibility()
	_save_game()
	_refresh_pet()


func _petgear_roll_many(n: int) -> void:
	var rows: Array = []
	for i in n:
		var r := _petgear_roll(false)
		if r.is_empty():
			break
		rows.append(r)
	if rows.is_empty():
		return
	_show_pet_results(rows)
	_save_game()
	_refresh_pet()


# ── 펫 소환 공개 연출 (5단계, "실감나게") ──────────────────────────────────
#
# 소환 탭의 _show_gacha_results 문법을 그대로 따른다: 어둠막 + 카드 + 등급 글로
# + 순서대로 튀어나오는 트윈. 다른 점 하나 — 펫은 그림이 애니 첫 프레임이고,
# 새 펫 / 조각 / 승급이 부제로 갈린다.
var _pet_reveal: Control


func _show_pet_results(rows: Array) -> void:
	if _pet_reveal == null or not is_inside_tree():
		return
	for child in _pet_reveal.get_children():
		child.queue_free()
	_pet_reveal.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.025, 0.94)
	shade.size = Vector2(PANEL_W, PANEL_FULL_H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_pet_reveal.add_child(shade)
	var title := _panel_label(_pet_reveal, Vector2(PAD, 20.0), Type.SIZE_MID,
		Color(0.96, 0.84, 0.58), CONTENT_W, 28.0)
	title.text = "소환 결과" if rows.size() > 1 else "새 동행" \
		if int(rows[0].get("star", 0)) <= 1 else "다시 만났다"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 30·50연은 카드가 판을 넘는다 — 여럿이면 스크롤 통에 담는다(장비와 같은 문법).
	var grid3: Control = null
	if rows.size() > 1:
		var scroll3 := ScrollContainer.new()
		scroll3.position = Vector2(0.0, 56.0)
		scroll3.size = Vector2(PANEL_W, 550.0)
		scroll3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_pet_reveal.add_child(scroll3)
		grid3 = Control.new()
		grid3.custom_minimum_size = Vector2(PANEL_W - 16.0,
			float((rows.size() + 4) / 5) * 150.0 + 8.0)
		scroll3.add_child(grid3)
	var cards: Array[Control] = []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var one := rows.size() == 1
		var card := Control.new()
		card.position = Vector2(232.0, 120.0) if one else \
			Vector2(48.0 + float(i % 5) * 100.0, 8.0 + float(i / 5) * 150.0)
		card.size = Vector2(112.0, 160.0) if one else Vector2(80.0, 120.0)
		if one:
			_pet_reveal.add_child(card)
		else:
			grid3.add_child(card)
		var rar := GachaDefs.rarity(str(row["rarity"]))
		var icon_path: String = ("res://assets/anim/pet_%s_idle/0.png" \
			if bool(row["pet"]) else "res://assets/items/petw_%s.png") \
			% str(row["id"])
		var box := 56.0 if one else 48.0
		var art_at := Vector2(28.0, 30.0) if one else Vector2(16.0, 18.0)
		var glow := ColorRect.new()
		glow.position = art_at
		glow.size = Vector2(box, box)
		glow.color = Color(rar["col"], 0.30)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(glow)
		card.add_child(Ui.image("res://assets/ui/gear_card.png" if one \
			else "res://assets/ui/gear_card_small.png", Vector2.ZERO,
			Vector2(112.0, 128.0) if one else Vector2(80.0, 96.0)))
		card.add_child(Ui.icon(icon_path, art_at, box))
		_add_summon_rarity_fx(card, rar,
			"res://assets/ui/gear_card.png" if one \
			else "res://assets/ui/gear_card_small.png", Vector2.ZERO,
			Vector2(112.0, 128.0) if one else Vector2(80.0, 96.0))
		var nm := _panel_label(card, Vector2(-14.0 if one else -10.0,
			132.0 if one else 96.0), Type.SIZE_SMALL, Color(rar["col"]),
			140.0 if one else 100.0, 18.0)
		nm.text = "%s %d성" % [str(row["name"]), int(row["star"])]
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb := _panel_label(card, Vector2(-14.0 if one else -10.0,
			152.0 if one else 114.0), Type.SIZE_SMALL,
			Color(0.72, 0.70, 0.74), 140.0 if one else 100.0, 16.0)
		sb.text = str(row["sub"])
		sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards.append(card)
	# 보유 줄 + 이어 뽑기 — 장비 소환 결과 창과 같은 문법(사장님 2026-08-25).
	var pkind := "pet" if bool(rows[0].get("pet", true)) else "petgear"
	var have3 := int(tickets.get(pkind, 0))
	var px3 := (PANEL_W - 320.0) * 0.5
	_pet_reveal.add_child(Ui.set_pill(NEST, Vector2(px3, 612.0),
		Vector2(150.0, 30.0)))
	_pet_reveal.add_child(Ui.icon(TicketDefs.icon_of(pkind),
		Vector2(px3 + 14.0, 617.0), 20.0))
	var tl3 := _panel_label(_pet_reveal, Vector2(px3 + 40.0, 613.0),
		Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), 100.0, 28.0)
	tl3.text = str(have3)
	_pet_reveal.add_child(Ui.set_pill(NEST, Vector2(px3 + 158.0, 612.0),
		Vector2(162.0, 30.0)))
	_pet_reveal.add_child(Ui.icon("res://assets/ui/res_gem.png",
		Vector2(px3 + 172.0, 617.0), 20.0))
	var gl3 := _panel_label(_pet_reveal, Vector2(px3 + 198.0, 613.0),
		Type.SIZE_SMALL, Color(0.92, 0.86, 0.86), 112.0, 28.0)
	gl3.text = _n(gem)
	# 30·50연은 **낼 수 있을 때만** 버튼이 보인다. 권이 2~9장이면 털기도 낀다.
	var opts3: Array = []
	for cnt5 in [1, 10, 30, 50]:
		var tk5: int = mini(have3, cnt5)
		var gm5 := GachaDefs.COST * float(cnt5 - tk5)
		if cnt5 >= 30 and gem < gm5:
			continue
		opts3.append({"label": ("%d연" % cnt5) if cnt5 > 1 else "1회",
			"count": cnt5, "tk": tk5, "gm": int(gm5), "off": gem < gm5})
		if cnt5 == 10 and have3 >= 2 and have3 <= 9:
			opts3.append({"label": "권 %d장" % have3, "count": have3,
				"tk": have3, "gm": 0, "off": false})
	var bw3 := minf(126.0, (516.0 - float(opts3.size() - 1) * 9.0) / float(opts3.size()))
	var bx03 := (PANEL_W - (bw3 * float(opts3.size())
		+ 9.0 * float(opts3.size() - 1))) * 0.5
	for i5 in opts3.size():
		var o5: Dictionary = opts3[i5]
		var bx5 := bx03 + float(i5) * (bw3 + 9.0)
		var pb5 := Ui.button("", Vector2(bx5, 646.0), Vector2(bw3, 54.0),
			Type.SIZE_SMALL)
		pb5.disabled = bool(o5["off"])
		var cnt6: int = int(o5["count"])
		if pkind == "pet":
			pb5.pressed.connect(func() -> void: _pet_roll_many(cnt6))
		else:
			pb5.pressed.connect(func() -> void: _petgear_roll_many(cnt6))
		_pet_reveal.add_child(pb5)
		var nm5 := _panel_label(_pet_reveal, Vector2(bx5, 652.0),
			Type.SIZE_SMALL, Color(1.0, 0.96, 0.90), bw3, 18.0)
		nm5.text = str(o5["label"])
		nm5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row5 := HBoxContainer.new()
		row5.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row5.position = Vector2(bx5 + bw3 * 0.5 - 67.0, 674.0)
		row5.size = Vector2(134.0, 20.0)
		row5.alignment = BoxContainer.ALIGNMENT_CENTER
		row5.add_theme_constant_override("separation", 2)
		_pet_reveal.add_child(row5)
		if int(o5["tk"]) > 0:
			_price_bit(row5, TicketDefs.icon_of(pkind), str(o5["tk"]))
		if int(o5["gm"]) > 0:
			if int(o5["tk"]) > 0:
				_price_bit(row5, "", "+")
			_price_bit(row5, "res://assets/ui/res_gem.png", str(o5["gm"]))
	# [보관함으로]가 확인 옆에 선다(사장님) — 뽑은 걸 바로 보러 가는 지름길.
	# 펫 뽑기면 보유 탭, 장비 뽑기면 장비 탭이다.
	var dest := "own" if bool(rows[0].get("pet", true)) else "gear"
	var store := Ui.button("보관함으로", Vector2(PAD + CONTENT_W * 0.5 - 206.0,
		FULL_BOTTOM - 60.0), Vector2(200.0, 50.0), Type.SIZE_SMALL)
	store.pressed.connect(func() -> void:
		_pet_reveal.visible = false
		_mile_pop()
		_pet_set_mode(dest))
	_pet_reveal.add_child(store)
	var ok := Ui.button("확인", Vector2(PAD + CONTENT_W * 0.5 + 6.0,
		FULL_BOTTOM - 60.0), Vector2(200.0, 50.0), Type.SIZE_SMALL)
	ok.pressed.connect(func() -> void:
		_pet_reveal.visible = false
		_mile_pop())
	_pet_reveal.add_child(ok)
	# 순서대로 튀어나온다 — 열 장이 한꺼번에 뜨면 열 장이 아니라 한 장으로 읽힌다.
	var tween := create_tween()
	for card in cards:
		card.modulate.a = 0.0
		card.scale = Vector2(0.6, 0.6)
		card.pivot_offset = card.size * 0.5
		tween.tween_property(card, "modulate:a", 1.0, 0.07)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 강화 실패 — 몸을 떨고 잿빛으로 식으며 "실패"가 떠오른다. 성공과 실패가
# 같은 화면이면 어느 쪽이었는지 숫자를 읽어야 안다.
func _pet_feed_fail_fx() -> void:
	if _pet_feed_ui.is_empty() or not is_inside_tree():
		return
	var art: TextureRect = _pet_feed_ui["art"]
	art.pivot_offset = art.size * 0.5
	art.modulate = Color(0.55, 0.45, 0.5)
	var base_x := art.position.x
	var tw := create_tween()
	for off in [6.0, -6.0, 4.0, -4.0, 0.0]:
		tw.tween_property(art, "position:x", base_x + off, 0.05)
	tw.parallel().tween_property(art, "modulate", Color(1, 1, 1), 0.4)
	var pop := _panel_label(_pet_roots["feed"],
		Vector2(PAD, PET_GRID_Y + 96.0), Type.SIZE_MID,
		Color(0.72, 0.62, 0.66), CONTENT_W, 24.0)
	pop.text = "실패"
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(pop, "position:y", pop.position.y - 22.0, 0.5)
	tw2.tween_property(pop, "modulate:a", 0.0, 0.5).set_delay(0.1)
	tw2.chain().tween_callback(pop.queue_free)


# 강화 성공 — 펫이 튀어 오르고 금빛으로 번쩍이며 "+N레벨" 이 떠오른다.
# 숫자만 바뀌면 강화가 "된 건가?" 로 읽힌다(사장님: 실감나게).
func _pet_feed_fx(new_lv: int) -> void:
	if _pet_feed_ui.is_empty() or not is_inside_tree():
		return
	var art: TextureRect = _pet_feed_ui["art"]
	if art == null or not art.visible:
		return
	art.pivot_offset = art.size * 0.5
	art.modulate = Color(1.6, 1.35, 0.7)
	art.scale = Vector2(1.25, 1.25)
	var tw := create_tween().set_parallel()
	tw.tween_property(art, "modulate", Color(1, 1, 1), 0.35)
	tw.tween_property(art, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pop := _panel_label(_pet_roots["feed"],
		Vector2(PAD, PET_GRID_Y + 96.0), Type.SIZE_MID,
		Color(0.98, 0.86, 0.46), CONTENT_W, 24.0)
	pop.text = "+%d레벨" % new_lv
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(pop, "position:y", pop.position.y - 28.0, 0.6)
	tw2.tween_property(pop, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw2.chain().tween_callback(pop.queue_free)
