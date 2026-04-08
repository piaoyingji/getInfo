# Main_Menu.ps1
# Version: 1.5.0
# Description: サーバー一括調査ツール - メインメニュー (PS 5.1 互換 + 交互式メニュー)

$ErrorActionPreference = "Stop"

Try {
    # 1. 環境初期化
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    If (-not $ScriptDir) { $ScriptDir = Get-Location }
    Set-Location $ScriptDir

    # 2. 共通モジュールのロード
    $UtilsPath = Join-Path $ScriptDir "Module_Utils.ps1"
    If (Test-Path $UtilsPath) { . $UtilsPath } Else { throw "Module_Utils.ps1 not found." }

    # 3. モジュール存在チェック
    $ModuleFiles = @("Module_Apache.ps1", "Module_Tomcat.ps1", "Module_Oracle.ps1")
    Foreach ($M in $ModuleFiles) {
        $MPath = Join-Path $ScriptDir $M
        If (-not (Test-Path $MPath)) {
            throw "Missing: ${M}"
        }
    }

    # 4. 業務ロジックのロード
    . (Join-Path $ScriptDir "Module_Apache.ps1")
    . (Join-Path $ScriptDir "Module_Tomcat.ps1")
    . (Join-Path $ScriptDir "Module_Oracle.ps1")

    # 5. レポート初期化
    Write-MenuHeader (T "Searching")
    $PromptLabel = T "AskFilename"
    Write-Host "`n${PromptLabel}" -ForegroundColor White
    $InFilename = Read-Host ">>"
    
    If (-not [string]::IsNullOrWhiteSpace($InFilename)) {
        If ($InFilename -notlike "*.txt") { $InFilename += ".txt" }
        $Global:ReportFile = $InFilename
    } Else {
        $Global:ReportFile = "Investigation_Report.txt"
    }

    # レポートヘッダー書き込み (UTF8 指定で互換性確保)
    $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $Global:ReportFile -Value ((T "StartTime") + ": ${StartTime}") -Encoding UTF8
    Add-Content -Path $Global:ReportFile -Value "" -Encoding UTF8

    # 6. メインループ
    $Options = @(
        (T "MenuOption1"),
        (T "MenuOption2"),
        (T "MenuOption3"),
        (T "MenuOption4"),
        (T "MenuOptionExit")
    )

    $Selected = 0
    While ($true) {
        $Selected = Show-Menu -Title "Main Menu" -Options $Options -SelectedIndex $Selected
        
        Switch ($Selected) {
            0 {
                Write-MenuHeader (T "Searching")
                Investigate-Apache -Silent $true
                Investigate-Tomcat -Silent $true
                Investigate-Oracle -Silent $true
                Wait-AndClear
            }
            1 { Investigate-Apache }
            2 { Investigate-Tomcat }
            3 { Investigate-Oracle }
            4 { 
                Write-Host "Exiting..." -ForegroundColor Gray
                return 
            }
        }
    }

} Catch {
    Write-Host "`n[Critical Error] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    Write-Host "`nプログラムが異常終了しました。Enterキーを押してウィンドウを閉じてください。" -ForegroundColor Yellow
    Read-Host
}
