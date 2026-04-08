# Module_Apache.ps1
# Version: 1.5.0
# Description: Apache HTTP Server 调查模块 (PS 5.1 互换性强化)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $MenuTitle = "Apache HTTP Server $(T 'Searching')"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # 策略 A: 运行进程 (httpd.exe)
    Write-Host (T "ProcSearch") -ForegroundColor Gray
    Try {
        $HttpdProcesses = Get-CimInstance Win32_Process -Filter "Name = 'httpd.exe'" -ErrorAction SilentlyContinue
        Foreach ($Proc in $HttpdProcesses) {
            $Path = $Proc.ExecutablePath
            If ($Path -and (Test-Path $Path)) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    } Catch {}
    
    # 策略 B: 服务扫描
    Write-Host (T "SvcSearch") -ForegroundColor Gray
    Try {
        $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -like "*httpd.exe*" }
        Foreach ($Svc in $Services) {
            If ($Svc.PathName -match '"?([^"]+\.exe)"?') {
                $Path = $Matches[1]
                If (Test-Path $Path) { [void]$ApacheExes.Add($Path.ToLower()) }
            }
        }
    } Catch {}
    
    # 策略 C: 常用目录
    If ($ApacheExes.Count -eq 0) {
        Write-Host (T "PathSearch") -ForegroundColor Yellow
        $SearchRoots = @("D:\", "C:\")
        Foreach ($SRoot in $SearchRoots) {
            If (Test-Path $SRoot) {
                $Files = Get-ChildItem -Path $SRoot -Filter "httpd.exe" -File -Recurse -Depth 3 -ErrorAction SilentlyContinue
                Foreach ($F in $Files) { [void]$ApacheExes.Add($F.FullName.ToLower()) }
            }
        }
    }
    
    If ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult (T "NoneFound") -FullDetail "None httpd.exe detected."
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    Write-Host (T "ResultFound" @($ApacheExes.Count, "Apache")) -ForegroundColor Green
    
    $Count = 1
    Foreach ($ApacheExe in $ApacheExes) {
        $BinDir = Split-Path $ApacheExe
        $ApacheRoot = Split-Path $BinDir
        
        $VersionRaw = & "$ApacheExe" -v 2>$null | Out-String
        $VersionShort = "Unknown"
        If ($VersionRaw -match "Server version:\s+(.*)") { $VersionShort = $Matches[1].Trim() }
        
        $SSLInfo = T "SSL_Off"
        $FullSSLDetail = "N/A"
        
        $ConfPath = Join-Path $ApacheRoot "conf\httpd.conf"
        If (Test-Path $ConfPath) {
            $ConfContent = Get-Content $ConfPath
            $SSLInclude = $ConfContent | Select-String "Include .*ssl\.conf"
            If ($SSLInclude) {
                $SSLConfRel = ($SSLInclude.ToString() -split "Include ")[1].Trim()
                $SSLConfPath = Join-Path $ApacheRoot $SSLConfRel
                If (Test-Path $SSLConfPath) { $ConfContent += Get-Content $SSLConfPath }
            }
            
            If ($ConfContent | Select-String "SSLEngine on") {
                $SSLInfo = T "SSL_On"
                $CertMatch = $ConfContent | Select-String 'SSLCertificateFile\s+"?([^"]+)"?'
                If ($CertMatch) {
                    $CertPath = $CertMatch.Matches[0].Groups[1].Value.Trim()
                    If (-not (Test-Path $CertPath)) { $CertPath = Join-Path $ApacheRoot $CertPath }
                    If (Test-Path $CertPath) {
                        Try {
                            $CertObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
                            $FullSSLDetail = "Subject: $($CertObj.Subject)`nExpiry: $($CertObj.NotAfter.ToString('yyyy-MM-dd'))"
                        } Catch { $FullSSLDetail = "Parse Error" }
                    }
                }
            }
        }
        
        Log-Info -Title "Apache Instance [${Count}]" -ShortResult "${VersionShort} | SSL: ${SSLInfo}" -FullDetail "Path: ${ApacheRoot}`n${VersionRaw}`nSSL: ${FullSSLDetail}"
        $Count++
    }
    If (-not $Silent) { Wait-AndClear }
}
