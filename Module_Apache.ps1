# Module_Apache.ps1
# Version: 4.0.0
# Description: Apache 調査モジュール (v4.0.0 Markdown 対応版)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Apache Search [$CurrentDrive]"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # --- 戦略：サービス/プロセス/ディスクスキャン (既存ロジック維持) ---
    Write-Host "[1/3] $(T 'SvcSearch')..." -ForegroundColor Gray
    Try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | Foreach-Object {
            $ImgPath = $_.GetValue("ImagePath")
            If ($ImgPath -match "httpd\.exe") {
                If ($ImgPath -match '"?([^"]+\.exe)"?') {
                    $Path = $Matches[1]
                    If ($Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                        [void]$ApacheExes.Add($Path.ToLower())
                    }
                }
            }
        }
    } Catch {}

    Write-Host "[2/3] $(T 'ProcSearch')..." -ForegroundColor Gray
    $ProcFilter = "Name = 'httpd.exe'"
    Get-CimInstance Win32_Process -Filter $ProcFilter -ErrorAction SilentlyContinue | Foreach-Object {
        $Path = $_.ExecutablePath
        If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
            [void]$ApacheExes.Add($Path.ToLower())
        }
    }
    
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[3/3] $(T 'PathSearch')..." -ForegroundColor Yellow
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        Foreach ($Dir in $TargetFolders) {
            $Hits = cmd.exe /c "dir `"$($Dir.FullName)\httpd.exe`" /s /b 2>nul"
            If ($Hits) { Foreach ($H in $Hits) { If ($H -and (Test-Path $H)) { [void]$ApacheExes.Add($H.ToLower()) } } }
        }
    }
    
    # --- Markdown 出力 ---
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
        
        # Markdown 用の整形
        $MDDetail = "- **インストールパス**: `$Root` `r`n"
        $MDDetail += "#### バージョン詳細`r`n"
        $MDDetail += "```text`r`n"
        $MDDetail += $Version.Trim() + "`r`n"
        $MDDetail += '```' + "`r`n"
        
        Log-Info -Title "Apache Instance [${Count}]" -ShortResult "$ShortV" -FullDetail $MDDetail
        $Count++
    }
}
