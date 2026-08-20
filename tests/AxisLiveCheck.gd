extends SceneTree
# 화면이 "받는 중"이라 적는 축이 **정말로 전투 계산에 붙는가**.
# 도감 보너스와 펫 tough/speed 가 표시만 되고 실제로는 0이던 것을 잡는다
# (2026-08-20 발견 — 도감 공격 +30%, 펫 로스터 절반이 죽어 있었다).


func _init() -> void:
	await process_frame
	var scene: Node = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 1) 도감 이정표 — 장비를 본 적 없으면 0, 다 보면 값이 붙어야 한다.
	scene.gear_seen = {}
	scene.skill_owned = {}
	var d0: float = scene.damage()
	var h0: float = scene.max_hp()
	var g0: float = scene.gold_mult()
	for k in scene._lore_keys("gear"):
		scene.gear_seen[str(k)] = true
	for k in scene._lore_keys("skill"):
		scene.skill_owned[str(k)] = 0
	assert(scene.damage() > d0, "도감 수집이 공격에 안 붙는다")
	assert(scene.max_hp() > h0, "도감 수집이 체력에 안 붙는다")
	assert(scene.gold_mult() > g0, "도감 수집이 혈액에 안 붙는다")
	var lore_dmg: float = scene.damage() / d0
	assert(lore_dmg > 1.05, "도감 공격 몫이 너무 작다: x%.3f" % lore_dmg)

	# 2) 펫 — tough/speed 버프가 실제로 먹는가(로스터 절반이 이 둘이다).
	scene.pets_got = {}
	scene.pet_worn = ""
	var hp_bare: float = scene.max_hp()
	var iv_bare: float = scene.attack_interval()
	var tough_pet := ""
	var speed_pet := ""
	for p in PetDefs.PETS:
		var st := str(p["stat"])
		if st == "tough" and tough_pet == "":
			tough_pet = str(p["id"])
		if st == "speed" and speed_pet == "":
			speed_pet = str(p["id"])
	assert(tough_pet != "" and speed_pet != "", "표에 tough/speed 펫이 없다")
	scene.pets_got[tough_pet] = PetDefs.MAX_STAR
	scene.pet_lv[tough_pet] = 10
	scene.pet_worn = tough_pet
	assert(scene.max_hp() > hp_bare, "펫 체력 버프가 안 붙는다(로스터 6종)")
	scene.pets_got.erase(tough_pet)
	scene.pets_got[speed_pet] = PetDefs.MAX_STAR
	scene.pet_lv[speed_pet] = 10
	scene.pet_worn = speed_pet
	assert(scene.attack_interval() < iv_bare, "펫 공속 버프가 안 붙는다(로스터 6종)")

	print("AxisLiveCheck OK  (도감 공격 x%.2f)" % lore_dmg)
	quit()
