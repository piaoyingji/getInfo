# Module_Utils.ps1
# Version: 1.1.0
# Description: 通用工具函数模块 (去除重复时间戳，简化报告输出)

# --- 全局配置 ---
If (-not $Global:ReportFile) { $Global:ReportFile = "Investigation_Report.txt" }

# --- 函数定义 ---

# 1. 写入报告 (仅记录标题和内容，不再重复记录时间戳)
Function Write-ToReport {
    Param([String]$Title, [String]$Content)
    
    $Divider = "=" * 50
    $Header = "--- ${Title} ---"
    
    Add-Content -Path $Global:ReportFile -Value $Divider
    Add-Content -Path $Global:ReportFile -Value $Header
    Add-Content -Path $Global:ReportFile -Value $Content
    Add-Content -Path $Global:ReportFile -Value ""
}

# 2. 实时显示并记录
Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    
    # 实时显示在控制台 (关键信息)
    Write-Host "[RESULT] ${Title}: ${ShortResult}" -ForegroundColor Green
    
    # 全量记录到文件 (详细细节)
    Write-ToReport -Title $Title -Content $FullDetail
}

# 3. 打印菜单标题
Function Write-MenuHeader {
    Param([String]$MenuTitle)
    Clear-Host
    $Line = "*" * 60
    Write-Host $Line -ForegroundColor Cyan
    Write-Host "*  服务器调查工具集 - ${MenuTitle}" -ForegroundColor Cyan
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ""
}

# 4. 等待返回
Function Wait-AndClear {
    Write-Host "`n处理完成，按 [Enter] 键返回主菜单..." -ForegroundColor Yellow
    Read-Host
}

Write-Host "[INIT] Module_Utils 加载成功。" -ForegroundColor Gray
