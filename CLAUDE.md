# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Mandates

1. **Language**: Think in English. Interact with users in Japanese. Commit messages and PR descriptions must be in Japanese.
2. **TDD**: Follow t-wada style TDD strictly—RED-GREEN-REFACTOR without exception.

## Build & Development Commands

```bash
# Install dependencies
uv sync

# Local preview (live reload at http://127.0.0.1:8000)
uv run mkdocs serve

# Production build
uv run mkdocs build

# PDF build (requires GTK runtime and sets MKDOCS_PDF=1)
MKDOCS_PDF=1 uv run mkdocs build
```

## Testing

```powershell
# Run all Pester tests with code coverage
./scripts/tests/Run-AllTests.ps1

# Run a single test file
Invoke-Pester -Path ./scripts/tests/Setup-Local.Tests.ps1
```

Tests use Pester. Production scripts live in `scripts/`, test files in `scripts/tests/` with `*.Tests.ps1` naming.

## Project Structure

- `docs/` — Markdown source for MkDocs site; add `index.md` per section
- `mkdocs.yml` — Site config, navigation, plugins; update when adding pages
- `scripts/` — PowerShell helper scripts (e.g., `Setup-Local.ps1` for tooling bootstrap)
- `pyproject.toml`, `uv.lock` — Python dependencies managed by uv

## Tech Stack

- **MkDocs + Material for MkDocs** — Static site generator
- **Mermaid** — Diagrams in Markdown (rendered via `mermaid-to-svg` plugin)
- **Draw.io** — SVG diagrams (converted to PNG via `svg-to-png` plugin)
- **WeasyPrint** — PDF generation (via `to-pdf` plugin, enabled by `MKDOCS_PDF` env var)
- **Playwright** — Browser automation for Mermaid rendering
- **Marp** — Markdown presentations (requires Node.js)

## Coding Conventions

- Markdown: ATX headings, fenced code blocks with language hints, relative links within `docs/`
- Filenames: lowercase with hyphens (e.g., `getting-started.md`)
- YAML: two-space indentation; keep nav entries synchronized with files
- Run `uv run mkdocs build` before committing to catch broken links or syntax errors

## CI/CD

- **ci-tests.yml** — Runs Pester tests on `scripts/**` changes (Windows runner)
- **deploy-site.yml** — Builds and deploys to Azure Static Web Apps; PDF enabled only on main branch push

## Environment Setup (Windows)

Run as administrator:
```powershell
.\scripts\Setup-Local.ps1
```
Installs Python 3.13, uv, Node.js, Mermaid CLI, GTK+ Runtime, and project dependencies.
