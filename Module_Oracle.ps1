# Module_Oracle.ps1
# Version: 2.5.0
# Description: Oracle 調査モジュール (垂直フォーマット表示 v2.5.0)

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

    # --- ステップ1: メタデータから正確な所有者とテーブル名を特定 ---
    $MetaSql = "SET HEAD OFF`nSET FEEDBACK OFF`nSELECT OWNER || '.' || TABLE_NAME FROM ALL_TABLES WHERE UPPER(TABLE_NAME) = '$TargetBase' AND ROWNUM = 1;`nEXIT;"
    $MetaSql | Set-Content -Path $TmpSql -Encoding ASCII
    
    $FinalFullTable = $TargetBase
    Try {
        $MetaRes = (sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql").Trim()
        If (-not [string]::IsNullOrWhiteSpace($MetaRes) -and $MetaRes -notlike "*ORA-*") {
            $FinalFullTable = $MetaRes
        }
    } Catch {}

    # --- ステップ2: 垂直フォーマットでのクエリ実行 ---
    # 各レコードを NAME, VALUE, DESC の順で縦に並べる
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
FROM $FinalFullTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "取得失敗" -FullDetail "Error: $Output"
        } Else {
            # 出力が空の場合のケア
            If ([string]::IsNullOrWhiteSpace($Output)) { $Output = "該当するデータが見つかりませんでした。 (Condition: LIKE '%Version%')" }
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $Output
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail "Exception: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
