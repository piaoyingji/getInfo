# Main_Menu.ps1
# Version: 4.1.0
# Description: Server Investigation Suite (v4.1.0 ASCII-Clean for encoding safety)

$ErrorActionPreference = "Stop"

Try {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue
    If (-not $ScriptDir) { $ScriptDir = Get-Location }
    Set-Location $ScriptDir

    $UtilsPath = Join-Path $ScriptDir "Module_Utils.ps1"
    If (Test-Path $UtilsPath) { . $UtilsPath } Else { throw "Module_Utils.ps1 not found." }

    . (Join-Path $ScriptDir "Module_Apache.ps1")
    . (Join-Path $ScriptDir "Module_Tomcat.ps1")
    . (Join-Path $ScriptDir "Module_Oracle.ps1")

    # Ensure results folder exists
    $ResultDir = Join-Path $ScriptDir "result"
    if (-not (Test-Path $ResultDir)) { New-Item -Path $ResultDir -ItemType Directory | Out-Null }

    # [UI: Cover]
    Clear-Host
    Write-MenuHeader (T "CoverTitle")
    Write-Host "Version: 4.1.0 (Encoding Optimized)" -ForegroundColor Gray
    Write-Host "`n$(T 'Msg_InputFile')" -NoNewline
    $InFilename = Read-Host
    $BaseName = If ([string]::IsNullOrWhiteSpace($InFilename)) { "Investigation_Report.md" } Else { if ($InFilename -notlike "*.md") { $InFilename + ".md" } else { $InFilename } }
    $Global:ReportFile = Join-Path $ResultDir $BaseName

    $StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $Global:ReportFile -Value ("# Investigation Report`n`n- **Start Time**: $StartTime`n") -Encoding UTF8

    # [UI: Main Menu]
    $MainOptions = @(
        (T "Opt_All"),
        (T "Opt_Apache"),
        (T "Opt_Tomcat"),
        (T "Opt_Oracle"),
        (T "Opt_Settings"),
        (T "Opt_Exit")
    )

    $Selected = 0
    While ($true) {
        $Selected = Invoke-Menu -Title (T "MainTitle") -Options $MainOptions -Default $Selected
        
        Clear-Host
        Switch ($Selected) {
            0 { 
                Write-MenuHeader (T "InvestTotalTitle")
                # Investigating one by one to allow separate method selection
                Investigate-Apache
                Investigate-Tomcat
                Investigate-Oracle
                Wait-AndClear 
            }
            1 { 
                Write-MenuHeader (T "InvestTitle" @("Apache"))
                Investigate-Apache
                Wait-AndClear 
            }
            2 { 
                Write-MenuHeader (T "InvestTitle" @("Tomcat"))
                Investigate-Tomcat
                Wait-AndClear 
            }
            3 { 
                Write-MenuHeader (T "InvestTitle" @("Oracle"))
                Investigate-Oracle
                Wait-AndClear 
            }
            4 { 
                $SubOptions = @((T "Opt_Lang"), (T "Opt_Back"))
                $SubSelected = 0
                While ($true) {
                    $SubSelected = Invoke-Menu -Title (T "SubTitle") -Options $SubOptions -Default $SubSelected
                    If ($SubSelected -eq 0) { 
                        Write-Host "`n$(T 'Msg_Lang_JA_Only')" -ForegroundColor Yellow
                        Start-Sleep -Seconds 1 
                    } Else { break }
                }
                $Selected = 4
            }
            5 { 
                $FullPath = (Get-Item $Global:ReportFile).FullName
                Write-Host "`n[Report Path]: $FullPath" -ForegroundColor Cyan
                Write-Host "`n$(T 'Msg_Menu_Exit')" -ForegroundColor Gray
                Start-Sleep -Seconds 2
                return 
            }
        }
    }

} Catch {
    $ErrMsg = (T "Msg_Critical_Error") + " " + $_.Exception.Message
    Write-Host "`n$ErrMsg" -ForegroundColor Red
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    Write-Host "`n$(T 'Msg_Program_End')" -ForegroundColor White
    [void](Read-Host)
}
