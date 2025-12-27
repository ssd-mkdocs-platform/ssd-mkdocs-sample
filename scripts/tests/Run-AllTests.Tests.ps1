$ErrorActionPreference = 'Stop'

Describe 'Run-AllTests.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'Run-AllTests.ps1'
        $scriptsRoot = Split-Path -Path $PSScriptRoot -Parent

        $expectedCoverageTargets = Get-ChildItem -Path $scriptsRoot -Filter '*.ps1' -File -Recurse |
            Where-Object { $_.FullName -notmatch '[\\/](tests)[\\/]' } |
            ForEach-Object { $_.FullName }
    }

    It 'Invoke-PesterにCodeCoverageでプロダクションスクリプトを指定する' {
        Mock -CommandName Invoke-Pester

        & $scriptPath

        Assert-MockCalled Invoke-Pester -Times 1 -ParameterFilter {
            if (-not $CodeCoverage) {
                return $false
            }

            -not (Compare-Object -ReferenceObject $expectedCoverageTargets -DifferenceObject $CodeCoverage)
        }
    }
}
