#!/usr/bin/env bash
# setup-worktree.sh - Create or find existing worktree for an issue
# Usage: ./setup-worktree.sh <issue-number>
# Output: Prints the worktree path to stdout

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <issue-number>" >&2
    exit 1
fi

ISSUE="$1"

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: Not a git repository." >&2
    exit 1
fi

# Determine paths
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREES_ROOT="$(dirname "$REPO_ROOT")/${REPO_NAME}-worktrees"
BRANCH_NAME="fix-issue-${ISSUE}"
WORKTREE_PATH="${WORKTREES_ROOT}/${BRANCH_NAME}"

# Check if worktree already exists
if git worktree list | grep -q "${WORKTREE_PATH}"; then
    echo "$WORKTREE_PATH"
    exit 0
fi

# Create worktrees directory if it doesn't exist
mkdir -p "$WORKTREES_ROOT"

# Check if worktree path already exists (but not registered as worktree)
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "Error: Path already exists but is not a worktree: $WORKTREE_PATH" >&2
    exit 1
fi

# Check branch existence
HAS_LOCAL_BRANCH=false
REMOTE_START_POINT=""

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
    HAS_LOCAL_BRANCH=true
elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}" 2>/dev/null; then
    REMOTE_START_POINT="origin/${BRANCH_NAME}"
fi

# Create worktree
if [[ "$HAS_LOCAL_BRANCH" == "true" ]]; then
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
elif [[ -n "$REMOTE_START_POINT" ]]; then
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$REMOTE_START_POINT"
else
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" HEAD
fi

if [[ $? -ne 0 ]]; then
    echo "Error: git worktree add failed." >&2
    exit 1
fi

echo "$WORKTREE_PATH"
