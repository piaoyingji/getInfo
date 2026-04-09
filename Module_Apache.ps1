# Module_Apache.ps1
# Version: 4.3.0
# Description: Apache Investigation Module (v4.3.0 Parameterized search)

Function Investigate-Apache {
    Param(
        [Boolean]$Silent = $false,
        [Int]$Method = -1, # -1: Ask user, 0: Proc/Svc, 1: Path Scan
        [String]$TargetPath = ""
    )
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Apache Search [$CurrentDrive]"
    
    # Resolve Method
    $ResolvedMethod = $Method
    if ($ResolvedMethod -eq -1) {
        if (-not $Silent) {
            Write-MenuHeader $MenuTitle
            $Opts = @((T "Opt_Method_Proc"), (T "Opt_Method_Path"))
            $ResolvedMethod = Invoke-Menu -Title (T "Main_Apache") -Options $Opts
        } else {
            $ResolvedMethod = 0 # Default to Proc in silent mode if not specified
        }
    }

    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]

    if ($ResolvedMethod -eq 0) {
        # [Strategy 1] Services, Registry and Processes
        Write-Host "[Apache] $(T 'SvcSearch')..." -ForegroundColor Gray
        $RegPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        Try {
            foreach ($RegRoot in $RegPaths) {
                Get-ChildItem $RegRoot -ErrorAction SilentlyContinue | Foreach-Object {
                    $Path = ""
                    if ($_.PSParentPath -match "Services") {
                        $ImgPath = $_.GetValue("ImagePath")
                        if ($ImgPath -match "httpd\.exe") {
                            if ($ImgPath -match '"?([^"]+\.exe)"?') { $Path = $Matches[1] }
                        }
                    } else {
                        $DispName = $_.GetValue("DisplayName")
                        $InstallLoc = $_.GetValue("InstallLocation")
                        if ($DispName -match "Apache" -and $InstallLoc -and (Test-Path (Join-Path $InstallLoc "bin\httpd.exe"))) {
                            $Path = Join-Path $InstallLoc "bin\httpd.exe"
                        }
                    }
                    if ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                        [void]$ApacheExes.Add($Path.ToLower())
                    }
                }
            }
        } Catch {}

        Write-Host "[Apache] $(T 'ProcSearch')..." -ForegroundColor Gray
        Get-CimInstance Win32_Process -Filter "Name = 'httpd.exe'" -ErrorAction SilentlyContinue | Foreach-Object {
            $Path = $_.ExecutablePath
            if ($Path -and $Path.StartsWith($CurrentDrive) -and (Test-Path $Path)) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
    } else {
        # [Strategy 2] Target Folder Scan
        $ActualPath = $TargetPath
        if ([string]::IsNullOrWhiteSpace($ActualPath)) {
            $ActualPath = Read-Host "`n[Apache] $(T 'Msg_Input_Path')"
        }
        
        if ([string]::IsNullOrWhiteSpace($ActualPath) -or -not (Test-Path $ActualPath)) {
            Write-Host (T "Msg_Invalid_Path") -ForegroundColor Red
            return
        }

        Write-Host "[Apache] $(T 'PathSearch') @ $ActualPath..." -ForegroundColor Yellow
        $Hits = cmd.exe /c "dir `"$ActualPath\httpd.exe`" /s /b 2>nul"
        if ($Hits) {
            foreach ($H in $Hits) { if ($H -and (Test-Path $H)) { [void]$ApacheExes.Add($H.ToLower()) } }
        }
    }
    
    # Markdown Output
    if ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult (T "Msg_None") -FullDetail "No Apache found."
        return
    }
    
    Write-Host (T "Msg_Result" @($ApacheExes.Count, "Apache")) -ForegroundColor Green
    $Count = 1
    Foreach ($Exe in $ApacheExes) {
        $Root = Split-Path (Split-Path $Exe)
        $Version = & "$Exe" -v 2>$null | Out-String
        $ShortV = "Unknown"
        if ($Version -match "Server version:\s+(.*)") { $ShortV = $Matches[1].Trim() }
        
        $MDDetail = "- **Install Path**: `$Root` `r`n"
        $MDDetail += "#### Version Detail`r`n"
        $MDDetail += "```text`r`n"
        $MDDetail += $Version.Trim() + "`r`n"
        $MDDetail += '```' + "`r`n"
        
        Log-Info -Title "Apache Instance [${Count}]" -ShortResult "$ShortV" -FullDetail $MDDetail
        $Count++
    }
}
