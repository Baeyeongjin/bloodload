# 상점 UI 시트를 조각 png 로 자른다. PixelLab ui_asset 은 조각들을 한 장에
# 그려 주므로, 알파 행/열 투영으로 띄어진 덩어리를 찾아 개별 저장한다.
# 재뽑기가 잦아서 도구로 둔다 — 시트가 바뀌면 그냥 다시 돌리면 된다.
import sys
from PIL import Image

BASE = "assets/ui/shop"


def bands(mask, along):
    """along=0: 행 투영(세로 분할), along=1: 열 투영(가로 분할). (시작, 끝) 목록."""
    size = mask.size[1 - along]
    other = mask.size[along]
    px = mask.load()
    filled = []
    for i in range(size):
        # PIL 은 px[x, y] — 행 투영(i=y)이면 j 가 x 다.
        row_has = any(
            (px[j, i] if along == 0 else px[i, j]) > 8 for j in range(other))
        filled.append(row_has)
    out = []
    start = None
    for i, f in enumerate(filled):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, size))
    return out


def crop_trim(im, box):
    part = im.crop(box)
    a = part.getchannel("A")
    bb = a.getbbox()
    return part.crop(bb) if bb else part


def slice_v(im, names):
    """세로로 쌓인 조각들 — 행 투영으로."""
    a = im.getchannel("A")
    rows = bands(a, along=0)
    assert len(rows) == len(names), f"{len(names)}조각이어야 하는데 {len(rows)}개"
    for (y0, y1), name in zip(rows, names):
        crop_trim(im, (0, y0, im.width, y1)).save(f"{BASE}/{name}.png")
        print(name, "ok")


# 탭 전용 세트(사장님 2026-08-13: "각각 UI 다르게") — 시트마다 세로로 쌓인
# 조각들이라 행 투영으로 잘린다. 조각 수가 다르면 assert 가 걸린다(재뽑기 신호).
#
# **몸판·버튼은 2차본이다** (사장님: "너무 화려함, 간단한 버전으로") — 1차
# *_card 시트는 화려한 쪽이라 지금 안 쓴다(재뽑기 원본으로 남겨 둘 뿐).
# 여기 적힌 것만 잘린다: 안 적힌 시트를 자르면 담백한 판이 화려한 걸로 되돌아간다.
SETS = "assets/ui/sets"
SET_SHEETS = {
    "forge_body3": ["forge_body"],
    "forge_btn2": ["forge_button", "forge_pill"],
    "forge_tabs": ["forge_tab_on", "forge_tab_off"],
    "astro_body2": ["astro_body"],
    "astro_btn2": ["astro_button", "astro_pill"],
    "astro_tabs": ["astro_tab_on", "astro_tab_off"],
    "gate_card": ["gate_row", "gate_button", "gate_pill"],
    "gate_tabs": ["gate_tab_on", "gate_tab_off"],
    # 사슬 카드는 세로로 늘리면 사슬이 판 가운데를 먹는다 — 넓은 판·긴 띠는
    # 사슬 없는 전용 자산으로 따로 뽑았다(사장님: "깨지는 부분은 신규 UI").
    "gate_bars": ["gate_bar", "gate_panel"],
}


# 임무판(duty, 양피지)과 도감(tome, 가죽책) — 2026-08-18.
#
# 두 시트의 구조가 같다: 3행, 열 구성 1/1/4 (실측). 위 세트들처럼 행만 나뉜 게
# 아니라 **행 안에서 또 열로 나뉘어** 있어서 격자로 읽는다.
# 이름은 왼쪽 위에서 오른쪽 아래 순서다 — 시트를 다시 뽑으면 순서만 확인하면 된다.
SHEET5 = {
    "duty": ["body", "band", "card", "pill", "tab_on", "tab_off"],
    "tome": ["body", "band", "card", "pill", "tab_on", "tab_off"],
    # 둥지(펫 탭, 2026-08-18) — 5행 1/1/4/1/1. 행2가 [card, tab_on, tab_off,
    # pill] 이고 행3 작은 알약, 행4 원형 배지는 지금 안 쓴다(여분).
    "nest": ["body", "band", "card", "tab_on", "tab_off", "pill",
             "pill2", "badge"],
    # 핏빛 계약(2026-08-18) — 5행 2/1/5/2/2. 검은 철판에 핏자국 테두리.
    # 여분(body2·cell·cell2·pill2·pill3·badge)은 지금 안 쓴다.
    "oath": ["body", "body2", "band", "card", "tab_on", "tab_off",
             "cell", "cell2", "pill", "pill2", "pill3", "badge"],
}


def slice_grid(prefix, names):
    """행 투영으로 줄을 찾고, 줄 안에서 열 투영으로 조각을 뗀다.

    **시트는 장식 없이 뽑는다.** 판은 NinePatch 로 늘려 쓰는데 인장·리본이
    박혀 있으면 같이 늘어나고 탭에서는 글자를 덮는다(실측 캡처). 한 번 자동으로
    지워 봤는데 확산 자국이 더 지저분했다 — 프롬프트에서 빼는 쪽이 답이다.
    붉은 강조는 글자 색(Main.DUTY_RED)이 맡는다.
    """
    im = Image.open(f"{SETS}/{prefix}_sheet.png").convert("RGBA")
    k = 0
    for (y0, y1) in bands(im.getchannel("A"), along=0):
        sub = im.crop((0, y0, im.width, y1))
        for (x0, x1) in bands(sub.getchannel("A"), along=1):
            if k >= len(names):
                return
            crop_trim(sub, (x0, 0, x1, sub.height)).save(
                f"{SETS}/{prefix}_{names[k]}.png")
            k += 1
    assert k == len(names), f"{prefix}: {len(names)}조각이어야 하는데 {k}개"


def slice_sets():
    global BASE
    keep = BASE
    BASE = SETS
    for sheet, names in SET_SHEETS.items():
        slice_v(Image.open(f"{SETS}/{sheet}.png").convert("RGBA"), names)
    for prefix, names in SHEET5.items():
        slice_grid(prefix, names)
    BASE = keep


def main():
    slice_sets()
    # 세로 카드: 제목 띠 / 그림 창 / 가격 띠
    slice_v(Image.open(f"{BASE}/card_v.png").convert("RGBA"),
            ["card_title", "card_art", "card_price"])

    # 와이드: 리본 / 카드 몸 / 알약
    slice_v(Image.open(f"{BASE}/card_w.png").convert("RGBA"),
            ["ribbon", "wide_body", "pill"])

    # 배지 시트: 위(배지·도장) / 아래(자물쇠·탭2) — 밴드 안에서 열 투영으로.
    im = Image.open(f"{BASE}/badges.png").convert("RGBA")
    a = im.getchannel("A")
    rows = bands(a, along=0)
    assert len(rows) >= 2, f"배지 시트 행이 {len(rows)}개"
    top, bottom = rows[0], rows[-1]

    top_im = im.crop((0, top[0], im.width, top[1]))
    cols = bands(top_im.getchannel("A"), along=1)
    assert len(cols) == 2, f"윗줄 열이 {len(cols)}개"
    crop_trim(top_im, (cols[0][0], 0, cols[0][1], top_im.height)).save(
        f"{BASE}/badge_star.png")
    crop_trim(top_im, (cols[1][0], 0, cols[1][1], top_im.height)).save(
        f"{BASE}/stamp_soldout.png")

    bot_im = im.crop((0, bottom[0], im.width, bottom[1]))
    cols = bands(bot_im.getchannel("A"), along=1)
    assert len(cols) == 2, f"아랫줄 열이 {len(cols)}개"
    crop_trim(bot_im, (cols[0][0], 0, cols[0][1], bot_im.height)).save(
        f"{BASE}/lock.png")
    right = bot_im.crop((cols[1][0], 0, cols[1][1], bot_im.height))
    tabs = bands(right.getchannel("A"), along=0)
    assert len(tabs) == 2, f"탭이 {len(tabs)}개"
    crop_trim(right, (0, tabs[0][0], right.width, tabs[0][1])).save(
        f"{BASE}/tab_on.png")
    crop_trim(right, (0, tabs[1][0], right.width, tabs[1][1])).save(
        f"{BASE}/tab_off.png")
    print("badges ok")


if __name__ == "__main__":
    main()
