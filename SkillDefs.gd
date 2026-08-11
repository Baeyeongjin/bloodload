class_name SkillDefs
extends RefCounted

# 스킬. 형태 4 x 등급 5 = 20종, 장착 슬롯 6칸.
# 설계 근거는 docs/SKILL_PLAN.md 에 있다.
#
# **원소는 없다.** 전부 피(血) 계열이고, 갈리는 축은 형태(무엇을 하는가)와
# 등급(얼마나 센가) 둘뿐이다. 자동 전투에서 속성 상성은 플레이어가 개입할 수 없는
# 곳에서 결과만 흔들어서 뺐다.
#
# 등급 배수는 GachaDefs.RARITIES 의 power 를 그대로 쓴다 — 장비와 같은 표를 봐야
# "레전더리는 대충 이 정도"라는 감이 한 게임 안에서 일관된다.

# 형태. 쿨다운을 여기서 가른다 — **6칸을 다 껴도 동시에 터지는 게 2개를 안 넘는**
# 근거가 이 표다. 등급이 올라도 쿨다운은 그대로다.
#
# **형태는 기본값이고, 스킬 고유 규칙(RULES)이 그 위에 얹힌다** (2026-08-06 사장님:
# "스킬마다 고유 규칙을 줘야 하는 게 맞아"). 같은 날 아침의 "등급은 위력만 올린다"를
# 이 결정이 덮었다 — 그 원칙대로면 20종이 숫자만 다른 네 스킬이라 뽑는 맛이 없다.
# 표출(FX_OVERRIDE)과 같은 원리다: 기본값은 형태가, 예외는 스킬이 적는다.
const SHAPES := {
	"strike": {
		# **fx_y 는 몸통 가운데 기준의 미세 조정이다.** -36 은 기준선이 발밑 근처였을 때
		# 쓰던 값이라, 기준을 `Foe.body_mid_y()`(진짜 몸통 가운데)로 고친 뒤에는 너무
		# 크다 — 슬라임(높이 64)이면 `ground_y-32-36 = ground_y-68` 로 **정수리보다 4px 위**다.
		# 사장님: "발사 이펙트가 약간 위에서 발사되는 느낌." 몸통에 맞춘다.
		"name": "격", "role": "단일", "cooldown": 7.0, "power": 2.2,
		"motion": "heavy", "fx_y": 0.0, "fx_fps": 16.0,
		"fx_style": "burst",
	},
	"wave": {
		# heavy(내려치기)를 격과 나눠 쓰다가 sweep(횡베기)을 따로 뽑았다 —
		# 같은 모션이면 격이 나갔는지 파가 나갔는지 캐릭터 몸으로는 구분이 안 된다.
		# fx_y 0 — 격과 같은 이유다(위 참고). 몸통 가운데 기준으로 바뀌었다.
		"name": "파", "role": "광역", "cooldown": 13.0, "power": 1.4,
		"motion": "sweep", "fx_y": 0.0, "fx_fps": 16.0,
		"fx_style": "sweep",
	},
	"field": {
		# 바닥에 깔리는 문양이라 기준 높이가 발밑(0)이다. 다른 것과 같은 높이에 두면
		# 공중에 뜬 표지판으로 보인다 — 실제로 그렇게 보였다.
		# fx_y 가 0 이면 지면 정중앙이라 **원래부터 절반이 땅 밑**이었다. 타원으로
		# 눕혀 그리므로 조금만 올리면 바닥에 놓인 것으로 읽힌다.
		#
		# **유일한 다단히트다**(2026-08-06). `hold` 스타일로 바닥에 **머무는** 그림인데
		# 피해는 깔리는 순간 한 번뿐이라 그림과 규칙이 어긋나 있었다 — 틱으로 바꾸니
		# 오히려 맞아진다. 이펙트를 새로 뽑을 필요가 없는 유일한 형태이기도 하다
		# (격·파를 다단히트로 만들면 터지는 한 번짜리 그림이 연타를 못 표현한다).
		#
		# 수치는 damage_lab(Godot 참조 구현)의 **정액형** DoT 를 따른다: 지속시간
		# 동안 초당 2틱, 틱마다 같은 피해. 감쇠형(화상: 첫 틱 40%, 틱마다 -10%)은
		# "터진 여파"고, 정액형이 "머무는 장판"이다 — 우리 그림은 후자다.
		# 총량은 power 로 맞춘다: 한 방 0.9 를 틱 수로 나눠 넣으므로 DPS 는 그대로고,
		# **서 있는 동안 계속 맞는다**는 규칙만 새로 생긴다.
		#
		# **fx_fps 는 지속시간에서 나온다.** 10fps 면 프레임 9장이 0.9초에 끝나 그림이
		# 사라진 뒤에도 2초 넘게 피해가 들어갔다 — 어디서 맞는지 안 보이는 장판이었다.
		# 9 / 3.0 = 3fps 로 두면 그림이 있는 동안만 때린다. 프레임 수가 바뀌면 이 값도
		# 바꿔야 한다(그래서 아래 tests/AoeCheck 가 둘을 같이 잰다).
		"name": "진", "role": "광역", "cooldown": 19.0, "power": 0.9,
		"motion": "cast", "fx_y": -14.0, "fx_fps": 3.0,
		"fx_style": "hold", "duration": 3.0, "tick_rate": 2.0,
	},
	"ward": {
		# ward 는 자기한테 거는 동작이라 앞으로 뻗는 cast 와 자세가 다르다.
		# **fx_y 는 0 이다.** -40 이었는데 그러면 고리 중심이 영웅 몸 가운데가 아니라
		# `ground_y-72`, 즉 **머리 위 8px** 에 온다(영웅은 ground_y-64~ground_y).
		# 가호는 몸을 감싸는 것이라 기준점이 곧 영웅 중심이어야 한다 — `_fx_anchor_y` 가
		# orbit·pulse 에는 지면 보정을 안 하고 `body_mid + fx_y` 를 그대로 쓴다.
		"name": "가호", "role": "버프", "cooldown": 23.0, "power": 0.0,
		"motion": "ward", "fx_y": 0.0, "fx_fps": 12.0,
		"fx_style": "orbit", "duration": 6.0, "bonus": 0.30,
	},
}

const SHAPE_ORDER := ["strike", "wave", "field", "ward"]

# 이름표. 형태 x 등급으로 20칸이 정확히 찬다.
# 세로줄이 같은 형태의 상위 버전이라 아이콘도 같은 계열로 골라 뒀다.
const NAMES := {
	"strike": {"common": "피의 송곳니", "uncommon": "핏빛 창", "rare": "사혈 발톱",
		"epic": "처형자의 아가리", "legend": "심연의 손"},
	"wave": {"common": "피의 손길", "uncommon": "튀는 피", "rare": "혈우",
		"epic": "뱀의 무리", "legend": "붉은 소용돌이"},
	"field": {"common": "비명의 흔적", "uncommon": "갈라진 대지", "rare": "감시의 눈",
		"epic": "피의 제단", "legend": "피의 왕좌"},
	"ward": {"common": "피의 결계", "uncommon": "진홍 방패", "rare": "붉은 성배",
		"epic": "혈월", "legend": "불멸의 심장"},
}

# 스킬 고유 규칙. **형태 기본값을 덮는 것만** 적는다 (2026-08-06 사장님 지시).
# 여기 없는 스킬은 형태 규칙 그대로다: 격 = 단일 한 방, 파 = 화면 안 전부 한 방,
# 진 = 맞는 놈마다 문양 + 다단히트, 가호 = 버프.
const RULES := {
	# 피의 손길 — **관통.** 이펙트 하나가 앞으로 나아가며(sweep 전진) 화면 안 전부를
	# 꿰뚫는다(사장님: 이펙트 하나만, 관통으로). 피해는 파 기본과 같고 표출만 하나다.
	"wave_common": {"pierce": true},
	# 핏빛 창 — **날아가 두 명을 꿰뚫는다**(2026-08-11 사장님: "몬스터 2마리 공격").
	# 이름은 격(strike)이지만 동작은 파(wave)다 — 갈라진 대지와 같은 `as` 매듭이다.
	# 관통이라 이펙트는 하나만 뜨고, sweep 전진(190px)이 곧 "꿰뚫었다"가 된다.
	#
	# **위력을 격 2.2 에서 파 1.4 로 내린다.** 안 내리면 등급 사다리가 뒤집힌다:
	# 격 위력 그대로 둘에게 넣으면 총 2 x 1.35 = 2.7 로, 쿨타임이 같은(둘 다 격 7초)
	# 사혈 발톱(레어, 1.8)보다 세진다. 이 저장소가 이미 두 번 밟은 함정이다
	# (RULES.hits 주석 — "위력을 그대로 여러 번 넣으면 사다리가 뒤집힌다").
	# 1.4 면 한 명당 0.86배 · 둘 합쳐 1.72배로 사혈 발톱 아래에 들어간다 —
	# 단일로는 약하고 둘 이상일 때 앞서는, 광역이 값을 치르는 자리다.
	"strike_uncommon": {"as": "wave", "pierce": true, "max_targets": 2,
		"power": 1.4},
	# 튀는 피 — 하나에 던지면 **표창처럼 튕겨** 가까운 놈 순서로 최대 3명을 맞힌다.
	"wave_uncommon": {"bounce": 3},
	# 비명의 흔적 — 몹마다 까는 대신 **웅덩이 하나**를 무리 가운데에 크게 깔고
	# 가까운 4마리까지만 때린다. puddle 값이 문양 배율이다(64px x 3 = 화면 몹 무리의
	# 반~3분의 1 폭, 사장님 지정). 틱마다 뜨던 피격 이펙트는 뺐다(no_hit_fx) —
	# 4마리 x 6틱 = 24장이 웅덩이를 가렸다.
	# `fixed` — 전진해도 웅덩이가 뒤로 안 밀린다(2026-08-11 사장님: "비명의 흔적도
	# 고정시켜주면 좋을듯"). 자리는 몹 발밑 그대로다(`screen` 과 다른 점).
	"field_common": {"puddle": 3.0, "max_targets": 4, "no_hit_fx": true,
		"fixed": true},
	# 갈라진 대지 — **장판이 아니다**(2026-08-10 사장님: "갈라진대지 장판아니고 그냥
	# 넓은 범위에 단일로 한번 타격하고 끝이고 이펙트가 오래 머무르는거아니야").
	#
	# 이름은 진(field)이지만 **동작은 파(wave)** 다: 한 번에 3명까지 때리고 끝난다.
	# 그전에는 이름이 진이라는 이유로 장판 기계(3초 머무는 문양 + 틱)를 타고 있었다 —
	# `as` 가 그 매듭을 끊는다.
	#
	# `fps 12` 로 이펙트 수명이 0.75초다(진 기본 3fps = 3초). 땅이 갈라졌다 닫히는
	# 그림이라 오래 남으면 갈라진 채로 굳는다.
	# 죽은 몹은 갈라진 땅 밑으로 꺼진다(Foe.pit_fall). 흔들림은 한 번에 몬다.
	#
	# **이펙트는 하나이고, 가장 가까운 몹 발밑에 놓인다**(`puddle`). 맞는 놈마다 깔면
	# 지저분하고(사장님), 무리 한가운데로 잡으면 몹 사이 빈 자리에 뜬다.
	# 그림은 후보 셋을 배경 위에 얹어 보고 사장님이 고른 B(솟구치는 피)다 —
	# 앞선 균열 그림 두 판은 돌바닥이 딸려 와 사각형 덩어리로 보였다.
	#
	# **크기·자리는 셋이 얽혀 있다.** 임팩트 순간 영웅과 몹은 59px 밖에 안 떨어져
	# 있고(몹 잉크 29 + BODY_HALF 30) 그 간격은 못 벌린다 — 벌리면 영웅이 그만큼
	# 따라 나가 때리므로 화면상 거리는 그대로고 왕복만 생긴다(FRONT_X 주석).
	# 그래서 **폭을 키우는 대신 몹 너머로 민다**:
	#
	#   puddle 2.0  -> 96 x 등급 1.12 x 2.0 = 215px
	#   push  26    -> 중심 285 + 26 = 311,  덮는 폭 203~418
	#                  몹 몸통 256~314 을 덮고 영웅 몸통 181~245 과는 42px 만 겹친다.
	#                  55 로 밀어 봤더니 몹보다 오른쪽으로 빠져 "몹 발밑"이 안 됐다 —
	#                  영웅을 피하는 것보다 **몹 위에 있는 것**이 먼저다
	#
	# 세로는 손잡이가 없다 — 바닥 스킬 전부가 **아래끝 = 지면선** 하나다
	# (2026-08-10 사장님: "딱 저 초록선에 딱 맞게". `_fx_anchor_y` 주석 참고).
	"field_uncommon": {"as": "wave", "pit_kill": true, "quake": 7.0,
		"max_targets": 3, "fps": 12.0, "puddle": 2.0, "push": 26.0},
	# 감시의 눈 — **화면 가운데에 하나 뜨고 화면 안 전부를 5번 때린다**
	# (2026-08-11 사장님: "커다란 눈이 하나 나오고 여러 개 눈이 하나씩 나오는 모션 /
	# 화면 중앙쯤에 나오고 / 화면에 나와 있는 몬스터 5번 다단히트").
	#
	# `stagger` 를 뺐다. 그건 **대상마다 눈을 하나씩 시간차로 까서** 소환을 흉내 낸
	# 장치였는데, 이제 눈이 늘어나는 연출을 그림이 직접 한다 — 같은 일을 두 군데서
	# 하면 눈이 두 배로 뜬다.
	# `max_targets` 도 뺐다. 화면 안 전부가 대상이다(`screen` 이 판정 폭을 화면으로
	# 넓힌다) — 상한을 남겨 두면 "화면에 보이는데 안 맞는 놈"이 생긴다.
	# `puddle` 은 여기서 **크기 손잡이**로만 쓴다(하나로 크게 깐다는 뜻은 `screen` 이
	# 이미 정한다). 64 x 등급 1.26 x 1.1 = 89px — 1.6(129px)은 위가 진행바에 닿았다
	# (2026-08-11 사장님: "눈 크기 좀 줄이고"). 아래끝을 몹 머리선에 맞추므로
	# 키우면 위로만 자란다 — 천장이 진행바다.
	"field_rare": {"ticks": 5, "screen": true, "puddle": 1.1},
	# 사혈 발톱 — **한 놈을 두 번 긁는다**(2026-08-10 사장님 지시). 총 피해는 그대로
	# 두고 반씩 나눠 두 박자에 넣는다 — 위력을 그대로 두 번 넣으면 격 레어 하나가
	# 에픽보다 세진다. 이펙트는 그대로 쓰되(사장님: "이펙트는 그냥 냅둬") 두 번 뜬다.
	"strike_rare": {"hits": 2, "hit_gap": 0.15},
	# 처형자의 아가리 — **앞으로 나아가며 다섯을 문다**(2026-08-11 사장님: "앞에 있는
	# 몬스터는 다 맞도록 최대 5마리, 화면에 없는 몬스터는 공격 X"). 핏빛 창과 같은
	# `as` + `pierce` 다: 이펙트 하나가 sweep 으로 190px 전진하며 훑는다.
	# 화면 밖은 `_aoe_targets` 가 이미 `_on_screen` 으로 거른다 — 따로 안 적는다.
	#
	# **위력·쿨타임을 파 값으로 같이 옮긴다.** 격 값(2.2 / 7초)으로 다섯을 때리면
	# 에픽 하나가 레전더리(심연의 손, 단일 12.1)를 두 배 넘게 앞선다.
	# 파 값이면 한 명당 2.04배 · 쿨 13초라, 다섯이 다 서 있어도 레전더리 언저리다.
	"strike_epic": {"as": "wave", "pierce": true, "max_targets": 5,
		"power": 1.4, "cooldown": 13.0},
	# 가호 3종은 **패시브**다(2026-08-10 사장님: "진홍 방패는 패시브로 돌리자 /
	# 붉은 성배도 패시브처리 / 혈월은 패시브 처리"). 시전도 모션도 없고 장착만
	# 하면 상시로 붙는다. 세기는 그대로다 — `Main._passive_ward_bonus` 가 표의
	# `bonus` 를 가동률(duration/cooldown)로 환산해서 준다.
	#
	# 피의 결계(커먼)와 불멸의 심장(레전더리)은 **액티브로 남는다** — 커먼은 지시가
	# 없었고, 레전더리는 오히려 발동 연출이 붙는 쪽으로 지시받았다.
	"ward_uncommon": {"passive": true},
	"ward_rare": {"passive": true},
	"ward_epic": {"passive": true},
	# 불멸의 심장 — **액티브로 남는 유일한 상위 가호**(2026-08-10 사장님: "캐릭터 주변
	# 검붉은 오오라 발현 눈은 빨갛게 검에도 붉은 오오라 이펙트 기본공격실현시 몬스터를
	# 광역으로 공격하는 붉은검기가 나감").
	#
	# `tint 0.60` — 피의 제단(0.45)보다 짙다. 눈·검을 따로 물들일 수는 없다(스프라이트가
	# 한 장이다) — 몸 전체가 더 검붉어지는 것으로 "각성했다"를 읽힌다.
	# `cleave` — 버프가 도는 동안 **평타가 광역이 된다.** 값이 그때 쓸 이펙트 이름이다.
	"ward_legend": {"tint": 0.60, "cleave": "fx_cleave_wave"},
	# **광역은 전부 무리 가운데 하나다**(2026-08-10 사장님: "다 가운데 하나로 바꿔").
	# 맞는 놈마다 깔면 같은 그림이 셋 넷 겹쳐 화면이 지저분해진다.
	#
	# 배율은 **그림의 빽빽함**이 정한다. 비명의 흔적은 잉크 49% 라 x3 으로 넓혀도
	# 성기게 퍼지지만, 뱀의 무리는 54% 짜리 덩어리라 x2 면 화면 3분의 1을 덮는 벽이
	# 된다(실측: 화면으로 확인하고 내렸다). 넓히는 게 목적이 아니라 **하나로 모으는**
	# 게 목적이다.
	#  - 누운 것(파) -> **1.0, 즉 안 키운다.** `sweep` 스타일이 트윈에서 이미 1.6배로
	#    넘겼다 늘어나므로(`_anim_fx`) 여기서 또 곱하면 218px 짜리 벽이 된다.
	#    1.5 로 두고 화면을 찍어 보고 내렸다 — 목적은 넓히기가 아니라 하나로 모으기다.
	#  - **선 것(rise: 제단·왕좌)은 키우면 위로 자란다** -> 1.25 만. 2.0 이면 영웅
	#    키의 세 배짜리 기둥이 되어 전투 띠를 가린다.
	#
	# 두 종은 **일부러 뺐다**: 혈우(wave_rare)는 비라서 여러 방울이 맞고, 감시의 눈
	# (field_rare)은 "눈이 하나씩 소환된다"가 사장님이 지시한 설계 그 자체다.
	# 뱀의 무리 — **머리가 하나씩 나와 앞으로 쏟아지며 4연타**(2026-08-11 사장님:
	# "뱀의 머리가 소환되어 앞에 적을 다단히트 시키면서 앞으로 발사되는 느낌").
	# 소환 연출은 그림이 맡고(머리가 1 -> 3), 전진은 `sweep` 이, 연타는 `ticks` 가 맡는다.
	# 총 피해는 그대로다 — 4로 나눠 넣는다.
	"wave_epic": {"puddle": 1.0, "ticks": 4},
	"wave_legend": {"puddle": 1.0},
	# 피의 제단 — **자기 버프다**(2026-08-10 사장님: "스킬사용하면 캐릭터주변에 검은
	# 오오라 이펙트 발현 후 캐릭터가 든 칼이 붉게 물드는 이펙트후 공격력 50% 버프").
	# 이름은 진(field)이지만 동작은 가호(ward)다.
	#
	# 배수 0.50 은 등급표(WARD_BONUS)가 아니라 **사장님이 지정한 값**이라 직접 적는다.
	# 지속 6초는 가호 형태 기본과 같게 뒀다 — 쿨다운 19초 대비 가동률 32% 로,
	# 상시가 아니라 "터뜨리는" 버프다.
	# `tint` 는 버프 도중 영웅을 붉게 물들이는 정도다(칼만 따로 못 물들인다 —
	# 스프라이트가 한 장이다. 몸 전체가 붉어지면 "피를 뒤집어썼다"로 읽힌다).
	# 표출(style: orbit)은 아래 FX_OVERRIDE 에 있다 — 규칙과 표출은 표를 나눠 쓴다.
	"field_epic": {"as": "ward", "bonus": 0.50, "duration": 6.0, "tint": 0.45},
	"field_legend": {"puddle": 1.25},
}


static func rule_of(key: String) -> Dictionary:
	return RULES.get(key, {})


# 그 스킬이 **실제로 어떻게 동작하는가**. 형태(shape)는 기본값일 뿐이고 스킬이
# 덮어쓸 수 있다(RULES.as).
#
# 2026-08-10 사장님: "각 스킬별 타입이 정해지는게 아니라 고유로 가야해".
# 그전에는 `_resolve_skill` 이 형태로 분기해서, 진(field)에 든 스킬은 **무조건**
# 바닥에 머무는 장판이어야 했다 — 갈라진 대지는 "넓은 범위 단일 타격"인데 이름이
# 진이라는 이유로 장판 기계를 타고 있었다. 이름(형태)과 동작을 갈라 둔다.
#
# 형태는 여전히 남는다: 쿨다운·기본 위력·모션·조합 표가 형태 단위이고, 그건
# 20종을 한 눈에 재는 틀이라 유지된다. 바뀌는 건 **무엇을 하는가**뿐이다.
static func behavior_of(key: String) -> String:
	return str(rule_of(key).get("as", split(key)[0]))


# 진(field)이 실제로 때리는 횟수. **여기 하나만 본다** — Main 과 검사가 각자
# `duration x tick_rate` 를 다시 계산하면 규칙(one_shot·ticks)을 얹는 순간 갈린다.
static func ticks_of(key: String) -> int:
	var rule := rule_of(key)
	# **규칙이 적어 뒀으면 형태를 안 본다.** 파(wave)에도 다단히트가 붙었는데
	# (뱀의 무리), 파 형태에는 duration·tick_rate 가 없어서 형태부터 보면 늘 1이
	# 나온다 — 규칙이 있는데 조용히 무시되는 쪽이 제일 나쁘다.
	if rule.has("ticks"):
		return maxi(1, int(rule["ticks"]))
	var shape := shape_of(key)
	if not shape.has("duration") or not shape.has("tick_rate"):
		return 1
	return maxi(1, int(round(float(shape["duration"]) * float(shape["tick_rate"]))))


const SLOTS := 6            # 장착 칸
const LV_POWER := 0.12      # 레벨당 위력 +12%
const LV_CD_STEPS := [5, 10]   # 이 레벨에 도달할 때마다 쿨다운 -8%
const LV_CD_CUT := 0.08
const CD_FLOOR := 0.45      # 쿨다운 하한 배수. 이게 없으면 후반에 스킬이 상시 발동이 된다
const SHARD_PER_LV := 3     # N -> N+1 레벨에 조각 3N 개
const SYNTH_SHARDS := 5     # 같은 스킬 조각 5개로 **다음 등급**으로 승급 (장비와 같은 값)


static func key_of(shape: String, rarity: String) -> String:
	return "%s_%s" % [shape, rarity]


static func split(key: String) -> Array:
	var parts := key.split("_")
	return [str(parts[0]), str(parts[1])] if parts.size() >= 2 else ["strike", "common"]


static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for shape in SHAPE_ORDER:
		for r in GachaDefs.RARITIES:
			if GachaDefs.rarity_index(str(r["key"])) > GachaDefs.SKILL_TOP_INDEX:
				continue   # 스킬은 신화가 없다
			out.append(key_of(shape, str(r["key"])))
	return out


static func name_of(key: String) -> String:
	var sr := split(key)
	return str(NAMES.get(sr[0], {}).get(sr[1], key))


static func shape_of(key: String) -> Dictionary:
	return SHAPES.get(split(key)[0], SHAPES["strike"])


static func icon_path(key: String) -> String:
	var sr := split(key)
	return "res://assets/skills/sk_%s_%s.png" % [sr[1], sr[0]]


# 이펙트는 **스킬마다 다르다.** 형태 4종만 두면 1,000회 뽑아 나온 레전더리가
# 커먼과 똑같이 터져서 뽑은 보람이 없다. 대신 실루엣 계열은 형태별로 묶어 뒀다 —
# 격은 전부 터지는 점, 파는 옆으로 쓸기, 진은 바닥에 눕기, 가호는 가운데가 빈 고리.
# 그래야 "무엇이 나갔나"는 계속 읽히면서 등급 차이도 보인다.
static func fx_of(key: String) -> String:
	var sr := split(key)
	return "fx_sk_%s_%s" % [sr[1], sr[0]]


# 피격 이펙트. 몹 위에 뜨는 거라 32px 로 작다 — 스킬 이펙트만 하면 몹이 안 보인다.
# 가호는 버프라 피격이 없다.
const HIT_FX := {"strike": "fx_hit_pierce", "wave": "fx_hit_splash",
	"field": "fx_hit_mark", "ward": ""}

# **피격 이펙트를 전부 껐다**(2026-08-10 사장님: "몬스터 맞앗을때 나오는 이펙트들
# 다빼줘도될것같음"). 스킬 이펙트를 무리 가운데 하나로 모아 놓고 나니, 맞는 놈마다
# 뜨던 작은 피격 그림이 그 위에 겹쳐서 다시 지저분해졌다 — 피해는 숫자로 이미 보인다.
#
# 표(HIT_FX)와 자산(`fx_hit_*`)은 **안 지웠다.** 되돌리려면 이 상수만 false 로
# 되돌리면 되고, 지웠다가 다시 뽑는 것보다 그게 싸다.
const HIT_FX_ON := false


static func hit_fx_of(key: String) -> String:
	if not HIT_FX_ON:
		return ""
	return str(HIT_FX.get(split(key)[0], ""))


# 등급이 오를수록 같은 형태라도 **더 크고, 잔상이 붙고, 화면이 흔들린다.**
# 그림 20종이 다 달라도 움직임까지 달라야 등급 차이가 전투에서 읽힌다 —
# 목록에서만 다르고 화면에서 같으면 뽑은 보람이 없다.
#
# 잔상(echo)은 같은 이펙트를 조금 늦게·작게·흐리게 한 번 더 띄우는 것이다.
# 새 자산이 필요 없고 "빠르게 지나갔다"가 그것만으로 읽힌다.
const FX_TIER := [
	{"scale": 1.00, "echo": 0, "shake": 0.0},   # 커먼
	{"scale": 1.12, "echo": 1, "shake": 2.0},   # 언커먼
	{"scale": 1.26, "echo": 2, "shake": 3.5},   # 레어
	{"scale": 1.42, "echo": 3, "shake": 5.0},   # 에픽
	{"scale": 1.60, "echo": 4, "shake": 7.0},   # 레전더리
]


# 형태 기본값을 그대로 쓰면 어긋나는 스킬만 적는다.
#
# **서 있는 물건은 돌리지 않는다.** 형태 하나에 스타일 하나를 묶었더니 방패·성배·심장이
# 뒤집히고, 얼굴과 눈이 기울고, 비가 옆으로 날아갔다. 그림이 구체적이라 형태로는 못 묶는다.
# 근거와 전체 표는 docs/SKILL_VFX_RECIPE.md 4-3.
const FX_OVERRIDE := {
	# 혈우 — 비는 위에서 내려온다. y 는 **떨어져 도착하는 자리**이고 거기서
	# FALL_DROP 만큼 위에서 시작한다. -78 은 너무 높아 나무 높이에서 떨어졌다.
	# **flip -1 = 그림이 왼쪽을 향해 그려졌다.** 코드는 `scale.x = sign(hero_face)` 로만
	# 뒤집는데, 몹이 전부 오른쪽에 서므로 영웅은 늘 오른쪽을 보고(face +1) 그림이 원본
	# 그대로 나간다 — 그래서 왼쪽으로 그려진 이펙트는 **등 뒤로 나간다**(사장님 지적).
	# 2026-08-06 프레임 대조: 피의 손길은 번짐이 왼쪽 아래로, 튀는 피는 물보라가
	# 왼쪽 위로 흐른다. 뱀의 무리는 무게중심이 왼쪽이지만 **머리는 오른쪽**이라 그대로 둔다
	# — 무게중심으로만 재면 여기서 틀린다.
	"wave_common": {"flip": -1.0},
	# 튀는 피 — 2026-08-06 튕김(ricochet) 그림으로 교체. **새 그림은 오른쪽을 향한다**
	# (임팩트 스플래시 → 핏방울이 오른쪽 위로 튕겨 나감) — flip 을 빼야 진행 방향과
	# 맞는다. 옛 물보라(왼쪽 향함)로 되돌리면 flip -1 도 같이 되돌릴 것.
	"wave_rare": {"style": "fall", "y": -48.0},
	# 핏빛 창 — **날아와서 꽂힌다**(2026-08-10 사장님: "이펙트 위아래 반전만 시켜주고
	# 창이 날라와서 몬스터한테 관통하는 이펙트로"). 그림을 가로로 날아가는 창으로
	# 다시 뽑았으므로 `flip_v` 를 뺀다 — 그건 옛 그림(창끝이 오른쪽 위)을 내리꽂는
	# 창으로 세우려던 보정이고, 새 그림에 걸면 창이 뒤집힌다.
	#
	# `sweep` 은 **앞으로 나아가며 늘어나는** 스타일이다(190px 전진). 격은 단일이라
	# 표적 하나에 꽂히고, 나아가는 궤적이 곧 "날아왔다"가 된다.
	# fps 는 낮게 둬서 꽂힌 뒤 서서히 사라진다(수명 0.56 → 1.1초).
	"strike_uncommon": {"style": "sweep", "fps": 8.0, "skew": 0.0},
	# skew 0 = 안 기울인다. **정면 대칭인 그림은 기울이면 깊이감이 아니라
	# 찌그러진 그림이 된다.** 비스듬히 그려진 것(송곳니·창)만 기울여야 산다.
	# 갈라진 대지 — **땅에서 솟구치는 피**라 `rise` 다(2026-08-10 B 안). `hold` 로 두면
	# 세로가 길 폭(52px)으로 눌려 솟는 그림이 납작해지고 가로로만 늘어난다.
	# `rise` 는 아래끝을 지면에 붙인 채 위로 자란다 — 분출이 그 모양이다.
	"field_uncommon": {"style": "rise", "y": -10.0, "skew": 0.0},
	# 감시의 눈 — **바닥 문양이 아니라 떠 있는 눈이다**(2026-08-10). `hold` 로 두면
	# 세로가 길 폭(52px)으로 눌려 눈이 납작한 얼룩이 된다 — 화면에서 뭔지 안 읽혔다.
	# `pulse` 는 제자리에서 커졌다 작아지고 지면 보정을 안 받는다. 몹 몸통 위에 떠서
	# 노려보는 그림이 된다.
	"field_rare": {"style": "pulse", "y": -18.0},
	# 뱀의 무리 — 파 기본 16fps 면 9장이 0.56초라 **머리가 하나씩 나오는 구간이
	# 0.25초**로 지나가 안 보인다. 10fps(0.9초)로 늦춰 소환이 읽히게 한다.
	"wave_epic": {"fps": 10.0},
	# 붉은 소용돌이 — **캐릭터 키보다 살짝 크게**(2026-08-11 사장님).
	# 캐릭터는 32px 도트를 2배로 그려 화면 64px 이다. 레전더리 배율 1.60 을 그대로
	# 쓰면 102px 이라 캐릭터의 1.6배였다. 0.78 을 곱해 80px — 키의 1.25배다.
	#
	# **skew 0 이 더 큰 문제였다.** 파 기본 `sweep` 은 깊이감을 주려고 기울이고
	# 세로를 누르는데, 정면 대칭인 원형 소용돌이에 걸면 **납작한 팬케이크**가 된다
	# (실측: 화면에서 소용돌이로 안 읽혔다). 이미 적어 둔 원칙인데
	# — "정면 대칭인 그림은 기울이면 깊이감이 아니라 찌그러진 그림이 된다" —
	# 파 쪽에는 안 걸려 있었다.
	"wave_legend": {"scale": 0.78, "skew": 0.0},
	"strike_rare": {"skew": 0.0},       # 사혈 발톱 — 교차 베기라 정면이 맞다
	# 처형자의 아가리 — **옆모습으로 다시 뽑았다**(2026-08-10 사장님: "몬스터 방향이어야
	# 해"). 정면으로 벌린 입은 아무리 기울여도 관객을 무는 그림이라 `rot` 로는 못 고친다.
	# 이제 주둥이가 오른쪽을 향하고, 몹이 늘 오른쪽에 서므로 그대로 표적을 문다.
	# `rot` 는 뺐다 — 옆모습을 또 기울이면 턱이 어긋난다.
	# 처형자의 아가리 — **입을 벌렸다 닫으며 앞으로 나아간다**(2026-08-11 사장님).
	# `sweep` 이 190px 전진을 맡고 그림이 무는 동작을 맡는다 — 핏빛 창과 같은 분담이다.
	# 옆모습이라 `rot` 은 안 쓴다(기울이면 턱이 어긋난다).
	# 크기는 0.75배 — 아가리 그림이 64px 캔버스를 꽉 채워서 등급 배율 1.42 를 그대로
	# 쓰면 91px 이라 몹을 통째로 덮었다(2026-08-11 사장님: "크기를 좀 줄여줘도").
	"strike_epic": {"style": "sweep", "fps": 10.0, "skew": 0.0, "scale": 0.75},
	# 심연의 손 — **바닥에서 손이 올라와 몹을 끌고 내려간다.** 격인데도 rise 를 쓰는
	# 유일한 스킬이다. 몹 발밑에서 시작해야 "끌려간다"가 읽히므로 y 도 지면 가까이 둔다.
	"strike_legend": {"style": "rise", "y": -16.0, "skew": 0.0},
	# 피의 제단 — **몸에 두르는 오오라**로 바뀌었다(2026-08-10). 솟아오르는 제단이
	# 아니라 영웅을 감싸는 고리다: `orbit` 은 영웅 뒤(z=2)에 깔려 후광으로 읽힌다.
	"field_epic": {"style": "orbit"},
	"field_legend": {"style": "rise"},                 # 피의 왕좌 — 솟아오른다
	"ward_common": {"style": "pulse"},                 # 피의 결계 — 돔은 안 돈다
	"ward_uncommon": {"style": "pulse"},               # 진홍 방패 — 세워져 있어야 한다
	"ward_rare": {"style": "pulse"},                   # 붉은 성배 — 세워져 있어야 한다
	"ward_legend": {"style": "pulse"},                 # 불멸의 심장 — 뛰지, 돌지 않는다
}


# 이펙트 재생에 필요한 값을 한 사전으로. Main 이 형태·등급을 따로 캐지 않게 한다.
static func fx_profile(key: String) -> Dictionary:
	var shape := shape_of(key)
	var tier: Dictionary = FX_TIER[clampi(
		GachaDefs.rarity_index(str(split(key)[1])), 0, FX_TIER.size() - 1)]
	var over: Dictionary = FX_OVERRIDE.get(key, {})
	return {
		"fx": fx_of(key),
		"style": str(over.get("style", shape.get("fx_style", "burst"))),
		"y": float(over.get("y", shape["fx_y"])),
		# 1.0 = 스타일 기본 기울기, 0.0 = 안 기울인다
		"skew": float(over.get("skew", 1.0)),
		# 1.0 = 그림이 오른쪽을 향한다(기본), -1.0 = 왼쪽을 향해 그려져 뒤집어야 한다
		"flip": float(over.get("flip", 1.0)),
		# -1.0 = 세로로 뒤집는다 — 솟는 그림을 내리꽂는 그림으로
		"flip_v": float(over.get("flip_v", 1.0)),
		# 도(degree). **영웅이 보는 쪽을 따라 부호가 뒤집힌다** — 안 그러면 왼쪽을
		# 볼 때 반대로 기운다. `skew`(찌그러뜨리기)와 다르다: 이건 그림 전체를 돌린다.
		"rot": float(over.get("rot", 0.0)),
		"fps": float(over.get("fps", shape["fx_fps"])),
		# 등급 배율에 **그림별 보정**을 곱한다(FX_OVERRIDE.scale, 1.0 = 그대로).
		# 등급 사다리는 크기로도 읽히므로 tier 값 자체는 안 건드린다 — 그림이
		# 캔버스를 얼마나 채우느냐가 자산마다 다를 뿐이다.
		"scale": float(tier["scale"]) * float(over.get("scale", 1.0)),
		"echo": int(tier["echo"]),
		"shake": float(tier["shake"]),
	}


static func rarity_of(key: String) -> Dictionary:
	return GachaDefs.rarity(split(key)[1])


# 위력 배수 = 형태 기본 x 등급 x 레벨. 곱셈으로 쌓는 이유: 등급을 올려도, 레벨을
# 올려도 체감이 같은 비율로 붙어야 "무엇을 키울까"가 취향 문제로 남는다.
# **`as` 로 동작을 옮긴 스킬은 위력도 같이 옮긴다**(RULES.power). 형태 위력은
# "단일 2.2 / 광역 1.4 / 장판 0.9" 로 **대상 수의 값**이다 — 동작만 광역으로 바꾸고
# 위력을 단일에 두면 그 값을 안 치르고 광역이 된다(핏빛 창 주석의 숫자).
static func power(key: String, lv: int) -> float:
	return float(rule_of(key).get("power", shape_of(key)["power"])) \
		* float(rarity_of(key)["power"]) \
		* (1.0 + LV_POWER * float(maxi(0, lv)))


# 화면에 적는 역할(단일/광역/버프)은 **동작**을 따른다. 형태 표를 그대로 읽으면
# `as` 로 옮긴 스킬이 "단일"이라고 적힌 채 둘을 때린다 — 글자가 거짓말이 된다.
static func role_of(key: String) -> String:
	return str(SHAPES[behavior_of(key)]["role"])


# 자동 장착·정렬이 쓰는 "세기". 등급만 보지 않는 이유: 커먼을 5레벨까지 올린 게
# 갓 뽑은 레어보다 셀 수 있는데, 등급으로만 고르면 그걸 빼고 낀다.
#
# 가호는 피해가 0이라 power 로는 서로 못 가른다 — 그때만 등급·레벨로 잰다.
static func rank(key: String, lv: int) -> float:
	var p := power(key, lv)
	if p > 0.0:
		return p
	return float(rarity_of(key)["power"]) * (1.0 + LV_POWER * float(maxi(0, lv)))


# 쿨다운은 **레벨마다 깎지 않는다.** 매 레벨 깎으면 후반에 스킬이 상시 발동이 되고
# 기본 공격이 사라진다. 정해진 두 지점에서만 계단으로 내린다.
static func cooldown(key: String, lv: int) -> float:
	var cut := 0.0
	for step in LV_CD_STEPS:
		if lv >= int(step):
			cut += LV_CD_CUT
	# 위력과 같은 이유로 쿨타임도 `as` 를 따라간다(RULES.cooldown) — 형태의
	# "단일 7초 / 광역 13초 / 장판 19초"는 **대상 수의 값**이다. 다섯을 한 번에
	# 때리면서 단일 쿨타임을 쓰면 그 값을 안 치른다.
	return float(rule_of(key).get("cooldown", shape_of(key)["cooldown"])) \
		* maxf(CD_FLOOR, 1.0 - cut)


# ── 가호(ward) 등급 성장 ───────────────────────────────────────────────────
# **가호는 피해가 0이라 power() 로 등급이 안 갈린다.** 그래서 `duration 6.0` ·
# `bonus 0.30` 이 SHAPES 표에서 그대로 복사돼, 레전더리 `불멸의 심장`과 커먼
# `피의 결계`가 **완전히 같은 스킬**이었다 — 소환 풀의 4분의 1(가호 5종)이
# 등급 차이 없이 돌고 있었다.
#
# 축을 둘로 나눈다: **등급은 배수를, 레벨은 지속시간을** 올린다.
# 등급 배수를 rarity power(1.0~5.5)로 곱하면 레전더리가 +165% 가 되는데,
# 23초 쿨다운에 6초 지속이면 평균 +43% 라 다른 형태를 다 눌러 버린다.
# 표로 직접 적어 완만하게 잡았다 — 값을 보고 정할 수 있는 게 낫다.
const WARD_BONUS := [0.30, 0.45, 0.65, 0.90, 1.20]   # 등급별 피해 배수
const WARD_LV_DURATION := 0.3    # 레벨당 지속 +0.3초


static func ward_bonus(key: String) -> float:
	# 스킬이 직접 적을 수 있다(RULES.bonus) — 피의 제단은 진(field)인데 버프로
	# 동작하므로 등급표(WARD_BONUS)의 "가호 에픽" 값이 아니라 제 값을 쓴다.
	var rule := rule_of(key)
	if rule.has("bonus"):
		return float(rule["bonus"])
	var idx := clampi(GachaDefs.rarity_index(str(split(key)[1])), 0, WARD_BONUS.size() - 1)
	return float(WARD_BONUS[idx])


static func ward_duration(key: String, lv: int) -> float:
	# 형태에 duration 이 없으면(격·파) 스킬이 적은 값을 쓴다.
	return float(rule_of(key).get("duration",
		shape_of(key).get("duration", 0.0))) + WARD_LV_DURATION * float(maxi(0, lv))


# 다음 레벨에 드는 조각. 레벨이 오를수록 무거워진다.
static func shard_cost(lv: int) -> int:
	return SHARD_PER_LV * (maxi(0, lv) + 1)


# 승급 결과 키. **형태는 그대로, 등급만 한 칸 위.** 최고 등급이면 빈 문자열.
# 형태를 바꾸면 "격을 올렸는데 버프가 나왔다"가 되어 조합이 도박이 된다.
static func promote_key(key: String) -> String:
	var sr := split(key)
	var idx := GachaDefs.rarity_index(str(sr[1]))
	if idx >= GachaDefs.SKILL_TOP_INDEX:
		return ""
	return key_of(str(sr[0]), str(GachaDefs.RARITIES[idx + 1]["key"]))


# ── 조합 버프 ──────────────────────────────────────────────────────────────
# 이게 없으면 장착은 "제일 센 것 6개"라서 결정이 아니다.
# **모으기와 펼치기가 둘 다 답이어야** 조합이 성립한다 — 한쪽만 이득이면 그건 정답이다.
const COMBO_SAME_2 := 0.15   # 같은 형태 2개: 그 형태 위력 +15%
const COMBO_SAME_3 := 0.30   # 3개: +30%
const COMBO_ALL_SHAPES := 0.08   # 네 형태를 모두 장착: 전 스탯 +8%


# keys: 장착 중인 스킬 키 목록. 형태별 위력 보정을 돌려준다.
static func combo_power(keys: Array) -> Dictionary:
	var count := {}
	for k in keys:
		var shape := str(split(str(k))[0])
		count[shape] = int(count.get(shape, 0)) + 1
	var out := {}
	for shape_key in count:
		var n := int(count[shape_key])
		out[shape_key] = COMBO_SAME_3 if n >= 3 else (COMBO_SAME_2 if n == 2 else 0.0)
	return out


# 네 형태를 모두 갖췄을 때의 전 스탯 보너스. 없으면 0.
static func combo_spread(keys: Array) -> float:
	var seen := {}
	for k in keys:
		seen[str(split(str(k))[0])] = true
	return COMBO_ALL_SHAPES if seen.size() >= SHAPE_ORDER.size() else 0.0
