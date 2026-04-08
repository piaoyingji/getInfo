# Module_Oracle.ps1
# Version: 1.3.1
# Description: Oracle Database 调查模块 (全多语言支持 + 对齐格式化)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    $MenuTitle = "Oracle Database $(T 'Searching')"
    If (-not $Silent) { Write-MenuHeader $MenuTitle }
    
    # 1. 检查 sqlplus 是否可用
    $SqlPlusRaw = & sqlplus -v 2>$null | Out-String
    If ([string]::IsNullOrWhiteSpace($SqlPlusRaw)) {
        Log-Info -Title "Oracle Database" -ShortResult (T "NoneFound") -FullDetail "sqlplus not found in PATH."
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    $OracleVersion = ($SqlPlusRaw -split "`n" | Select-String "Release").ToString().Trim()
    
    # 2. 交互式获取凭据
    Write-Host "--- Oracle Login ---" -ForegroundColor Gray
    $User = Read-Host "Username"
    $Pass = Read-Host "Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $PassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $Instance = Read-Host "Host/SID (e.g. 127.0.0.1/orcl)"
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($PassPlain) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "[Warn] Incomplete input." -ForegroundColor Yellow
        Wait-AndClear
        return
    }
    
    Write-Host "`n[Action] Connecting..." -ForegroundColor Gray
    
    # 3. 执行 SQL
    $ConnStr = "${User}/${PassPlain}@${Instance}"
    $SqlCmd = @"
SET HEAD OFF
SET FEEDBACK OFF
SET LINESIZE 3000
SET PAGESIZE 0
SET TRIMSPOOL ON
SELECT CS_CPROPERTYNAME || '###' || CS_CPROPERTYVALUE || '###' || CS_CPROPERTYDESC FROM UHR.CONF_SYSCONTROL WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    
    $SqlOutput = $SqlCmd | & sqlplus -s $ConnStr 2>&1 | Out-String
    
    If ($SqlOutput -match "ORA-") {
        Log-Info -Title "Oracle Database" -ShortResult "Error" -FullDetail "SQL Error: ${SqlOutput}"
    } Else {
        # 4. 对齐逻辑处理
        $Lines = $SqlOutput -split "`r?`n" | Where-Object { $_ -match '###' }
        
        If ($Lines.Count -gt 0) {
            $Data = foreach ($L in $Lines) {
                $Parts = $L -split '###'
                [PSCustomObject]@{
                    NAME  = if ($Parts[0]) { $Parts[0].Trim() } else { "" }
                    VALUE = if ($Parts[1]) { $Parts[1].Trim() } else { "" }
                    DESC  = if ($Parts[2]) { $Parts[2].Trim() } else { "" }
                }
            }
            
            $MaxName = ($Data | Measure-Object -Property NAME -Maximum -ErrorAction SilentlyContinue).Maximum.Length
            if ($MaxName -lt 20) { $MaxName = 20 }
            $MaxValue = ($Data | Measure-Object -Property VALUE -Maximum -ErrorAction SilentlyContinue).Maximum.Length
            if ($MaxValue -lt 20) { $MaxValue = 20 }
            
            $HeaderLine = "{0,-$MaxName} | {1,-$MaxValue} | {2}" -f "PROPERTY_NAME", "VALUE", "DESCRIPTION"
            $Separator  = "-" * ($MaxName + $MaxValue + 30)
            
            $FormattedLines = @($HeaderLine, $Separator)
            foreach ($Item in $Data) {
                $FormattedLines += "{0,-$MaxName} | {1,-$MaxValue} | {2}" -f $Item.NAME, $Item.VALUE, $Item.DESC
            }
            $CleanOutput = $FormattedLines -join "`n"
        } Else {
            $CleanOutput = T "NoneFound"
        }
        
        $FullOutput = "Oracle Version: ${OracleVersion}`n`nQuery Result:`n${CleanOutput}"
        Log-Info -Title "Oracle Database" -ShortResult ("${OracleVersion} | " + (T "Searching") + " Done") -FullDetail $FullOutput
    }
    
    If (-not $Silent) { Wait-AndClear }
}
