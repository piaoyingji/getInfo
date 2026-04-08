# Main_Menu.ps1
# Version: 1.4.0
# Description: サーバー一括調査ツール - メインメニュー (日本語専用版)

$ErrorActionPreference = "Continue"

# 1. 環境初期化
If ($PSScriptRoot) { $Root = $PSScriptRoot } Else { $Root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue }
If (-not $Root) { $Root = Get-Location }
Set-Location $Root

# 2. 共通モジュールのロード
. (Join-Path $Root "Module_Utils.ps1")

# 3. モジュール存在チェック
$Modules = @("Module_Apache.ps1", "Module_Tomcat.ps1", "Module_Oracle.ps1")
Foreach ($M in $Modules) {
    If (-not (Test-Path (Join-Path $Root $M))) {
        Write-Host "[Error] ファイルが見つかりません: ${M}" -ForegroundColor Red
        Read-Host "Enterキーを押して終了します..."
        Exit
    }
}

# 4. 業務ロジックのロード
. (Join-Path $Root "Module_Apache.ps1")
. (Join-Path $Root "Module_Tomcat.ps1")
. (Join-Path $Root "Module_Oracle.ps1")

# 5. レポート初期化
Clear-Host
Write-MenuHeader (T "Searching")

$PromptLabel = T "AskFilename"
$InFilename = Read-Host $PromptLabel
If (-not [string]::IsNullOrWhiteSpace($InFilename)) {
    If ($InFilename -notlike "*.txt") { $InFilename += ".txt" }
    $Global:ReportFile = $InFilename
} Else {
    $Global:ReportFile = "Investigation_Report.txt"
}

# レポートヘッダー書き込み
$StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Set-Content -Path $Global:ReportFile -Value ((T "StartTime") + ": ${StartTime}")
Add-Content -Path $Global:ReportFile -Value ""

# 6. メインループ
$UserAction = ""
While ($UserAction -ne "5") {
    Write-MenuHeader "メインメニュー"
    
    Write-Host (" " + (T "MenuOption1")) -ForegroundColor Green
    Write-Host (" " + (T "MenuOption2")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOption3")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOption4")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOptionExit")) -ForegroundColor Gray
    Write-Host ""
    
    $UserAction = Read-Host ">>"
    
    Switch ($UserAction) {
        "1" {
            Write-MenuHeader (T "Searching")
            Investigate-Apache -Silent $true
            Investigate-Tomcat -Silent $true
            Investigate-Oracle -Silent $true
            Wait-AndClear
        }
        "2" { Investigate-Apache }
        "3" { Investigate-Tomcat }
        "4" { Investigate-Oracle }
        "5" { break }
    }
}
