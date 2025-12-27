# Repository Guidelines

## Core Mandates

**CRITICAL: You must adhere to these rules in all interactions.**

1.  **Language**:
    *   **Think in English.**
    *   **Interact with the user in Japanese.**
    *   Plans and artifacts (commit messages, PR descriptions) must be written in **Japanese**.
2.  **Test-Driven Development (TDD)**:
    *   Strictly adhere to the **t-wada style** of TDD.
    *   **RED-GREEN-REFACTOR** cycle must be followed without exception.
    *   Write a failing test first, then implement the minimal code to pass it, then refactor.

## Project Structure & Module Organization
- `docs/`: Source Markdown for the MkDocs site; keep section folders shallow and add `index.md` per section.
- `mkdocs.yml`: Site configuration, navigation, and plugin settings; update when adding pages.
- `scripts/`: Helper scripts (e.g., `Setup-Environments.ps1` for tooling bootstrap).
- `site/`: MkDocs build output; do not edit manually or commit unless explicitly required.
- `pyproject.toml`, `uv.lock`: Python project and dependency lock managed by `uv`.

## Build, Test, and Development Commands
- `uv sync`: Install Python dependencies defined in `pyproject.toml`.
- `uv run mkdocs serve`: Local preview with live reload at `http://127.0.0.1:8000`.
- `uv run mkdocs build`: Production build into `site/`; fails on navigation or syntax errors.
- `uv run mkdocs pdf`: Generate PDF output (uses WeasyPrint; ensure GTK runtime is installed).
- `npm install -g @mermaid-js/mermaid-cli`: Needed once for Mermaid rendering; ensure Node.js is present (use `scripts/Setup-Environments.ps1` on Windows).

## Coding Style & Naming Conventions
- Markdown: Use ATX headings, ordered lists for procedures, and fenced code blocks with language hints.
- Filenames: Lowercase with hyphens (e.g., `getting-started.md`); keep folder names aligned with navigation titles.
- Links: Prefer relative links within `docs/`; avoid absolute file URLs.
- YAML (`mkdocs.yml`): Two-space indentation; keep navigation entries synchronized with actual files.

## Testing Guidelines
- Run `uv run mkdocs build` before committing to catch broken links, missing pages, or syntax issues.
- For PDF output changes, verify `uv run mkdocs pdf` once per change set to ensure assets render correctly.
- When adding Mermaid diagrams, render locally (via `mmdc` or MkDocs preview) to confirm layout and fonts.

## Commit & Pull Request Guidelines
- Commits: Use clear, imperative summaries (e.g., `Add architecture overview page`, `Fix PDF build path`); group related doc changes together.
- Pull Requests: Include a short description of scope, key pages touched, and any build commands run (`mkdocs build`, `mkdocs pdf`). Attach screenshots or PDF snippets if visual layout changes.
- Navigation changes: Call out any edits to `mkdocs.yml` so reviewers can verify menu impacts.

## Environment Tips
- Preferred workflow: Run `scripts/Setup-Environments.ps1` on Windows to install Python 3.13, uv, Node.js, Mermaid CLI, and GTK runtime.
- Keep `uv.lock` in sync (`uv sync` regenerates as needed) and commit updates when dependencies change.***
