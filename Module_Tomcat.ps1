# Module_Tomcat.ps1
# Version: 1.3.0
# Description: Tomcat 调查模块 (全能检索版：支持运行进程侦测、服务扫描及多级目录搜索)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache Tomcat 调查" }
    
    # --- 1. 全方位搜索策略 (解决深层路径无法检测问题) ---
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 侦测正在运行的 Java 进程 (最强逻辑，无论多深都能找到)
    Write-Host "[Search] 正在分析运行中的进程 (java.exe)..." -ForegroundColor Gray
    Try {
        $JavaProcesses = Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $JavaProcesses) {
            # 从命令行提取 -Dcatalina.home 或 -Dcatalina.base
            If ($Proc.CommandLine -match '-Dcatalina\.home="?([^"\s]+)"?') {
                $Path = $Matches[1].TrimEnd('\')
                If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
            }
            ElseIf ($Proc.CommandLine -match '-Dcatalina\.base="?([^"\s]+)"?') {
                $Path = $Matches[1].TrimEnd('\')
                If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
            }
        }
    } Catch {}
    
    # 策略 B: 扫描 Windows 服务
    Write-Host "[Search] 正在扫描 Windows 服务..." -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
    Foreach ($Svc in $Services) {
        If ($Svc.PathName -match '"?([^"]+)\\bin\\') {
            $Path = $Matches[1].TrimEnd('\')
            If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
        }
    }

    # 策略 C: 环境变量
    If ($env:CATALINA_HOME -and (Test-Path $env:CATALINA_HOME)) { [void]$TomcatRoots.Add($env:CATALINA_HOME.ToLower()) }
    If ($env:CATALINA_BASE -and (Test-Path $env:CATALINA_BASE)) { [void]$TomcatRoots.Add($env:CATALINA_BASE.ToLower()) }

    # 策略 D: 扫描常用目录 (如果前几项没找够，适当放宽深度)
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[Search] 未发现运行中的实例，正在尝试深层目录扫描 (此操作较慢)..." -ForegroundColor Yellow
        $SearchRoots = @("D:\", "C:\", "D:\Web", "C:\Program Files")
        Foreach ($SRoot in $SearchRoots) {
            If (Test-Path $SRoot) {
                # 深度放宽到 4 级以覆盖更多非标路径
                $Jars = Get-ChildItem -Path $SRoot -Filter "catalina.jar" -File -Recurse -Depth 4 -ErrorAction SilentlyContinue
                Foreach ($J in $Jars) {
                    $TRoot = $J.Directory.Parent.Parent.FullName.ToLower()
                    [void]$TomcatRoots.Add($TRoot)
                }
            }
        }
    }
    
    # --- 2. 结果汇总与详细调查 ---
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult "无" -FullDetail "在运行进程及常用目录中均未发现 Tomcat 实例。"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host "[Info] 共发现 $($TomcatRoots.Count) 个 Tomcat 潜在实例。" -ForegroundColor Green
    
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        # 版本调查
        $VersionShort = "未知"
        $VersionRaw = "N/A"
        $VersionPath = Join-Path $TRoot "bin\version.bat"
        
        If (Test-Path $VersionPath) {
            $VersionRaw = & $VersionPath | Out-String
            $VersionShortMatch = $VersionRaw | Select-String "Server version:\s+(.*)"
            If ($VersionShortMatch) { $VersionShort = $Matches[1].Trim() }
        }
        
        if ($VersionShort -eq "未知") {
             $RelNotes = Join-Path $TRoot "RELEASE-NOTES"
             If (Test-Path $RelNotes) {
                 $VersionShort = (Get-Content $RelNotes | Select-Object -First 1).Trim()
             }
        }
        
        # 环境统计 (Webapps)
        $WebappsPath = Join-Path $TRoot "webapps"
        $EnvList = @()
        If (Test-Path $WebappsPath) {
            $DefaultApps = @("ROOT", "docs", "examples", "host-manager", "manager")
            $Apps = Get-ChildItem -Path $WebappsPath -Directory
            Foreach ($App in $Apps) {
                If ($App.Name -notin $DefaultApps) { $EnvList += $App.Name }
            }
        }
        
        # 记录
        $ShortOutput = "${VersionShort} | 子环境: $($EnvList.Count)"
        $FullOutput = "Tomcat 实例 [${Count}]`n目录: ${TRoot}`n${VersionRaw}`n业务部署点: $($EnvList -join ', ')"
        
        Log-Info -Title "Tomcat 实例 [${Count}]" -ShortResult $ShortOutput -FullDetail $FullOutput
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
