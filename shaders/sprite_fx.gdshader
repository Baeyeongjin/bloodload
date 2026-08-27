shader_type canvas_item;

// 몹·영웅 스프라이트 효과 둘. CanvasItem 은 재질을 하나만 가지므로 한 파일이다.
//
//  1) 피격 번쩍임 — 색을 **덮어쓴다**
//  2) 사망 디졸브 — 알파를 **픽셀 단위로 지운다**
//
// 왜 self_modulate(곱셈)가 아닌가: 곱하는 값은 원래 색에 딸려간다. 미궁 깊이
// 색(depth_tint, 최대 0.78배)이 씌워진 몹은 7을 곱해도 덜 밝았고, 그래서 보스와
// 잡몹에 서로 다른 배수를 줘야 했다. 덮어쓰면 몹이 밝든 어둡든 결과가 같다.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 덩어리 하나의 지름(소스 픽셀). 32x32 몹이면 5면 가로로 여섯 덩어리쯤 된다.
uniform float blob_size : hint_range(1.0, 16.0) = 5.0;
// 타들어가는 경계의 두께. 없으면 그냥 구멍이 뚫리는 것으로 읽힌다.
uniform vec4 burn_color : source_color = vec4(0.86, 0.18, 0.20, 1.0);
uniform float burn_width : hint_range(0.0, 0.5) = 0.09;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// **부드러운** 노이즈여야 한다. 픽셀마다 독립인 흰 노이즈를 쓰면 문턱 띠가
// 스프라이트 전체에 흩어져서 '타는 경계'가 아니라 색종이가 뿌려진 것처럼
// 보인다 — 실측으로 확인했다. 값이 이웃과 이어져야 띠가 선으로 뭉친다.
//
// 그러면서도 **노이즈 텍스처는 안 쓴다**. 좌표를 소스 픽셀 격자에 먼저
// 끊어(floor) 넣으므로 한 도트 안은 전부 같은 값이다 — 도트가 뭉개지지 않는다.
float blob_noise(vec2 cell) {
	vec2 p = cell / blob_size;
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			   mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
			   f.y);
}

void fragment() {
	// **texture() 를 다시 읽지 않는다.** COLOR 는 들어올 때 이미
	// `텍스처 x modulate x 그릴 때 준 tint` 다 — 여기서 TEXTURE 를 새로 샘플링해
	// 덮어쓰면 미궁 깊이 색·버프 tint·처형 붉은 물듦이 통째로 사라진다.
	// (MODULATE 라는 built-in 은 4.7 canvas_item 에 없다 — 실측으로 확인했다.)
	vec4 c = COLOR;

	if (c.a < 0.999) {
		// **알파가 곧 디졸브 진행도다.** Foe 가 죽을 때 tint 알파를 떨어뜨리는데,
		// 그걸 반투명으로 쓰지 않고 "얼마나 지울지"로 읽는다. 배선이 안 늘어난다.
		// 도트는 반투명해지면 안 된다 — 색 하나하나가 고른 값인데 50% 알파로
		// 깔리면 뒷배경과 섞여 죽은 색이 된다. 지우되 남은 픽셀은 온전히 둔다.
		// (영웅은 알파가 안 떨어져서 여기 안 들어온다.)
		float cut = 1.0 - c.a;
		float n = blob_noise(floor(UV / TEXTURE_PIXEL_SIZE));
		if (n < cut) {
			discard;
		}
		if (n < cut + burn_width) {
			c.rgb = burn_color.rgb;
		}
		c.a = 1.0;
	}

	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
