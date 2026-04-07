# Module_Tomcat.ps1
# Version: 1.0.0
# Description: Tomcat 调查模块 (容错增强版)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache Tomcat 调查" }
    
    # 1. 搜索核心文件
    $CatalinaJar = Get-ChildItem -Path "D:\", "C:\" -Filter "catalina.jar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    If (-not $CatalinaJar) {
        $VersionBat = Get-ChildItem -Path "D:\", "C:\" -Filter "version.bat" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        If (-not $VersionBat) {
            # 未发现时的友好处理
            Log-Info -Title "Apache Tomcat" -ShortResult "无 (未发现程序)" -FullDetail "在 D 盘和 C 盘均未找到 Tomcat 相关核心文件。"
            If (-not $Silent) { Wait-AndClear }
            return
        }
        $TomcatRoot = $VersionBat.Directory.Parent.FullName
    } Else {
        $TomcatRoot = $CatalinaJar.Directory.Parent.Parent.FullName
    }
    
    # 2. 获取版本
    $VersionShort = "无 (系统版本未识别)"
    $VersionRaw = "N/A"
    $VersionPath = Join-Path $TomcatRoot "bin\version.bat"
    
    If (Test-Path $VersionPath) {
        $VersionRaw = & $VersionPath | Out-String
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
    
    # 4. 统计 Context 节点 (从 server.xml)
    $ServerXml = Join-Path $TomcatRoot "conf\server.xml"
    $XmlContextCount = 0
    If (Test-Path $ServerXml) {
        $XmlContent = Get-Content $ServerXml
        $XmlContextCount = ($XmlContent | Select-String "<Context" -AllMatches).Matches.Count
    }
    
    # 5. 汇总与显示
    $ShortOutput = "${VersionShort} | 子环境: ${EnvCount}"
    $FullOutput = "Tomcat 根目录: ${TomcatRoot}`n${VersionRaw}`nWebapps 部署项: $($EnvList -join ', ') (共 ${EnvCount} 个)"
    
    Log-Info -Title "Apache Tomcat" -ShortResult $ShortOutput -FullDetail $FullOutput
    
    If (-not $Silent) { Wait-AndClear }
}
