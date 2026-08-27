shader_type canvas_item;

// 피격 번쩍임. 예전엔 self_modulate 로 밝기를 곱했는데(잡몹 x7, 보스 x3),
// **곱셈은 어두운 몹을 못 하얗게 만든다** — 미궁 깊이 색(depth_tint, 최대 0.78배)
// 이 씌워진 몹은 7을 곱해도 덜 밝았다. 보스와 잡몹에 서로 다른 배수를 줘야
// 했던 것도 같은 이유다(사장님 "너무 과해"): 곱하는 값은 원래 색에 딸려간다.
//
// 셰이더는 색을 **덮어쓴다.** 몹이 밝든 어둡든, 깊은 층이든 아니든 결과가 같아서
// 세기 손잡이가 하나로 끝난다.

// 0 이면 원래 색, 1 이면 완전히 flash_color. 코드가 피격 때 넣는다.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// **texture() 를 다시 읽지 않는다.** COLOR 는 fragment 로 들어올 때 이미
	// `텍스처 x modulate` 다 — 여기서 TEXTURE 를 새로 샘플링해 덮어쓰면
	// 미궁 깊이 색과 버프 tint, 사망 페이드(modulate.a)가 통째로 사라진다.
	// (강좌 코드가 texture() 를 읽는 건 modulate 를 안 쓰는 프로젝트라서다.
	//  MODULATE 라는 built-in 은 4.7 canvas_item 에 없다 — 실측으로 확인했다.)
	// 알파는 안 건드린다: 번쩍인다고 실루엣이 커지거나 사라지면 안 된다.
	COLOR = vec4(mix(COLOR.rgb, flash_color.rgb, flash), COLOR.a);
}
