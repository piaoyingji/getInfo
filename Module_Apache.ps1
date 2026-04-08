# Module_Apache.ps1
# Version: 1.3.1
# Description: Apache HTTP Server 调查模块 (全多语言支持)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $MenuTitle = "Apache HTTP Server $(T 'Searching')"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    # --- 1. 全方位搜索策略 ---
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 侦测运行进程
    Write-Host (T "ProcSearch") -ForegroundColor Gray
    Try {
        $HttpdProcesses = Get-CimInstance Win32_Process -Filter "Name = 'httpd.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $HttpdProcesses) {
            $Path = $Proc.ExecutablePath
            If ($Path -and (Test-Path $Path)) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    } Catch {}
    
    # 策略 B: 扫描服务
    Write-Host (T "SvcSearch") -ForegroundColor Gray
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*httpd.exe*" }
    Foreach ($Svc in $Services) {
        If ($Svc.PathName -match '"?([^"]+\.exe)"?') {
            $Path = $Matches[1]
            If (Test-Path $Path) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    }
    
    # 策略 C: 扫描常用目录
    If ($ApacheExes.Count -eq 0) {
        Write-Host (T "PathSearch") -ForegroundColor Yellow
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
        Log-Info -Title "Apache HTTP Server" -ShortResult (T "NoneFound") -FullDetail "No httpd.exe found."
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host (T "ResultFound" @($ApacheExes.Count, "Apache")) -ForegroundColor Green
    
    $Count = 1
    Foreach ($ApacheExe in $ApacheExes) {
        $BinDir = Split-Path $ApacheExe
        $ApacheRoot = Split-Path $BinDir
        
        # 获取版本
        $VersionRaw = & ""$ApacheExe"" -v 2>$null | Out-String
        $VersionShort = "Unknown"
        If ($VersionRaw -match "Server version:\s+(.*)") {
            $VersionShort = $Matches[1].Trim()
        }
        
        # 3. 调查 SSL
        $SSLInfo = T "SSL_Off"
        $SSLExpiry = T "NoneFound"
        $FullSSLDetail = "No SSL configuration found."
        
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
                $SSLInfo = T "SSL_On"
                $CertMatch = $ConfContent | Select-String 'SSLCertificateFile\s+"?([^"]+)"?'
                If ($CertMatch) {
                    $CertPathRaw = $CertMatch.Matches[0].Groups[1].Value.Trim()
                    $CertPath = $CertPathRaw
                    If (-not (Test-Path $CertPath)) { $CertPath = Join-Path $ApacheRoot $CertPathRaw }
                    
                    If (Test-Path $CertPath) {
                        Try {
                            $CertObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
                            $SSLExpiry = $CertObj.NotAfter.ToString("yyyy-MM-dd")
                            $FullSSLDetail = "Cert: ${CertPath}`nSubject: $($CertObj.Subject)`nExpiry: ${SSLExpiry}"
                        } Catch {
                            $FullSSLDetail = "Error parsing cert: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        
        # 4. 汇总
        Log-Info -Title "Apache Instance [${Count}]" -ShortResult "${VersionShort} | SSL: ${SSLInfo}" -FullDetail "Root: ${ApacheRoot}`n${VersionRaw}`nSSL Detail: ${FullSSLDetail}"
        $Count++
    }
    
    If (-not $Silent) { Wait-AndClear }
}
