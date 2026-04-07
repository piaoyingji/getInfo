# Module_Oracle.ps1
# Version: 1.0.0
# Description: Oracle Database 调查模块 (容错增强版)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    If (-not $Silent) { Write-MenuHeader "Oracle Database 调查" }
    
    # 1. 检查 sqlplus 是否可用
    $SqlPlusRaw = & sqlplus -v 2>$null | Out-String
    If ([string]::IsNullOrWhiteSpace($SqlPlusRaw)) {
        Log-Info -Title "Oracle Database" -ShortResult "无 (未发现 sqlplus)" -FullDetail "本地系统 PATH 中未发现 sqlplus 命令，无法执行数据库调查。"
        If (-not $Silent) { Wait-AndClear }
        return
    }
    
    $OracleVersion = ($SqlPlusRaw -split "`n" | Select-String "Release").ToString().Trim()
    
    # 2. 交互式获取凭据
    Write-Host "--- 数据库登录信息 ---" -ForegroundColor Gray
    $User = Read-Host "请输入 Oracle 用户名"
    $Pass = Read-Host "请输入密码" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $PassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $Instance = Read-Host "请输入数据库实例/SID (例如: 127.0.0.1/orcl)"
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($PassPlain) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "[Warn] 输入不完整，已取消本次数据库查询。" -ForegroundColor Yellow
        Wait-AndClear
        return
    }
    
    Write-Host "`n[Action] 正在连接数据库并执行查询..." -ForegroundColor Gray
    
    # 3. 执行 SQL
    $ConnStr = "${User}/${PassPlain}@${Instance}"
    $SqlCmd = @"
SET HEAD OFF
SET FEEDBACK OFF
SET LINESIZE 2000
SELECT CS_CPROPERTYNAME || ' | ' || CS_CPROPERTYVALUE || ' | ' || CS_CPROPERTYDESC FROM UHR.CONF_SYSCONTROL WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    
    $SqlOutput = $SqlCmd | & sqlplus -s $ConnStr 2>&1 | Out-String
    
    If ($SqlOutput -match "ORA-") {
        $ShortOutput = "查询异常 (详情见报告)"
        $FullOutput = "Oracle Version: ${OracleVersion}`n查询报错: ${SqlOutput}"
        Log-Info -Title "Oracle Database" -ShortResult $ShortOutput -FullDetail $FullOutput
    } Else {
        $CleanOutput = $SqlOutput.Trim()
        If ([string]::IsNullOrWhiteSpace($CleanOutput)) { $CleanOutput = "无 (未找到相关业务版本配置数据)" }
        
        $ShortOutput = "${OracleVersion} | 系统版本数据已获取"
        $FullOutput = "Oracle 版本: ${OracleVersion}`n查询结果:`n${CleanOutput}"
        
        Log-Info -Title "Oracle Database" -ShortResult $ShortOutput -FullDetail $FullOutput
    }
    
    If (-not $Silent) { Wait-AndClear }
}
