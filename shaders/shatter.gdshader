shader_type particles;

// 스프라이트를 **제 픽셀로** 흩뿌린다. 각 파티클이 제 격자 칸으로 그림을 찍어
// 그 색을 들고 가므로, 터지는 순간에는 구름이 원래 그림이고 흩어지면서 픽셀이
// 날아간다. **새 그림이 0장 든다** — 몹이 서른 종이어도 폭발은 하나로 끝난다.
// (출처: PlayWithFurcifer "Sprite Explosion Effect Using a Particle Shader",
//  docs/ATTACK_FX_RECIPE.md 7장. 원본은 Godot 3 의 vertex() 판이다.)

uniform sampler2D sprite_tex : filter_nearest, source_color;
uniform float sprite_size = 64.0;   // 화면에 그려지는 몸 크기(px)
uniform float burst = 2.4;          // 중심에서 밀어내는 배수
uniform float rise = 90.0;          // 위로 한 번 띄우는 속도
uniform float gravity = 300.0;
uniform int cells = 16;             // 가로·세로 몇 칸으로 쪼갤까


void start() {
	// **격자로 앉힌다.** 무작위로 뿌리면 빈 곳과 뭉친 곳이 생겨 터지는 첫
	// 프레임에 원래 그림이 안 읽힌다 — 그 한 프레임이 이 기법의 전부다.
	int n = max(1, cells);
	float u = (float(INDEX % n) + 0.5) / float(n);
	float v = (float((INDEX / n) % n) + 0.5) / float(n);

	vec4 c = texture(sprite_tex, vec2(u, v));
	// 빈 칸은 아예 안 띄운다. 안 그러면 투명한 사각형이 몸 둘레에 흩어진다.
	ACTIVE = c.a > 0.35;
	COLOR = vec4(c.rgb, 1.0);

	// 원본 그림에서의 자리를 화면 크기로 편다. v 는 아래로 크는 축이라
	// 그대로 두면 위아래가 뒤집힌다.
	vec2 p = vec2(u - 0.5, v - 0.5) * sprite_size;
	// **조각 크기는 여기서 준다.** 노드에 scale 을 걸면 자리(TRANSFORM[3])까지
	// 같이 줄어서 구름이 한 줌으로 뭉친다 — 처음에 그렇게 짰다가 캡처로 봤다.
	float s = sprite_size / float(n);
	TRANSFORM[0].xyz = vec3(s, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, s, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
	TRANSFORM[3].xyz = vec3(p.x, p.y, 0.0);

	// 중심에서 멀수록 빠르게 — 덩어리가 벌어지며 터진다.
	VELOCITY = vec3(p * burst, 0.0);
	VELOCITY.y -= rise;
	CUSTOM.x = 0.0;
}


void process() {
	VELOCITY.y += gravity * DELTA;
	CUSTOM.x += DELTA / max(0.001, LIFETIME);
	// 끝에서 갑자기 사라지지 않게 뒤쪽에서만 옅어진다.
	COLOR.a = clamp((1.0 - CUSTOM.x) * 2.2, 0.0, 1.0);
}
