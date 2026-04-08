# Module_Tomcat.ps1
# Version: 1.3.1
# Description: Tomcat 调查模块 (全多语言支持)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $MenuTitle = "Apache Tomcat $(T 'Searching')"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    # --- 1. 全方位搜索策略 ---
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 运行进程 (java.exe)
    Write-Host (T "ProcSearch") -ForegroundColor Gray
    Try {
        $JavaProcesses = Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $JavaProcesses) {
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
    
    # 策略 B: 服务扫描
    Write-Host (T "SvcSearch") -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
    Foreach ($Svc in $Services) {
        If ($Svc.PathName -match '"?([^"]+)\\bin\\') {
            $Path = $Matches[1].TrimEnd('\')
            If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
        }
    }

    # 策略 C: 目录扫描
    If ($TomcatRoots.Count -eq 0) {
        Write-Host (T "PathSearch") -ForegroundColor Yellow
        $SearchRoots = @("D:\", "C:\", "D:\Java", "C:\Java", "C:\Program Files")
        Foreach ($SRoot in $SearchRoots) {
            If (Test-Path $SRoot) {
                $Jars = Get-ChildItem -Path $SRoot -Filter "catalina.jar" -File -Recurse -Depth 4 -ErrorAction SilentlyContinue
                Foreach ($J in $Jars) {
                    $TRoot = $J.Directory.Parent.Parent.FullName.ToLower()
                    [void]$TomcatRoots.Add($TRoot)
                }
            }
        }
    }
    
    # --- 2. 结果汇总 ---
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult (T "NoneFound") -FullDetail "No Tomcat instances found."
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host (T "ResultFound" @($TomcatRoots.Count, "Tomcat")) -ForegroundColor Green
    
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        # 版本调查
        $VersionShort = "Unknown"
        $VersionRaw = "N/A"
        $VersionPath = Join-Path $TRoot "bin\version.bat"
        
        If (Test-Path $VersionPath) {
            $VersionRaw = & $VersionPath | Out-String
            $VersionShortMatch = $VersionRaw | Select-String "Server version:\s+(.*)"
            If ($VersionShortMatch) { $VersionShort = $Matches[1].Trim() }
        }
        
        # 环境统计
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
        $ShortOutput = "${VersionShort} | $(T 'WebappsInfo'): $($EnvList.Count)"
        $FullOutput = "Tomcat Instance [${Count}]`nPath: ${TRoot}`n${VersionRaw}`nApps: $($EnvList -join ', ')"
        
        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult $ShortOutput -FullDetail $FullOutput
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
