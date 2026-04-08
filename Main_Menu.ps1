# Main_Menu.ps1
# Version: 3.4.0
# Description: サーバー一括調査ツール (v3.4.0 Oracle パイプ区切り対照版)

$ErrorActionPreference = "Stop"

Try {
    # 1. パス初期化
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue
    If (-not $ScriptDir) { $ScriptDir = Get-Location }
    Set-Location $ScriptDir

    # 2. 共通モジュールのロード
    $UtilsPath = Join-Path $ScriptDir "Module_Utils.ps1"
    If (Test-Path $UtilsPath) { . $UtilsPath } Else { throw "Module_Utils.ps1 が見つかりません。" }

    . (Join-Path $ScriptDir "Module_Apache.ps1")
    . (Join-Path $ScriptDir "Module_Tomcat.ps1")
    . (Join-Path $ScriptDir "Module_Oracle.ps1")

    # --- [画面1: 表紙] ---
    Clear-Host
    Write-MenuHeader (T "CoverTitle")
    Write-Host "Version: 3.4.0 (Aligned Table Output Mode)" -ForegroundColor Gray
    Write-Host "`n$(T 'Msg_InputFile')" -NoNewline
    $InFilename = Read-Host
    $Global:ReportFile = If ([string]::IsNullOrWhiteSpace($InFilename)) { "Investigation_Report.txt" } Else { if ($InFilename -notlike "*.txt") { $InFilename + ".txt" } else { $InFilename } }

    $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $Global:ReportFile -Value ("$(T 'Msg_Start'): $StartTime`n") -Encoding UTF8

    # --- [画面2: メインメニュー] ---
    $MainOptions = @(
        (T "Opt_All"),
        (T "Opt_Apache"),
        (T "Opt_Tomcat"),
        (T "Opt_Oracle"),
        (T "Opt_Settings"),
        (T "Opt_Exit")
    )

    $Selected = 0
    While ($true) {
        $Selected = Invoke-Menu -Title (T "MainTitle") -Options $MainOptions -Default $Selected
        
        Clear-Host
        Switch ($Selected) {
            0 { 
                Write-MenuHeader (T "InvestTotalTitle")
                Investigate-Apache -Silent $true
                Investigate-Tomcat -Silent $true
                Investigate-Oracle -Silent $true
                Wait-AndClear 
            }
            1 { 
                Write-MenuHeader (T "InvestTitle" @("Apache"))
                Investigate-Apache -Silent $true
                Wait-AndClear 
            }
            2 { 
                Write-MenuHeader (T "InvestTitle" @("Tomcat"))
                Investigate-Tomcat -Silent $true
                Wait-AndClear 
            }
            3 { 
                Write-MenuHeader (T "InvestTitle" @("Oracle"))
                Investigate-Oracle -Silent $true
                Wait-AndClear 
            }
            4 { 
                $SubOptions = @((T "Opt_Lang"), (T "Opt_Back"))
                $SubSelected = 0
                While ($true) {
                    $SubSelected = Invoke-Menu -Title (T "SubTitle") -Options $SubOptions -Default $SubSelected
                    If ($SubSelected -eq 0) { 
                        Write-Host "`n現在は日本語のみ対応しています。" -ForegroundColor Yellow
                        Start-Sleep -Seconds 1 
                    } Else { break }
                }
                $Selected = 4
            }
            5 { 
                Write-Host "`n終了します..." -ForegroundColor Gray
                return 
            }
        }
    }

} Catch {
    Write-Host "`n[Critical Error] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    Write-Host "`nプログラムが異常終了しました。Enterキーを押してください。" -ForegroundColor White
    [void](Read-Host)
}
