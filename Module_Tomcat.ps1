# Module_Tomcat.ps1
# Version: 1.9.0
# Description: Tomcat 調査モジュール (深層ディレクトリ探索 + 権限配慮型スキャン)

Function Investigate-Tomcat {
    Param([Boolean]$Silent = $false)
    
    $CurrentDrive = (Get-Location).Drive.Name + ":"
    $MenuTitle = "Tomcat Search [$CurrentDrive] (v1.9.0 Deep Scan)"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    $TomcatRoots = New-Object System.Collections.Generic.HashSet[string]
    
    # 辅助函数：智能识别 Tomcat 根目录 (bin 且含 webapps/conf/lib)
    Function Get-TomcatRoot {
        Param([String]$Path)
        If ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $null }
        $Current = $Path
        # 如果当前路径是二进制文件，先取其目录
        If (-not (Test-Path $Path -PathType Container)) { $Current = Split-Path $Path }
        
        # 向上爬升 5 层寻找特征目录
        For ($i=0; $i -lt 5; $i++) {
            $hasBin = Test-Path (Join-Path $Current "bin")
            $hasConf = Test-Path (Join-Path $Current "conf")
            $hasWebapps = Test-Path (Join-Path $Current "webapps")
            $hasLib = Test-Path (Join-Path $Current "lib")
            
            # 满足 Tomcat 结构特征
            If ($hasBin -And ($hasConf -or $hasWebapps -or $hasLib)) {
                return $Current
            }
            $Parent = Split-Path $Current
            If ($Parent -eq $Current -or $null -eq $Parent) { break }
            $Current = $Parent
        }
        return $null
    }

    # 1. プロセススキャン (WMI + Get-Process 双方向)
    Write-Host "[1/3] $(T 'Msg_Proc')..." -ForegroundColor Gray
    # WMI 経由
    $WmiProcs = Get-CimInstance Win32_Process -Filter "Name LIKE '%tomcat%' OR Name = 'java.exe' OR CommandLine LIKE '%catalina%'" -ErrorAction SilentlyContinue
    Foreach ($P in $WmiProcs) {
        $Paths = @($P.ExecutablePath)
        If ($P.CommandLine -match '-Dcatalina\.home="?([^"^\-]+)"?') { $Paths += $Matches[1].Trim().TrimEnd('\').Trim('"') }
        
        Foreach ($Path in $Paths) {
            $Root = Get-TomcatRoot $Path
            If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                [void]$TomcatRoots.Add($Root.ToLower())
            }
        }
    }
    
    # Get-Process 経由 (WMIでパスが取れないプロセスの補完)
    # ※管理者で実行していない場合、他ユーザーのパスは取得不可
    Try {
        Get-Process | Where-Object { $_.Name -like "*tomcat*" } | Foreach-Object {
            $Root = Get-TomcatRoot $_.Path
            If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                [void]$TomcatRoots.Add($Root.ToLower())
            }
        }
    } Catch {}

    # 2. Windows サービススキャン
    Write-Host "[2/3] $(T 'Msg_Svc')..." -ForegroundColor Gray
    $SvcFilter = "PathName LIKE '%tomcat%' OR PathName LIKE '%catalina%' OR DisplayName LIKE '%tomcat%'"
    Get-CimInstance Win32_Service -Filter $SvcFilter -ErrorAction SilentlyContinue | Foreach-Object {
        $PathToTest = $null
        If ($_.PathName -match '"?([^"]+)\\bin\\') { $PathToTest = $Matches[1] }
        ElseIf ($_.PathName -match '-Dcatalina\.home="?([^"^\-]+)"?') { $PathToTest = $Matches[1].Trim().TrimEnd('\').Trim('"') }
        
        $Root = Get-TomcatRoot $PathToTest
        If ($Root -and $Root.StartsWith($CurrentDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
            [void]$TomcatRoots.Add($Root.ToLower())
        }
    }

    # 3. 有限ディスクスキャン (さらに広範囲な検索)
    If ($TomcatRoots.Count -eq 0) {
        Write-Host "[3/3] $(T 'Msg_Dir')..." -ForegroundColor Gray
        $Excludes = "Windows|ProgramData|Users|Recycle|System Volume|AppData"
        $TargetFolders = Get-ChildItem ($CurrentDrive + "\") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $Excludes }
        
        Foreach ($Dir in $TargetFolders) {
            Write-Host "   Searching $($Dir.FullName)..." -ForegroundColor DarkGray
            
            # 高速ファイル検索 (cmd.exe の dir コマンドを利用してGet-ChildItem -Recurseの遅延を回避)
            $Cmd1 = "dir `"$($Dir.FullName)\catalina.bat`" /s /b 2>nul"
            $Cmd2 = "dir `"$($Dir.FullName)\tomcat*.exe`" /s /b 2>nul"
            $Hits = @(cmd.exe /c $Cmd1) + @(cmd.exe /c $Cmd2)
            
            If ($Hits) {
                Foreach ($H in $Hits) {
                    $Root = Get-TomcatRoot $H
                    If ($Root) { [void]$TomcatRoots.Add($Root.ToLower()) }
                }
            }
        }
    }
    
    If ($TomcatRoots.Count -eq 0) {
        Log-Info -Title "Apache Tomcat" -ShortResult (T "Msg_None") -FullDetail "No Instance found on ${CurrentDrive}. (Tips: 管理者権限で実行してください)"
        return
    }
    
    Write-Host (T "Msg_Result" @($TomcatRoots.Count, "Tomcat")) -ForegroundColor Green
    
    $Count = 1
    Foreach ($TRoot in $TomcatRoots) {
        $VerPath = Join-Path $TRoot "bin\version.bat"
        $RawV = "N/A"; $ShortV = "Unknown"
        If (Test-Path $VerPath) {
            $RawV = & "$VerPath" | Out-String
            If ($RawV -match "Server version:\s+(.*)") { $ShortV = $Matches[1].Trim() }
        }
        $Apps = @()
        If (Test-Path (Join-Path $TRoot "webapps")) {
            $Apps = Get-ChildItem (Join-Path $TRoot "webapps") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @("ROOT","docs","examples","manager","host-manager") }
        }
        
        Log-Info -Title "Tomcat Instance [${Count}]" -ShortResult "${ShortV} | Apps: $($Apps.Count)" -FullDetail "Root: $TRoot`n$RawV`nWebapps: $($Apps.Name -join ', ')"
        $Count++
    }
}
