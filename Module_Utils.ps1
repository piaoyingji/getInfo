# Module_Utils.ps1
# Version: 1.0.0
# Description: 通用工具函数模块，负责路径搜索、报告记录、格式化输出。

# --- 全局配置 ---
If (-not $Global:ReportFile) { $Global:ReportFile = "Investigation_Report.txt" }
$Global:AppVersion = "1.0.0"

# --- 函数定义 ---

# 1. 查找文件路径 (优先扫描 D 盘)
Function Find-ToolRoot {
    Param([String]$SearchPattern, [String[]]$TargetPaths = @("D:\", "C:\"))
    
    Foreach ($Path in $TargetPaths) {
        If (Test-Path $Path) {
            Write-Host "[Searching] 在 ${Path} 搜索 ${SearchPattern}..." -ForegroundColor Gray
            $Files = Get-ChildItem -Path $Path -Filter $SearchPattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 3
            If ($Files) { return $Files | Select-Object -ExpandProperty DirectoryName -Unique }
        }
    }
    return $null
}

# 2. 写入报告 (全量记录)
Function Write-ToReport {
    Param([String]$Title, [String]$Content)
    
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Divider = "=" * 50
    $Header = "[${Time}] ${Title}"
    
    Add-Content -Path $Global:ReportFile -Value $Divider
    Add-Content -Path $Global:ReportFile -Value $Header
    Add-Content -Path $Global:ReportFile -Value $Content
    Add-Content -Path $Global:ReportFile -Value $Divider
    Add-Content -Path $Global:ReportFile -Value ""
}

# 3. 实时显示并记录
Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    
    # 实时显示在控制台 (关键信息)
    Write-Host "[RESULT] ${Title}: ${ShortResult}" -ForegroundColor Green
    
    # 全量记录到文件 (详细细节)
    Write-ToReport -Title $Title -Content $FullDetail
}

# 4. 打印菜单标题
Function Write-MenuHeader {
    Param([String]$MenuTitle)
    Clear-Host
    $Line = "*" * 60
    Write-Host $Line -ForegroundColor Cyan
    Write-Host "*  服务器调查工具集 v${Global:AppVersion} - ${MenuTitle}" -ForegroundColor Cyan
    Write-Host $Line -ForegroundColor Cyan
    Write-Host ""
}

# 5. 等待返回
Function Wait-AndClear {
    Write-Host "`n处理完成，按 [Enter] 键返回主菜单..." -ForegroundColor Yellow
    Read-Host
}

Write-Host "[INIT] Module_Utils 加载成功。" -ForegroundColor Gray
