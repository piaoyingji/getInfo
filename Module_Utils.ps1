# Module_Utils.ps1
# Version: 1.5.0
# Description: 通用工具函数模块 (兼容性优化 + 交互式菜单)

# --- 全局配置 ---
If (-not $Global:ReportFile) { $Global:ReportFile = "Investigation_Report.txt" }

# --- 日本語辞書 ---
$Global:Lang = "ja-JP"
$Global:I18n = @{
    "ja-JP" = @{
        "MenuHeader"     = "サーバー一括調査ツール"
        "MenuInstructions" = "矢印キー [↑/↓] で移動、[Enter] で決定"
        "MenuOption1"    = "全量調査 (Apache + Tomcat + Oracle)"
        "MenuOption2"    = "Apache HTTP Server 调查"
        "MenuOption3"    = "Apache Tomcat 调查"
        "MenuOption4"    = "Oracle Database 调查"
        "MenuOptionExit" = "終了"
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

# --- 交互式菜单逻辑 (兼容 PS 5.1+) ---
Function Show-Menu {
    Param(
        [String]$Title,
        [String[]]$Options,
        [Int]$SelectedIndex = 0
    )

    $OriginalPos = $Host.UI.RawUI.CursorPosition
    $CurrentIndex = $SelectedIndex
    $Running = $true

    While ($Running) {
        $Host.UI.RawUI.CursorPosition = $OriginalPos
        Write-MenuHeader $Title
        Write-Host (T "MenuInstructions") -ForegroundColor Gray
        Write-Host ""

        For ($i = 0; $i -lt $Options.Count; $i++) {
            If ($i -eq $CurrentIndex) {
                Write-Host " > $($Options[$i])" -ForegroundColor Cyan -BackgroundColor DarkBlue
            } Else {
                Write-Host "   $($Options[$i])" -ForegroundColor White
            }
        }

        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        
        Switch ($Key) {
            38 { # Up Arrow
                $CurrentIndex--
                If ($CurrentIndex -lt 0) { $CurrentIndex = $Options.Count - 1 }
            }
            40 { # Down Arrow
                $CurrentIndex++
                If ($CurrentIndex -ge $Options.Count) { $CurrentIndex = 0 }
            }
            13 { # Enter
                $Running = $false
            }
        }
    }
    return $CurrentIndex
}

# --- 核心工具函数 ---

Function Write-ToReport {
    Param([String]$Title, [String]$Content)
    $Divider = "=" * 50
    $Header = "--- ${Title} ---"
    # 强制使用 UTF8 以增强兼容性
    Add-Content -Path $Global:ReportFile -Value $Divider -Encoding UTF8
    Add-Content -Path $Global:ReportFile -Value $Header -Encoding UTF8
    Add-Content -Path $Global:ReportFile -Value $Content -Encoding UTF8
    Add-Content -Path $Global:ReportFile -Value "" -Encoding UTF8
}

Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    Write-Host "[RESULT] ${Title}: ${ShortResult}" -ForegroundColor Green
    Write-ToReport -Title $Title -Content $FullDetail
}

Function Write-MenuHeader {
    Param([String]$MenuTitle)
    # 不清理控制台以防部分终端显示异常，改为重排
    # Clear-Host
    $Line = "*" * 60
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ("*  " + (T "MenuHeader") + " - ${MenuTitle}") -ForegroundColor Cyan
    Write-Host $Line -ForegroundColor Cyan
}

Function Wait-AndClear {
    Write-Host ("`n" + (T "WaitReturn")) -ForegroundColor Yellow
    Read-Host
}

Write-Host "[INIT] Module_Utils Loaded (v1.5.0 Compatible Mode)" -ForegroundColor Gray
