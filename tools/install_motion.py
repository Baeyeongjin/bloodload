# -*- coding: utf-8 -*-
# PixelLab animate_image 결과를 모션 폴더에 설치한다. **받기 전에 다 검사한다.**
#
#   python tools/install_motion.py valentino_1 attack=<job-id> dash=<job-id> ...
#   python tools/install_motion.py --check valentino_1        (이미 깔린 것만 재검사)
#
# 왜 도구로 두는가: 여기서 걸러야 할 사고가 이미 셋 났고, 셋 다 게임을 켜야만
# 보였다. 검사는 자산이 들어오는 순간에 있어야 한다.
#
#   1. **프레임이 전부 같은 스틸** - 다운로드 URL 은 `?index=N` 이다. `?frame=N` 은
#      조용히 무시되고 같은 이미지가 온다. 그걸로 뽑아 커밋한 적이 있다(7e13672):
#      프레임 수·크기·사거리 검사를 다 통과하는데 화면에서는 동작이 통째로 없다.
#   2. **애니 도중에 캐릭터가 돌아선다** - 생성기가 "휘두른다"를 몸을 회전시켜
#      표현한다. 코드는 그림이 왼쪽을 본다고 보고 flip_h 로 뒤집으므로, 영웅이
#      제자리에서 회전한다. 사장님: "뒤에서 돌아서 공격하는 모션임?"
#   3. **동작이 캔버스에 안 들어간다** - 32x32 는 잉크가 26~31칸을 차지해서 자세가
#      2~4px 밖에 못 바뀐다. 큰 동작은 64x64 처럼 여백 있는 캔버스에 뽑는다.
import os
import shutil
import sys
import urllib.request
from hashlib import md5

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "anim")
FRAMES = 9              # frame_count 8 -> 결과 9장
# **큰 동작이 필요한 모션.** 여백 캔버스로 뽑아야 하고, 자세 변화를 검사한다.
# idle(숨쉬기)·cast·ward 는 원래 작아야 하는 모션이라 이 규칙을 안 받는다 -
# 숨쉬기가 36px 씩 움직이면 그게 오히려 버그다.
BIG = {"attack", "heavy", "hurt", "dash", "walk", "death", "special"}
# **무기가 뻗는 모션만** 폭으로 잰다. 걷기·피격은 다리·몸이 좌우로 벌어져서 폭이
# 그대로인데도 자세는 크게 바뀐다 - 실측: 방향 고정으로 다시 뽑은 walk 이 폭 4px 인데
# 실루엣은 18% 바뀌었다. 폭으로만 재면 멀쩡한 걷기를 반려한다.
REACH = {"attack", "heavy", "special"}
MIN_SPAN = 10           # 화면 픽셀. 32 캔버스로 뽑으면 3~8 이 나와 걸린다
# 이웃 프레임 사이에 실루엣이 몇 % 바뀌는가. **동작이 있는지의 진짜 지표다.**
# 실측 기준: 32px 예전 판 9~15% / idle(숨쉬기) 5% / 64px 여백 판 18~33%.
# 8 이면 스틸(0%)과 숨쉬기는 걸리고 예전 판도 통과한다 - 하한이지 목표가 아니다.
MIN_CHANGE = 8.0
# 이웃 프레임 사이에 잉크 중심이 튀어도 되는 한계(화면 픽셀). 자동 반전이 자세를
# 어긋나게 붙였는지 잡는다. 정상 모션 실측: idle 0.3 / sweep 1.0 / cast 1.1 /
# ward 0.8 / attack 2.0 / heavy 1.7 - 8 이면 넉넉하면서 진짜 튐은 잡는다.
MAX_JUMP = 8.0
URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"


def ink_box(im):
    return im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()


def facing(im):
    """망토(어두운 붉은색)가 몸 중심의 어느 쪽에 있는가.

    망토는 등 뒤에 있으므로 **양수 = 왼쪽을 본다**(망토가 오른쪽). 원본 그림이
    왼쪽을 보고 코드가 flip_h 로 뒤집으므로, 전 프레임이 양수여야 한다.
    망토가 없는 스킨이면 None 을 돌려주고 검사를 건너뛴다.
    """
    px = im.load()
    w, h = im.size
    cape = ink = [0, 0]
    cape, ink = [0, 0], [0, 0]
    for x in range(w):
        for y in range(h):
            r, g, b, a = px[x, y]
            if a <= 8:
                continue
            ink[0] += x
            ink[1] += 1
            if 55 < r < 150 and r >= g * 1.8 and r >= b * 1.6:
                cape[0] += x
                cape[1] += 1
    if not ink[1] or cape[1] < 8:
        return None
    return cape[0] / cape[1] - ink[0] / ink[1]


def ink_center(im):
    px = im.load()
    w, h = im.size
    sx = n = 0
    for x in range(w):
        for y in range(h):
            if px[x, y][3] > 8:
                sx += x
                n += 1
    return sx / max(1, n)


def autoflip(motion, paths):
    """오른쪽을 보는 프레임만 좌우 반전해 저장한다. 반전한 프레임 번호를 돌려준다.

    왜 이게 맞는가: 생성기는 "뒤로 밀린다"를 **몸을 돌려서** 그린다. 그 프레임에서는
    밀리는 방향도 같이 반대로 그려져 있으므로, 좌우 반전하면 보는 방향과 밀림 방향이
    **둘 다** 제자리로 온다. 그림을 버리지 않고 쓸 수 있다.
    """
    flipped = []
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        v = facing(im)
        if v is not None and v < 0.0:
            im.transpose(Image.FLIP_LEFT_RIGHT).save(p)
            flipped.append(i)
    return flipped


def check(motion, paths, strict_foot=True, flipped=None, skip_face=False):
    """설치 전에 다 본다. 실패는 assert 로 즉시 멈춘다."""
    digests, boxes, faces = [], [], []
    for i, p in enumerate(paths):
        raw = open(p, "rb").read()
        assert len(raw) > 200, \
            "%s f%d 가 %dB - index 범위를 넘겨 빈 자리를 받았다" % (motion, i, len(raw))
        digests.append(md5(raw).hexdigest())
        im = Image.open(p).convert("RGBA")
        w, h = im.size
        assert w >= h and h in (32, 64, 96, 128), "%s f%d 캔버스 %dx%d" % (motion, i, w, h)
        bb = ink_box(im)
        assert bb is not None, "%s f%d 가 통째로 비었다" % (motion, i)
        assert (bb[2] - bb[0]) * (bb[3] - bb[1]) > 60, "%s f%d 잉크가 너무 적다" % (motion, i)
        boxes.append(bb)
        faces.append(facing(im))

    # (1) 스틸 방지
    assert len(set(digests)) == len(digests), \
        "%s: 프레임이 서로 같다 (고유 %d/%d) - ?index= 로 받았는지 확인할 것" \
        % (motion, len(set(digests)), len(digests))

    # (2) 방향 고정 - **망토가 있는 스킨에서만 자동 판정이 된다.**
    #
    # 몹은 망토 같은 표식이 없어서 좌우 대칭 상관으로 재 봤는데 **못 쓴다.**
    # 실측(2026-08-06): 기존 정상 몹 자산의 정규화 점수가 -0.036~+0.055 로 퍼져
    # 있고(ice_wisp -0.036, goblin -0.024 가 정상인데 음수), 실제 반전의 신호 크기는
    # 그 프레임 자기 비대칭과 같다(skeleton f3 은 +0.020 -> -0.020). 두 분포가
    # 겹치므로 임계값을 어디에 두든 오탐이나 누락이 난다.
    #
    # 그래서 몹은 **사람이 대조표를 보고 확인한다.** 여기서 없는 검사를 있는 척하지
    # 않는다 - 통과 도장이 거짓이면 검사가 없는 것보다 나쁘다.
    known = [] if skip_face else         [(i, v) for i, v in enumerate(faces) if v is not None]
    if skip_face:
        print("        [주의] %s: --no-flip - 방향은 대조표로 확인할 것" % motion)
    if not known and not skip_face:
        print("        [주의] %s: 망토가 없어 방향 자동 판정 불가 - 대조표를 볼 것" % motion)
    if known:
        bad = [i for i, v in known if v < 0.0]
        assert not bad, \
            "%s: f%s 에서 캐릭터가 오른쪽을 본다 - 애니 도중에 돌아선다.\n" \
            "        프롬프트에 'STRICT SIDE VIEW, faces LEFT in every frame, never rotates,\n" \
            "        cape stays behind him on the RIGHT side' 를 넣어 다시 뽑을 것.\n" \
            "        측정값: %s" % (motion, ",".join(map(str, bad)),
                                   [round(v, 1) for _, v in known])

    # (3) 자동 반전이 자세를 어긋나게 붙이지 않았는가. 반전은 캔버스 중심 기준이라
    #     잉크가 한쪽으로 치우친 프레임을 뒤집으면 위치가 튄다.
    #
    # **반전이 없었으면 검사하지 않는다.** 무기를 크게 휘두르면 잉크 중심이 정상적으로
    # 8px 넘게 움직인다(오크 실측 36.3 -> 28.2). 반전을 안 했는데 이 검사가 걸리면
    # 멀쩡한 그림을 반려하는 것이다 - 이 검사의 대상은 반전 자국뿐이다.
    scale = 2 if Image.open(paths[0]).width == 32 else 1
    centers = [ink_center(Image.open(p).convert("RGBA")) * scale for p in paths]
    jumps = [abs(centers[i + 1] - centers[i]) for i in range(len(centers) - 1)]
    if jumps and flipped:
        worst = max(jumps)
        assert worst <= MAX_JUMP, \
            "%s: 이웃 프레임 사이에 몸이 %.0f 화면px 튄다 (한계 %.0f) - 자동 반전이\n" \
            "        자세를 어긋나게 붙였다. 그 모션은 방향 고정을 넣어 다시 뽑을 것.\n" \
            "        중심 이동: %s" % (motion, worst, MAX_JUMP,
                                    [round(c, 1) for c in centers])

    # (4) 동작이 읽히는가. 폭(무기 뻗음)과 실루엣 변화(몸 전체) 둘을 본다.
    ws = [(b[2] - b[0]) * 2 for b in boxes]
    hs = [(b[3] - b[1]) * 2 for b in boxes]
    span = max(ws) - min(ws)
    masks = [Image.open(p).convert("RGBA").getchannel("A").point(
        lambda v: 255 if v > 8 else 0) for p in paths]
    rates = []
    for i in range(len(masks) - 1):
        dif = ImageChops.difference(masks[i], masks[i + 1])
        moved = sum(1 for v in dif.getdata() if v > 0)
        ink = sum(1 for v in masks[i].getdata() if v > 0)
        rates.append(100.0 * moved / max(1, ink))
    change = sum(rates) / max(1, len(rates))

    if motion == "death":
        # 눕기는 **높이가 접혀야** 성립한다. 32 캔버스에서는 불가능했던 것.
        assert hs[-1] < hs[0] * 0.7, \
            "death 가 안 누웠다: 높이 %d -> %d (30%% 이상 접혀야 한다)" % (hs[0], hs[-1])
        assert ws[-1] > hs[-1], \
            "death 마지막이 세로로 길다 (폭 %d, 높이 %d) - 서 있는 것과 구분이 안 된다" \
            % (ws[-1], hs[-1])
    else:
        if strict_foot:
            drift = max(b[3] for b in boxes) - min(b[3] for b in boxes)
            assert drift <= 3, "%s: 발 높이가 %d칸 흔들린다" % (motion, drift)
        if motion in REACH:
            assert span >= MIN_SPAN, \
                "%s: 무기 뻗음 변화가 %d 화면px 뿐이다 - 여백 있는 캔버스에 뽑을 것" \
                % (motion, span)
        if motion in BIG:
            assert change >= MIN_CHANGE, \
                "%s: 프레임간 실루엣이 평균 %.0f%% 만 바뀐다 (하한 %.0f%%) - 동작이 안 읽힌다" \
                % (motion, change, MIN_CHANGE)
    return ws, hs, boxes, faces, change


def fetch(job, tmp):
    os.makedirs(tmp, exist_ok=True)
    paths = []
    for i in range(FRAMES):
        p = os.path.join(tmp, "%d.png" % i)
        urllib.request.urlretrieve(URL % (job, i), p)
        paths.append(p)
    return paths


def report(motion, ws, hs, faces, change):
    known = [v for v in faces if v is not None]
    face = "망토 %.1f~%.1f" % (min(known), max(known)) if known else "망토 없음"
    print("%-8s 폭 %3d~%-3d (%2d)  높이 %3d~%-3d  실루엣 %2.0f%%  %s"
          % (motion, min(ws), max(ws), max(ws) - min(ws), min(hs), max(hs),
             change, face))


def main(argv):
    if not argv:
        print(__doc__ or "usage: install_motion.py <skin> motion=<job> ...")
        return 1
    # --no-span: 폭(사거리) 검사를 끈다. **세로·제자리 동작에만 쓴다** —
    # HANDOFF 8-2 의 그 선례다(boss_2 발밑 충격파·boss_3 얼음 가시·boss_4 촉수는
    # 가로 폭이 안 변하는 게 맞다). 긴 드레스처럼 팔이 몸에 붙은 실루엣도 같은
    # 경우라, 세 번 다시 뽑아도 0px 이 나온다. 실루엣 변화 검사는 그대로 걸린다.
    global REACH
    if "--no-span" in argv:
        argv = [a for a in argv if a != "--no-span"]
        REACH = set()
    # --no-flip: 자동 반전을 끈다. **붉은 계열 갑주 스킨에 필수** — facing() 이
    # 어두운 붉은색을 망토로 읽는데, 마왕(용암 갑주)은 몸 전체가 그 색이라
    # 멀쩡한 왼쪽 보기를 오른쪽 보기로 오판해 통째로 뒤집었다(2026-08-24 실측,
    # 사장님: "캐릭터는 오른쪽을 봐야한다"). 끄면 방향은 사람이 눈으로 본다.
    no_flip = "--no-flip" in argv
    if no_flip:
        argv = [a for a in argv if a != "--no-flip"]
    check_only = argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    skin, rest = argv[0], argv[1:]
    tmp_root = os.path.join(ROOT, ".motion_tmp")

    if check_only:
        motions = [d for d in sorted(os.listdir(ANIM)) if d.startswith(skin + "_")]
        for d in motions:
            motion = d[len(skin) + 1:]
            paths = [os.path.join(ANIM, d, "%d.png" % i)
                     for i in range(len(os.listdir(os.path.join(ANIM, d))) // 2 or 1)]
            paths = [p for p in paths if os.path.exists(p)]
            if len(paths) < 2:
                continue
            ws, hs, _, faces, ch = check(motion, paths, strict_foot=False)
            report(motion, ws, hs, faces, ch)
        print("전부 통과")
        return 0

    jobs = dict(a.split("=", 1) for a in rest)
    for motion, job in jobs.items():
        # `모션=<job>:air` — 공중 모션(점프 내려찍기). 발 고정 검사를 끄는 게
        # 아니라 **뒤집는다**: 발이 6칸도 안 뜨면 점프가 아니라 실패다.
        airborne = job.endswith(":air")
        if airborne:
            job = job[:-4]
        paths = fetch(job, os.path.join(tmp_root, motion))
        # **발 기준선 정렬** — 시드가 캔버스 어디에 있었든, f0 의 잉크 밑단을
        # 발렌티노 규격(64 캔버스 48 / 32 캔버스 32)으로 옮기고 같은 오프셋을
        # 전 프레임에 적용한다. 2026-08-24 실측: edit_image 로 만든 64 시드가
        # 몸을 위 절반에 놓아 스킨 4종이 공격 때 16px 위로 순간이동했다.
        from PIL import Image as _Im
        _f0 = _Im.open(paths[0]).convert("RGBA")
        _target = 48 if _f0.height == 64 else 32
        _bb = ink_box(_f0)
        _dy = _target - _bb[3]
        if _dy != 0:
            for _p in paths:
                _im = _Im.open(_p).convert("RGBA")
                _out = _Im.new("RGBA", _im.size, (0, 0, 0, 0))
                _out.paste(_im, (0, _dy))
                _out.save(_p)
            print("%-8s 발 기준선 %+dpx 이동" % (motion, _dy))
        # **뻗는 방향 통일** — f0 대비 잉크가 오른쪽으로 확장되면 생성기가
        # 오른쪽 보기로 그린 것이다(원본 규격은 왼쪽 보기). 기하 판정이라
        # 색 기반 autoflip 과 달리 갑주 색에 안 속는다. 2026-08-24 실측:
        # --no-flip 으로 깐 스킨 4종 15모션이 몬스터 반대쪽을 때렸다.
        _b0 = ink_box(_Im.open(paths[0]).convert("RGBA"))
        _L = _R = 0
        for _p in paths[1:]:
            _b = ink_box(_Im.open(_p).convert("RGBA"))
            _L = max(_L, _b0[0] - _b[0])
            _R = max(_R, _b[2] - _b0[2])
        if _R > _L + 4:
            for _p in paths:
                _Im.open(_p).convert("RGBA").transpose(
                    _Im.FLIP_LEFT_RIGHT).save(_p)
            print("%-8s 오른쪽으로 뻗어 좌우 반전 (L%d/R%d)" % (motion, _L, _R))
        flips = [] if no_flip else autoflip(motion, paths)
        if flips:
            print("%-8s f%s 를 좌우 반전했다 (생성기가 돌려 그린 프레임)"
                  % (motion, ",".join(map(str, flips))))
        # **가로 중심 정렬** — f0 잉크 중심을 캔버스 중심으로. 반전은 캔버스
        # 중심 기준 미러라 치우친 시드를 반대쪽으로 옮겨 놓는다(2026-08-24
        # 실측: 스킨 12모션이 15~17px 옆으로 순간이동). 같은 dx 를 전 프레임에
        # 적용하고, 잘리면 양쪽을 똑같이 늘려 중심을 지킨다.
        _f0c = _Im.open(paths[0]).convert("RGBA")
        _bbc = ink_box(_f0c)
        _dx = _f0c.width // 2 - (_bbc[0] + _bbc[2]) // 2
        if abs(_dx) > 2:
            _pad = 0
            for _p in paths:
                _b = ink_box(_Im.open(_p).convert("RGBA"))
                _pad = max(_pad, -(_b[0] + _dx),
                           _b[2] + _dx - (_f0c.width - 1))
            _pad = max(0, (_pad + 1) // 2 * 2)
            for _p in paths:
                _im = _Im.open(_p).convert("RGBA")
                _out = _Im.new("RGBA",
                    (_im.width + 2 * _pad, _im.height), (0, 0, 0, 0))
                _out.paste(_im, (_dx + _pad, 0))
                _out.save(_p)
            print("%-8s 가로 중심 %+dpx 이동 (캔버스 +%d)"
                  % (motion, _dx, 2 * _pad))
        if airborne:
            from PIL import Image as _I
            feet = [ink_box(_I.open(pp).convert("RGBA"))[3] for pp in paths]
            lift = max(feet) - min(feet)
            assert lift >= 6,                 "%s: 공중 모션인데 발이 %d칸만 뜬다 - 점프가 안 그려졌다" % (motion, lift)
        ws, hs, _, faces, ch = check(motion, paths, flipped=flips,
                                     strict_foot=not airborne,
                                     skip_face=no_flip)
        dst = os.path.join(ANIM, "%s_%s" % (skin, motion))
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(dst):
            os.remove(os.path.join(dst, f))
        for i, p in enumerate(paths):
            shutil.copy(p, os.path.join(dst, "%d.png" % i))
        report(motion, ws, hs, faces, ch)
    shutil.rmtree(tmp_root, ignore_errors=True)
    print("설치 완료 - godot --headless --path . --import 를 돌릴 것")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
