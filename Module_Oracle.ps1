# Module_Oracle.ps1
# Version: 4.3.8
# Description: Oracle Investigation Module (v4.3.8 SELECT * Support)

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

    $SchemaName = $OraUser -replace '\s+as\s+sysdba\s*', ''
    $TargetTable = $SchemaName + '.CONF_SYSCONTROL'
    $FilterSql = 'WHERE CS_CPROPERTYNAME LIKE ''%Version%'''

    $MsgConnect = T 'Ora_Connect'
    Write-Host "`n$MsgConnect" -ForegroundColor Cyan
    
    $SqlLines = @(
        'SET PAGESIZE 100',
        'SET FEEDBACK OFF',
        'SET VERIFY OFF',
        'SET HEADING OFF',
        'SET LINESIZE 3000',
        'SET TRIMSPOOL ON',
        'COLUMN BANNER FORMAT A200',
        'COLUMN VAL FORMAT A200',
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
        
        # Use COLSEP for SELECT *
        'SELECT ''[DATA_START]'' FROM DUAL;',
        'SET HEADING ON',
        'SET COLSEP "|"',
        'SELECT * FROM ' + $TargetTable + ' ' + $FilterSql + ';',
        'SET HEADING OFF',
        'SELECT ''[DATA_END]'' FROM DUAL;',
        'EXIT;'
    )
    $SqlText = $SqlLines -join "`n"

    $ConnectStr = $OraUser + '/' + $OraPass + '@' + $OraInst
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
        Param($Raw, $DefaultHeader = $null)
        if ([string]::IsNullOrWhiteSpace($Raw)) { return (T 'Ora_Table_NoData') }
        $Rows = $Raw -split "`n" | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^-+$' }
        if ($Rows.Count -eq 0) { return (T 'Ora_Table_NoData') }
        
        $Grid = @()
        foreach ($R in $Rows) { 
            $Cols = $R -split '\|' | ForEach-Object { $_.Trim() }
            $Grid += ,$Cols 
        }

        # If data has no natural header but we want one
        if ($DefaultHeader -and $Grid.Count -gt 0 -and $Grid[0].Count -eq $DefaultHeader.Count) {
             # Check if first row is already a header (heuristic: does it look like column names?)
             # For simplicity, if DefaultHeader is passed, we INSERT it as the first row if the input was heading-off
             # But here we use HEADING ON for DATA_START, so Grid[0] IS the header.
        }

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
        for ($c=0; $c -lt $MaxW.Count; $c++) { $Res += ' ' + [string]($Grid[0][$c]).PadRight($MaxW[$c]) + ' |' }
        $Res += $NL + '|'
        for ($c=0; $c -lt $MaxW.Count; $c++) { $Res += ' :' + ('-' * ($MaxW[$c]-1)) + ' |' }
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

    # Manual headers for these since we use HEADING OFF + Manual Pipe concat in SQL
    $DirTable = Build-Table -Raw ('OWNER|NAME|PATH' + $NL + $OraDir)
    $MemTable = Build-Table -Raw ('PARAMETER|VALUE' + $NL + $OraMem)
    
    # Automatic header for this since we use HEADING ON + COLSEP in SQL
    $DataTable = Build-Table -Raw $RawData

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
