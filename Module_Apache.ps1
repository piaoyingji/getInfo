# Module_Apache.ps1
# Version: 1.2.0
# Description: Apache HTTP Server 调查模块 (高性能检索版)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache HTTP Server 调查" }
    
    # --- 1. 高性能搜索策略 ---
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 检查已注册的 Windows 服务 (最快)
    Write-Host "[Search] 正在扫描 Windows 服务..." -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*httpd.exe*" }
    Foreach ($Svc in $Services) {
        # 提取路径 (处理带引号和参数的情况)
        If ($Svc.PathName -match '"?([^"]+\.exe)"?') {
            $Path = $Matches[1]
            If (Test-Path $Path) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    }
    
    # 策略 B: 扫描常见安装路径 (深度限制为 3 级，避免全盘递归)
    Write-Host "[Search] 正在扫描常用目录 (深度限制)..." -ForegroundColor Gray
    $CommonPaths = @("D:\", "C:\", "C:\Program Files", "C:\Program Files (x86)", "D:\App", "D:\Web", "D:\Server")
    Foreach ($RootPath in $CommonPaths) {
        If (Test-Path $RootPath) {
            # 搜索当前目录及下属两级子目录
            $Files = Get-ChildItem -Path $RootPath -Filter "httpd.exe" -File -Recurse -Depth 2 -ErrorAction SilentlyContinue
            Foreach ($F in $Files) { [void]$ApacheExes.Add($F.FullName.ToLower()) }
        }
    }
    
    If ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult "无" -FullDetail "未发现活跃服务或常用路径下的 httpd.exe"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    # --- 2. 遍历结果 ---
    $Count = 1
    Foreach ($ApacheExe in $ApacheExes) {
        $BinDir = Split-Path $ApacheExe
        $ApacheRoot = Split-Path $BinDir
        
        # 获取版本
        $VersionRaw = & $ApacheExe -v 2>$null | Out-String
        $VersionShort = "未知"
        If ($VersionRaw -match "Server version:\s+(.*)") {
            $VersionShort = $Matches[1].Trim()
        }
        
        # 3. 调查 SSL
        $SSLInfo = "未开启 SSL"
        $SSLExpiry = "无"
        $SSLDomain = "无"
        $FullSSLDetail = "未在配置中发现相关 SSL 设定"
        
        $ConfPath = Join-Path $ApacheRoot "conf\httpd.conf"
        If (Test-Path $ConfPath) {
            $ConfContent = Get-Content $ConfPath
            $SSLInclude = $ConfContent | Select-String "Include .*ssl\.conf"
            If ($SSLInclude) {
                $SSLConfRelative = ($SSLInclude.ToString() -split "Include ")[1].Trim()
                $SSLConfPath = Join-Path $ApacheRoot $SSLConfRelative
                If (Test-Path $SSLConfPath) { $ConfContent += Get-Content $SSLConfPath }
            }
            
            If ($ConfContent | Select-String "SSLEngine on") {
                $SSLInfo = "已开启 SSL"
                $CertMatch = $ConfContent | Select-String 'SSLCertificateFile\s+"?([^"]+)"?'
                If ($CertMatch) {
                    $CertPathRaw = $CertMatch.Matches[0].Groups[1].Value.Trim()
                    $CertPath = $CertPathRaw
                    If (-not (Test-Path $CertPath)) { $CertPath = Join-Path $ApacheRoot $CertPathRaw }
                    
                    If (Test-Path $CertPath) {
                        Try {
                            $CertObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
                            $SSLDomain = $CertObj.Subject
                            $SSLExpiry = $CertObj.NotAfter.ToString("yyyy-MM-dd")
                            $FullSSLDetail = "证书路径: ${CertPath}`n域名: ${SSLDomain}`n到期日: ${SSLExpiry}"
                        } Catch {
                            $FullSSLDetail = "解析证书失败: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        
        # 4. 汇总
        Log-Info -Title "Apache 实例 [${Count}]" -ShortResult "${VersionShort} | SSL: ${SSLInfo}" -FullDetail "根目录: ${ApacheRoot}`n${VersionRaw}`nSSL: ${FullSSLDetail}"
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
