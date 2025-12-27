$ErrorActionPreference = 'Stop'

# このフォルダ配下のPesterテストをすべて実行する
Invoke-Pester -Path $PSScriptRoot
