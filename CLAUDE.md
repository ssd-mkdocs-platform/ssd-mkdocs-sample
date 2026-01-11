# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Mandates

1. **Language**: Think in English. Interact with users in Japanese. Commit messages and PR descriptions must be in Japanese.
2. **TDD**: Follow t-wada style TDD strictly—RED-GREEN-REFACTOR without exception.

## Rules

Project rules are defined in `.claude/rules/`.

| Rule | Scope | Notes |
|------|-------|-------|
| `.claude/rules/writing-guide.md` | `docs/**/*.md` | Manual checks are marked with （手動）. Update both files together. |

## Agent Skills

Project-specific Agent Skills are defined in `.claude/skills/`. Claude automatically uses these based on context.

| Skill | Description |
|-------|-------------|
| `creating-issues` | Create GitHub Issues interactively |
| `creating-prs` | Analyze diff from main branch and create PR |
| `starting-issues` | Start issue work (create branch → Plan mode) |

## Build & Development Commands

```bash
# Install dependencies
pnpm python:sync
pnpm install

# Local preview (live reload at http://127.0.0.1:8000)
pnpm mkdocs

# Production build (basic)
pnpm mkdocs:build

# PDF build (requires GTK runtime)
pnpm mkdocs:pdf
```

## Project Structure

- `docs/` — Markdown source for MkDocs site; add `index.md` per section
- `mkdocs.yml` — Site config, navigation, plugins; update when adding pages
- `scripts/` — Node.js helper scripts for builds
- `pyproject.toml`, `uv.lock` — Python dependencies (uv)
- `package.json`, `pnpm-lock.yaml` — Node.js dependencies (pnpm) for textlint
- `.claude/skills/` — Agent Skills for Claude Code

## Tech Stack

- **MkDocs + Material for MkDocs** — Static site generator
- **Mermaid** — Diagrams in Markdown (rendered via `mermaid-to-svg` plugin)
- **Draw.io** — SVG diagrams (converted to PNG via `svg-to-png` plugin)
- **WeasyPrint** — PDF generation (via `to-pdf` plugin)
- **Playwright** — Browser automation for Mermaid rendering
- **textlint** — Japanese text linting with JTF style guide

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `RENDER_SVG` | Enable Mermaid → SVG conversion |
| `RENDER_PNG` | Enable SVG → PNG conversion (for PDF) |
| `ENABLE_PDF` | Enable PDF generation |

## Coding Conventions

- Markdown: ATX headings, fenced code blocks with language hints, relative links within `docs/`
- Filenames: lowercase with hyphens (e.g., `getting-started.md`)
- YAML: two-space indentation; keep nav entries synchronized with files
- Run `pnpm mkdocs:build` before committing to catch broken links or syntax errors

## CI/CD

- **textlint.yml** — Runs textlint on `docs/**/*.md` changes
- **deploy-site.yml** — Builds and deploys; Azure SWA for preview, GitHub Pages for production
- **close-preview.yml** — Deletes Azure SWA preview environments on PR close








