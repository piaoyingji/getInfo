# Main_Menu.ps1
# Version: 1.3.0
# Description: 服务器一键调查工具 - 主入口脚本 (全多语言支持 + 状态持久化)

$ErrorActionPreference = "Continue"

# 1. 初始化环境与路径
If ($PSScriptRoot) { $Root = $PSScriptRoot } Else { $Root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue }
If (-not $Root) { $Root = Get-Location }
Set-Location $Root

# 2. 加载基础工具 (包含多语言字典和 Load-Settings)
. (Join-Path $Root "Module_Utils.ps1")

# 3. 业务模块预检查
$Modules = @("Module_Apache.ps1", "Module_Tomcat.ps1", "Module_Oracle.ps1")
Foreach ($M in $Modules) {
    If (-not (Test-Path (Join-Path $Root $M))) {
        Write-Host "[Critical Error] Missing: ${M}" -ForegroundColor Red
        Read-Host "Press [Enter] to exit..."
        Exit
    }
}

# 4. 首次运行引导 (如果配置文件不存在，主动要求选择语言)
If (-not (Test-Path (Join-Path $Root "config.ini"))) {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Welcome / 欢迎使用 / ようこそ" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
    Write-Host "1. 中文 (Simplified Chinese)"
    Write-Host "2. English"
    Write-Host "3. 日本語 (Japanese)"
    Write-Host ""
    $InitialChoice = Read-Host "Please select your language [1-3]"
    Switch ($InitialChoice) {
        "1" { Save-Settings "zh-CN" }
        "2" { Save-Settings "en-US" }
        "3" { Save-Settings "ja-JP" }
        Default { Save-Settings "zh-CN" }
    }
}

# 5. 加载业务逻辑组件
. (Join-Path $Root "Module_Apache.ps1")
. (Join-Path $Root "Module_Tomcat.ps1")
. (Join-Path $Root "Module_Oracle.ps1")

# 6. 初始化报告
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

# 写入报告头 (仅开始时间)
$StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Set-Content -Path $Global:ReportFile -Value ((T "StartTime") + ": ${StartTime}")
Add-Content -Path $Global:ReportFile -Value ""

# 7. 主循环
$UserAction = ""
While ($UserAction -ne "5") {
    Write-MenuHeader "Main Menu"
    
    Write-Host (" " + (T "MenuOption1")) -ForegroundColor Green
    Write-Host (" " + (T "MenuOption2")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOption3")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOption4")) -ForegroundColor Cyan
    Write-Host (" " + (T "MenuOptionLang")) -ForegroundColor Yellow
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
        "L" {
            # 语言切换子菜单
            Write-MenuHeader "Language / 言語"
            Write-Host "1. 中文 (zh-CN)"
            Write-Host "2. English (en-US)"
            Write-Host "3. 日本語 (ja-JP)"
            $LC = Read-Host "Choice"
            Switch ($LC) {
                "1" { Save-Settings "zh-CN" }
                "2" { Save-Settings "en-US" }
                "3" { Save-Settings "ja-JP" }
            }
        }
        "5" { break }
    }
}
