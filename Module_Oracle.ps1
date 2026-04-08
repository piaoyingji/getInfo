# Module_Oracle.ps1
# Version: 2.4.0
# Description: Oracle 調査モジュール (テーブル・条件修正版 v2.4.0)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    # 日本語出力を正しく受け取るためのエンコーディング設定
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

    $TargetBase = "CONF_SYSCONTROL"
    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # --- ステップ1: メタデータから正確な所有者とテーブル名を取得 ---
    $MetaSql = "SET HEAD OFF`nSET FEEDBACK OFF`nSELECT OWNER || '.' || TABLE_NAME FROM ALL_TABLES WHERE UPPER(TABLE_NAME) = '$TargetBase' AND ROWNUM = 1;`nEXIT;"
    $MetaSql | Set-Content -Path $TmpSql -Encoding ASCII
    
    $FinalFullTable = $TargetBase
    Try {
        $MetaRes = (sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql").Trim()
        If (-not [string]::IsNullOrWhiteSpace($MetaRes) -and $MetaRes -notlike "*ORA-*") {
            $FinalFullTable = $MetaRes
            Write-Host "[Info] Detect Table: $FinalFullTable" -ForegroundColor Cyan
        }
    } Catch {}

    # --- ステップ2: 本番クエリの実行 ---
    # 条件: WHERE CS_CPROPERTYNAME LIKE '%Version%'
    $MainSql = @"
SET PAGESIZE 100
SET LINESIZE 500
SET FEEDBACK OFF
SET HEADING ON
SET WRAP OFF
COLUMN CS_CPROPERTYNAME FORMAT A40
COLUMN CS_CPROPERTYVALUE FORMAT A60
COLUMN CS_CPROPERTYDESC FORMAT A60
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC 
FROM $FinalFullTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    # 実行ログ
    $LogDetail = "--- SQL Execution Log ---`n"
    $LogDetail += "Metadata Search SQL:`n$MetaSql`n"
    $LogDetail += "Final Script:`n$MainSql`n"
    $LogDetail += "-------------------------`n"

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        $LogDetail += "--- Raw Output ---`n$Output"

        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "取得失敗" -FullDetail $LogDetail
        } Else {
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $LogDetail
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail "Exception: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
