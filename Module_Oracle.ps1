# Module_Oracle.ps1
# Version: 2.6.0
# Description: Oracle 調査モジュール (ユーザー名指定テーブル・垂直フォーマット・ログあり)

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

    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # ユーザー自身をスキーマとしてテーブルを指定
    $TargetTable = "${User}.CONF_SYSCONTROL"

    # --- 垂直フォーマットでのクエリ実行 ---
    $MainSql = @"
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 1000
SET TERMOUT OFF
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

    # 実行ログ
    $LogDetail = "--- SQL Execution Log ---`n"
    $LogDetail += "Executed Script:`n$MainSql`n"
    $LogDetail += "-------------------------`n"

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            $LogDetail += "--- Raw Output ---`n$Output"
            Log-Info -Title "Oracle Database" -ShortResult "取得失敗" -FullDetail $LogDetail
        } Else {
            # 出力が空の場合のケア
            If ([string]::IsNullOrWhiteSpace($Output)) { $Output = "該当するデータが見つかりませんでした。 (Condition: LIKE '%Version%')" }
            $LogDetail += "--- Query Result ---`n$Output"
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $LogDetail
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail "Exception: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
