#!/bin/bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

echo "=== [1/3] Installing Python dependencies ==="
uv sync --frozen

echo "=== [2/3] Installing Playwright browser ==="
uv run playwright install chromium

echo "=== [3/3] Setting up pnpm and Node.js dependencies ==="
corepack enable
corepack prepare pnpm@10.27.0 --activate
pnpm install --frozen-lockfile

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Available commands:"
echo "  pnpm mkdocs           - Start MkDocs live preview (http://localhost:8000)"
echo "  pnpm mkdocs:build     - Build MkDocs static site"
echo "  pnpm mkdocs:build:svg - Render Mermaid diagrams to SVG"
echo "  pnpm mkdocs:pdf       - Generate PDF"
echo "  pnpm lint:text        - Run textlint"
echo "  pnpm lint:text:fix    - Fix textlint issues"
