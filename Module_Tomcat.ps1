# Module_Tomcat.ps1
# Version: 1.5.0
# Description: Tomcat 调查模块 (PS 5.1 互换性强化)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $MenuTitle = "Apache Tomcat $(T 'Searching')"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 运行进程
    Write-Host (T "ProcSearch") -ForegroundColor Gray
    Try {
        $JavaProcesses = Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $JavaProcesses) {
            $CmdLine = $Proc.CommandLine
            If ($CmdLine -match '-Dcatalina\.home="?([^"\s]+)"?') {
                $Path = $Matches[1].TrimEnd('\')
                If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
            }
            ElseIf ($CmdLine -match '-Dcatalina\.base="?([^"\s]+)"?') {
                $Path = $Matches[1].TrimEnd('\')
                If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
            }
        }
    } Catch {}
    
    # 策略 B: 服务扫描
    Write-Host (T "SvcSearch") -ForegroundColor Gray
    Try {
        $SS = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
        Foreach ($S in $SS) {
            If ($S.PathName -match '"?([^"]+)\\bin\\') {
                $Path = $Matches[1].TrimEnd('\')
                If (Test-Path $Path) { [void]$TomcatRoots.Add($Path.ToLower()) }
            }
        }
    } Catch {}

    # 策略 C: 目录扫描
    If ($TomcatRoots.Count -eq 0) {
        Write-Host (T "PathSearch") -ForegroundColor Yellow
        $SearchRoots = @("D:\", "C:\")
        Foreach ($SRoot in $SearchRoots) {
            If (Test-Path $SRoot) {
                # 深度限制以防挂死
                $Jars = Get-ChildItem -Path $SRoot -Filter "catalina.jar" -File -Recurse -Depth 4 -ErrorAction SilentlyContinue
                Foreach ($J in $Jars) {
                    $TRoot = $J.Directory.Parent.Parent.FullName.ToLower()
                    [void]$TomcatRoots.Add($TRoot)
                }
            }
        }
    }
    
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult (T "NoneFound") -FullDetail "None Tomcat instances detected."
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host (T "ResultFound" @($TomcatRoots.Count, "Tomcat")) -ForegroundColor Green
    
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        $VersionShort = "Unknown"
        $VersionRaw = "N/A"
        $VersionPath = Join-Path $TRoot "bin\version.bat"
        
        If (Test-Path $VersionPath) {
            $VersionRaw = & "$VersionPath" | Out-String
            If ($VersionRaw -match "Server version:\s+(.*)") { $VersionShort = $Matches[1].Trim() }
        }
        
        $WebappsPath = Join-Path $TRoot "webapps"
        $EnvList = @()
        If (Test-Path $WebappsPath) {
            $DefaultApps = @("ROOT", "docs", "examples", "host-manager", "manager")
            $Apps = Get-ChildItem -Path $WebappsPath -Directory
            Foreach ($App in $Apps) {
                If ($App.Name -notin $DefaultApps) { $EnvList += $App.Name }
            }
        }
        
        $ShortOutput = "${VersionShort} | $(T 'WebappsInfo'): $($EnvList.Count)"
        $FullOutput = "Instance [${Count}] Path: ${TRoot}`n${VersionRaw}`nApps: $($EnvList -join ', ')"
        
        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult $ShortOutput -FullDetail $FullOutput
        $Count++
    }
    If (-not $Silent) { Wait-AndClear }
}
