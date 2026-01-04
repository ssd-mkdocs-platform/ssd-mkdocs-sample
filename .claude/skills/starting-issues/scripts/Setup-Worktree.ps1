# Setup-Worktree.ps1 - Create or find existing worktree for an issue
# Usage: pwsh -File Setup-Worktree.ps1 -Issue <number>
# Output: Prints the worktree path to stdout

param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Issue
)

$ErrorActionPreference = 'Stop'

# Get repository root
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    Write-Error "Not a git repository."
    exit 1
}
$repoRoot = $repoRoot.Trim()

# Determine paths
$repoName = Split-Path -Leaf $repoRoot
$worktreesRoot = Join-Path (Split-Path -Parent $repoRoot) "$repoName-worktrees"
$branchName = "fix-issue-$Issue"
$worktreePath = Join-Path $worktreesRoot $branchName

# Check if worktree already exists
$existingWorktrees = git worktree list
if ($existingWorktrees -match [regex]::Escape($worktreePath)) {
    Write-Output $worktreePath
    exit 0
}

# Create worktrees directory if it doesn't exist
if (-not (Test-Path $worktreesRoot)) {
    New-Item -ItemType Directory -Path $worktreesRoot | Out-Null
}

# Check if path already exists (but not registered as worktree)
if (Test-Path $worktreePath) {
    Write-Error "Path already exists but is not a worktree: $worktreePath"
    exit 1
}

# Check branch existence
$hasLocalBranch = $false
$remoteStartPoint = $null

git show-ref --verify --quiet "refs/heads/$branchName" 2>$null
if ($LASTEXITCODE -eq 0) {
    $hasLocalBranch = $true
}
else {
    git show-ref --verify --quiet "refs/remotes/origin/$branchName" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $remoteStartPoint = "origin/$branchName"
    }
}

# Create worktree
if ($hasLocalBranch) {
    git worktree add $worktreePath $branchName
}
elseif ($remoteStartPoint) {
    git worktree add -b $branchName $worktreePath $remoteStartPoint
}
else {
    git worktree add -b $branchName $worktreePath HEAD
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "git worktree add failed (exit code: $LASTEXITCODE)."
    exit 1
}

Write-Output $worktreePath
