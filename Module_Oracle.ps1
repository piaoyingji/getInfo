# Module_Oracle.ps1
# Version: 4.2.0
# Description: Oracle Investigation Module (v4.2.0 Stable fix)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    $OriginalEncoding = [Console]::OutputEncoding
    Try {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(932)
    } Catch {}

    Write-Host ("`n" + (T 'Ora_Header')) -ForegroundColor Cyan
    Write-Host (T 'Ora_User') -NoNewline; $User = Read-Host
    Write-Host (T 'Ora_Pass') -NoNewline; $Pass = Read-Host -AsSecureString
    Write-Host (T 'Ora_Inst') -NoNewline; $Instance = Read-Host
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host (T 'Ora_Empty') -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $TmpSql = Join-Path $env:TEMP 'invest_ora.sql'
    
    Write-Host ("`n" + (T 'Ora_Connect')) -ForegroundColor Gray

    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    # Define SQL using an array of strings to avoid heredoc issues during development
    $SqlLines = @(
        'SET PAGESIZE 1000',
        'SET FEEDBACK OFF',
        'SET HEADING ON',
        'SET LINESIZE 1000',
        'SET TERMOUT ON',
        'SET ECHO OFF',
        'SET VERIFY OFF',
        'SET TRIMSPOOL ON',
        "SET COLSEP ' | '",
        'SET UNDERLINE OFF',
        '',
        'PROMPT [VERSION_START]',
        'SELECT BANNER FROM V$VERSION;',
        'PROMPT [VERSION_END]',
        '',
        'PROMPT [DATA_START]',
        'COLUMN PROPERTY_NAME FORMAT A30',
        'COLUMN VALUE         FORMAT A30',
        'COLUMN DESCRIPTION   FORMAT A60',
        '',
        'SELECT ',
        '    CS_CPROPERTYNAME  AS PROPERTY_NAME, ',
        '    CS_CPROPERTYVALUE AS VALUE, ',
        '    CS_CPROPERTYDESC  AS DESCRIPTION',
        "FROM $TargetTable ",
        "WHERE CS_CPROPERTYNAME LIKE '%Version%';",
        'PROMPT [DATA_END]',
        'EXIT;'
    )
    $SqlText = $SqlLines -join "`r`n"
    $SqlText | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $ConnectStr = "${User}/${UnsecurePass}@${Instance}"
        # Quote the connection string for sqlplus
        $RawOutput = sqlplus -S "$ConnectStr" "@$TmpSql"
        $OutputStr = $RawOutput -join "`r`n"

        $OraVer = 'FAIL'
        If ($OutputStr -match '(?s)\[VERSION_START\]\s*(.*?)\s*\[VERSION_END\]') {
            $OraVer = $Matches[1].Trim()
        }

        $MDTable = ""
        If ($OutputStr -match '(?s)\[DATA_START\]\s*(.*?)\s*\[DATA_END\]') {
            $DataBlock = $Matches[1].Trim()
            $Lines = $DataBlock -split "\r?\n" | Where-Object { $_.Trim() -ne "" }
            
            If ($Lines.Count -ge 1) {
                # Calculate widths and align
                $DataRows = @()
                $MaxColumnWidths = @(0, 0, 0)
                
                foreach ($Line in $Lines) {
                    $Cells = $Line -split ' \| ' | ForEach-Object { $_.Trim() }
                    $DataRows += ,$Cells
                    for ($i = 0; $i -lt $Cells.Count -and $i -lt 3; $i++) {
                        if ($Cells[$i].Length -gt $MaxColumnWidths[$i]) {
                            $MaxColumnWidths[$i] = $Cells[$i].Length
                        }
                    }
                }

                for ($i = 0; $i -lt 3; $i++) {
                    if ($MaxColumnWidths[$i] -lt 3) { $MaxColumnWidths[$i] = 3 }
                }
                
                # Header
                $Header = '| '
                $Sep = '| '
                for ($i = 0; $i -lt 3; $i++) {
                    $Val = if ($i -lt $DataRows[0].Count) { $DataRows[0][$i] } else { '' }
                    $Header += $Val.PadRight($MaxColumnWidths[$i]) + ' | '
                    $Sep += (':' + ('-' * ($MaxColumnWidths[$i] - 1))) + ' | '
                }
                $MDTable += $Header.TrimEnd() + "`r`n"
                $MDTable += $Sep.TrimEnd() + "`r`n"
                
                # Rows
                for ($r = 1; $r -lt $DataRows.Count; $r++) {
                    $RowStr = '| '
                    for ($c = 0; $c -lt 3; $c++) {
                        $Val = if ($c -lt $DataRows[$r].Count) { $DataRows[$r][$c] } else { '' }
                        $RowStr += $Val.PadRight($MaxColumnWidths[$c]) + ' | '
                    }
                    $MDTable += $RowStr.TrimEnd() + "`r`n"
                }
            }
        }

        If ([string]::IsNullOrWhiteSpace($MDTable)) { 
            If ($OutputStr -match 'ORA-\d+') {
                $ErrHead = '> [!CAUTION]' + "`r`n> " + (T 'Ora_Table_Error') + "`r`n`r`n"
                $MDTable = $ErrHead + '```' + "`r`n$($OutputStr.Trim())`r`n" + '```'
            } Else {
                $MDTable = T 'Ora_Table_NoData'
            }
        }

        # Build final markdown using concatenation to avoid backtick/interpolation confusion
        $Line_Break = "`n"
        # Markdown assembly (Version and Table only)
        $Section2 = (T 'Ora_Summary_Ver') + $Line_Break
        $Section2 += '> ' + $OraVer + $Line_Break + $Line_Break
        
        $TableTitle = (T 'Ora_Summary_Table' $TargetTable)
        $Section3 = $TableTitle + $Line_Break + $MDTable

        $FinalMD = $Section2 + $Section3

        Log-Info -Title (T 'Ora_Result_Title') -ShortResult (T 'Ora_Short_Success') -FullDetail $FinalMD

    } Catch {
        $ErrorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
        Log-Info -Title (T 'Ora_Result_Title') -ShortResult (T 'Ora_Short_Error') -FullDetail ('Msg: ' + $ErrorMsg)
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
