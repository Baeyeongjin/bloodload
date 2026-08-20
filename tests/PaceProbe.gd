extends SceneTree

# **며칠에 몇 구간인가.** 사장님 기준(2026-08-13): 참고작을 2주 하니 105층,
# 과금은 광고 제거 + 멤버십뿐. 우리도 그 속도를 따라가야 한다.
#
# 지금 있던 자(CurveSweep·BalanceTest)는 **구간만 재고 시간을 안 잰다** — "벽이
# 어디 서나"는 알아도 "그 벽에 며칠에 닿나"는 몰랐다. 그래서 사장님 기준을
# 검증할 수가 없었다. 이 프로브가 그 축을 잰다.
#
# 하루 모델 (참고작 플레이 습관에 맞춘 값):
#   접속 60분 — 그동안 실시간으로 구간을 민다
#   방치 8시간 — 상한만큼 자동 전진 + 혈액
#   일일 배급 — 임무 보석·혈정, 재화 던전 3종 x3판
# 번 재화는 그 자리에서 전투력이 가장 많이 오르는 곳에 쓴다(CurveSweep 과 같은
# 정책). 미궁·혈맥까지 넣는다 — 그게 빠지면 훈련 상한 60 에 묶여 7일차부터 한
# 칸도 못 간다(실측).
#
# 2026-08-18 재측정 — 그동안 안 재던 축을 다 넣었다(사장님 지시):
#   시련(격파 = 영구 공·체 %, 미궁이 잠금) · 펫(펫권 뽑기·먹이 강화·수집·동행
#   버프) · 출석(30일 표) · 은총(6주 로테이션 중 표/시간을 주는 것) · 천장
#   상자(뽑을수록 소환권 환류). 은총의 gold·sweep 은 **엔진의 실시간 주차**가
#   gold_mult()/소탕에 이미 붙어 있어서(같은 실행 안에서는 상수) 모델에 다시
#   더하지 않는다 — ticket·hours·raid 만 모의 주차 로테이션으로 넣는다.
#
#     godot --headless --script tests/PaceProbe.gd
#     godot --headless --script tests/PaceProbe.gd -- --days=30

const PLAY_MINUTES := 60.0
const IDLE_HOURS := 8.0
# 멤버십(설계서 5-3 "혈세") — 사장님이 실제로 산 두 가지 중 하나. 방치 +4시간,
# 재화 던전 +1판. 광고 제거는 진행 속도와 무관이라 안 센다.
const MEMBER_IDLE_BONUS := 4.0
const MEMBER_RAID_BONUS := 1


# 곡선 후보 스윕 — [적 배수, 보상 배수].
#
# **목표 페이스** (사장님 2026-08-13): 처음엔 금방 오르고 점점 느려진다.
#     1달 150 · 2달 250 · 3달 300
# 달마다 +150 -> +100 -> +50 으로 증분이 반씩 줄어드는 감속 곡선이다. 참고작을
# 2주 하고 105층이었다는 실측이 출발점이고, 사장님이 거기서 이 페이스를 잡았다.
# 500 완주는 이 기울기의 꼬리라 반년 너머에 놓인다 — 끝을 못 보는 게 아니라
# **끝이 목표가 아닌 구간**이 뒤에 길게 남는 게 방치형의 모양이다.
# [적 배수, 보상 배수, 적 선형항, 비용지수 배수]. 넷째가 스탯 비용 손잡이다 —
# **요구는 지수인데 스탯 성장은 선형**이라(합연산), 비용만 낮추면 초반이 폭주하고
# (14일 완주) 높이면 후반이 막힌다. 둘을 같이 흔들어야 자리가 맞는다.
# 원래 선형항을 같이 흔든다 — 그게 **초반을 눌러
# 전체를 아래로 당기는** 손잡이라, 지수만 만지면 모양(감속의 기울기)이 안 맞는다.
# 후보 (2026-08-14 재측정): 지금 값(1.45/0.90)이 **14일에 150** 을 찍는다 —
# 1달 목표를 2주에 당겼고 90일은 280 으로 목표(300)에 못 미쳤다. 초반을 눌러
# 뒤로 미뤄야 한다.
#
# **POWER_CURVE 가 그 손잡이다.** p^c 에서 c 를 낮추면 p<1(초반)에서는 값이
# 커지고 p>1(후반)에서는 작아진다 — 초반 요구를 올리고 후반 요구를 내린다.
# 정확히 "처음 빠르고 점점 감속"의 반대편을 눌러 곡선을 목표에 맞춘다.
const SWEEP := [
	[1.42, 1.40, 0.0, 1.00],   # 90일 정확 · 30일 +50
	[1.42, 1.40, 0.0, 1.02],
	[1.42, 1.42, 0.0, 1.02],   # 돈을 올려 후반 보강
	[1.42, 1.42, 0.0, 1.04],
	[1.42, 1.44, 0.0, 1.05],
]


func _init() -> void:
	var days := 14
	var sweep := false
	var compare := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = maxi(1, int(arg.trim_prefix("--days=")))
		if arg == "--sweep":
			sweep = true
		if arg == "--prestige":
			compare = true
	if sweep:
		_sweep(days)
		return
	if compare:
		_compare(days)
		return
	print("")
	print("하루 모델: 접속 %d분 + 방치 %d시간 + 일일 배급"
		% [int(PLAY_MINUTES), int(IDLE_HOURS)])
	print("%-10s %-12s %-12s %-14s %s"
		% ["", "무과금", "멤버십", "차이", "비고"])
	print("-".repeat(64))
	var free := _run(days, false)
	var paid := _run(days, true)
	# **통산 최고(peak)로 찍는다** — 회귀가 그날 구간을 1로 되돌리므로 log 로는
	# "며칠에 어디까지 갔나"를 못 읽는다(30일차가 60일차보다 큰 표가 나왔다).
	for i in _marks(days):
		var f: int = free["peak"][i - 1]
		var p: int = paid["peak"][i - 1]
		print("%-10s %-12d %-12d %-14s %s"
			% ["%d일차" % i, f, p, "+%d" % (p - f),
			"<- 목표 150" if i == 30 else ("<- 목표 250" if i == 60 			else ("<- 목표 300" if i == 90 else ""))])
	print("")
	print("무과금 진단 — 무엇이 병목인가")
	print("%-8s %-8s %-8s %-10s %-10s %-6s %-8s %-10s %s"
		% ["일차", "구간", "미궁층", "훈련상한", "공격렙", "시련", "혈흔", "남은혈액", "전투력"])
	for i in _marks(days):
		var d: Dictionary = free["diag"][i - 1]
		print("%-8d %-8d %-8d %-10d %-10d %-6d %-8d %-10s %s"
			% [i, int(d["stage"]), int(d["floor"]), int(d["cap"]), int(d["lv"]),
			int(d.get("trial", 0)), int(d["marks"]), _n(float(d["gold"])),
			_n(float(d["power"]))])
	print("")
	print("전투력 — %d일차 무과금 %s · 멤버십 %s"
		% [days, _n(float(free["power"])), _n(float(paid["power"]))])
	# **어느 축이 성장을 끌고 있나.** 곡선이 안 맞을 때 곡선부터 만지면 안 된다 —
	# 성장 쪽이 과하면 곡선을 아무리 세워도 모양만 바뀌고 자리가 안 맞는다.
	print("")
	print("축별 기여 (%d일차 무과금, 공격력 기준 배수)" % days)
	var a: Dictionary = free["axes"]
	for k in ["스탯", "장비", "도감", "혈맹", "혈맥", "유물", "칭호", "회귀",
			"시련", "펫"]:
		print("  %-8s x%.2f" % [k, float(a.get(k, 1.0))])
	print("PaceProbe OK")
	quit()


# **회귀를 얼마나 자주 누르는 게 이득인가.** 이걸 재는 이유: 200일 실측에서
# 배율이 21배까지 갔는데 110일에 19구간뿐이었다. 회귀가 주는 것(공격 배율)과
# 뺏는 것(스탯·혈액, 그리고 되돌아오는 날들)이 비긴다는 뜻이다.
#
# **누를수록 손해라면 그건 설계 결함이다** — 유저가 "안 누르는 게 최선"인
# 버튼을 화면에 두면 안 된다. 안 누름을 견줄 기준으로 같이 찍는다.
# 회귀 뒤 구간이 1 로 떨어지므로 그날 자리(log)가 아니라 **통산 최고**(peak)를
# 본다 — 질문이 "며칠에 어디까지 갔나"이기 때문이다.
func _compare(days: int) -> void:
	print("")
	print("회귀 정책 — 정체 며칠 만에 누르나 · 통산 최고 구간 (+ = 멤버십)")
	var head := "%-12s" % "정책"
	for d in _marks(days):
		head += "%-7s" % ("%d일" % d)
	head += "  혈흔"
	print(head)
	print("-".repeat(head.length()))
	# **멤버십도 같이 찍는다** — 90일 표에서 멤버십(256)이 무과금(270)보다 낮게
	# 나왔다(사장님 보고). 자원이 많은 쪽이 벽에 빨리 닿아 회귀를 더 자주 누르고
	# 그 되돌림이 후반을 깎는다는 가설이라, 정책별로 갈라 보지 않으면 안 보인다.
	for member in [false, true]:
		for after in [0, 1, 3, 7]:
			var r := _run(days, member, after)
			var label := "안 누름" if after == 0 else "정체 %d일" % after
			var line := "%-12s" % (label + ("+" if member else ""))
			for d in _marks(days):
				line += "%-7d" % int(r["peak"][d - 1])
			line += "  %d" % int(r["diag"][days - 1]["marks"])
			print(line)
	# **혈흔 하나의 값어치.** 문턱을 두니 총 혈흔이 10개로 줄어(반복 수령이 유일한
	# 성장 경로였다) 배율이 x1.6 뿐이다. MARK_POWER 가 그 세기를 되찾는 손잡이다 —
	# MARK_STEP 과 곱으로만 작용하므로 손잡이는 이것 하나면 된다.
	var keep_m: float = PrestigeDefs.MARK_POWER
	_knob(days, "혈흔 하나의 값어치 (MARK_POWER)", [0.06, 0.2, 0.4, 0.6, 1.0],
		func(v: float) -> void: PrestigeDefs.MARK_POWER = v)
	PrestigeDefs.MARK_POWER = keep_m
	# **스탯 비용 지수.** 200일 진단에서 혈액이 1.25조 남은 채 250구간에 고착했다 —
	# 상한(682)도 재화도 아니고 **다음 레벨 가격**이 벽이다. 회귀 배율을 13배로
	# 키워도 안 뚫렸던 이유가 여기 있다(배율은 공격력에만 붙어 가격표를 못 건드린다).
	var keep_c: float = StatDefs.COST_EXP_SCALE
	_knob(days, "스탯 비용 지수 (COST_EXP_SCALE)", [1.0, 0.8, 0.6, 0.35],
		func(v: float) -> void: StatDefs.COST_EXP_SCALE = v)
	StatDefs.COST_EXP_SCALE = keep_c
	print("PaceProbe OK")
	quit()


# 손잡이 하나를 훑어 나란히 찍는다. 회귀 세기와 스탯 비용이 같은 모양의
# 질문("이 값을 흔들면 며칠에 어디까지 가나")이라 표를 공유한다.
func _knob(days: int, title: String, values: Array, apply: Callable) -> void:
	print("")
	print(title + " — 정체 3일 정책 · 통산 최고 구간")
	var head := "%-12s" % "값"
	for d in _marks(days):
		head += "%-7s" % ("%d일" % d)
	print(head)
	print("-".repeat(head.length()))
	for v in values:
		apply.call(float(v))
		var r := _run(days, false, 3)
		var line := "%-12s" % ("%.2f" % float(v))
		for d in _marks(days):
			line += "%-7d" % int(r["peak"][d - 1])
		print(line)


# 찍어 볼 일차. 200일을 재면 14·30 만 보고는 어디서 멈췄는지 못 찾는다.
static func _marks(days: int) -> Array[int]:
	var out: Array[int] = []
	for d in [1, 3, 7, 14, 30, 60, 90, 120, 150, 200]:
		if d < days:
			out.append(d)
	out.append(days)
	return out


# 후보마다 7·14·30·60일차를 나란히. 고르는 자리는 **14일 멤버십**이다.
func _sweep(days: int) -> void:
	var keep_p: float = StageDefs.POWER_STEP
	var keep_g: float = StageDefs.GOLD_STEP
	var keep_l: float = StageDefs.POWER_LINEAR
	var keep_c: float = StageDefs.POWER_CURVE
	print("")
	print("목표(멤버십): 1달 150 · 2달 250 · 3달 300 — 처음 빠르고 점점 감속")
	print("%-18s %-11s %-11s %-11s %s"
		% ["곡선", "14일", "30일", "60일", "90일  (무과금 / 멤버십)"])
	print("-".repeat(76))
	for c in SWEEP:
		StageDefs.POWER_STEP = float(c[0])
		StageDefs.GOLD_STEP = float(c[1])
		StageDefs.POWER_LINEAR = float(c[2])
		StageDefs.POWER_CURVE = float(c[3])
		var f := _run(days, false)
		var m := _run(days, true)
		var cells := PackedStringArray()
		for d in [14, 30, 60, 90]:
			if d > days:
				cells.append("-")
				continue
			cells.append("%d/%d" % [int(f["peak"][d - 1]), int(m["peak"][d - 1])])
		print("%-18s %-10s %-10s %-10s %s"
			% ["x%.2f 돈%.2f 곡%.2f" % [float(c[0]), float(c[1]), float(c[3])],
			cells[0], cells[1], cells[2], cells[3]])
	StageDefs.POWER_STEP = keep_p
	StageDefs.GOLD_STEP = keep_g
	StageDefs.POWER_LINEAR = keep_l
	StageDefs.POWER_CURVE = keep_c
	print("")
	print("목표 로그식  s(t) = 144·ln(t) - 341   (500 도달 ~340일)")
	print("PaceProbe OK")
	quit()


# 모의 은총 — 시뮬레이션 일차로 주차를 센다(엔진 주차는 실시간이라 못 쓴다).
static func _boon_of(day: int) -> Dictionary:
	return BoonDefs.BOONS[(day / 7) % BoonDefs.BOONS.size()]


# prestige_after — 며칠 정체하면 회귀하나. 0 이면 안 누른다(견줄 기준).
func _run(days: int, member: bool, prestige_after: int = 1) -> Dictionary:
	# **씨앗을 심는다.** 소환이 난수라 안 심으면 실행마다 답이 달라진다 —
	# 실측: 같은 설정에서 200일 도달이 250 과 280 으로 갈렸다. 후보를 견주는
	# 자리에서 그 흔들림은 곧 잘못된 결론이다(주석만 있고 구현이 없었다).
	seed(20260814)
	var game = load("res://Main.gd").new()
	game.save_muted = true   # 모의에서 판마다 디스크를 두드리지 않는다
	var gold := 0.0
	var log: Array[int] = []
	var peak: Array[int] = []
	var diag: Array[Dictionary] = []
	for day in days:
		var boon := _boon_of(day)
		# 1) 방치 — 상한만큼 잔다. 실제로는 오프라인 절반 효율이 붙는다.
		var idle := IDLE_HOURS + (MEMBER_IDLE_BONUS if member else 0.0) \
			+ (float(boon["value"]) if str(boon["kind"]) == "hours" else 0.0)
		gold += _farm(game, idle * 3600.0, 0.5)
		# 2) 접속 — 그동안 계속 민다. 미는 도중에도 버는 게 실제 흐름이라
		#    구간을 넘길 때마다 그 구간의 몫이 들어온다.
		gold += _farm(game, PLAY_MINUTES * 60.0, 1.0)
		# 3) 일일 배급 — 재화 던전(혈액)만 센다. 보석은 소환으로 가고
		#    소환은 이 모델에 없다(위 주석).
		var raids := RaidDefs.TRIES_PER_DAY + (MEMBER_RAID_BONUS if member else 0)
		var raid_mult := 2.0 if str(boon["kind"]) == "raid" else 1.0
		if game.best_stage >= RaidDefs.OPEN_STAGE:
			for i in raids:
				gold += RaidDefs.reward("blood",
					maxi(1, game.raid_best.get("blood", 0))) * raid_mult
			game.raid_best["blood"] = int(game.raid_best.get("blood", 0)) + 1
		# 4) 미궁 — 갈 수 있는 층까지 민다. **이게 빠지면 훈련 상한 60 에 묶여
		#    7일차부터 한 칸도 못 간다**(실측). 미궁은 승급(상한)과 혈정의 문이다.
		_climb(game)
		# 4.5) 시련 — 미궁이 연 단계를 그 자리에서 민다. 격파 = 영구 공·체 %.
		_trial_up(game)
		# 5) 혈정으로 혈맥 — 곱연산이라 후반의 주력이다.
		_buy_traits(game)
		# 6) 정수의 성소·계약의 제단 — 장비 강화와 혈맹의 배급.
		if game.best_stage >= RaidDefs.open_stage("essence"):
			for i in raids:
				game.essence += RaidDefs.reward("essence",
					maxi(1, game.raid_best.get("essence", 0))) * raid_mult
			game.raid_best["essence"] = int(game.raid_best.get("essence", 0)) + 1
		if game.best_stage >= RaidDefs.open_stage("pact"):
			for i in raids:
				game.sigil += RaidDefs.reward("pact",
					maxi(1, game.raid_best.get("pact", 0))) * raid_mult
			game.raid_best["pact"] = int(game.raid_best.get("pact", 0)) + 1
		# 6.5) 출석 — 30일 표. 소환권은 지갑에 꽂혀 아래 소환이 그날 쓴다.
		_attend_day(game)
		# 7) 소환 — 하루치를 굴려 장비·스킬을 얻는다. 난수는 고정 씨앗이라
		#    같은 곡선이면 같은 결과가 나온다(_run 첫머리에서 심는다).
		_summon_day(game, member,
			int(float(boon["value"])) if str(boon["kind"]) == "ticket" else 0)
		# 7.4) 핏빛 계약 — 접속 1시간이면 자연 충전 1~2장(오프라인엔 안 찬다).
		#      계약의 서·팩은 모의에 없다(과금 상품). 카드는 아래 전진에서 쓴다.
		var cards := 2 if day > 0 else 3
		# 7.5) 펫 — 펫권 뽑기·먹이 강화·수집·동행 버프 (2026-08-18 재측정).
		_pet_day(game, day, raid_mult)
		# 8) 인장으로 혈맹 — 선형 비용이라 꾸준히 팔린다.
		while game.sigil >= PactDefs.cost(game.pact_lv) 				and game.pact_lv < PactDefs.level_cap():
			game.sigil -= PactDefs.cost(game.pact_lv)
			game.pact_lv += 1
		# 9) 번 것을 전부 쓴다 — 전투력이 가장 많이 오르는 순서로.
		gold = _shop(game, gold)
		# 10) 갈 수 있는 데까지 전진.
		while game.stage < StageDefs.total_stages() and _can(game, game.stage):
			game.stage += 1
			game.best_stage = maxi(game.best_stage, game.stage)
		# 10.5) 막히면 **계약 카드를 쓴다** — 그게 이 시스템의 목적이다(운빨 돌파).
		#       평균값으로 공격 +50% 를 잡는다(커먼 30 ~ 레어 60 의 가운데).
		#       카드가 있는 동안만, 그리고 카드로도 못 넘으면 거기서 멈춘다.
		while cards > 0 and game.stage < StageDefs.total_stages():
			game.oath_fx = {"attack": 0.5}
			game.oath_fx_t = 60.0
			var pushed := _can(game, game.stage)
			game.oath_fx = {}
			game.oath_fx_t = 0.0
			if not pushed:
				break
			cards -= 1
			game.stage += 1
			game.best_stage = maxi(game.best_stage, game.stage)
			while game.stage < StageDefs.total_stages() and _can(game, game.stage):
				game.stage += 1
				game.best_stage = maxi(game.best_stage, game.stage)
		_earn_titles(game)
		log.append(game.stage)
		peak.append(maxi(game.stage, peak[-1] if not peak.is_empty() else 0))
		# 11) 회귀 — **막히면 누른다.** 실제 유저의 방아쇠가 그거다(어제와 같은
		#     자리면 벽이다). 화면 함수(_prestige_do)는 노드가 없어 못 부르므로
		#     되돌리는 것만 같게 만든다 — 구간·스탯·혈액. 뽑은 것과 기록은 남는다.
		#     best_stage 가 1 로 가면 던전·미궁·스탯 해금이 같이 닫히는데,
		#     **그게 실제 경험이라** 모델도 그대로 둔다.
		if prestige_after > 0 \
				and PrestigeDefs.can(game.best_stage, game.prestige_peak) \
				and _stuck_days(log) >= prestige_after:
			game.prestige_marks += PrestigeDefs.marks_for(game.best_stage,
				game.prestige_peak)
			game.prestige_peak = maxi(game.prestige_peak, game.best_stage)
			game.prestige_count += 1
			game.stage = 1
			game.best_stage = 1
			game.lv = {}
			gold = 0.0
		# **어디서 막혔는가**를 같이 남긴다 — 구간만 보면 "느리다"까지만 알고
		# 무엇이 병목인지는 모른다(멤버십 차이가 0 인 이유가 여기 있다).
		diag.append({"stage": game.stage, "floor": game.dungeon_best,
			"trial": game.trial_stage,
			"cap": StatDefs.train_cap(game.dungeon_best, game.best_stage),
			"lv": int(game.stat_lv("damage")), "marks": game.prestige_marks,
			"gold": gold, "crystal": game.crystal,
			"power": Balance.combat_power(game.dps(), game.max_hp(),
				game.regen_per_sec())})
	return {"log": log, "peak": peak, "diag": diag, "axes": _axes(game),
		"power": Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())}


# 마지막 자리에서 며칠째 제자리인가. 어제와 같으면 1일 정체다.
static func _stuck_days(log: Array[int]) -> int:
	if log.size() < 2:
		return 0
	var n := 0
	while n + 1 < log.size() and log[-1 - n] == log[-2 - n]:
		n += 1
	return n


# 공격력 한 줄을 축별로 쪼갠다. damage() 는
#   hero_damage(효과레벨, 장비합, 영웅레벨) x (1 + 수집 + 도감 + 혈맹)
# 이고 혈맥은 그 바깥에서 곱해진다(dps 쪽). 각 축을 뺀 값과 비교해 몫을 낸다.
func _axes(game) -> Dictionary:
	var base := Balance.hero_damage(1, 0.0, 1)
	var stat_only := Balance.hero_damage(int(game.stat_lv("damage")), 0.0, game.hero_lv)
	var with_gear := Balance.hero_damage(int(game.stat_lv("damage")),
		game._gear_stat("damage"), game.hero_lv)
	var free_lv := int(game._stat_eff("damage")) - int(game.stat_lv("damage"))
	var with_title := Balance.hero_damage(int(game.stat_lv("damage")) + free_lv,
		0.0, game.hero_lv)
	return {
		"스탯": stat_only / base,
		"장비": with_gear / maxf(0.001, stat_only),
		"도감": 1.0 + FoeTiers.codex_bonus(game.codex_knowledge, "damage"),
		"혈맹": 1.0 + PactDefs.bonus(game.pact_lv),
		"혈맥": TraitDefs.mult("attack", game.traits),
		"유물": RelicDefs.mult("damage", game.relics),
		"칭호": with_title / maxf(0.001, stat_only),
		"회귀": game._prestige_mult(),
		"시련": TrialDefs.mult(game.trial_stage),
		"펫": 1.0 + game._pet_mult("damage"),
	}


# seconds 동안 지금 자리에서 번 혈액. eff 는 오프라인 절반 효율(0.5) 자리다.
# 못 넘는 구간에 서 있으면 한 칸 아래에서 번다(실제로도 그렇게 된다).
func _farm(game, seconds: float, eff: float) -> float:
	var st: int = game.stage
	if not _can(game, st):
		st = maxi(1, st - 1)
	var p: Dictionary = game._offline_profile(st)
	var kill_time := maxf(0.2, float(p["hp"]) / maxf(0.001, game.dps()))
	var kills := seconds / kill_time
	# 도감 — 잡은 만큼 쌓인다. 그 막의 로스터에 고르게 나눠 넣는다(실제로도
	# 한 막 안에서 섞여 나온다). 도감 보정은 공격·체력·흡혈에 그대로 붙는다.
	var act: Dictionary = StageDefs.ACTS[StageDefs.act_of(st)]
	var roster: Array = act.get("roster", [])
	if not roster.is_empty():
		for key in roster:
			game.codex[str(key)] = int(game.codex.get(str(key), 0)) 				+ int(kills / float(roster.size()))
		game.codex_found = game.codex.size()
		game.codex_knowledge = 0
		for k in game.codex:
			game.codex_knowledge += FoeTiers.codex_level(int(game.codex[k]))
	return kills * StageDefs.gold_per_kill(st) * game.gold_mult() * eff


# 하루치 소환. 보석은 임무 배급(설계서 4-1: 하루 약 25 + 주간 몫)으로,
# 소환권은 하루 4장 + 주간 몫을 하루로 편 값이다. 멤버십은 매일 보석 100 +
# 소환권 3(설계서 5-3). 나온 장비는 슬롯별 최고만 장착한다.
func _summon_day(game, member: bool, extra := 0) -> void:
	var pulls := 4 + 2 + extra             # 소환권 4 + 보석 25~35 -> 1~2회
	if member:
		pulls += 3 + 3                     # 소환권 3 + 보석 100 -> 3회
	# 출석·천장이 지갑에 꽂아 둔 소환권과 보석을 그날 소진한다.
	for tk in TicketDefs.KINDS:
		pulls += int(game.tickets.get(tk, 0))
		game.tickets[tk] = 0
	var gem_pulls := int(game.gem / GachaDefs.COST)
	if gem_pulls > 0:
		game.gem -= float(gem_pulls) * GachaDefs.COST
		pulls += gem_pulls
	# 유물은 100구간부터 열린다 — 열리면 뽑기 한 자리를 유물이 가져간다
	# (실제 유저도 후반엔 유물을 민다).
	var kinds: Array = ["weapon", "armor", "trinket", "skill"]
	if game.best_stage >= RelicDefs.OPEN_STAGE:
		kinds.append("relic")
	for i in pulls:
		var kind: String = kinds[i % kinds.size()]
		game._gacha_kind = kind
		var lv := GachaDefs.level(int(game.gacha_pulls.get(kind, 0)))
		var r := GachaDefs.pull(1, int(game.gacha_pity.get(kind, 0)), lv,
			kind == "skill")
		game.gacha_pity[kind] = int(r["pity"])
		game.gacha_pulls[kind] = int(game.gacha_pulls.get(kind, 0)) + 1
		game._mile_add(kind, 1)   # 천장 상자 — 차면 소환권이 지갑으로 돌아온다
		if kind == "skill":
			game._receive_gacha_skill(str(r["rarities"][0]))
		elif kind == "relic":
			game._receive_gacha_relic(str(r["rarities"][0]))
		else:
			game._receive_gacha_gear(str(r["rarities"][0]))
	_equip_best(game)
	_upgrade_gear(game)


# 슬롯마다 가장 센 것을 장착. 실제 화면에도 "더 센 게 나오면 갈아 끼운다"가
# 자동으로 걸려 있다(Main._load_game 의 정규화와 같은 비교).
func _equip_best(game) -> void:
	for key in game.gear_inventory:
		var item: Dictionary = game.gear_inventory[key]
		var slot := str(item.get("slot", ""))
		if slot == "":
			continue
		var now: Dictionary = game.equipped.get(slot, {})
		if now.is_empty() or GearDefs.power(item) > GearDefs.power(now):
			var eq: Dictionary = item.duplicate(true)
			eq["inventory_key"] = key
			game.equipped[slot] = eq


# 정수로 장착 장비를 강화 — 살 수 있는 동안 계속. 전투력이 가장 많이 오르는
# 곳부터가 아니라 균등하게 돈다(실제 유저도 장착품을 고르게 올린다).
func _upgrade_gear(game) -> void:
	var moved := true
	while moved:
		moved = false
		for slot in game.equipped:
			var item: Dictionary = game.equipped[slot]
			var c := GearDefs.upgrade_cost(item)
			if game.essence < c:
				continue
			game.essence -= c
			item["lv"] = int(item.get("lv", 0)) + 1
			var key := str(item.get("inventory_key", ""))
			if game.gear_inventory.has(key):
				game.gear_inventory[key]["lv"] = item["lv"]
			moved = true


# 시련 — 열린 단계를 이길 수 있는 동안 민다. 파수꾼은 hp_mult 3.6 보스 하나.
# 체력·피해·간격 전부 엔진 공식(FoeTiers/Balance) 그대로 — 모델식을 따로 두면
# 갈린다.
static func _trial_up(game) -> void:
	while game.trial_stage < TrialDefs.max_stage() \
			and game.dungeon_best >= TrialDefs.floor_need(game.trial_stage + 1):
		var eq := TrialDefs.eq_stage(game.trial_stage + 1)
		var power := StageDefs.enemy_power(eq)
		if not Balance.can_clear_stage(game.max_hp(), game.regen_per_sec(),
				game.dps(), 1,
				FoeTiers.foe_hp(3.6, power, true, false), 1,
				Balance.foe_damage(power) * Foe.avg_attack_mult(true, false),
				Balance.foe_attack_interval(3.6),
				TrialDefs.TIME_LIMIT, game.attack_interval()):
			break
		game.trial_stage += 1


# 출석 — 30일 표를 매일 받는다. 소환권은 지갑으로(그날 소환이 쓴다),
# 혈정·보석은 해당 재화로.
static func _attend_day(game) -> void:
	var a := AttendDefs.of(AttendDefs.next_day(game.attend_got))
	game.attend_got += 1
	var reward := str(a["reward"])
	var amount := float(a["amount"])
	if reward.begins_with("ticket_"):
		var tk := reward.trim_prefix("ticket_")
		game.tickets[tk] = int(game.tickets.get(tk, 0)) + int(amount)
	elif reward == "crystal":
		game.crystal += amount
	elif reward == "gem":
		game.gem += amount


# 펫 — 임무 펫권(일 1)·장비권(주 3)을 굴리고, 먹이 던전을 돌고, 다 모이면
# 강화하고, 물어온 재화를 받고, 공격 펫 최강을 동행시킨다.
# 수집은 하루 7시간으로 친다: 상한 6시간(하루 한 번 받기) + 접속 1시간.
static func _pet_day(game, day: int, raid_mult: float) -> void:
	if game.best_stage < PetDefs.PET_OPEN:
		return
	game.tickets["pet"] = int(game.tickets.get("pet", 0)) + 1
	if day % 7 == 6:
		game.tickets["petgear"] = int(game.tickets.get("petgear", 0)) + 3
	if game.best_stage >= RaidDefs.open_stage("hunt"):
		for i in RaidDefs.TRIES_PER_DAY:
			game.feed += RaidDefs.reward("hunt",
				maxi(1, game.raid_best.get("hunt", 0))) * raid_mult
		game.raid_best["hunt"] = int(game.raid_best.get("hunt", 0)) + 1
	while int(game.tickets.get("pet", 0)) > 0:
		game._pet_roll(false)
	while int(game.tickets.get("petgear", 0)) > 0:
		game._petgear_roll()
	# 동행 — 공격(damage) 펫 중 버프가 가장 큰 놈.
	var best_pet := ""
	var best_v := 0.0
	for id in game.pets_got:
		if str(PetDefs.of(str(id)).get("stat", "")) != "damage":
			continue
		var v := PetDefs.bonus(str(id), "damage", game._pet_lv(str(id)),
			game._pet_star(str(id)))
		if v > best_v:
			best_v = v
			best_pet = str(id)
	if best_pet != "":
		game.pet_worn = best_pet
		# 강화는 동행에게 몰아준다 — 실제 유저의 최적 행동이다.
		while game._pet_feed(best_pet):
			pass
	# 수집 — 물어온 재화를 받는다.
	for id in game.pets_got:
		var amt := PetDefs.accrue(str(id), 0.0, 7.0, game._pet_lv(str(id)),
			game._pet_star(str(id)))
		match str(PetDefs.of(str(id))["gain"]):
			"crystal": game.crystal += amt
			"essence": game.essence += amt
			"sigil": game.sigil += amt
			"feed": game.feed += amt


# 조건을 채운 칭호를 딴다 — 공짜 스탯 레벨이라 곡선에 실제로 들어간다.
func _earn_titles(game) -> void:
	var state: Dictionary = game._title_state()
	for t in TitleDefs.TITLES:
		var id := str(t["id"])
		if not game.titles_got.has(id) and TitleDefs.earned(id, state):
			game.titles_got[id] = true


# 미궁 — 열린 층 안에서 갈 수 있는 데까지. 하루치 소탕 혈정도 여기서 받는다.
# 층이 짧아(5마리) 접속 시간을 따로 떼지 않는다.
func _climb(game) -> void:
	var open_to := DungeonDefs.open_floors(game.best_stage)
	while game.dungeon_best < open_to:
		var fl: int = int(game.dungeon_best) + 1
		var eq := DungeonDefs.eq_stage(fl)
		var p: Dictionary = game._offline_profile(eq)
		if not Balance.can_clear_stage(game.max_hp(), game.regen_per_sec(), game.dps(),
				DungeonDefs.kills_needed(fl), float(p["hp"]), int(p["count"]),
				float(p["damage"]), float(p["interval"]),
				DungeonDefs.time_limit(fl), game.attack_interval()):
			break
		game.dungeon_best = fl
	# 소탕 — 하루치, 오프라인 절반 효율은 실제 코드와 같다.
	game.crystal += DungeonDefs.sweep_per_hour(game.dungeon_best) * 24.0 * 0.5


# 혈맥 — 줄기 순서대로, 살 수 있는 만큼. 앞 노드가 만렙이어야 다음이 열린다.
func _buy_traits(game) -> void:
	for id in TraitDefs.order():
		var node := TraitDefs.node(str(id))
		while TraitDefs.level_of(str(id), game.traits) < TraitDefs.MAX_LV:
			if not TraitDefs.lock_reason(str(id), game.traits, game.hero_lv,
					game.dungeon_best).is_empty():
				return
			var c := TraitDefs.cost(int(node["tier"]))
			if game.crystal < c:
				return
			game.crystal -= c
			game.traits[str(id)] = TraitDefs.level_of(str(id), game.traits) + 1


func _can(game, st: int) -> bool:
	var p: Dictionary = game._offline_profile(st)
	return Balance.can_clear_stage(game.max_hp(), game.regen_per_sec(), game.dps(),
		StageDefs.kills_needed(st), float(p["hp"]), int(p["count"]),
		float(p["damage"]), float(p["interval"]), StageDefs.time_limit(st),
		game.attack_interval())


# 전투력당 값이 가장 싼 스탯부터 산다 (CurveSweep._shop 과 같은 정책).
func _shop(game, gold: float) -> float:
	while true:
		var best := ""
		var best_cost := 0.0
		var best_score := 0.0
		for s in StatDefs.STATS:
			var key := str(s["key"])
			if not StatDefs.is_open(key, game.best_stage, game.lv):
				continue
			var lv: int = game.stat_lv(key)
			if StatDefs.at_cap(key, lv) \
					or lv >= StatDefs.train_cap(game.dungeon_best, game.best_stage):
				continue
			var cost: float = game.upgrade_cost(key, lv)
			if cost > gold:
				continue
			var score := _gain(game, key, lv) / maxf(1.0, cost)
			if score > best_score:
				best_score = score
				best = key
				best_cost = cost
		if best == "":
			return gold
		gold -= best_cost
		game.lv[best] = game.stat_lv(best) + 1
	return gold


func _gain(game, key: String, lv: int) -> float:
	var before := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv + 1
	var after := Balance.combat_power(game.dps(), game.max_hp(), game.regen_per_sec())
	game.lv[key] = lv
	return maxf(0.0, after - before)


static func _n(v: float) -> String:
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1000.0:
		return "%.1fK" % (v / 1000.0)
	return "%.0f" % v
