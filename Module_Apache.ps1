# Module_Apache.ps1
# Version: 1.0.0
# Description: Apache HTTP Server 调查模块 (容错增强版)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Apache HTTP Server 调查" }
    
    # 1. 搜索 httpd.exe
    $ApacheBin = Get-ChildItem -Path "D:\", "C:\" -Filter "httpd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    If (-not $ApacheBin) {
        # 如果未找到，不再报 Error，而是记录为“无”
        Log-Info -Title "Apache HTTP Server" -ShortResult "无 (未发现程序)" -FullDetail "在 D 盘和 C 盘均未找到 httpd.exe"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    $ApacheRoot = $ApacheBin.Directory.Parent.FullName
    $ApacheExe = $ApacheBin.FullName
    
    # 2. 获取版本
    $VersionRaw = & $ApacheExe -v 2>$null | Out-String
    $VersionShort = "未知 (获取版本失败)"
    If ($VersionRaw -match "Server version:\s+(.*)") {
        $VersionShort = $Matches[1].Trim()
    }
    
    # 3. 调查 SSL
    $SSLInfo = "未开启 SSL"
    $SSLExpiry = "无"
    $SSLDomain = "无"
    $FullSSLDetail = "未在配置中发现相关 SSL 设定"
    
    # 查找配置文件 (httpd.conf)
    $ConfPath = Join-Path $ApacheRoot "conf\httpd.conf"
    If (Test-Path $ConfPath) {
        $ConfContent = Get-Content $ConfPath
        
        # 查找包含的 SSL 配置
        $SSLInclude = $ConfContent | Select-String "Include .*ssl\.conf"
        If ($SSLInclude) {
            $SSLConfRelative = ($SSLInclude.ToString() -split "Include ")[1].Trim()
            $SSLConfPath = Join-Path $ApacheRoot $SSLConfRelative
            If (Test-Path $SSLConfPath) { $ConfContent += Get-Content $SSLConfPath }
        }
        
        # 匹配 SSLEngine
        If ($ConfContent | Select-String "SSLEngine on") {
            $SSLInfo = "已开启 SSL"
            
            # 查找证书文件路径
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
                } Else {
                    $FullSSLDetail = "配置了证书但路径无效: ${CertPath}"
                }
            }
        }
    }
    
    # 4. 汇总与显示
    $ShortOutput = "${VersionShort} | SSL: ${SSLInfo} | 到期日: ${SSLExpiry}"
    $FullOutput = "Apache 根目录: ${ApacheRoot}`n${VersionRaw}`nSSL 详情:`n${FullSSLDetail}"
    
    Log-Info -Title "Apache HTTP Server" -ShortResult $ShortOutput -FullDetail $FullOutput
    
    If (-not $Silent) { Wait-AndClear }
}
