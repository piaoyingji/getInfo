# Module_Utils.ps1
# Version: 1.4.0
# Description: 通用工具函数模块 (日本語版专用)

# --- 全局配置 ---
If (-not $Global:ReportFile) { $Global:ReportFile = "Investigation_Report.txt" }

# --- 日本語辞書 ---
$Global:Lang = "ja-JP"
$Global:I18n = @{
    "ja-JP" = @{
        "MenuHeader"     = "サーバー一括調査ツール"
        "MenuOption1"    = "[1] 全量調査 (Apache + Tomcat + Oracle)"
        "MenuOption2"    = "[2] Apache HTTP Server 調査"
        "MenuOption3"    = "[3] Apache Tomcat 調査"
        "MenuOption4"    = "[4] Oracle Database 調査"
        "MenuOptionExit" = "[5] 終了"
        "AskFilename"    = "調査結果のファイル名を入力してください (デフォルト: Investigation_Report.txt)"
        "StartTime"      = "調査開始時間"
        "Searching"      = "検索中"
        "ResultFound"    = "{1} が {0} 件見つかりました。"
        "NoneFound"      = "なし"
        "WaitReturn"     = "完了しました。[Enter] キーを押してメニューに戻ります..."
        "SvcSearch"      = "[Search] Windows サービスをスキャン中..."
        "ProcSearch"     = "[Search] 実行中のプロセスを分析中..."
        "PathSearch"     = "[Search] 一般的なディレクトリをスキャン中..."
        "SSL_On"         = "SSL 有効"
        "SSL_Off"        = "SSL 無効"
        "Expr_Date"      = "有効期限"
        "WebappsInfo"    = "デプロイ済み環境"
        "OracleLogin"    = "--- Oracle ログイン ---"
        "Username"       = "ユーザー名"
        "Password"       = "パスワード"
        "Instance"       = "接続先/SID"
        "Connecting"     = "[Action] 接続中..."
    }
}

# --- 翻訳補助関数 ---
Function T {
    Param([String]$Key, [Object[]]$Args)
    $Str = $Global:I18n["ja-JP"][$Key]
    If ($null -eq $Str) { return $Key }
    If ($Args) { return $Str -f $Args }
    return $Str
}

# --- 核心工具関数 ---

Function Write-ToReport {
    Param([String]$Title, [String]$Content)
    $Divider = "=" * 50
    $Header = "--- ${Title} ---"
    Add-Content -Path $Global:ReportFile -Value $Divider
    Add-Content -Path $Global:ReportFile -Value $Header
    Add-Content -Path $Global:ReportFile -Value $Content
    Add-Content -Path $Global:ReportFile -Value ""
}

Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    Write-Host "[RESULT] ${Title}: ${ShortResult}" -ForegroundColor Green
    Write-ToReport -Title $Title -Content $FullDetail
}

Function Write-MenuHeader {
    Param([String]$MenuTitle)
    Clear-Host
    $Line = "*" * 60
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ("*  " + (T "MenuHeader") + " - ${MenuTitle}") -ForegroundColor Cyan
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ""
}

Function Wait-AndClear {
    Write-Host ("`n" + (T "WaitReturn")) -ForegroundColor Yellow
    Read-Host
}

Write-Host "[INIT] Module_Utils Loaded (Japanese version v1.4.0)" -ForegroundColor Gray
