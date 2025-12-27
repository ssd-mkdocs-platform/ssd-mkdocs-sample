# MkDocs環境セットアップスクリプト
# uvを使用してPython環境とパッケージを管理

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,
        [string] $Name = $Id
    )

    $installed = winget list --id $Id -e --source winget --accept-source-agreements 2>$null | Where-Object { $_ -match [regex]::Escape($Id) }
    if ($installed) {
        Write-Host "$Name は既にインストール済みのためスキップします。" -ForegroundColor Green
        return
    }

    Write-Host "$Name をインストールしています..." -ForegroundColor Yellow
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
}

function Update-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Install-NpmGlobalPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Package,
        [string] $Name = $Package
    )

    $npmListJson = npm list -g --depth=0 --json --long 2>$null
    $npmList = $null
    try {
        $npmList = $npmListJson | ConvertFrom-Json
    }
    catch {
        Write-Host "npmのインストール状況を取得できなかったため、${Name} をインストールします。" -ForegroundColor Yellow
    }

    $npmInstalled = $false
    if ($npmList -and $npmList.dependencies) {
        $npmInstalled = $npmList.dependencies.PSObject.Properties.Name -contains $Package
    }

    if ($npmInstalled) {
        Write-Host "$Name は既にインストール済みのためスキップします。" -ForegroundColor Green
        return
    }

    Write-Host "$Name をインストールしています..." -ForegroundColor Yellow
    npm install -g $Package
}

function Install-PlaywrightBrowsers {
    $playwrightDir = Join-Path $env:USERPROFILE "AppData\\Local\\ms-playwright"
    $installed = Test-Path $playwrightDir -PathType Container -ErrorAction SilentlyContinue
    if ($installed) {
        $hasBrowsers = (Get-ChildItem $playwrightDir -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }).Count -gt 0
        if ($hasBrowsers) {
            Write-Host "Playwrightブラウザは既にインストール済みのためスキップします。" -ForegroundColor Green
            return
        }
    }

    Write-Host "Playwrightブラウザをインストールしています..." -ForegroundColor Yellow
    uv run python -m playwright install
}

Write-Host "=== MkDocsドキュメンテーション環境のセットアップを開始します ===" -ForegroundColor Green

# Python 3.13とuvをインストール
Install-WingetPackage -Id "Python.Python.3.13" -Name "Python 3.13"
Install-WingetPackage -Id "astral-sh.uv" -Name "uv"

# WeasyPrintから利用するGTK+ランタイムをインストールする
Install-WingetPackage -Id "tschoonj.GTKForWindows" -Name "GTK+ runtime (WeasyPrint)"

# Mermaid CLIをインストールするためのNode.jsをインストール
Install-WingetPackage -Id "OpenJS.NodeJS" -Name "Node.js (Mermaid CLI)"

# Mermaid CLIをインストールするためのNode.jsをインストール
Install-WingetPackage -Id "Microsoft.AzureCLI" -Name "Azure CLI"

# 新規インストールされたコマンドを認識させる
Update-Path

# Mermaid CLIをインストール
Install-NpmGlobalPackage -Package "@mermaid-js/mermaid-cli" -Name "Mermaid CLI"

# プロジェクトディレクトリに移動
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    throw "スクリプトのパスを取得できませんでした。"
}

$scriptRoot = Split-Path -Parent $scriptPath
$projectRoot = Split-Path -Parent $scriptRoot
$previousLocation = Get-Location

try {
    Set-Location $projectRoot

    # pyproject.tomlに定義された依存関係をインストール
    Write-Host "uv sync を実行して依存関係をインストールします..." -ForegroundColor Yellow
    uv sync
    Write-Host "uv sync が完了しました。" -ForegroundColor Green

    # Playwrightブラウザのインストール
    Install-PlaywrightBrowsers
}
finally {
    Set-Location $previousLocation
}
