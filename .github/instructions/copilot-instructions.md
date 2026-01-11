# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Core Mandates

1. **Language**: Think in English. Interact with users in Japanese. Commit messages and PR descriptions must be in Japanese.
2. **TDD**: Follow t-wada style TDD strictly?RED-GREEN-REFACTOR without exception.

## Project Structure

- `../../docs/` — Markdown source for MkDocs site; add `index.md` per section
- `../../mkdocs.yml` — Site config, navigation, plugins; update when adding pages
- `../../scripts/` — Node.js helper scripts for builds
- `../../pyproject.toml`, `../../uv.lock` — Python dependencies (uv)
- `../../package.json`, `../../pnpm-lock.yaml` — Node.js dependencies (pnpm) for textlint
