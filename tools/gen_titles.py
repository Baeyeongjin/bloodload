# 칭호 표(TitleDefs.TITLES)를 생성한다.
#
# 왜 도구인가: 사장님이 12개는 너무 적다고 해서 100개로 늘렸는데, 손으로 쓰면
# 조건 계단이 어긋나고(같은 축의 두 칭호가 순서를 뒤집는다) 보상이 난이도와
# 따로 논다. 축마다 계단을 세우고 값을 계산해 뽑는다 — 곡선을 바꾸면 다시 돌린다.
#
#     python tools/gen_titles.py > /tmp/titles.txt   # 눈으로 확인
#     python tools/gen_titles.py --write             # TitleDefs.gd 에 심는다
import io
import re
import sys

# 조건 축과 계단. **각 축이 그 축만으로 오르는 시리즈**를 만든다 —
# 유저가 "이걸 더 하면 저게 열린다"를 한 축에서 읽을 수 있어야 한다.
#
# (kind, [계단], 이름 짓는 법, 주는 능력치)
NUM = {1: "첫", 3: "세", 5: "다섯", 8: "여덟", 10: "열", 12: "열두",
       15: "열다섯", 20: "스무", 25: "스물다섯", 30: "서른", 40: "마흔",
       50: "쉰", 60: "예순", 70: "일흔", 80: "여든", 100: "백"}


def kor(n):
    return NUM.get(n, str(n))


SERIES = [
    # 본편 구간 — 가장 굵은 축이라 계단이 제일 많다.
    ("stage", [10, 20, 30, 50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500],
     lambda n: "%d구간의 주인" % n, "damage"),
    # 미궁 층
    ("floor", [5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100],
     lambda n: "%s 층의 어둠" % kor(n), "tough"),
    # 누적 처치
    ("kills", [100, 500, 1000, 3000, 10000, 30000, 100000, 300000,
               1000000, 3000000],
     lambda n: "%s의 사냥" % _big(n), "speed"),
    # 도감 발견 종수
    ("species", [3, 5, 8, 10, 12, 15, 18, 20, 22],
     lambda n: "%s 종의 기록" % kor(n), "gold"),
    # 도감 지식 합계
    ("knowledge", [5, 10, 20, 30, 45, 60, 80, 100, 130],
     lambda n: "지식 %d의 학자" % n, "damage"),
    # 보유 스킬 종수
    ("skills", [3, 6, 9, 12, 14, 16, 18, 20],
     lambda n: "%s 개의 손" % kor(n), "speed"),
    # 혈맥 노드
    ("traits", [3, 6, 9, 12, 16, 20, 24, 28],
     lambda n: "핏줄 %d갈래" % n, "gold"),
    # 영웅 레벨
    ("hero", [5, 10, 15, 25, 40, 60, 80, 100, 120],
     lambda n: "%d레벨의 군주" % n, "tough"),
]

# 두 축을 함께 요구하는 칭호. 시리즈만 있으면 "한 축만 파도 다 딴다"가 되어
# 도감·미궁·혈맥을 안 건드리는 사람이 생긴다.
PAIRS = [
    ("깨어난 군주", "damage", [("stage", 10), ("kills", 100)]),
    ("피맛", "gold", [("kills", 500), ("species", 5)]),
    ("미궁의 문", "tough", [("floor", 5), ("stage", 30)]),
    ("선혈 학자", "damage", [("knowledge", 10), ("species", 10)]),
    ("여섯 개의 손", "speed", [("skills", 6), ("hero", 10)]),
    ("백 걸음", "damage", [("stage", 100), ("hero", 25)]),
    ("스무 층의 어둠", "tough", [("floor", 20), ("kills", 3000)]),
    ("핏줄 각성", "gold", [("traits", 3), ("floor", 10)]),
    ("이백 고지", "damage", [("stage", 200), ("knowledge", 30)]),
    ("학살자", "speed", [("kills", 10000), ("species", 15)]),
    ("혈맥의 주인", "tough", [("traits", 12), ("floor", 60)]),
    ("군림하는 왕", "damage", [("stage", 450), ("floor", 80)]),
    ("탐식", "gold", [("kills", 30000), ("traits", 9)]),
    ("불면", "speed", [("hero", 40), ("skills", 12)]),
    ("옛 이름", "damage", [("species", 18), ("knowledge", 45)]),
    ("깊은 곳의 것", "tough", [("floor", 50), ("hero", 40)]),
    ("피의 계보", "gold", [("traits", 16), ("knowledge", 60)]),
    ("삼백의 밤", "damage", [("stage", 300), ("floor", 40)]),
    ("끝의 문턱", "tough", [("stage", 400), ("traits", 20)]),
    ("모든 것을 본 자", "damage", [("species", 22), ("knowledge", 100)]),
    ("영원한 밤", "tough", [("stage", 500), ("hero", 100)]),
]


def _big(n):
    if n >= 1000000:
        return "백만"
    if n >= 100000:
        return "십만"
    if n >= 10000:
        return "만"
    if n >= 1000:
        return "천"
    return str(n)


# 조건이 얼마나 깊은가 → 공짜 훈련 레벨. 계단의 몇 번째인지로 잰다.
def levels_for(step_index, total_steps):
    t = step_index / max(1, total_steps - 1)
    return 2 + int(round(t * 8))          # 2 .. 10


def build():
    out = []
    used = set()

    def add(tid, name, stat, levels, conds):
        assert tid not in used, "id 충돌: %s" % tid
        used.add(tid)
        out.append((tid, name, stat, levels, conds))

    for kind, steps, namer, stat in SERIES:
        for i, n in enumerate(steps):
            add("%s%d" % (kind, n), namer(n), stat,
                levels_for(i, len(steps)), [(kind, n)])

    for i, (name, stat, conds) in enumerate(PAIRS):
        # 짝 칭호는 두 축을 요구하므로 한 단계 더 준다.
        deep = max(_depth(k, n) for k, n in conds)
        add("pair%d" % i, name, stat, min(10, deep + 1), conds)
    return out


def _depth(kind, n):
    for k, steps, _, _ in SERIES:
        if k == kind:
            below = [i for i, s in enumerate(steps) if s <= n]
            return levels_for(below[-1] if below else 0, len(steps))
    return 2


def render(rows):
    lines = ["const TITLES := ["]
    for tid, name, stat, levels, conds in rows:
        cs = ", ".join('{"kind": "%s", "n": %d}' % (k, n) for k, n in conds)
        lines.append('\t{"id": "%s", "name": "%s", "stat": "%s", "levels": %d,'
                     % (tid, name, stat, levels))
        lines.append('\t\t"conds": [%s]},' % cs)
    lines.append("]")
    return "\n".join(lines)


def main():
    rows = build()
    text = render(rows)
    if "--write" not in sys.argv:
        print(text)
        print("\n총 %d개" % len(rows))
        return
    p = "TitleDefs.gd"
    s = io.open(p, encoding="utf-8").read()
    s2 = re.sub(r"const TITLES := \[.*?\n\]", text, s, count=1, flags=re.S)
    assert s2 != s, "TITLES 블록을 못 찾았다"
    io.open(p, "w", encoding="utf-8").write(s2)
    print("TitleDefs.gd 에 %d개를 심었다" % len(rows))


if __name__ == "__main__":
    main()
