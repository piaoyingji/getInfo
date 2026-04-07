# Module_Tomcat.ps1
# Version: 1.2.0
# Description: Tomcat 调查模块 (高性能检索版)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache Tomcat 调查" }
    
    # --- 1. 高性能搜索策略 ---
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 检查已注册的 Windows 服务 (快速定位)
    Write-Host "[Search] 正在扫描 Windows 服务..." -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
    Foreach ($Svc in $Services) {
        # 尝试从可执行路径推断根目录
        # 通常路径为 ...\bin\tomcat.exe 或 ...\bin\bootstrap.jar
        If ($Svc.PathName -match '"?([^"]+)\\bin\\') {
            $Root = $Matches[1]
            If (Test-Path $Root) { [void]$TomcatRoots.Add($Root.ToLower()) }
        }
    }
    
    # 策略 B: 扫描常用安装路径 (深度限制)
    Write-Host "[Search] 正在扫描常用目录 (深度限制)..." -ForegroundColor Gray
    $CommonPaths = @("D:\", "C:\", "D:\Java", "C:\Java", "D:\App", "C:\Program Files")
    Foreach ($RootPath in $CommonPaths) {
        If (Test-Path $RootPath) {
            # 搜索包含 catalina.jar 的目录
            $Jars = Get-ChildItem -Path $RootPath -Filter "catalina.jar" -File -Recurse -Depth 3 -ErrorAction SilentlyContinue
            Foreach ($J in $Jars) {
                # catalina.jar 通常在 lib 目录下，其父目录即为 Tomcat 根目录
                $TRoot = $J.Directory.Parent.FullName
                [void]$TomcatRoots.Add($TRoot.ToLower())
            }
        }
    }
    
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult "无" -FullDetail "未发现活跃服务或常用路径下的 Tomcat 实例"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    # --- 2. 遍历结果 ---
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        # 获取版本
        $VersionShort = "未知"
        $VersionRaw = "N/A"
        $VersionPath = Join-Path $TRoot "bin\version.bat"
        
        If (Test-Path $VersionPath) {
            $VersionRaw = & $VersionPath | Out-String
            $VersionShortMatch = $VersionRaw | Select-String "Server version:\s+(.*)"
            If ($VersionShortMatch) { $VersionShort = $Matches[1].Trim() }
        } Else {
            # 备选：解析 RELEASE-NOTES
            $RelNotes = Join-Path $TRoot "RELEASE-NOTES"
            If (Test-Path $RelNotes) {
                $VersionShort = (Get-Content $RelNotes | Select-Object -First 1).Trim()
            }
        }
        
        # 3. 统计环境 (Webapps 下的目录)
        $WebappsPath = Join-Path $TRoot "webapps"
        $EnvCount = 0
        $EnvList = @()
        If (Test-Path $WebappsPath) {
            $DefaultApps = @("ROOT", "docs", "examples", "host-manager", "manager")
            $Apps = Get-ChildItem -Path $WebappsPath -Directory
            Foreach ($App in $Apps) {
                If ($App.Name -notin $DefaultApps) {
                    $EnvCount++
                    $EnvList += $App.Name
                }
            }
        }
        
        # 4. 汇总
        Log-Info -Title "Tomcat 实例 [${Count}]" -ShortResult "${VersionShort} | 子环境: ${EnvCount}" -FullDetail "根目录: ${TRoot}`n${VersionRaw}`nWebapps 部署项: $($EnvList -join ', ') (共 ${EnvCount} 个)"
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
