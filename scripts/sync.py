#!/usr/bin/env python3
"""옵시디언 보관함 → 저장소 동기화 + Quarto 변환.

  python scripts/sync.py            # config.toml 의 vault_dir 사용
  python scripts/sync.py --dry-run  # 변경 예정만 표시

하는 일
  1. 보관함의 원고 .md 를 manuscript/ 로 복사 (git 이 원고 이력 관리)
  2. 최적화 그림을 docs/assets/ 로 복사
  3. manuscript/*.md → docs/chapters/*.qmd 변환 (obsidian2qmd)

보관함에는 .git 을 두지 않는다. 저장소는 보관함 밖에 있고 이 스크립트가 한 방향으로만
복사하므로, Syncthing 이 .git 을 건드릴 일이 없다.
"""
from __future__ import annotations
import argparse, filecmp, shutil, sys, tomllib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from obsidian2qmd import convert  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
IMG = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"}


def copy_if_changed(src, dst, dry):
    if dst.exists() and filecmp.cmp(src, dst, shallow=False):
        return None
    act = "갱신" if dst.exists() else "추가"
    if not dry:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    return act


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cfg_path = ROOT / "config.toml"
    if not cfg_path.exists():
        sys.exit(f"config.toml 없음. config.example.toml 을 복사해 채운다:\n  cp {ROOT/'config.example.toml'} {cfg_path}")
    cfg = tomllib.loads(cfg_path.read_text(encoding="utf-8"))
    vault = Path(cfg["vault_dir"]).expanduser()
    image_src = Path(cfg.get("image_dir") or vault).expanduser()
    chapters = cfg["chapters"]  # [{md, title}] 순서 = 챕터 순서

    changed = 0
    print(f"[원고] {vault}")
    for i, ch in enumerate(chapters, 1):
        md = vault / ch["md"]
        if not md.exists():
            print(f"  건너뜀(없음): {ch['md']}"); continue
        st = copy_if_changed(md, ROOT / "manuscript" / md.name, args.dry_run)
        if st: changed += 1; print(f"  {st}  manuscript/{md.name}")

    print(f"[그림] {image_src} → docs/assets/")
    for img in sorted(image_src.iterdir()):
        if img.suffix.lower() in IMG:
            st = copy_if_changed(img, ROOT / "docs/assets" / img.name, args.dry_run)
            if st: changed += 1; print(f"  {st}  docs/assets/{img.name}")

    print("[변환] manuscript/*.md → docs/chapters/*.qmd")
    for i, ch in enumerate(chapters, 1):
        src = ROOT / "manuscript" / Path(ch["md"]).name
        if not src.exists(): continue
        out = ROOT / "docs/chapters" / f"ch{i}.qmd"
        if not args.dry_run:
            convert(src, out, ch["title"], f"c{i}")
        print(f"  {src.name}  →  docs/chapters/{out.name}")

    print()
    print(f"(모의) 변경 예정 {changed}건" if args.dry_run
          else f"완료. 변경 {changed}건. 다음: cd docs && quarto preview")


if __name__ == "__main__":
    main()
