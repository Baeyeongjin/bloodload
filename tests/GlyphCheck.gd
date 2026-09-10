extends SceneTree

# 폰트에 **없는 글리프**를 잡는다 (사장님 2026-09-10: "웹에서 깨지는 이모티콘").
#
# 왜 웹에서만 깨지나: `Type.PATH` 한 장으로 끝내고 폴백을 안 둔다. 데스크톱은
# TextServer 가 **OS 폰트로 자동 폴백**해서 없는 글자도 그려 주지만, 웹 빌드에는
# 그 시스템 폰트가 없다 — 그래서 PC 에서 멀쩡하던 기호가 폰에서 두부가 된다.
# 2026-09-10 에 13종이 그 상태였다(— … » ─ + » · ○ ● * - O 書).
#
# **표를 손으로 들고 있지 않는다.** 소스의 문자열 리터럴을 직접 훑어서 화면에
# 나갈 수 있는 비ASCII 문자를 모으고, 폰트가 그릴 수 있는지 하나씩 묻는다 —
# 이래야 **새 기호를 써도 자동으로** 걸린다(손으로 적은 표는 반드시 낡는다).

func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("안 끝났다")
		quit(1))
	var f := Type.font()
	assert(f != null, "폰트를 못 읽었다")

	# 핵심(한글·ASCII)이 없으면 UI 가 통째로 두부다 — 먼저 못 박는다.
	for s in ["가", "혈", "액", "A", "0"]:
		assert(f.has_char(s.unicode_at(0)),
			"폰트에 %s 가 없다 — UI 가 통째로 깨진다" % s)

	var re := RegEx.create_from_string('"((?:[^"\\\\]|\\\\.)*)"')
	var bad := {}          # 문자 -> 처음 본 파일
	var seen := {}         # 문자 -> true (쓰이는 기호 전부)
	for path in _gd_files():
		var src := FileAccess.get_file_as_string(path)
		if src.is_empty():
			continue
		for line in src.split("\n"):
			# 주석의 기호는 화면에 안 나간다.
			if line.strip_edges().begins_with("#"):
				continue
			for m in re.search_all(line):
				for ch in m.get_string(1):
					var c: int = ch.unicode_at(0)
					if c < 128 or _hangul(c):
						continue
					seen[ch] = true
					if not f.has_char(c) and not bad.has(ch):
						bad[ch] = path.get_file()

	var names := PackedStringArray()
	for ch in seen:
		names.append("%s(U+%04X)" % [str(ch), str(ch).unicode_at(0)])
	print("문자열에 쓰인 기호 %d 종: %s" % [seen.size(), " ".join(names)])

	if not bad.is_empty():
		for ch in bad:
			printerr("  없음: %s U+%04X  (%s)"
				% [str(ch), str(ch).unicode_at(0), str(bad[ch])])
	assert(bad.is_empty(),
		"폰트에 없는 기호를 쓰고 있다 — 웹에서 두부가 된다: %s" % str(bad.keys()))
	print("GlyphCheck OK")
	quit()


func _hangul(c: int) -> bool:
	return (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E)


# 저장소 루트의 .gd 전부. tests/ 는 화면에 안 나가므로 뺀다.
func _gd_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://")
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".gd"):
			out.append("res://" + n)
		n = d.get_next()
	d.list_dir_end()
	return out
