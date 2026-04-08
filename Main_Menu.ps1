# Main_Menu.ps1
# Version: 1.5.1
# Description: サーバー一括調査ツール - メインメニュー (子母メニュー構造 + 交互式)

$ErrorActionPreference = "Stop"

Try {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    If (-not $ScriptDir) { $ScriptDir = Get-Location }
    Set-Location $ScriptDir

    $UtilsPath = Join-Path $ScriptDir "Module_Utils.ps1"
    If (Test-Path $UtilsPath) { . $UtilsPath } Else { throw "Module_Utils.ps1 not found." }

    . (Join-Path $ScriptDir "Module_Apache.ps1")
    . (Join-Path $ScriptDir "Module_Tomcat.ps1")
    . (Join-Path $ScriptDir "Module_Oracle.ps1")

    # 初期設定
    Write-MenuHeader (T "Searching")
    Write-Host "`n$(T 'AskFilename')" -ForegroundColor White
    $InFilename = Read-Host ">>"
    $Global:ReportFile = If ([string]::IsNullOrWhiteSpace($InFilename)) { "Investigation_Report.txt" } Else { if ($InFilename -notlike "*.txt") { $InFilename + ".txt" } else { $InFilename } }

    $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $Global:ReportFile -Value ((T "StartTime") + ": ${StartTime}") -Encoding UTF8
    Add-Content -Path $Global:ReportFile -Value "" -Encoding UTF8

    $MainMenuOptions = @((T "MenuOption1"), (T "MenuOption2"), (T "MenuOption3"), (T "MenuOption4"), (T "MenuOptionSettings"), (T "MenuOptionExit"))
    $SubMenuOptions = @((T "LangChoice"), (T "ReturnMain"))

    $MainSelected = 0
    While ($true) {
        $MainSelected = Show-Menu -Title "Main Menu" -Options $MainMenuOptions -SelectedIndex $MainSelected
        
        Switch ($MainSelected) {
            0 { Write-MenuHeader (T "Searching"); Investigate-Apache -Silent $true; Investigate-Tomcat -Silent $true; Investigate-Oracle -Silent $true; Wait-AndClear }
            1 { Investigate-Apache }
            2 { Investigate-Tomcat }
            3 { Investigate-Oracle }
            4 { 
                # 設定子メニュー (子母構造の復活)
                $SubSelected = 0
                While ($true) {
                    $SubSelected = Show-Menu -Title (T "SubMenuHeader") -Options $SubMenuOptions -SelectedIndex $SubSelected
                    If ($SubSelected -eq 0) { Write-Host "`n現在は日本語版のみ有効です。" -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
                    Else { break }
                }
            }
            5 { Write-Host "Exiting..." -ForegroundColor Gray; return }
        }
    }
} Catch {
    Write-Host "`n[Critical Error] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nプログラムが異常終了しました。Enterキーを押してください。" -ForegroundColor Yellow
    Read-Host
}
