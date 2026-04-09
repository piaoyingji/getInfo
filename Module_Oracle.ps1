# Module_Oracle.ps1
# Version: 4.3.7
# Description: Oracle Investigation Module (v4.3.7 Table Order & Alignment fix)

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
        'SET PAGESIZE 0',
        'SET FEEDBACK OFF',
        'SET VERIFY OFF',
        'SET HEADING OFF',
        'SET LINESIZE 2000',
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
        'SELECT ''[DATA_START]'' FROM DUAL;',
        'SELECT CS_CPROPERTYNAME || ''|'' || CS_CPROPERTYVALUE FROM ' + $TargetTable + ' ' + $FilterSql + ';',
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
        Param($Raw, $Head1 = 'Column 1', $Head2 = 'Column 2', $Head3 = $null)
        if ([string]::IsNullOrWhiteSpace($Raw)) { return (T 'Ora_Table_NoData') }
        $Rows = $Raw -split "`n" | Where-Object { $_.Trim() -ne '' }
        if ($Rows.Count -eq 0) { return (T 'Ora_Table_NoData') }
        
        $Grid = @()
        $Header = @($Head1, $Head2)
        if ($Head3) { $Header += $Head3 }
        $Grid += ,$Header

        foreach ($R in $Rows) { 
            $Cols = $R -split '\|' | ForEach-Object { $_.Trim() }
            $Grid += ,$Cols 
        }
        
        $MaxW = @()
        $ColCount = $Grid[0].Count
        for ($c=0; $c -lt $ColCount; $c++) {
            $Width = 5 
            foreach ($row in $Grid) { 
                if ($c -lt $row.Count -and $row[$c].Length -gt $Width) { $Width = $row[$c].Length } 
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

    $DataTable = Build-Table -Raw $RawData -Head1 'PROPERTY_NAME' -Head2 'VALUE'
    $DirTable = Build-Table -Raw $OraDir -Head1 'OWNER' -Head2 'NAME' -Head3 'PATH'
    $MemTable = Build-Table -Raw $OraMem -Head1 'PARAMETER' -Head2 'VALUE'

    # REVISED ORDER: Login -> Version -> SYSTEM CONFIG -> Encoding -> Directories -> Memory
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
