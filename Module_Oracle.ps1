# Module_Oracle.ps1
# Version: 2.7.0
# Description: Oracle 調査モジュール (ご指定SQL再現・垂直整列・ログ出力版)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    # 日本語文字化け対策
    $OriginalEncoding = [Console]::OutputEncoding
    Try {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(932)
    } Catch {}

    Write-Host "`n$(T 'Ora_Header')" -ForegroundColor Cyan
    Write-Host (T "Ora_User") -NoNewline; $User = Read-Host
    Write-Host (T "Ora_Pass") -NoNewline; $Pass = Read-Host -AsSecureString
    Write-Host (T "Ora_Inst") -NoNewline; $Instance = Read-Host
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "ユーザー名または接続先が空です。調査をスキップします。" -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # --- ご指定のSQL文を構築 ---
    # UHRの部分は入力されたユーザー名 ($User) を使用します
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    # 垂直フォーマット用のSQL
    # LABEL : VALUE の形式で1レコードにつき複数行出力し、最後に区切り線を入れます
    $MainSql = @"
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET TERMOUT OFF
SET LINESIZE 1000
SELECT 
'NAME  : ' || CS_CPROPERTYNAME || CHR(10) ||
'VALUE : ' || CS_CPROPERTYVALUE || CHR(10) ||
'DESC  : ' || CS_CPROPERTYDESC || CHR(10) ||
'------------------------------------------------------------'
FROM $TargetTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    # 実行ログの構築 (ご要望通り実行SQLをログに含めます)
    $LogDetail = "--- SQL Execution Log ---`n"
    $LogDetail += "Executed SQL:`n$MainSql`n"
    $LogDetail += "-------------------------`n"

    Try {
        # 安定の一時ファイル方式で実行
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            $LogDetail += "--- Error Output ---`n$Output"
            Log-Info -Title "Oracle Database" -ShortResult "エラー発生" -FullDetail $LogDetail
        } Else {
            If ([string]::IsNullOrWhiteSpace($Output)) { 
                $Output = "該当データなし (Table: $TargetTable, Condition: LIKE '%Version%')" 
            }
            $LogDetail += "--- Query Results ---`n$Output"
            Log-Info -Title "Oracle Database" -ShortResult "成功" -FullDetail $LogDetail
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "例外発生" -FullDetail "Msg: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
