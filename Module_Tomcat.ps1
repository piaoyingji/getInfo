# Module_Tomcat.ps1
# Version: 1.1.0
# Description: Tomcat 调查模块 (多实例支持 + 容错增强)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache Tomcat 调查" }
    
    # 1. 搜索所有 catalina.jar
    $CatalinaJars = Get-ChildItem -Path "D:\", "C:\" -Filter "catalina.jar" -Recurse -ErrorAction SilentlyContinue
    
    If (-not $CatalinaJars) {
        Log-Info -Title "Apache Tomcat" -ShortResult "无" -FullDetail "在 D 盘和 C 盘均未找到 Tomcat 核心文件 (catalina.jar)"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    # 2. 遍历每个发现的实例
    $Count = 1
    Foreach ($Jar in $CatalinaJars) {
        $TomcatRoot = $Jar.Directory.Parent.Parent.FullName
        
        # 获取版本
        $VersionShort = "未知"
        $VersionRaw = "N/A"
        $VersionPath = Join-Path $TomcatRoot "bin\version.bat"
        
        If (Test-Path $VersionPath) {
            $VersionRaw = & ""$VersionPath"" | Out-String
            $VersionShortMatch = $VersionRaw | Select-String "Server version:\s+(.*)"
            If ($VersionShortMatch) { $VersionShort = $Matches[1].Trim() }
        } Else {
            $RelNotes = Join-Path $TomcatRoot "RELEASE-NOTES"
            If (Test-Path $RelNotes) {
                $VersionShort = (Get-Content $RelNotes | Select-Object -First 1).Trim()
            }
        }
        
        # 3. 统计环境 (Webapps 下的目录)
        $WebappsPath = Join-Path $TomcatRoot "webapps"
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
        
        # 4. 汇总与显示
        $ShortOutput = "${VersionShort} | 子环境: ${EnvCount}"
        $FullOutput = "实例 [${Count}]`n根目录: ${TomcatRoot}`n${VersionRaw}`nWebapps 部署项: $($EnvList -join ', ') (共 ${EnvCount} 个)"
        
        Log-Info -Title "Tomcat 实例 [${Count}]" -ShortResult $ShortOutput -FullDetail $FullOutput
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
