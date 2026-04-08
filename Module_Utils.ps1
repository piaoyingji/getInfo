# Module_Utils.ps1
# Version: 1.2.0
# Description: 通用工具函数模块 (增加多语言支持与设置持久化)

# --- 全局配置 ---
If (-not $Global:ReportFile) { $Global:ReportFile = "Investigation_Report.txt" }

# --- 多语言字典 ---
$Global:Lang = "zh-CN" # 默认语言
$SettingsFile = Join-Path $PSScriptRoot "config.ini"

$Global:I18n = @{
    "zh-CN" = @{
        "MenuHeader"     = "服务器调查工具集"
        "MenuOption1"    = "[1] 全量同步调查 (Apache + Tomcat + Oracle)"
        "MenuOption2"    = "[2] 单独调查 Apache HTTP Server"
        "MenuOption3"    = "[3] 单独调查 Apache Tomcat"
        "MenuOption4"    = "[4] 单独调查 Oracle Database"
        "MenuOptionLang" = "[L] 语言设置 / Language Settings / 言語設定"
        "MenuOptionExit" = "[5] 正常退出程序"
        "LangSelect"     = "请选择语言: 1.中文 2.English 3.日本語"
        "AskFilename"    = "请输入调查结果存档文件名 (默认为 Investigation_Report.txt)"
        "StartTime"      = "调查开始时间"
        "Searching"      = "正在检索"
        "ResultFound"    = "共发现 {0} 个 {1} 实例。"
        "NoneFound"      = "无"
        "WaitReturn"     = "处理完成，按 [Enter] 键返回主菜单..."
        "SvcSearch"      = "[Search] 正在扫描 Windows 服务..."
        "ProcSearch"     = "[Search] 正在分析运行中的进程..."
        "PathSearch"     = "[Search] 正在扫描常用目录..."
        "SSL_On"         = "已开启 SSL"
        "SSL_Off"        = "未开启 SSL"
        "Expr_Date"      = "到期日"
        "WebappsInfo"    = "业务部署点"
    }
    "en-US" = @{
        "MenuHeader"     = "Server Investigation Toolset"
        "MenuOption1"    = "[1] Full Investigation (Apache + Tomcat + Oracle)"
        "MenuOption2"    = "[2] Investigate Apache HTTP Server"
        "MenuOption3"    = "[3] Investigate Apache Tomcat"
        "MenuOption4"    = "[4] Investigate Oracle Database"
        "MenuOptionLang" = "[L] Language Settings"
        "MenuOptionExit" = "[5] Exit"
        "LangSelect"     = "Select Language: 1.Chinese 2.English 3.Japanese"
        "AskFilename"    = "Enter report filename (default: Investigation_Report.txt)"
        "StartTime"      = "Investigation Start Time"
        "Searching"      = "Searching"
        "ResultFound"    = "Found {0} instances of {1}."
        "NoneFound"      = "None"
        "WaitReturn"     = "Completed. Press [Enter] to return to menu..."
        "SvcSearch"      = "[Search] Scanning Windows Services..."
        "ProcSearch"     = "[Search] Analyzing running processes..."
        "PathSearch"     = "[Search] Scanning common directories..."
        "SSL_On"         = "SSL Enabled"
        "SSL_Off"        = "SSL Disabled"
        "Expr_Date"      = "Expiry Date"
        "WebappsInfo"    = "Webapps"
    }
    "ja-JP" = @{
        "MenuHeader"     = "サーバー一括調査ツール"
        "MenuOption1"    = "[1] 全量調査 (Apache + Tomcat + Oracle)"
        "MenuOption2"    = "[2] Apache HTTP Server 調査"
        "MenuOption3"    = "[3] Apache Tomcat 調査"
        "MenuOption4"    = "[4] Oracle Database 调查"
        "MenuOptionLang" = "[L] 言語設定 / Language Settings"
        "MenuOptionExit" = "[5] 終了"
        "LangSelect"     = "言語を選択してください: 1.中国語 2.英語 3.日本語"
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
    }
}

# --- 设置持久化函数 ---
Function Load-Settings {
    If (Test-Path $SettingsFile) {
        $SavedLang = Get-Content $SettingsFile | Select-Object -First 1
        If ($Global:I18n.ContainsKey($SavedLang)) {
            $Global:Lang = $SavedLang
        }
    }
}

Function Save-Settings {
    Param([String]$LangCode)
    $LangCode | Out-File $SettingsFile -Encoding utf8
    $Global:Lang = $LangCode
}

# --- 翻译辅助函数 ---
Function T {
    Param([String]$Key, [Object[]]$Args)
    $Str = $Global:I18n[$Global:Lang][$Key]
    If ($null -eq $Str) { return $Key }
    If ($Args) { return $Str -f $Args }
    return $Str
}

# --- 核心工具函数 ---

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

# 初始化
Load-Settings
Write-Host "[INIT] Module_Utils Loaded (Lang: $Global:Lang)" -ForegroundColor Gray
