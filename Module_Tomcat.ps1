# Module_Tomcat.ps1
# Version: 4.1.0
# Description: Tomcat Investigation Module (v4.0.1 Speed Optimized)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Tomcat Search [$CurrentDrive]"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # Helper function to find root from binary/folder path
    Function Get-TomcatRoot {
        Param([String]$Path)
        If ([string]::IsNullOrWhiteSpace($Path)) { return $null }
        $Path = $Path.Replace('"', '').Trim()
        If (-not (Test-Path $Path)) { return $null }
        $Current = If (Test-Path $Path -PathType Container) { $Path } Else { Split-Path $Path }
        For ($i=0; $i -lt 5; $i++) {
            If ((Test-Path (Join-Path $Current "bin")) -And ((Test-Path (Join-Path $Current "lib")) -or (Test-Path (Join-Path $Current "conf")))) { return $Current }
            $Parent = Split-Path $Current; If ($Parent -eq $Current -or $null -eq $Parent) { break }; $Current = $Parent
        }
        return $null
    }

    # [1/4] Environment, Registry and Services
    Write-Host "[1/4] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        # 1. Environment Variable
        $EnvHome = [System.Environment]::GetEnvironmentVariable("CATALINA_HOME", "Machine")
        If ($EnvHome) { $Root = Get-TomcatRoot $EnvHome; If ($Root -and $Root.StartsWith($CurrentDrive)) { [void]$TomcatRoots.Add($Root.ToLower()) } }

        # 2. Registry
        $RegPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($RegRoot in $RegPaths) {
            Get-ChildItem $RegRoot -ErrorAction SilentlyContinue | Foreach-Object {
                $Path = ""
                If ($_.PSParentPath -match "Services") {
                    If ($_.Name -like "*tomcat*" -or $_.GetValue("DisplayName") -like "*tomcat*") {
                        $ImgPath = $_.GetValue("ImagePath")
                        If ($ImgPath) { $Path = $ImgPath -replace ' -.*$', '' }
                    }
                } Else {
                    $DispName = $_.GetValue("DisplayName")
                    If ($DispName -match "Tomcat") { $Path = $_.GetValue("InstallLocation") }
                }
                If ($Path) { $Root = Get-TomcatRoot $Path; If ($Root -and $Root.StartsWith($CurrentDrive)) { [void]$TomcatRoots.Add($Root.ToLower()) } }
            }
        }
    } Catch {}

    # [2/4] Processes
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[2/4] $(T 'ProcSearch')..." -ForegroundColor Gray
        $ProcFilter = "Name LIKE '%tomcat%' OR Name = 'java.exe'"
        Get-CimInstance Win32_Process -Filter $ProcFilter -ErrorAction SilentlyContinue | Foreach-Object {
            If ($_.Name -eq "java.exe" -and $_.CommandLine -notmatch "catalina") { return }
            $Paths = @($_.ExecutablePath)
            If ($_.CommandLine -match '-Dcatalina\.home="?([^"^\-]+)"?') { $Paths += $Matches[1].TrimEnd('\').Trim('"') }
            Foreach ($P in $Paths) { $Root = Get-TomcatRoot $P; If ($Root -and $Root.StartsWith($CurrentDrive)) { [void]$TomcatRoots.Add($Root.ToLower()) } }
        }
    }
    
    # Markdown Output
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult (T "Msg_None") -FullDetail "No Instance found on ${CurrentDrive}."
        return
    }
    
    Write-Host (T "Msg_Result" @($TomcatRoots.Count, "Tomcat")) -ForegroundColor Green
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        $VerPath = Join-Path $TRoot "bin\version.bat"
        $RawV = "N/A"; $ShortV = "Unknown"
        If (Test-Path $VerPath) { $RawV = & "$VerPath" | Out-String; If ($RawV -match "Server version:\s+(.*)") { $ShortV = $Matches[1].Trim() } }
        
        $Apps = @()
        If (Test-Path (Join-Path $TRoot "webapps")) {
            $Apps = Get-ChildItem (Join-Path $TRoot "webapps") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @("ROOT","docs","examples","manager","host-manager") }
        }
        
        $MDDetail = "- **Root Directory**: `$TRoot` `r`n"
        $MDDetail += "#### Web Applications`r`n"
        If ($Apps.Count -gt 0) {
            Foreach ($App in $Apps) { $MDDetail += "  - $($App.Name) `r`n" }
        } Else {
            $MDDetail += "  - (None) `r`n"
        }
        $MDDetail += "`r`n#### Version Detail`r`n"
        $MDDetail += "```text`r`n"
        $MDDetail += $RawV.Trim() + "`r`n"
        $MDDetail += '```' + "`r`n"
        
        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult "$ShortV | Apps: $($Apps.Count)" -FullDetail $MDDetail
        $Count++
    }
}
