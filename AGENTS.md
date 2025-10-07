# Repository Guidelines

## Project Structure & Module Organization
Runtime code lives in `knotty-lib/`, which houses the Typed Racket modules (for example, `chart.rkt`, `knitspeak-parser.rkt`), shared assets in `resources/`, and the onboarding script `demo.rkt`. The `knotty/` collection carries package metadata (`info.rkt`), documentation sources in `scribblings/`, and suite-level tests in `tests/`. Tooling at the repo root (`Makefile`, `README.md`, `CHANGES.md`) supports builds, onboarding, and release tracking.

## Build, Test, and Development Commands
- `make install` — links `knotty` and `knotty-lib` into your local Racket installation with dependencies.
- `make build` — compiles the library so Typed Racket type errors appear before runtime.
- `make test` — executes rackunit suites from both collections via `raco test -exp`.
- `make cover` — writes coverage results to `coverage/` and opens the HTML report.
- `make clean` — removes compiled artifacts and cached docs when refactoring.
- `raco docs knotty` — opens the generated manual for API confirmation.

## Coding Style & Naming Conventions
Use `#lang sweet-exp typed/racket` with the default two-space Racket indentation; rely on the editor’s auto-format. Modules and functions stay lowercase with hyphen separators (`pull-direction.rkt`, `bytes->chart-row`), while exported structs and types use TitleCase (`Chart-row`, `Pattern`). Keep `require` blocks ordered by origin (stdlib, third-party, project) and prefer explicit `provide` lists. Place helper scripts at the repo root rather than inside collections.

## Testing Guidelines
Mirror the library layout when adding tests: create `knotty/tests/<module>.rkt`, wrap assertions in `module+ test`, and use `typed/rackunit` primitives. Call `make test` before every push; for focused work, `raco test knotty-lib/<file>.rkt` runs a single module. Aim to cover new control flow and verify with `make cover`, cleaning generated artifacts afterward.

## Commit & Pull Request Guidelines
Follow the existing style of concise, imperative messages (for example, “Add draw-lib dependency”) and reference issues with `#<id>` when closing work. Group related edits into one commit to keep diffs reviewable. Pull requests should link issues, list manual test commands, and attach screenshots whenever HTML or GUI output changes. Call out breaking changes or new external requirements in the PR description.

## Documentation & Assets
Update `knotty/scribblings/` alongside API or CLI changes and regenerate docs with `make build-docs` before publishing. Store new charts, fonts, or color files in `knotty-lib/resources/` and capture licensing notes in `LICENSE` or `CHANGES.md`. Keep demonstrations confined to `knotty-lib/demo.rkt` so the example remains a focused onboarding path.
