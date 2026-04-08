# Module_Oracle.ps1
# Version: 3.5.0
# Description: Oracle 調査モジュール (バージョン取得・改行不具合修正 v3.5.0)

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
    # 加えて、Oracleのバージョン情報も取得します
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
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

PROMPT [ ORACLE VERSION ]
SELECT BANNER FROM V`$VERSION;

PROMPT
PROMPT [ PROPERTY CONFIGURATION ]
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

        # sqlplus の出力を直接キャプチャし、配列を改行コードで明示的に結合
        $RawOutput = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        $Output = $RawOutput -join "`r`n"
        
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
