# Module_Tomcat.ps1
# Version: 4.0.0
# Description: Tomcat 調査モジュール (v4.0.0 Markdown 対応版)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Tomcat Search [$CurrentDrive]"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # --- 戦略：サービス/プロセス/環境変数/ディスクスキャン (既存ロジック維持) ---
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

    Write-Host "[1/4] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        $SvcList = Get-Service | Where-Object { $_.Name -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
        Foreach ($S in $SvcList) {
            $ImgPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($S.Name)" -ErrorAction SilentlyContinue).ImagePath
            If ($ImgPath) { $Root = Get-TomcatRoot ($ImgPath -replace ' -.*$', ''); If ($Root -and $Root.StartsWith($CurrentDrive)) { [void]$TomcatRoots.Add($Root.ToLower()) } }
        }
    } Catch {}

    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[2/4] $(T 'ProcSearch')..." -ForegroundColor Gray
        Get-CimInstance Win32_Process -Filter "Name LIKE '%tomcat%' OR Name = 'java.exe'" -ErrorAction SilentlyContinue | Foreach-Object {
            If ($_.Name -eq "java.exe" -and $_.CommandLine -notmatch "catalina") { return }
            $Paths = @($_.ExecutablePath); If ($_.CommandLine -match '-Dcatalina\.home="?([^"^\-]+)"?') { $Paths += $Matches[1].TrimEnd('\').Trim('"') }
            Foreach ($P in $Paths) { $Root = Get-TomcatRoot $P; If ($Root -and $Root.StartsWith($CurrentDrive)) { [void]$TomcatRoots.Add($Root.ToLower()) } }
        }
    }
    
    # --- Markdown 出力 ---
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
        
        # Markdown 用の整形
        $MDDetail = "- **ルートディレクトリ**: `$TRoot` `r`n"
        $MDDetail += "#### 搭載 Web アプリケーション`r`n"
        If ($Apps.Count -gt 0) {
            Foreach ($App in $Apps) { $MDDetail += "  - $($App.Name) `r`n" }
        } Else {
            $MDDetail += "  - (なし) `r`n"
        }
        $MDDetail += "`r`n#### バージョン詳細`r`n"
        $MDDetail += "```text`r`n"
        $MDDetail += $RawV.Trim() + "`r`n"
        $MDDetail += '```' + "`r`n"

        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult "$ShortV | Apps: $($Apps.Count)" -FullDetail $MDDetail
        $Count++
    }
}
