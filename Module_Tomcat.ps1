# Module_Tomcat.ps1
# Version: 2.1.0
# Description: Tomcat 調査モジュール (瞬時検索優先 + ディスクスキャン最小化)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Tomcat Search [$CurrentDrive] (v2.1.0 Instant Mode)"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # --- 辅助関数：パスからTomcatの根ディレクトリを特定 ---
    Function Get-TomcatRoot {
        Param([String]$Path)
        If ([string]::IsNullOrWhiteSpace($Path)) { return $null }
        $Path = $Path.Replace('"', '').Trim()
        If (-not (Test-Path $Path)) { return $null }
        
        $Current = If (Test-Path $Path -PathType Container) { $Path } Else { Split-Path $Path }
        
        # 最大5階層上まで探索
        For ($i=0; $i -lt 5; $i++) {
            # Tomcatの構成要素（bin, lib, conf, webappsのいずれか複数）を確認
            $hasBin = Test-Path (Join-Path $Current "bin")
            $hasLib = Test-Path (Join-Path $Current "lib")
            $hasConf = Test-Path (Join-Path $Current "conf")
            
            If ($hasBin -And ($hasLib -or $hasConf)) {
                return $Current
            }
            $Parent = Split-Path $Current
            If ($Parent -eq $Current -or $null -eq $Parent) { break }
            $Current = $Parent
        }
        return $null
    }

    # --- 戦略 0: Get-Service (Windowsサービス情報を一瞬で取得) ---
    Write-Host "[1/4] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        # Get-Service は WMI よりも速く、サービス名や表示名から直接ヒットさせます
        $SvcList = Get-Service | Where-Object { $_.Name -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }
        Foreach ($S in $SvcList) {
            # レジストリから ImagePath を取得（Get-Serviceではパスが取れないため）
            $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($S.Name)"
            $ImgPath = (Get-ItemProperty $RegPath -ErrorAction SilentlyContinue).ImagePath
            If ($ImgPath) {
                $CleanPath = $ImgPath -replace ' -.*$', '' # 引数を除去
                $Root = Get-TomcatRoot $CleanPath
                If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$TomcatRoots.Add($Root.ToLower())
                }
            }
        }
    } Catch {}

    # --- 戦略 1: 実行中プロセス (WMI) ---
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[2/4] $(T 'Msg_Proc')..." -ForegroundColor Gray
        $WmiProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%tomcat%' OR Name = 'java.exe'" -ErrorAction SilentlyContinue
        Foreach ($P in $WmiProcs) {
            # java.exe の場合は CommandLine に catalina が含まれるかチェック
            If ($P.Name -eq "java.exe" -and $P.CommandLine -notmatch "catalina") { continue }
            
            $Paths = @($P.ExecutablePath)
            If ($P.CommandLine -match '-Dcatalina\.home="?([^"^\-]+)"?') { $Paths += $Matches[1].TrimEnd('\').Trim('"') }
            
            Foreach ($Path in $Paths) {
                $Root = Get-TomcatRoot $Path
                If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$TomcatRoots.Add($Root.ToLower())
                }
            }
        }
    }

    # --- 戦略 2: 環境変数の確認 ---
    If ($env:CATALINA_HOME) {
        $Root = Get-TomcatRoot $env:CATALINA_HOME
        If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) { [void]$TomcatRoots.Add($Root.ToLower()) }
    }

    # --- 戦略 3: ディスクスキャン (最終手段) ---
    # 高速検索で1つも見つからない場合、あるいはユーザーが明示的に全量を探したい場合のみ
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[3/4] $(T 'PathSearch')..." -ForegroundColor Yellow
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        
        Foreach ($Dir in $TargetFolders) {
            Write-Host "   Searching $($Dir.FullName)..." -ForegroundColor DarkGray
            # 検索対象を version.bat に絞ることで dir /s の出力を激減させ高速化
            $CmdSearch = "where /r `"$($Dir.FullName)`" version.bat 2>nul"
            $Hits = cmd.exe /c $CmdSearch
            
            If ($Hits) {
                Foreach ($H in $Hits) {
                    $Root = Get-TomcatRoot $H
                    If ($Root) { [void]$TomcatRoots.Add($Root.ToLower()) }
                }
            }
        }
    } Else {
        Write-Host "[Skip] サービス/プロセスから Tomcat を検知したため、低速な全ディスクスキャンを省略しました。" -ForegroundColor Cyan
    }
    
    # --- レポート出力 ---
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult (T "Msg_None") -FullDetail "No Instance found on ${CurrentDrive}.`n(注意: 管理者権限で実行すると、より多くのプロセス情報を取得できます)"
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
