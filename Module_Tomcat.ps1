# Module_Tomcat.ps1
# Version: 2.0.0
# Description: Tomcat 調査モジュール (レジストリ瞬時探索 + 深層ディレクトリ探索)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Tomcat Search [$CurrentDrive] (v2.0.0 Instant Mode)"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 辅助関数：スマート識別
    Function Get-TomcatRoot {
        Param([String]$Path)
        If ([string]::IsNullOrWhiteSpace($Path)) { return $null }
        $Path = $Path.Replace('"', '').Trim()
        If (-not (Test-Path $Path)) { return $null }
        $Current = If (Test-Path $Path -PathType Container) { $Path } Else { Split-Path $Path }
        
        For ($i=0; $i -lt 5; $i++) {
            If ((Test-Path (Join-Path $Current "bin")) -And ((Test-Path (Join-Path $Current "conf")) -or (Test-Path (Join-Path $Current "lib")))) {
                return $Current
            }
            $Parent = Split-Path $Current
            If ($Parent -eq $Current -or $null -eq $Parent) { break }
            $Current = $Parent
        }
        return $null
    }

    # --- 戦略 0: レジストリ (サービス情報) から一瞬で取得 ---
    Write-Host "[1/4] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | Foreach-Object {
            $ImgPath = $_.GetValue("ImagePath")
            If ($ImgPath -match "tomcat|catalina") {
                # ImagePath から実行ファイルのディレクトリを抽出
                $CleanPath = $ImgPath -replace ' -.*$', '' # 引数を除去
                $Root = Get-TomcatRoot $CleanPath
                If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$TomcatRoots.Add($Root.ToLower())
                }
            }
        }
    } Catch {}

    # --- 戦略 1: 実行中プロセスから取得 ---
    Write-Host "[2/4] $(T 'Msg_Proc')..." -ForegroundColor Gray
    $WmiProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%tomcat%' OR Name = 'java.exe' OR CommandLine LIKE '%catalina%'" -ErrorAction SilentlyContinue
    Foreach ($P in $WmiProcs) {
        $Paths = @($P.ExecutablePath)
        If ($P.CommandLine -match '-Dcatalina\.home="?([^"^\-]+)"?') { $Paths += $Matches[1].TrimEnd('\').Trim('"') }
        Foreach ($Path in $Paths) {
            $Root = Get-TomcatRoot $Path
            If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                [void]$TomcatRoots.Add($Root.ToLower())
            }
        }
    }

    # --- 戦略 2: 環境変数から取得 ---
    If ($env:CATALINA_HOME) {
        $Root = Get-TomcatRoot $env:CATALINA_HOME
        If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) { [void]$TomcatRoots.Add($Root.ToLower()) }
    }

    # --- 戦略 3: ディスクスキャン (上記で見つからなかった場合のみ実行) ---
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[3/4] $(T 'PathSearch')..." -ForegroundColor Yellow
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        
        Foreach ($Dir in $TargetFolders) {
            Write-Host "   Searching $($Dir.FullName)..." -ForegroundColor DarkGray
            $Hits = @(cmd.exe /c "dir `"$($Dir.FullName)\catalina.bat`" /s /b 2>nul") + @(cmd.exe /c "dir `"$($Dir.FullName)\tomcat*.exe`" /s /b 2>nul")
            Foreach ($H in $Hits) {
                If ($H) {
                    $Root = Get-TomcatRoot $H
                    If ($Root) { [void]$TomcatRoots.Add($Root.ToLower()) }
                }
            }
        }
    } Else {
        Write-Host "[Skip] 高速検索で発見されたため、ディスクスキャンを省略しました。" -ForegroundColor Cyan
    }
    
    # --- 結果出力 ---
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
        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult "${ShortV} | Apps: $($Apps.Count)" -FullDetail "Root: $TRoot`n$RawV`nWebapps: $($Apps.Name -join ', ')"
        $Count++
    }
}
