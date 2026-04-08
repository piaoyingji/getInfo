# Module_Apache.ps1
# Version: 1.9.0
# Description: Apache 調査モジュール (超高速化：コマンドプロンプトdir検索 + WMI)

Function Investigate-Apache {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Apache Search [$CurrentDrive] (v1.9.0 Turbo Mode)"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $ApacheExes = New-Object System.Collections.Generic.HashSet[string]
    
    # 1. プロセススキャン (WMI)
    Write-Host "[1/3] $(T 'ProcSearch')..." -ForegroundColor Gray
    $ProcFilter = "Name = 'httpd.exe'"
    Get-CimInstance Win32_Process -Filter $ProcFilter -ErrorAction SilentlyContinue | Foreach-Object {
        $Path = $_.ExecutablePath
        If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
            [void]$ApacheExes.Add($Path.ToLower())
        }
    }
    
    # Get-Process 経由 (WMIでパスが取れないプロセスの補完)
    Try {
        Get-Process "httpd" -ErrorAction SilentlyContinue | Foreach-Object {
            $Path = $_.Path
            If ($Path -and $Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                [void]$ApacheExes.Add($Path.ToLower())
            }
        }
    } Catch {}
    
    # 2. Windows サービススキャン
    Write-Host "[2/3] $(T 'SvcSearch')..." -ForegroundColor Gray
    $SvcFilter = "PathName LIKE '%httpd.exe%'"
    Get-CimInstance Win32_Service -Filter $SvcFilter -ErrorAction SilentlyContinue | Foreach-Object {
        If ($_.PathName -match '"?([^"]+\.exe)"?') {
            $Path = $Matches[1]
            If ($Path.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Path)) {
                [void]$ApacheExes.Add($Path.ToLower())
            }
        }
    }
    
    # 3. 有限ディスクスキャン (高速dirコマンド使用)
    If ($ApacheExes.Count -eq 0) {
        Write-Host "[3/3] $(T 'PathSearch')..." -ForegroundColor Gray
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        
        Foreach ($Dir in $TargetFolders) {
            Write-Host "   Searching $($Dir.FullName)..." -ForegroundColor DarkGray
            
            $CmdSearch = "dir `"$($Dir.FullName)\httpd.exe`" /s /b 2>nul"
            $Hits = cmd.exe /c $CmdSearch
            
            If ($Hits) {
                Foreach ($H in $Hits) {
                    If ($H -and (Test-Path $H)) { [void]$ApacheExes.Add($H.ToLower()) }
                }
            }
        }
    }
    
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
