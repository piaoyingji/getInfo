# Module_Utils.ps1
# Version: 4.1.0
# Description: Global Utilities (v4.5.0 Robust Interactive Menu version)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$JsonPath = Join-Path $ScriptDir "I18n.json"

if (Test-Path $JsonPath) {
    try {
        $RawJson = Get-Content -Path $JsonPath -Raw -Encoding UTF8
        $Global:I18nMap = $RawJson | ConvertFrom-Json
    } catch {
        $Global:I18nMap = $null
    }
}

Function T {
    Param([String]$Key)
    if (-not $Global:I18nMap) { return $Key }
    $Val = $Global:I18nMap."ja-JP".$Key
    if ($null -eq $Val) { $Val = $Key }
    if ($args -and $args.Count -gt 0) {
        try { return $Val -f $args } catch { return $Val }
    }
    return $Val
}

# Robust Interactive Arrow-Key Menu
Function Invoke-Menu {
    Param(
        [String]$Title,
        [Array]$Options,
        [Int]$Default = 0
    )
    $Current = $Default
    $RawUI = $Host.UI.RawUI
    $OldCursorSize = $RawUI.CursorSize
    try { $RawUI.CursorSize = 0 } catch {}

    while ($true) {
        Clear-Host
        Write-Host "`n****************************************" -ForegroundColor DarkCyan
        Write-Host "* $Title" -ForegroundColor DarkCyan
        Write-Host "****************************************" -ForegroundColor DarkCyan
        Write-Host " (Arrows: Move, Enter: Select, Q: Back/Exit)`n" -ForegroundColor Gray

        for ($i=0; $i -lt $Options.Count; $i++) {
            if ($i -eq $Current) {
                Write-Host (" > {0} " -f $Options[$i]) -ForegroundColor Black -BackgroundColor White
            } else {
                Write-Host ("   {0} " -f $Options[$i])
            }
        }

        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.VirtualKeyCode -eq 38) { # Up
            $Current = if ($Current -gt 0) { $Current - 1 } else { $Options.Count - 1 }
        } elseif ($Key.VirtualKeyCode -eq 40) { # Down
            $Current = if ($Current -lt $Options.Count - 1) { $Current + 1 } else { 0 }
        } elseif ($Key.VirtualKeyCode -eq 13) { # Enter
            break
        } elseif ($Key.Character -eq 'q' -or $Key.Character -eq 'Q') {
            # Map Q to the last option (usually Exit or Back)
            $Current = $Options.Count - 1
            break
        }
    }
    
    try { $RawUI.CursorSize = $OldCursorSize } catch {}
    Clear-Host
    return $Current
}

Function Wait-AndClear {
    if ($Global:ReportFile -and (Test-Path $Global:ReportFile)) {
        $FullPath = (Get-Item $Global:ReportFile).FullName
        Write-Host "`n[Report]: $FullPath" -ForegroundColor Cyan
    }
    Write-Host "$(T 'Opt_Back')..." -ForegroundColor Gray
    [void](Read-Host)
    Clear-Host
}

Function Write-MenuHeader {
    Param([String]$Title)
    Write-Host "`n****************************************" -ForegroundColor DarkCyan
    Write-Host "* $Title" -ForegroundColor DarkCyan
    Write-Host "****************************************" -ForegroundColor DarkCyan
}

Function Log-Info {
    Param([String]$Title, [String]$ShortResult, [String]$FullDetail)
    $Content = "`n## $Title`n"
    $Content += "- **結果概略**: $ShortResult`n"
    if ($FullDetail) {
        $Content += "### 詳細情報`n"
        $Content += "$FullDetail`n"
    }
    if ($Global:ReportFile) {
        Add-Content -Path $Global:ReportFile -Value $Content -Encoding UTF8
    } else {
        Write-Host "`n$Content"
    }
}
