# Module_Apache.ps1
# Version: 4.1.0
# Description: Apache Investigation Module (v4.0.1 Speed Optimized)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Apache Search [$CurrentDrive]"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # [1/3] Registry and Services
    Write-Host "[1/3] $(T 'SvcSearch')..." -ForegroundColor Gray
    $RegPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    Try {
        foreach ($RegRoot in $RegPaths) {
            Get-ChildItem $RegRoot -ErrorAction SilentlyContinue | Foreach-Object {
                $Path = ""
                If ($_.PSParentPath -match "Services") {
                    $ImgPath = $_.GetValue("ImagePath")
                    If ($ImgPath -match "httpd\.exe") {
                        if ($ImgPath -match '"?([^"]+\.exe)"?') { $Path = $Matches[1] }
                    }
                } Else {
                    $DispName = $_.GetValue("DisplayName")
                    $InstallLoc = $_.GetValue("InstallLocation")
                    If ($DispName -match "Apache" -and $InstallLoc -and (Test-Path (Join-Path $InstallLoc "bin\httpd.exe"))) {
                        $Path = Join-Path $InstallLoc "bin\httpd.exe"
                    }
                }
                If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                    [void]$ApacheExes.Add($Path.ToLower())
                }
            }
        }
    } Catch {}

    # [2/3] Processes and 'where' command
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[2/3] $(T 'ProcSearch')..." -ForegroundColor Gray
        Get-CimInstance Win32_Process -Filter "Name = 'httpd.exe'" -ErrorAction SilentlyContinue | Foreach-Object {
            $Path = $_.ExecutablePath
            If ($Path -and $Path.StartsWith($CurrentDrive) -and (Test-Path $Path)) { [void]$ApacheExes.Add($Path.ToLower()) }
        }
        where.exe httpd.exe 2>$null | Foreach-Object {
            If ($_ -and $_.StartsWith($CurrentDrive) -and (Test-Path $_)) { [void]$ApacheExes.Add($_.ToLower()) }
        }
    }
    
    # [3/3] Disk Scan (Last Resort)
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[3/3] $(T 'PathSearch')..." -ForegroundColor Yellow
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData|Common Files|Microsoft|Package Cache"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        Foreach ($Dir in $TargetFolders) {
            $SearchPath = Join-Path $Dir.FullName "httpd.exe"
            if (Test-Path $SearchPath) { [void]$ApacheExes.Add($SearchPath.ToLower()); continue }
            
            $Hits = cmd.exe /c "dir `"$($Dir.FullName)\httpd.exe`" /s /b 2>nul"
            If ($Hits) { Foreach ($H in $Hits) { If ($H -and (Test-Path $H)) { [void]$ApacheExes.Add($H.ToLower()) } } }
        }
    }
    
    # Markdown Output
    If ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult (T "Msg_None") -FullDetail "No Apache found on ${CurrentDrive}."
        return
    }
    
    Write-Host (T "Msg_Result" @($ApacheExes.Count, "Apache")) -ForegroundColor Green
    $Count = 1
    Foreach ($Exe in $ApacheExes) {
        $Root = Split-Path (Split-Path $Exe)
        $Version = & "$Exe" -v 2>$null | Out-String
        $ShortV = "Unknown"
        If ($Version -match "Server version:\s+(.*)") { $ShortV = $Matches[1].Trim() }
        
        $MDDetail = "- **Install Path**: `$Root` `r`n"
        $MDDetail += "#### Version Detail`r`n"
        $MDDetail += "```text`r`n"
        $MDDetail += $Version.Trim() + "`r`n"
        $MDDetail += '```' + "`r`n"
        
        Log-Info -Title "Apache Instance [${Count}]" -ShortResult "$ShortV" -FullDetail $MDDetail
        $Count++
    }
}
