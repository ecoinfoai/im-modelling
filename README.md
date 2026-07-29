# im-modelling

감염미생물학 12–14주차 교안 + Julia 시뮬레이션 → Quarto → GitHub Pages.

사이트: <https://ecoinfoai.github.io/im-modelling/>

## Documenter 를 써 보셨다면 — Quarto 대응표

| Documenter.jl | 이 저장소 (Quarto) | 역할 |
|---|---|---|
| `docs/make.jl` | `docs/_quarto.yml` | 빌드 설정 |
| `docs/Project.toml` | `docs/Project.toml` | 문서 렌더용 Julia 환경 (동일) |
| `docs/src/*.md` | `docs/chapters/*.qmd`, `docs/index.qmd` | 게시할 문서 원본 |
| `@example` 블록 | ` ```{julia} ` 블록 | 문서 안에서 코드 실행 → 결과 삽입 |
| `docs/build/` | `docs/_site/` | 렌더 결과 (게시물) |
| `makedocs()` + `deploydocs()` | `quarto render` + `quarto publish gh-pages` | 빌드·배포 |

핵심 차이 두 가지. (1) Documenter는 `docs/src/` 아래에 소스를 두지만, Quarto는 소스와
설정을 `docs/` 아래에 두고 결과를 `docs/_site/` 로 낸다 — 그래서 `docs/src/` 대신
`docs/chapters/` 를 쓴다. (2) 코드 실행 문법이 `@example` → ` ```{julia} ` 로 바뀐다.

## 시뮬레이션 코드는 어디에 두나 — `src/` 다 (`docs/` 아님)

Documenter와 똑같다. **재사용·검증할 계산·작도 코드는 패키지(`src/ImModelling.jl`)에
둔다.** 문서(`docs/chapters/*.qmd`)의 ` ```{julia} ` 블록은 그 함수를 **호출만** 한다.

```julia
# docs/chapters/ch3.qmd 안 — 로직이 아니라 호출만
using ImModelling
vibrio_year_histogram()      # ← 실제 코드는 src/ 에 있고 test/ 가 검증한다
```

이렇게 나누는 이유는 **TDD** 때문이다. `.qmd` 안에 파묻힌 코드는 `Test.jl` 로 검증할 수
없다. `src/` 에 두면 `test/runtests.jl` 가 단위 검증하고, 문서는 검증된 코드를 부른다.

## 폴더 구조

```
im-modelling/
├── Project.toml            ImModelling 패키지 정의 (+ 의존성)
├── src/ImModelling.jl       시뮬레이션·작도 함수  ← 코드는 여기
├── test/runtests.jl         Test.jl (TDD)
├── manuscript/              옵시디언 원고 .md (Syncthing 밖, git이 이력 관리)
├── scripts/
│   ├── obsidian2qmd.py      옵시디언 → Quarto 변환기
│   └── sync.py              보관함 → 저장소 복사 + 변환
├── docs/
│   ├── _quarto.yml          사이트 설정 (≈ make.jl)
│   ├── Project.toml          문서 렌더용 Julia 환경
│   ├── index.qmd
│   ├── chapters/ch1–3.qmd    변환 산출물(자동 생성) — 직접 편집 금지
│   ├── assets/               최적화 그림 16개
│   └── styles.scss
├── config.example.toml
└── .gitignore
```

## 최초 설치 (게시 담당 머신 = ecoinfonix, 한 번만)

```bash
git clone https://github.com/ecoinfoai/im-modelling.git
cd im-modelling

# 1) 보관함 경로 설정
cp config.example.toml config.toml && $EDITOR config.toml

# 2) 패키지 + 테스트 환경
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'          # TDD 확인

# 3) 문서 렌더 환경 (부모 패키지를 dev 로 물린다)
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'

# 4) Quarto 확인 (https://quarto.org/docs/download/)
quarto check
```

## 평소 작업

원고는 어느 머신에서든 옵시디언으로 쓴다(Syncthing이 ecoinfonix까지 옮긴다). 게시할 때만
ecoinfonix에서:

```bash
python scripts/sync.py                 # 원고·그림 가져오기 + chapters/*.qmd 변환
cd docs && quarto preview              # 브라우저 확인 (선택)
quarto publish gh-pages                # 렌더 후 gh-pages 로 배포
cd .. && git add -A && git commit -m "원고 갱신" && git push
```

`quarto publish gh-pages` 는 **로컬에서 렌더한 결과만** 올리므로 GitHub 서버에 Julia가
없어도 된다. 계산 결과는 `docs/_freeze/` 에 저장(freeze)되어, 바뀐 문서만 다시 계산한다.

## 그림 방침

수치·통계가 들어가는 그림은 `src/` 함수로 그려 문서에서 호출한다(자료가 바뀌면 다시
그리고, 출처·계산이 코드로 남는다). 개념 삽화는 `docs/assets/` 의 정적 이미지로 둔다.
그림은 커밋 전 최적화한다(가로 1600px, 재양자화).

현재 코드로 옮긴 그림: Ch.3 `vibrio_year_histogram`(구 ch3_fig2), `seoul_temp_bimodal`
(구 ch3_fig4). 나머지 교수 데모 13종은 각 장 ▶ 교수 데모 상자에 명세가 있고 차례로 구현한다.

## 원고 참조 vs 실제 파일명 (변환기가 자동 교정)

옵시디언 원고의 두 이미지 참조는 실제 파일명과 달라, 변환기(`NAME_FIX`)가 자동으로 맞춘다.
옵시디언 원고 자체를 고쳐 두면 이 예외도 없앨 수 있다.

| 옵시디언 원고 참조 | 실제 파일 | 비고 |
|---|---|---|
| `ch1_fig1_Typhoon_Haiyan.jpg.jpg` | `…Haiyan.jpg` | 이중 확장자 |
| `ch2_fig2_barrier_arrow.jpeg` | `…barrow.png` | 일러스트 PNG로 교체 |
