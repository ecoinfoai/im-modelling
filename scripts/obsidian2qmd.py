#!/usr/bin/env python3
"""옵시디언 원고(.md) → Quarto 챕터(.qmd) 변환기.

원고는 옵시디언에서만 편집한다. 이 스크립트가 빌드 시점에 한 방향으로 변환하므로
docs/chapters/*.qmd 는 직접 손대지 않는다(자동 생성물, .gitignore 대상).

변환 규칙
  1. 프런트매터(속성 테이블) 전부 제거 → 대신 H1 제목 한 줄. GitHub 게시본에는 속성 불필요.
  2. 콜아웃  > [!note] 제목  →  ::: {.callout-note title="제목"} … :::
             단, '교수 데모'·'다음 단계' 상자는 집필용 메모라 게시본에서 뺀다(DROP_TITLE_RE).
  3. 그림  ![[fig.png]] + "그림 N. 설명"
           → ![설명](../assets/fig.png){#fig-…}
           "그림 N." 은 떼어낸다. #fig- id 가 붙으면 Quarto 가 번호를 매기므로,
           그대로 두면 "그림 1: 그림 1. 설명" 처럼 두 번 나온다.
           단, 코드로 대체하기로 한 그림은 ```{julia}``` 블록으로 치환(CODE_FIGURES).
  4. 파일명 교정(NAME_FIX): 원고 참조명 → 실제 assets 파일명.
  5. 위키링크 [[문서]] → 표시 텍스트만.
"""
from __future__ import annotations
import re, sys, unicodedata
from pathlib import Path

CALLOUT_MAP = {
    "note": "note", "info": "note", "abstract": "note", "summary": "note", "todo": "note",
    "tip": "tip", "hint": "tip", "success": "tip", "check": "tip", "done": "tip",
    "question": "tip", "help": "tip", "faq": "tip",
    "warning": "warning", "attention": "warning",
    "caution": "caution",
    "danger": "important", "error": "important", "failure": "important",
    "fail": "important", "missing": "important", "bug": "important",
    "example": "note",
}
DROP_TITLE_RE = re.compile(r"교수\s*데모|다음\s*단계")
CALLOUT_OPEN_RE = re.compile(r"^>\s*\[!([A-Za-z]+)\]([+-]?)\s*(.*)$")
EMBED_RE = re.compile(r"^!\[\[([^\]|]+?)(?:\|([^\]]*))?\]\]\s*$")
WIKILINK_RE = re.compile(r"(?<!!)\[\[([^\]|]+?)(?:\|([^\]]*))?\]\]")
CAPTION_RE = re.compile(r"^그림\s*\d+\s*[.、]?\s*(.*)$")

# 원고 참조명 → assets 실제 파일명 (수정된 것만)
NAME_FIX = {
    "ch1_fig1_Typhoon_Haiyan.jpg.jpg": "ch1_fig1_Typhoon_Haiyan.jpg",  # 이중 확장자
    "ch2_fig2_barrier_arrow.jpeg": "ch2_fig2_barrier_arrow.png",       # 일러스트 PNG 내보내기
}
# 코드로 대체하는 그림: 원고 참조명 → (ImModelling 함수, 라벨)
#   fig2(비브리오 히스토그램)·fig4(서울 이봉분포)는 정적 일러스트가 없는 데이터 그림이라
#   코드로 그린다. 개념 삽화(fig1/3/5/6 등)는 교수님이 만든 정적 이미지를 그대로 둔다.
#   ※ Ch.3 교수 데모 함수(demo_*)는 src/에 구현·유지하되 문서에는 삽입하지 않는다(추후 사용).
CODE_FIGURES = {
    "ch3_fig2_v_vulnificus_histogram.png": ("vibrio_year_histogram()", "fig-ch3-vibrio"),
    "ch3_fig4_seoul_temp_bimodal.png":     ("seoul_temp_bimodal()",     "fig-ch3-seoul-temp"),
}


def slugify(name: str) -> str:
    s = unicodedata.normalize("NFKD", Path(name).stem).lower()
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-") or "img"


def strip_frontmatter(text: str) -> list[str]:
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return lines[i + 1:]
    return lines


def convert_callouts(lines):
    out, i, n = [], 0, len(lines)
    while i < n:
        m = CALLOUT_OPEN_RE.match(lines[i])
        if not m:
            out.append(lines[i]); i += 1; continue
        kind_raw, fold, title = m.group(1).lower(), m.group(2), m.group(3).strip()
        kind = CALLOUT_MAP.get(kind_raw, "note")
        body, j = [], i + 1
        while j < n and lines[j].lstrip().startswith(">"):
            body.append(re.sub(r"^\s*>\s?", "", lines[j])); j += 1
        if DROP_TITLE_RE.search(title):      # 집필용 메모 상자는 문서 출력에서 제외
            i = j; continue
        if kind_raw == "quote":
            out.append("")
            if title: out += [f"> **{title}**", ">"]
            out += [f"> {b}" if b.strip() else ">" for b in body]
            out.append(""); i = j; continue
        classes = [f".callout-{kind}"]
        attrs = " ".join(classes)
        if title: attrs += f' title="{title}"'
        if fold == "-": attrs += ' collapse="true"'
        while body and not body[0].strip(): body.pop(0)
        while body and not body[-1].strip(): body.pop()
        out += ["", f"::: {{{attrs}}}", *body, ":::", ""]
        i = j
    return out


def convert_figures(lines, prefix):
    out, i, n = [], 0, len(lines)
    while i < n:
        m = EMBED_RE.match(lines[i].strip())
        if not m:
            out.append(lines[i]); i += 1; continue
        fname = m.group(1).strip()
        caption = (m.group(2) or "").strip()
        k = i + 1
        while k < n and not lines[k].strip():
            k += 1
        cap_m = CAPTION_RE.match(lines[k].strip()) if k < n else None
        if cap_m:
            caption = cap_m.group(1).strip(); i = k
        if fname in CODE_FIGURES:                      # 코드로 대체
            call, label = CODE_FIGURES[fname]
            cap = caption.replace('"', r'\"')
            out += ["", "```{julia}", f"#| label: {label}",
                    f'#| fig-cap: "{cap}"', call, "```", ""]
        else:                                          # 정적 그림
            real = NAME_FIX.get(fname, fname)
            cap = caption.replace("]", r"\]")
            out += ["", f"![{cap}](../assets/{real}){{#fig-{prefix}-{slugify(real)}}}", ""]
        i += 1
    return out


def convert_wikilinks(lines):
    return [WIKILINK_RE.sub(lambda m: (m.group(2) or m.group(1)).strip(), ln) for ln in lines]


def convert(md_path: Path, out_path: Path, title: str, prefix: str):
    body = strip_frontmatter(md_path.read_text(encoding="utf-8"))
    body = convert_callouts(body)
    body = convert_figures(body, prefix)
    body = convert_wikilinks(body)
    # 코드 그림이 있으면 setup 청크를 맨 앞에 한 번
    has_code = any(f in md_path.read_text(encoding="utf-8") for f in CODE_FIGURES)
    cleaned = []
    for ln in body:
        if not ln.strip() and cleaned and not cleaned[-1].strip():
            continue
        cleaned.append(ln)
    head = [f"# {title}", ""]
    if has_code:
        head += ["```{julia}", "#| echo: false", "#| output: false",
                 "using ImModelling", "```", ""]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(head + cleaned).strip() + "\n", encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) < 5:
        sys.exit("usage: obsidian2qmd.py <in.md> <out.qmd> <title> <prefix>")
    convert(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4])
    print(f"{sys.argv[1]} -> {sys.argv[2]}")
