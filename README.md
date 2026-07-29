# im-modelling

Teaching material for weeks 12–14 of *Infectious Microbiology* (Nursing),
published as a Quarto site.

**<https://ecoinfoai.github.io/im-modelling/>**

## Concept

A microbiology course is mostly static — what a pathogen is, what it causes, how
it is treated and prevented. These three chapters read the same subject
dynamically: how a changing environment shifts the odds of infection. The tools
stay conceptual rather than mathematical. Probability and distributions are used
as ways of seeing, not as formulas to solve.

| Chapter | Lens | Question |
|---|---|---|
| Ch.1 Environment | ecological and climate change | how do pathogens move when the climate shifts? |
| Ch.2 Probability | exposure ≠ infection ≠ severity | why layer defences, why does severity differ? |
| Ch.3 Distribution | the variation behind a mean | how do you prepare for a spread of outcomes? |

## Structure

Computation lives in the package, not in the prose. The `{julia}` blocks in
`docs/chapters/*.qmd` only call functions from `src/ImModelling.jl`, which keeps
the figures testable — code buried in a `.qmd` cannot be reached by `Test.jl`.

```
├── src/ImModelling.jl       simulation and plotting functions
├── test/runtests.jl         unit tests covering each of them
├── docs/
│   ├── _quarto.yml          site configuration
│   ├── index.qmd            landing page
│   ├── chapters/ch1–3.qmd   generated from Obsidian notes — do not edit directly
│   ├── assets/              static figures
│   └── _freeze/             cached results of executed Julia blocks
├── scripts/sync.py          Obsidian vault → chapters/*.qmd (see config.example.toml)
├── flake.nix, .envrc        devShell pinning the Quarto release
└── .github/workflows/       render and deploy on push to master
```

## Working on it

`direnv allow` once, then entering the directory puts Quarto on `PATH`.

```bash
python scripts/sync.py     # pull manuscripts and convert them
quarto preview docs        # check in a browser
git push                   # publishing is CI's job
```

Pushing to `master` renders the site with Julia and Quarto in CI and deploys it
to GitHub Pages. Committed `docs/_freeze/` results let CI skip Julia execution
for chapters that have not changed.

## License

| | |
|---|---|
| Code — `src/`, `test/`, `scripts/`, `flake.nix` | [MIT](LICENSE) |
| Teaching material — `docs/` | [CC BY-NC-SA 4.0](LICENSE-docs.md) |
| Figures quoted in Ch.1 | rights remain with the original authors — [see the list](LICENSE-docs.md) |
