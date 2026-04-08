# Module_Oracle.ps1
# Version: 3.4.0
# Description: Oracle 調査モジュール (パイプ区切り表形式・エイリアス対応 v3.4.0)

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
        Write-Host "ユーザー名または接続先が空です。" -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # ご指定のテーブル: {ユーザー名}.CONF_SYSCONTROL
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    # パイプ区切りの表形式出力を実現する設定
    # エイリアスを PROPERTY_NAME, VALUE, DESCRIPTION に設定
    $MainSql = @"
SET PAGESIZE 100
SET FEEDBACK OFF
SET HEADING ON
SET LINESIZE 500
SET TERMOUT ON
SET ECHO OFF
SET VERIFY OFF
SET TRIMSPOOL ON
SET COLSEP ' | '
SET UNDERLINE '-'

COLUMN PROPERTY_NAME FORMAT A25
COLUMN VALUE         FORMAT A25
COLUMN DESCRIPTION   FORMAT A60

SELECT 
    CS_CPROPERTYNAME  AS PROPERTY_NAME, 
    CS_CPROPERTYVALUE AS VALUE, 
    CS_CPROPERTYDESC  AS DESCRIPTION
FROM $TargetTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    # ASCII保存で安定性を確保
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        # 実行SQLをログに記録
        $LogContent = "Executed SQL:`n$MainSql`n`nResults:`n"

        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "エラー" -FullDetail ($LogContent + $Output)
        } Else {
            $CleanOutput = $Output.Trim()
            If ([string]::IsNullOrWhiteSpace($CleanOutput)) { $CleanOutput = "該当データなし" }
            Log-Info -Title "Oracle Database" -ShortResult "成功" -FullDetail ($LogContent + $CleanOutput)
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "例外発生" -FullDetail "Msg: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
