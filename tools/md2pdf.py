"""마크다운 -> PDF. 설계 문서를 사장님께 보내는 용도다.

풀 마크다운 파서가 아니다 — docs/ 문서가 실제로 쓰는 문법만 본다:
#/##/### 제목, 문단, - 목록, | 표 |, ``` 코드블록, --- 구분선, **굵게**.
그 밖의 문법이 필요해지면 그때 한 줄 더한다(YAGNI).

    python tools/md2pdf.py docs/MONETIZATION_PLAN.md out.pdf

한글은 맑은 고딕(윈도 기본)을 실어 넣는다. 폰트가 없는 PC면 여기서 멈춘다 —
조용히 네모로 찍히는 것보다 낫다.
"""
import re
import sys
from pathlib import Path

from fpdf import FPDF

FONT_DIR = Path("C:/Windows/Fonts")
FONTS = {"": "malgun.ttf", "B": "malgunbd.ttf"}
MARGIN = 16.0
BODY = 9.5
# 표 칸 안은 한 줄이 길어 본문보다 작게. 8 아래로 내리면 화면에서 안 읽힌다.
CELL = 8.0


class Doc(FPDF):
    def header(self):
        pass

    def footer(self):
        self.set_y(-12)
        self.set_font("malgun", "", 7)
        self.set_text_color(130)
        self.cell(0, 6, str(self.page_no()), align="C")


def strip_bold(s):
    return s.replace("**", "")


def bold_runs(s):
    """'a **b** c' -> [('a ', False), ('b', True), (' c', False)]"""
    out = []
    for i, part in enumerate(s.split("**")):
        if part:
            out.append((part, i % 2 == 1))
    return out


def write_rich(pdf, text, size):
    """굵게가 섞인 한 문단. write() 는 줄바꿈을 알아서 한다."""
    for run, is_bold in bold_runs(text):
        pdf.set_font("malgun", "B" if is_bold else "", size)
        pdf.write(size * 0.52, run)
    pdf.ln(size * 0.52)


def table(pdf, rows):
    """| 로 나뉜 표. 칸 폭은 글자 수 비율로 나눈다."""
    usable = pdf.w - MARGIN * 2
    ncol = max(len(r) for r in rows)
    rows = [r + [""] * (ncol - len(r)) for r in rows]
    weights = [max(len(r[c]) for r in rows) or 1 for c in range(ncol)]
    total = sum(weights)
    widths = [max(14.0, usable * w / total) for w in weights]
    # 반올림 누적으로 표가 여백을 넘는 것을 막는다.
    widths = [w * usable / sum(widths) for w in widths]
    pdf.set_font("malgun", "", CELL)
    line_h = CELL * 0.62
    for ri, row in enumerate(rows):
        heights = []
        for c, cell in enumerate(row):
            pdf.set_font("malgun", "B" if ri == 0 else "", CELL)
            n = len(pdf.multi_cell(widths[c], line_h, strip_bold(cell),
                                   dry_run=True, output="LINES"))
            heights.append(max(1, n))
        h = max(heights) * line_h + 1.4
        if pdf.get_y() + h > pdf.h - 18:
            pdf.add_page()
        y0 = pdf.get_y()
        x = MARGIN
        for c, cell in enumerate(row):
            pdf.set_xy(x, y0)
            pdf.set_font("malgun", "B" if ri == 0 else "", CELL)
            pdf.set_fill_color(238, 234, 240) if ri == 0 else pdf.set_fill_color(255)
            pdf.multi_cell(widths[c], line_h, strip_bold(cell), border=0,
                           align="L", fill=True, max_line_height=line_h)
            x += widths[c]
        pdf.set_xy(MARGIN, y0 + h)
        pdf.set_draw_color(206, 200, 210)
        pdf.line(MARGIN, y0 + h - 0.8, MARGIN + usable, y0 + h - 0.8)
    pdf.ln(2.5)


def render(md_path, pdf_path):
    for style, name in FONTS.items():
        if not (FONT_DIR / name).exists():
            sys.exit("폰트가 없다: %s" % (FONT_DIR / name))
    pdf = Doc(format="A4")
    pdf.set_auto_page_break(True, margin=18)
    pdf.set_margins(MARGIN, MARGIN, MARGIN)
    for style, name in FONTS.items():
        pdf.add_font("malgun", style, str(FONT_DIR / name))
    pdf.add_page()

    lines = Path(md_path).read_text(encoding="utf-8").splitlines()
    i = 0
    in_code = False
    code_buf = []
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        if line.startswith("```"):
            in_code = not in_code
            if not in_code:
                pdf.set_font("malgun", "", 8)
                pdf.set_fill_color(244, 242, 246)
                pdf.set_text_color(40)
                for cl in code_buf:
                    pdf.cell(0, 4.4, cl, fill=True, new_x="LMARGIN", new_y="NEXT")
                pdf.ln(2)
                code_buf = []
            i += 1
            continue
        if in_code:
            code_buf.append(raw)
            i += 1
            continue
        if not line:
            pdf.ln(2.2)
            i += 1
            continue
        if line.startswith("|"):
            block = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                # |---|---| 구분줄은 표 데이터가 아니다.
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    block.append(cells)
                i += 1
            table(pdf, block)
            continue
        if line.startswith("---"):
            pdf.ln(1.5)
            pdf.set_draw_color(180, 174, 186)
            pdf.line(MARGIN, pdf.get_y(), pdf.w - MARGIN, pdf.get_y())
            pdf.ln(3.5)
            i += 1
            continue
        if line.startswith("#"):
            level = len(line) - len(line.lstrip("#"))
            text = strip_bold(line.lstrip("# ").strip())
            size = {1: 17.0, 2: 13.0, 3: 10.5}.get(level, 10.0)
            # 새 장(##)은 페이지를 넘긴다 — 장이 페이지 끝에 반쯤 걸치면 안 읽힌다.
            if level == 2 and pdf.page_no() > 0 and pdf.get_y() > pdf.h * 0.62:
                pdf.add_page()
            pdf.ln(2.0 if level > 1 else 0.0)
            pdf.set_font("malgun", "B", size)
            pdf.set_text_color(90, 20, 30) if level < 3 else pdf.set_text_color(30)
            pdf.multi_cell(0, size * 0.62, text, new_x="LMARGIN", new_y="NEXT")
            pdf.set_text_color(30)
            pdf.ln(1.6)
            i += 1
            continue
        if line.lstrip().startswith(("- ", "* ")):
            indent = 3.0 if raw.startswith((" ", "\t")) else 0.0
            pdf.set_x(MARGIN + indent)
            pdf.set_font("malgun", "", BODY)
            pdf.cell(4.0, BODY * 0.52, "·")
            write_rich(pdf, line.lstrip()[2:], BODY)
            i += 1
            continue
        if line.startswith(">"):
            pdf.set_text_color(95)
            pdf.set_x(MARGIN + 3.0)
            write_rich(pdf, line.lstrip("> "), BODY)
            pdf.set_text_color(30)
            i += 1
            continue
        # 본문은 **문단 단위로 합쳐서** 넘긴다. 줄마다 따로 그리면 굵게가 줄을
        # 걸쳤을 때(`**앞줄` / `뒷줄**`) 굵기가 뒤집힌다 — 1쪽에서 실제로 났다.
        para = []
        while i < len(lines):
            nxt = lines[i].rstrip()
            if not nxt or nxt[0] in "#|->*" or nxt.startswith("```"):
                break
            para.append(nxt)
            i += 1
        write_rich(pdf, " ".join(para), BODY)
    pdf.output(pdf_path)
    print("%s (%d쪽)" % (pdf_path, pdf.page_no()))


if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2])
