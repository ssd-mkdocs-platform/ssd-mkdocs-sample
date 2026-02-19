$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Path $PSScriptRoot -Parent
$codeCoverageTargets = Get-ChildItem -Path $scriptsRoot -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.FullName -notmatch '[\\/](tests)[\\/]' } |
    ForEach-Object { $_.FullName }

# このフォルダ配下のPesterテストをすべて実行し、プロダクションスクリプトのカバレージを取得する
Invoke-Pester -Path $PSScriptRoot -CodeCoverage $codeCoverageTargets
