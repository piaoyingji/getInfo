# Module_Apache.ps1
# Version: 2.0.0
# Description: Apache 調査モジュール (レジストリ瞬時探索 + 超高速化)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Apache Search [$CurrentDrive] (v2.0.0 Instant Mode)"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # --- 戦略 0: レジストリ (サービス情報) から一瞬で取得 ---
    Write-Host "[1/3] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | Foreach-Object {
            $ImgPath = $_.GetValue("ImagePath")
            If ($ImgPath -match "httpd\.exe") {
                # ImagePath から実行ファイルのフルパスを抽出
                If ($ImgPath -match '"?([^"]+\.exe)"?') {
                    $Path = $Matches[1]
                    If ($Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                        [void]$ApacheExes.Add($Path.ToLower())
                    }
                }
            }
        }
    } Catch {}

    # --- 戦略 1: 実行中プロセスから取得 ---
    Write-Host "[2/3] $(T 'ProcSearch')..." -ForegroundColor Gray
    $ProcFilter = "Name = 'httpd.exe'"
    Get-CimInstance Win32_Process -Filter $ProcFilter -ErrorAction SilentlyContinue | Foreach-Object {
        $Path = $_.ExecutablePath
        If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
            [void]$ApacheExes.Add($Path.ToLower())
        }
    }
    
    # Get-Process 経由 (補完)
    Try {
        Get-Process "httpd" -ErrorAction SilentlyContinue | Foreach-Object {
            $Path = $_.Path
            If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                [void]$ApacheExes.Add($Path.ToLower())
            }
        }
    } Catch {}
    
    # --- 戦略 2: ディスクスキャン (上記で見つからなかった場合のみ実行) ---
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[3/3] $(T 'PathSearch')..." -ForegroundColor Yellow
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        
        Foreach ($Dir in $TargetFolders) {
            Write-Host "   Searching $($Dir.FullName)..." -ForegroundColor DarkGray
            $Hits = cmd.exe /c "dir `"$($Dir.FullName)\httpd.exe`" /s /b 2>nul"
            If ($Hits) {
                Foreach ($H in $Hits) {
                    If ($H -and (Test-Path $H)) { [void]$ApacheExes.Add($H.ToLower()) }
                }
            }
        }
    } Else {
        Write-Host "[Skip] 高速検索で発見されたため、ディスクスキャンを省略しました。" -ForegroundColor Cyan
    }
    
    # --- 結果出力 ---
    If ($ApacheExes.Count -eq 0) {
        Log-Info -Title "Apache HTTP Server" -ShortResult (T "Msg_None") -FullDetail "No Apache found on ${CurrentDrive}."
        return
    }
    
    Write-Host (T "Msg_Result" @($ApacheExes.Count, "Apache")) -ForegroundColor Green
    $Count = 1
    Foreach ($Exe in $ApacheExes) {
        $Root = Split-Path (Split-Path $Exe)
        $Version = & "$Exe" -v 2>$null | Out-String
        $ShortV = If ($Version -match "Server version:\s+(.*)") { $Matches[1].Trim() } Else { "Unknown" }
        Log-Info -Title "Apache [${Count}]" -ShortResult $ShortV -FullDetail "Location: $Root`n$Version"
        $Count++
    }
}
