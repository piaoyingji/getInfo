# Module_Oracle.ps1
# Version: 1.2.1
# Description: Oracle Database 调查模块 (对齐格式化版)

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
    
    # 3. 执行 SQL (使用特定分隔符以便后续处理)
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
        $ShortOutput = "查询异常 (详情见报告)"
        $FullOutput = "Oracle Version: ${OracleVersion}`n查询报错: ${SqlOutput}"
        Log-Info -Title "Oracle Database" -ShortResult $ShortOutput -FullDetail $FullOutput
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
            
            # 计算最大列宽
            $MaxName = ($Data | Measure-Object -Property NAME -Maximum -ErrorAction SilentlyContinue).Maximum.Length
            if ($MaxName -lt 20) { $MaxName = 20 }
            $MaxValue = ($Data | Measure-Object -Property VALUE -Maximum -ErrorAction SilentlyContinue).Maximum.Length
            if ($MaxValue -lt 20) { $MaxValue = 20 }
            
            # 构造表头
            $HeaderLine = "{0,-$MaxName} | {1,-$MaxValue} | {2}" -f "PROPERTY_NAME", "VALUE", "DESCRIPTION"
            $Separator  = "-" * ($MaxName + $MaxValue + 30)
            
            $FormattedLines = @($HeaderLine, $Separator)
            foreach ($Item in $Data) {
                $FormattedLines += "{0,-$MaxName} | {1,-$MaxValue} | {2}" -f $Item.NAME, $Item.VALUE, $Item.DESC
            }
            $CleanOutput = $FormattedLines -join "`n"
        } Else {
            $CleanOutput = "无 (未找到相关业务版本配置数据)"
        }
        
        $ShortOutput = "${OracleVersion} | 系统版本数据已获取"
        $FullOutput = "Oracle 版本: ${OracleVersion}`n`n查询结果:`n${CleanOutput}"
        
        Log-Info -Title "Oracle Database" -ShortResult $ShortOutput -FullDetail $FullOutput
    }
    
    If (-not $Silent) { Wait-AndClear }
}
