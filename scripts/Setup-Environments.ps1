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

    Write-Host "$Name をインストールしています..." -ForegroundColor Yellow
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
}

function Update-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

Write-Host "=== MkDocsドキュメンテーション環境のセットアップを開始します ===" -ForegroundColor Green

# Python 3.13とuvをインストール
Install-WingetPackage -Id "Python.Python.3.13" -Name "Python 3.13"
Install-WingetPackage -Id "astral-sh.uv" -Name "uv"

# WeasyPrintから利用するGTK+ランタイムをインストールする
Install-WingetPackage -Id "tschoonj.GTKForWindows" -Name "GTK+ runtime (WeasyPrint)"

# Mermaid CLIをインストールするためのNode.jsをインストール
Install-WingetPackage -Id "OpenJS.NodeJS" -Name "Node.js (Mermaid CLI)"

# 新規インストールされたコマンドを認識させる
Update-Path

# Mermaid CLIをインストール
npm install -g @mermaid-js/mermaid-cli

# プロジェクトディレクトリに移動
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location

try {
    Set-Location $projectRoot

    # pyproject.tomlに定義された依存関係をインストール
    uv sync

    # Playwrightブラウザのインストール
    Write-Host "Playwrightブラウザをインストールしています..." -ForegroundColor Yellow
    uv run python -m scripts.install_playwright_browsers
}
finally {
    Set-Location $previousLocation
}
