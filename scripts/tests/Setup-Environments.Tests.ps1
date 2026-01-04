$ErrorActionPreference = 'Stop'

Describe 'Setup-Environments.ps1' {
    BeforeAll {
        $start = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
        $current = (Resolve-Path $start).ProviderPath

        while ($true) {
            $candidate = Join-Path -Path $current -ChildPath 'Setup-Environments.ps1'
            if (Test-Path $candidate) {
                $scriptPath = (Resolve-Path $candidate).ProviderPath
                break
            }

            $parent = Split-Path -Path $current -Parent
            if (-not $parent -or $parent -eq $current) {
                throw 'Setup-Environments.ps1 のパスを解決できません。'
            }
            $current = $parent
        }

        function Reset-SetupEnvInvokers {
            foreach ($name in @(
                    'WingetInvoker',
                    'NpmInvoker',
                    'UvInvoker',
                    'TestPathInvoker',
                    'GetChildItemInvoker',
                    'SetLocationInvoker',
                    'GetLocationInvoker',
                    'GetEnvironmentVariableInvoker'
                )) {
                Set-Variable -Scope Script -Name $name -Value $null -ErrorAction SilentlyContinue
            }
        }

        # ログ出力を抑制する
        Mock -CommandName Write-Host {}
    }

    It 'ドットソースしても外部コマンドを呼び出さない' {
        Reset-SetupEnvInvokers
        Set-Variable -Scope Script -Name WingetInvoker -Value { throw 'winget should not run when dot-sourced' }
        Set-Variable -Scope Script -Name NpmInvoker -Value { throw 'npm should not run when dot-sourced' }
        Set-Variable -Scope Script -Name UvInvoker -Value { throw 'uv should not run when dot-sourced' }
        Set-Variable -Scope Script -Name TestPathInvoker -Value { throw 'Test-Path should not run when dot-sourced' }

        { . $scriptPath } | Should -Not -Throw
    }

    Context 'デフォルトinvoker' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
        }

        AfterEach {
            Remove-Item Function:\winget -ErrorAction SilentlyContinue
            Remove-Item Function:\npm -ErrorAction SilentlyContinue
            Remove-Item Function:\uv -ErrorAction SilentlyContinue
        }

        It '各コマンドに委譲する' {
            $global:WingetDefaultCalled = 0
            $global:NpmDefaultCalled = 0
            $global:UvDefaultCalled = 0

            function global:winget {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                $global:WingetDefaultCalled++
                $Args -join ' '
            }

            function global:npm {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                $global:NpmDefaultCalled++
                '{ "dependencies": { } }'
            }

            function global:uv {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                $global:UvDefaultCalled++
            }

            & $script:WingetInvoker 'list' '--id' 'dummy'
            & $script:NpmInvoker 'list' '-g' '--depth=0' '--json' '--long'
            & $script:UvInvoker 'sync'
            & $script:TestPathInvoker -Path 'C:\does-not-exist' -PathType Container -ErrorAction SilentlyContinue
            & $script:GetChildItemInvoker -Path 'C:\does-not-exist' -Force -ErrorAction SilentlyContinue
            & $script:SetLocationInvoker -Path (Get-Location).ProviderPath
            & $script:GetLocationInvoker | Out-Null

            $global:WingetDefaultCalled | Should -Be 1
            $global:NpmDefaultCalled | Should -Be 1
            $global:UvDefaultCalled | Should -Be 1
        }
    }

    Context 'Update-Path' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
        }

        It 'レジストリから取得したPATHに含まれる環境変数(%VAR%形式)を展開する' {
            # SystemRootの実際の値を取得（通常は C:\Windows）
            $actualSystemRoot = $env:SystemRoot

            # 未展開の環境変数を含むPATHをモックで返す
            Set-Variable -Scope Script -Name GetEnvironmentVariableInvoker -Value {
                param([string] $Variable, [string] $Target)
                if ($Variable -eq 'PATH' -and $Target -eq 'Machine') {
                    return '%SystemRoot%\System32;C:\Program Files\Test'
                }
                if ($Variable -eq 'PATH' -and $Target -eq 'User') {
                    return '%USERPROFILE%\bin'
                }
                return $null
            }

            Update-Path

            # 展開後のパスが含まれていることを確認
            $env:PATH | Should -Match ([regex]::Escape($actualSystemRoot))
            # 未展開の%SystemRoot%が残っていないことを確認
            $env:PATH | Should -Not -Match '%SystemRoot%'
            # 未展開の%USERPROFILE%が残っていないことを確認
            $env:PATH | Should -Not -Match '%USERPROFILE%'
        }

        It 'MachineパスとUserパスの両方を結合する' {
            Set-Variable -Scope Script -Name GetEnvironmentVariableInvoker -Value {
                param([string] $Variable, [string] $Target)
                if ($Variable -eq 'PATH' -and $Target -eq 'Machine') {
                    return 'C:\Machine\Path'
                }
                if ($Variable -eq 'PATH' -and $Target -eq 'User') {
                    return 'C:\User\Path'
                }
                return $null
            }

            Update-Path

            $env:PATH | Should -Match 'C:\\Machine\\Path'
            $env:PATH | Should -Match 'C:\\User\\Path'
        }
    }

    Context 'Install-WingetPackage' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
        }

        It 'インストール済みならwinget installを呼ばない' {
            $global:WingetCalls = @()

            Set-Variable -Scope Script -Name WingetInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                $global:WingetCalls += ,$Args
                if ($Args[0] -eq 'list') {
                    return 'Python.Python.3.13'
                }
                if ($Args[0] -eq 'install') {
                    throw 'install should not be called'
                }
            }

            Install-WingetPackage -Id 'Python.Python.3.13' -Name 'Python 3.13'

            $global:WingetCalls | Where-Object { $_[0] -eq 'list' } | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 1
            $global:WingetCalls | Where-Object { $_[0] -eq 'install' } | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 0
        }

        It '未インストールならwinget installで導入する' {
            $global:WingetCalls = @()

            Set-Variable -Scope Script -Name WingetInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                $global:WingetCalls += ,$Args
                if ($Args[0] -eq 'list') { return $null }
                if ($Args[0] -eq 'install') { return 'installed' }
            }

            Install-WingetPackage -Id 'Microsoft.AzureCLI' -Name 'Azure CLI'

            $global:WingetCalls | Where-Object { $_[0] -eq 'list' } | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 1
            $global:WingetCalls | Where-Object { $_[0] -eq 'install' } | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 1
        }
    }

    Context 'Install-NpmGlobalPackage' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
        }

        It '既に入っていればnpm installを呼ばない' {
            Set-Variable -Scope Script -Name NpmInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'list') { '{ "dependencies": { "@mermaid-js/mermaid-cli": {} } }' }
                elseif ($Args[0] -eq 'install') { throw 'npm install should not be called' }
            }

            Install-NpmGlobalPackage -Package '@mermaid-js/mermaid-cli' -Name 'Mermaid CLI'

            # listのみ呼ばれてinstallは呼ばれない
        }

        It '未インストールならnpm installする' {
            $global:NpmInstalls = 0

            Set-Variable -Scope Script -Name NpmInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'list') {
                    return '{ "dependencies": { } }'
                }
                if ($Args[0] -eq 'install') {
                    $global:NpmInstalls++
                }
            }

            Install-NpmGlobalPackage -Package '@mermaid-js/mermaid-cli' -Name 'Mermaid CLI'

            $global:NpmInstalls | Should -Be 1
        }

        It 'npm listのJSON変換に失敗した場合でもインストールする' {
            $global:NpmInstalls = 0

            Set-Variable -Scope Script -Name NpmInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'list') {
                    return 'not-json'
                }
                if ($Args[0] -eq 'install') {
                    $global:NpmInstalls++
                }
            }

            Install-NpmGlobalPackage -Package '@mermaid-js/mermaid-cli' -Name 'Mermaid CLI'

            $global:NpmInstalls | Should -Be 1
        }
    }

    Context 'Install-PlaywrightBrowsers' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
        }

        It 'ブラウザが既にあればuvを呼ばない' {
            Set-Variable -Scope Script -Name TestPathInvoker -Value {
                param([string] $Path, [string] $PathType, [System.Management.Automation.ActionPreference] $ErrorAction)
                $true
            }
            Set-Variable -Scope Script -Name GetChildItemInvoker -Value {
                param([string] $Path, [switch] $Force, [System.Management.Automation.ActionPreference] $ErrorAction)
                ,([pscustomobject]@{ PSIsContainer = $true })
            }
            Set-Variable -Scope Script -Name UvInvoker -Value { throw 'uv should not be called when browsers exist' }

            { Install-PlaywrightBrowsers } | Should -Not -Throw
        }

        It 'Playwrightディレクトリが空ならuvでインストールする' {
            $global:UvCalls = 0

            Set-Variable -Scope Script -Name TestPathInvoker -Value {
                param([string] $Path, [string] $PathType, [System.Management.Automation.ActionPreference] $ErrorAction)
                $true
            }
            Set-Variable -Scope Script -Name GetChildItemInvoker -Value {
                param([string] $Path, [switch] $Force, [System.Management.Automation.ActionPreference] $ErrorAction)
                @()
            }
            Set-Variable -Scope Script -Name UvInvoker -Value { $global:UvCalls++ }

            Install-PlaywrightBrowsers

            $global:UvCalls | Should -Be 1
        }

        It 'Playwrightディレクトリがなければuvでインストールする' {
            $global:UvCalls = 0

            Set-Variable -Scope Script -Name TestPathInvoker -Value {
                param([string] $Path, [string] $PathType, [System.Management.Automation.ActionPreference] $ErrorAction)
                $false
            }
            Set-Variable -Scope Script -Name UvInvoker -Value { $global:UvCalls++ }

            Install-PlaywrightBrowsers

            $global:UvCalls | Should -Be 1
        }
    }

    Context 'Invoke-SetupEnvironments' {
        BeforeEach {
            Reset-SetupEnvInvokers
            . $scriptPath
            $global:WingetPackages = @()
            $global:NpmCalls = 0
            $global:UvSyncCalls = 0
            $global:PlaywrightCalls = 0
        }

        It '全体のセットアップフローを呼び出す' {
            $tempRoot = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString()))

            Set-Variable -Scope Script -Name WingetInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'list') { return $null }
                if ($Args[0] -eq 'install') { $global:WingetPackages += $Args[2] }
            }
            Set-Variable -Scope Script -Name NpmInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'list') { '{ "dependencies": { } }' }
                if ($Args[0] -eq 'install') { $global:NpmCalls++ }
            }
            Set-Variable -Scope Script -Name UvInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'sync') { $global:UvSyncCalls++ }
                if ($Args[0] -eq 'run') { throw 'run should not be called in flow test' }
            }
            Set-Variable -Scope Script -Name SetLocationInvoker -Value {
                param([string] $Path)
                $global:Location = $Path
            }
            Set-Variable -Scope Script -Name GetLocationInvoker -Value { [pscustomobject]@{ ProviderPath = $tempRoot.FullName } }
            Mock -CommandName Install-PlaywrightBrowsers { $global:PlaywrightCalls++ }

            Invoke-SetupEnvironments -ProjectRoot $tempRoot.FullName

            $global:WingetPackages.Count | Should -Be 6
            $global:NpmCalls | Should -Be 1
            $global:UvSyncCalls | Should -Be 1
            $global:PlaywrightCalls | Should -Be 1
        }

        It 'ProjectRoot未指定の場合はスクリプトパスから解決する' {
            Reset-SetupEnvInvokers
            . $scriptPath

            $global:WingetCalls = 0
            $global:LocationCalls = @()
            Set-Variable -Scope Script -Name WingetInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'install') { $global:WingetCalls++ }
            }
            Set-Variable -Scope Script -Name NpmInvoker -Value {
                param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args)
                if ($Args[0] -eq 'install') { }
            }
            Set-Variable -Scope Script -Name UvInvoker -Value { param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Args) }
            Set-Variable -Scope Script -Name SetLocationInvoker -Value { param([string] $Path) $global:LocationCalls += $Path }
            Set-Variable -Scope Script -Name GetLocationInvoker -Value { [pscustomobject]@{ ProviderPath = 'C:\current' } }
            Mock -CommandName Install-PlaywrightBrowsers { }

            Invoke-SetupEnvironments

            $global:WingetCalls | Should -Be 6
            $global:LocationCalls[0] | Should -Match ([regex]::Escape((Split-Path -Parent $scriptPath | Split-Path -Parent)))
        }

        It 'スクリプトパスが空の場合は例外を投げる' {
            Reset-SetupEnvInvokers
            . $scriptPath

            $originalPath = $script:SetupEnvironmentsScriptPath
            $script:SetupEnvironmentsScriptPath = $null

            try {
                { Invoke-SetupEnvironments } | Should -Throw
            }
            finally {
                $script:SetupEnvironmentsScriptPath = $originalPath
            }
        }
    }
}
