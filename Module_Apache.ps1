# Module_Apache.ps1
# Version: 1.3.0
# Description: Apache HTTP Server 调查模块 (全能检索版：支持进程侦测、服务扫描及多级目录搜索)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache HTTP Server 调查" }
    
    # --- 1. 全方位搜索策略 ---
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 侦测正在运行的进程 (httpd.exe)
    Write-Host "[Search] 正在分析运行中的进程 (httpd.exe)..." -ForegroundColor Gray
    Try {
        $HttpdProcesses = Get-CimInstance Win32_Process -Filter "Name = 'httpd.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $HttpdProcesses) {
            $Path = $Proc.ExecutablePath
            If ($Path -and (Test-Path $Path)) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    } Catch {}
    
    # 策略 B: 检查已注册的 Windows 服务
    Write-Host "[Search] 正在扫描 Windows 服务..." -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*httpd.exe*" }
    Foreach ($Svc in $Services) {
        If ($Svc.PathName -match '"?([^"]+\.exe)"?') {
            $Path = $Matches[1]
            If (Test-Path $Path) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    }
    
    # 策略 C: 扫描常用安装路径 (如果前两项没找到，进行适度深挖)
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[Search] 未发现运行中的实例，正在进行备选目录扫描 (深度限制)..." -ForegroundColor Yellow
        $SearchRoots = @("D:\", "C:\", "C:\Program Files", "D:\App")
        Foreach ($SRoot in $SearchRoots) {
            If (Test-Path $SRoot) {
                $Files = Get-ChildItem -Path $SRoot -Filter "httpd.exe" -File -Recurse -Depth 3 -ErrorAction SilentlyContinue
                Foreach ($F in $Files) { [void]$ApacheExes.Add($F.FullName.ToLower()) }
            }
        }
    }
    
    # --- 2. 结果汇总与详细调查 ---
    If ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult "无" -FullDetail "未发现活跃服务或常用路径下的 httpd.exe"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host "[Info] 共发现 $($ApacheExes.Count) 个 Apache 潜在实例。" -ForegroundColor Green
    
    $Count = 1
    Foreach ($ApacheExe in $ApacheExes) {
        $BinDir = Split-Path $ApacheExe
        $ApacheRoot = Split-Path $BinDir
        
        # 获取版本
        $VersionRaw = & ""$ApacheExe"" -v 2>$null | Out-String
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
        Log-Info -Title "Apache 实例 [${Count}]" -ShortResult "${VersionShort} | SSL: ${SSLInfo}" -FullDetail "实例目录: ${ApacheRoot}`n${VersionRaw}`nSSL 详情:`n${FullSSLDetail}"
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
