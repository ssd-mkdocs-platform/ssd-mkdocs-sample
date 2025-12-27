# MkDocs環境セットアップスクリプト
# uvを使用してPython環境とパッケージを管理

[CmdletBinding()]
param(
    [string] $ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$script:SetupEnvironmentsScriptPath = $PSCommandPath

if (-not $script:WingetInvoker) {
    $script:WingetInvoker = { winget @args }
}

if (-not $script:NpmInvoker) {
    $script:NpmInvoker = { npm @args }
}

if (-not $script:UvInvoker) {
    $script:UvInvoker = { uv @args }
}

if (-not $script:TestPathInvoker) {
    $script:TestPathInvoker = {
        param(
            [string] $Path,
            [string] $PathType,
            [System.Management.Automation.ActionPreference] $ErrorAction
        )
        Test-Path -Path $Path -PathType $PathType -ErrorAction $ErrorAction
    }
}

if (-not $script:GetChildItemInvoker) {
    $script:GetChildItemInvoker = {
        param(
            [string] $Path,
            [switch] $Force,
            [System.Management.Automation.ActionPreference] $ErrorAction
        )
        Get-ChildItem -Path $Path -Force:$Force -ErrorAction $ErrorAction
    }
}

if (-not $script:SetLocationInvoker) {
    $script:SetLocationInvoker = {
        param([string] $Path)
        Set-Location -Path $Path
    }
}

if (-not $script:GetLocationInvoker) {
    $script:GetLocationInvoker = { Get-Location }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,
        [string] $Name = $Id
    )

    $installed = (& $script:WingetInvoker 'list' '--id' $Id '-e' '--source' 'winget' '--accept-source-agreements' 2>$null) | Where-Object { $_ -match [regex]::Escape($Id) }
    if ($installed) {
        Write-Host "$Name は既にインストール済みのためスキップします。" -ForegroundColor Green
        return
    }

    Write-Host "$Name をインストールしています..." -ForegroundColor Yellow
    & $script:WingetInvoker 'install' '--id' $Id '-e' '--silent' '--accept-package-agreements' '--accept-source-agreements'
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

    $npmList = $null
    try {
        $npmList = (& $script:NpmInvoker 'list' '-g' '--depth=0' '--json' '--long' 2>$null) | ConvertFrom-Json
    }
    catch {
        Write-Host "npmのインストール状況を取得できなかったため、${Name} をインストールします。" -ForegroundColor Yellow
    }

    $npmInstalled = $false
    if ($npmList -and $npmList.dependencies) {
        $dependencyNames = @($npmList.dependencies.PSObject.Properties | Select-Object -ExpandProperty Name)
        $npmInstalled = $dependencyNames -contains $Package
    }

    if ($npmInstalled) {
        Write-Host "$Name は既にインストール済みのためスキップします。" -ForegroundColor Green
        return
    }

    Write-Host "$Name をインストールしています..." -ForegroundColor Yellow
    & $script:NpmInvoker 'install' '-g' $Package
}

function Install-PlaywrightBrowsers {
    $playwrightDir = Join-Path $env:USERPROFILE "AppData\\Local\\ms-playwright"
    $installed = & $script:TestPathInvoker -Path $playwrightDir -PathType Container -ErrorAction SilentlyContinue
    if ($installed) {
        $browserDirs = @(& $script:GetChildItemInvoker -Path $playwrightDir -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })
        $hasBrowsers = $browserDirs.Count -gt 0
        if ($hasBrowsers) {
            Write-Host "Playwrightブラウザは既にインストール済みのためスキップします。" -ForegroundColor Green
            return
        }
    }

    Write-Host "Playwrightブラウザをインストールしています..." -ForegroundColor Yellow
    & $script:UvInvoker 'run' 'python' '-m' 'playwright' 'install'
}

function Invoke-SetupEnvironments {
    [CmdletBinding()]
    param(
        [string] $ProjectRoot
    )

    if ($ProjectRoot) {
        $resolvedProjectRoot = (Resolve-Path $ProjectRoot).ProviderPath
    }
    else {
        $scriptPath = $script:SetupEnvironmentsScriptPath
        if ([string]::IsNullOrEmpty($scriptPath)) {
            throw "スクリプトのパスを取得できませんでした。"
        }

        $scriptRoot = Split-Path -Parent $scriptPath
        $resolvedProjectRoot = Split-Path -Parent $scriptRoot
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

    # GitHub CLIをインストール
    Install-WingetPackage -Id "GitHub.cli" -Name "GitHub CLI"

    # 新規インストールされたコマンドを認識させる
    Update-Path

    # Mermaid CLIをインストール
    Install-NpmGlobalPackage -Package "@mermaid-js/mermaid-cli" -Name "Mermaid CLI"

    $previousLocation = & $script:GetLocationInvoker

    try {
        & $script:SetLocationInvoker -Path $resolvedProjectRoot

        # pyproject.tomlに定義された依存関係をインストール
        Write-Host "uv sync を実行して依存関係をインストールします..." -ForegroundColor Yellow
        & $script:UvInvoker 'sync'
        Write-Host "uv sync が完了しました。" -ForegroundColor Green

        # Playwrightブラウザのインストール
        Install-PlaywrightBrowsers
    }
    finally {
        $previousPath = if ($previousLocation -is [string]) { $previousLocation } else { $previousLocation.ProviderPath }
        & $script:SetLocationInvoker -Path $previousPath
    }
}

if ($MyInvocation.InvocationName -notin @('.', 'source')) {
    Invoke-SetupEnvironments @PSBoundParameters
}
