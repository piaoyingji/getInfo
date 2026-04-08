# Module_Utils.ps1
# Version: 2.5.0
# Description: 共通ユーティリティ (v2.5.0 Oracle 垂直フォーマット対応版)

$Global:ReportFile = "Investigation_Report.txt"
$Global:I18n = @{
    "ja-JP" = @{
        "MenuHeader"       = "サーバー一括調査ツール"
        "CoverTitle"       = "初期設定画面"
        "MainTitle"        = "メインメニュー"
        "SubTitle"         = "設定メニュー"
        "InvestTotalTitle" = "全量一括調査"
        "InvestTitle"      = "{0} 調査画面"
        "Opt_All"          = "全量調査 (Apache, Tomcat, Oracle)"
        "Opt_Apache"       = "Apache 調査"
        "Opt_Tomcat"       = "Tomcat 調査"
        "Opt_Oracle"       = "Oracle 調査"
        "Opt_Settings"     = "設定 / 子メニュー"
        "Opt_Exit"         = "終了"
        "Opt_Lang"         = "言語設定 (日本語固定)"
        "Opt_Back"         = "メインメニューに戻る"
        "ProcSearch"       = "実行中プロセスの検索中..."
        "SvcSearch"        = "レジストリ・サービス情報の検索中..."
        "PathSearch"       = "ディスク探索 (最終手段) 開始..."
        "Msg_Wait"         = "Enterキーを押してメニューに戻る..."
        "Msg_InputFile"    = "【入力】レポート名 (デフォルト: Investigation_Report.txt): "
        "Msg_Start"        = "調査開始時間"
        "Msg_Result"       = "[発見] {1} が {0} 件見つかりました。"
        "Msg_None"         = "該当なし"
        "Ora_Header"       = "--- Oracle ログイン ---"
        "Ora_User"         = "ユーザー名         : "
        "Ora_Pass"         = "パスワード         : "
        "Ora_Inst"         = "接続先/SID        : "
        "Ora_Connect"      = "[Action] 接続中..."
        "SSL_On"           = "有効"
        "SSL_Off"          = "無効"
        "WebappsInfo"      = "Webアプリ数"
    }
}

Function T {
    Param([String]$Key, [Object[]]$Args)
    $Val = $Global:I18n["ja-JP"][$Key]
    If ($null -eq $Val) { return $Key }
    If ($Args) { return $Val -f $Args } 
    return $Val
}

Function Invoke-Menu {
    Param(
        [String]$Title,
        [String[]]$Options,
        [Int]$Default = 0
    )
    $Selected = $Default
    While ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

    While ($true) {
        Clear-Host
        Write-MenuHeader $Title
        Write-Host " [↑/↓] キーで移動、[Enter] で決定" -ForegroundColor Gray
        Write-Host ""
        For ($i=0; $i -lt $Options.Count; $i++) {
            If ($i -eq $Selected) {
                Write-Host "  >> $($Options[$i])" -ForegroundColor Cyan -BackgroundColor DarkBlue
            } Else {
                Write-Host "     $($Options[$i])" -ForegroundColor White
            }
        }
        $KeyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $KeyCode = $KeyInfo.VirtualKeyCode
        If ($KeyCode -eq 38) { $Selected--; If ($Selected -lt 0) { $Selected = $Options.Count - 1 } }
        ElseIf ($KeyCode -eq 40) { $Selected++; If ($Selected -ge $Options.Count) { $Selected = 0 } }
        ElseIf ($KeyCode -eq 13) { return $Selected }
    }
}

Function Write-MenuHeader {
    Param([String]$SubTitle)
    $Line = "=" * 70
    Write-Host $Line -ForegroundColor Cyan
    Write-Host "   $(T 'MenuHeader') - $SubTitle" -ForegroundColor White
    Write-Host $Line -ForegroundColor Cyan
}

Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    Write-Host ("[RESULT] " + $Title + ": " + $ShortResult) -ForegroundColor Green
    $Content = ("="*50 + "`n--- " + $Title + " ---`n" + $FullDetail + "`n")
    Add-Content -Path $Global:ReportFile -Value $Content -Encoding UTF8
}

Function Wait-AndClear {
    Write-Host "`n$(T 'Msg_Wait')" -ForegroundColor Yellow
    [void](Read-Host)
}

Write-Host "[INIT] Module_Utils v2.5.0 ロード完了" -ForegroundColor Gray
