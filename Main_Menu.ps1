# Main_Menu.ps1
# Version: 1.0.0
# Description: 服务器一键调查工具 - 主入口脚本 (全量修复与性能增强版)

# 强制错误级别提示
$ErrorActionPreference = "Continue"

# 1. 动态获取脚本运行基础路径
If ($PSScriptRoot) {
    $Root = $PSScriptRoot
} Else {
    $Root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue
}
If (-not $Root) { $Root = Get-Location }
Set-Location $Root

# 2. 核心模块存在性预检查
$Modules = @("Module_Utils.ps1", "Module_Apache.ps1", "Module_Tomcat.ps1", "Module_Oracle.ps1")
Foreach ($M in $Modules) {
    If (-not (Test-Path (Join-Path $Root $M))) {
        Write-Host "[Critical Error] 缺失核心脚本文件: ${M}" -ForegroundColor Red
        Read-Host "请确保所有 .ps1 文件解压在同一路径下。按 [Enter] 退出..."
        Exit
    }
}

# 3. 稳健地加载工具集 (Utils 必须先载入)
Try {
    . (Join-Path $Root "Module_Utils.ps1")
} Catch {
    Write-Host "[Fatal] 加载 Module_Utils.ps1 失败: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按回车退出..."
    Exit
}

# 4. 交互初始化 (询问文件名)
Clear-Host
Write-Host "************************************************************" -ForegroundColor Cyan
Write-Host "*          服务器调查工具集 v1.0.0 (初始化)               *" -ForegroundColor Cyan
Write-Host "************************************************************`n" -ForegroundColor Cyan

$InFilename = Read-Host "请输入调查结果存档文件名 (默认为 Investigation_Report.txt)"
If (-not [string]::IsNullOrWhiteSpace($InFilename)) {
    If ($InFilename -notlike "*.txt") { $InFilename += ".txt" }
    $Global:ReportFile = $InFilename
} Else {
    $Global:ReportFile = "Investigation_Report.txt"
}
Write-Host "[Info] 调查输出将存至: ${Global:ReportFile}`n" -ForegroundColor Green

# 5. 加载业务逻辑组件 (带异常捕获)
Try {
    . (Join-Path $Root "Module_Apache.ps1")
    . (Join-Path $Root "Module_Tomcat.ps1")
    . (Join-Path $Root "Module_Oracle.ps1")
} Catch {
    Write-Host "[Fatal] 业务模块加载失败: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按回特退出..."
    Exit
}

# 初始化会话记录
Write-ToReport -Title "新调查会话" -Content "开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n脚本版本: ${Global:AppVersion}"

# 6. 主循环界面
$UserAction = ""
While ($UserAction -ne "5") {
    Write-MenuHeader "功能导航"
    
    Write-Host " [1] 全量同步调查 (Apache + Tomcat + Oracle)" -ForegroundColor Green
    Write-Host " [2] 单独调查 Apache HTTP Server" -ForegroundColor Cyan
    Write-Host " [3] 单独调查 Apache Tomcat" -ForegroundColor Cyan
    Write-Host " [4] 单独调查 Oracle Database" -ForegroundColor Cyan
    Write-Host " [5] 正常退出程序" -ForegroundColor Gray
    Write-Host ""
    
    $UserAction = Read-Host "请输入指令编号 [1-5]"
    
    Switch ($UserAction) {
        "1" {
            Write-MenuHeader "全方位自动扫描中..."
            Investigate-Apache -Silent $true
            Investigate-Tomcat -Silent $true
            Investigate-Oracle -Silent $true
            Write-Host "`n[Success] 全量扫描已结束，报表已更新: ${Global:ReportFile}" -ForegroundColor Green
            Wait-AndClear
        }
        "2" { Investigate-Apache }
        "3" { Investigate-Tomcat }
        "4" { Investigate-Oracle }
        "5" { Write-Host "系统正在安全关闭..." -ForegroundColor Gray }
        Default {
            Write-Host "[!] 指令无效，请重新输入 1 到 5 的数字。" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
