# Module_Oracle.ps1
# Version: 4.3.9
# Description: Oracle Investigation Module (v4.3.9 Final SQL/Alignment logic)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    $OraUser = ''
    $OraPass = ''
    $OraInst = ''
    
    if (-not $Silent) {
        Write-MenuHeader (T 'Main_Oracle')
        Write-Host (T 'Ora_Header')
        $OraUser = Read-Host (T 'Ora_User')
        $OraPass = Read-Host (T 'Ora_Pass')
        $OraInst = Read-Host (T 'Ora_Inst')
    }

    if ([string]::IsNullOrWhiteSpace($OraUser) -or [string]::IsNullOrWhiteSpace($OraInst)) {
        Write-Host (T 'Ora_Empty') -ForegroundColor Red
        return
    }

    # Dynamic Schema Name
    $SchemaName = $OraUser -replace '\s+as\s+sysdba\s*', ''
    $TargetTable = $SchemaName + '.CONF_SYSCONTROL'
    # Exactly as requested: SELECT * FROM ... WHERE ...
    $UserSql = 'SELECT * FROM ' + $TargetTable + ' WHERE CS_CPROPERTYNAME LIKE ''%Version%'';'

    $MsgConnect = T 'Ora_Connect'
    Write-Host "`n$MsgConnect" -ForegroundColor Cyan
    
    $SqlLines = @(
        'SET PAGESIZE 0',
        'SET FEEDBACK OFF',
        'SET VERIFY OFF',
        'SET HEADING OFF',
        'SET LINESIZE 5000',
        'SET TRIMSPOOL ON',
        'SET TERMOUT OFF',
        'SET PAGESIZE 0',
        'SELECT ''[VER_START]'' FROM DUAL;',
        'SELECT BANNER FROM V$VERSION;',
        'SELECT ''[VER_END]'' FROM DUAL;',
        'SELECT ''[CHAR_START]'' FROM DUAL;',
        'SELECT VALUE FROM NLS_DATABASE_PARAMETERS WHERE PARAMETER = ''NLS_CHARACTERSET'';',
        'SELECT ''[CHAR_END]'' FROM DUAL;',
        'SELECT ''[DIR_START]'' FROM DUAL;',
        'SELECT OWNER || ''|'' || DIRECTORY_NAME || ''|'' || DIRECTORY_PATH FROM ALL_DIRECTORIES;',
        'SELECT ''[DIR_END]'' FROM DUAL;',
        'SELECT ''[MEM_START]'' FROM DUAL;',
        'SELECT NAME || ''|'' || VALUE FROM V$PARAMETER WHERE NAME IN (''sga_target'', ''pga_aggregate_target'', ''memory_target'');',
        'SELECT ''[MEM_END]'' FROM DUAL;',
        
        'SELECT ''[DATA_START]'' FROM DUAL;',
        'SET HEADING ON',
        'SET COLSEP "|"',
        'SET PAGESIZE 1000',
        'SET NUMWIDTH 20',
        $UserSql,
        'SET HEADING OFF',
        'SELECT ''[DATA_END]'' FROM DUAL;',
        'EXIT;'
    )
    $SqlText = $SqlLines -join "`n"

    $ConnectStr = $OraUser + '/' + $OraPass + '@' + $OraInst
    # Run with -S (Silent) but we need the output
    $Output = $SqlText | sqlplus.exe -S $ConnectStr 2>&1
    $OutputStr = $Output | Out-String

    if ($OutputStr -match 'ORA-') {
        $ErrTitle = T 'Ora_Result_Title'
        $ErrRes = T 'Ora_Short_Error'
        Log-Info -Title $ErrTitle -ShortResult $ErrRes -FullDetail ('> [!CAUTION]' + "`n" + '> SQL Error: ' + $OutputStr)
        return
    }

    Function Get-Section {
        Param($In, $StartPattern, $EndPattern)
        if ($In -match ('(?s)' + $StartPattern + '\s*(.*?)\s*' + $EndPattern)) { return $Matches[1].Trim() }
        return ''
    }

    $OraVer = Get-Section $OutputStr '\[VER_START\]' '\[VER_END\]'
    $OraEnc = Get-Section $OutputStr '\[CHAR_START\]' '\[CHAR_END\]'
    $OraDir = Get-Section $OutputStr '\[DIR_START\]' '\[DIR_END\]'
    $OraMem = Get-Section $OutputStr '\[MEM_START\]' '\[MEM_END\]'
    $RawData = Get-Section $OutputStr '\[DATA_START\]' '\[DATA_END\]'

    $NL = [char]10
    $InfoList = @()
    $InfoList += '| Item | Value |'
    $InfoList += '| :--- | :--- |'
    $InfoList += ('| User | {0} |' -f $OraUser)
    $InfoList += ('| Password | {0} |' -f $OraPass)
    $InfoList += ('| SID/Service | {0} |' -f $OraInst)
    $LoginInfo = $InfoList -join $NL

    Function Build-Table {
        Param($Raw, $IsManualHeader = $false, $Head1 = '', $Head2 = '', $Head3 = '')
        if ([string]::IsNullOrWhiteSpace($Raw)) { return (T 'Ora_Table_NoData') }
        
        # Remove empty lines and sqlplus dashed lines (e.g. ---------)
        $Rows = $Raw -split "`n" | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*[-| ]+\s*$' }
        if ($Rows.Count -eq 0) { return (T 'Ora_Table_NoData') }
        
        $Grid = @()
        if ($IsManualHeader) {
            $H = @($Head1, $Head2)
            if ($Head3) { $H += $Head3 }
            $Grid += ,$H
        }

        foreach ($R in $Rows) { 
            # Split by | and trim each column
            $Cols = $R -split '\|' | ForEach-Object { ([string]$_).Trim() }
            $Grid += ,$Cols 
        }
        
        if ($Grid.Count -eq 0) { return (T 'Ora_Table_NoData') }

        $MaxW = @()
        $ColCount = $Grid[0].Count
        for ($c=0; $c -lt $ColCount; $c++) {
            $Width = 5 
            foreach ($row in $Grid) { 
                if ($c -lt $row.Count) {
                    $valStr = [string]($row[$c])
                    if ($valStr.Length -gt $Width) { $Width = $valStr.Length }
                }
            }
            $MaxW += $Width
        }

        $Res = '|'
        for ($c=0; $c -lt $MaxW.Count; $c++) { 
            $Res += ' ' + ([string]$Grid[0][$c]).PadRight($MaxW[$c]) + ' |' 
        }
        $Res += $NL + '|'
        for ($c=0; $c -lt $MaxW.Count; $c++) { 
            $Res += ' :' + ('-' * ($MaxW[$c]-1)) + ' |' 
        }
        $Res += $NL
        for ($r=1; $r -lt $Grid.Count; $r++) {
            $Res += '|'
            for ($c=0; $c -lt $MaxW.Count; $c++) { 
                $Val = if ($c -lt $Grid[$r].Count) { $Grid[$r][$c] } else { '' }
                $Res += ' ' + ([string]$Val).PadRight($MaxW[$c]) + ' |' 
            }
            $Res += $NL
        }
        return $Res
    }

    # Manual pipe concat used in SQL for these
    $DirTable = Build-Table -Raw $OraDir -IsManualHeader $true -Head1 'OWNER' -Head2 'NAME' -Head3 'PATH'
    $MemTable = Build-Table -Raw $OraMem -IsManualHeader $true -Head1 'PARAMETER' -Head2 'VALUE'
    
    # HEADING ON + COLSEP used in SQL for this (already has header in Rows[0])
    $DataTable = Build-Table -Raw $RawData -IsManualHeader $false

    $SummaryList = @()
    $SummaryList += (T 'Ora_Summary_Login')
    $SummaryList += $LoginInfo
    $SummaryList += ''
    $SummaryList += (T 'Ora_Summary_Ver')
    $SummaryList += ('> ' + $OraVer)
    $SummaryList += ''
    $SummaryList += (T 'Ora_Summary_Table' @($TargetTable))
    $SummaryList += $DataTable
    $SummaryList += ''
    $SummaryList += (T 'Ora_Summary_Enc')
    $SummaryList += ('> ' + $OraEnc)
    $SummaryList += ''
    $SummaryList += (T 'Ora_Summary_Dir')
    $SummaryList += $DirTable
    $SummaryList += ''
    $SummaryList += (T 'Ora_Summary_Mem')
    $SummaryList += $MemTable

    $FullDetail = $SummaryList -join $NL

    $OraTitle = T 'Ora_Result_Title'
    $OraSuccess = T 'Ora_Short_Success'
    Log-Info -Title $OraTitle -ShortResult $OraSuccess -FullDetail $FullDetail
    Write-Host "$OraSuccess" -ForegroundColor Green
}
