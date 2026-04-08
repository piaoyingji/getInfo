# Module_Oracle.ps1
# Version: 2.3.2
# Description: Oracle 調査モジュール (v2.3.2 メタデータ優先検知版)

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

    $TargetBase = "CS_PROPERTY_CNF"
    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # --- ステップ1: メタデータから正確な所有者とテーブル名を取得 ---
    # CSV形式で Owner,TableName を取得する
    $MetaSql = @"
SET HEAD OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET TERMOUT OFF
SELECT OWNER || ',' || TABLE_NAME FROM ALL_TABLES WHERE UPPER(TABLE_NAME) = '$TargetBase' AND ROWNUM = 1;
EXIT;
"@
    $MetaSql | Set-Content -Path $TmpSql -Encoding ASCII
    
    $FinalFullTable = $TargetBase # デフォルト
    Try {
        $MetaRes = (sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql").Trim()
        If (-not [string]::IsNullOrWhiteSpace($MetaRes) -and $MetaRes -match "^([^,]+),([^,]+)$") {
            $Owner = $Matches[1]
            $RealName = $Matches[2]
            # 特殊文字（小文字など）対策でダブルクォーテーションで囲む
            $FinalFullTable = "`"$Owner`".`"$RealName`""
            Write-Host "[Info] テーブル検知成功: $FinalFullTable" -ForegroundColor Cyan
        } Else {
            Write-Host "[Warn] メタデータからテーブルが見つかりませんでした。直打ちで試行します。" -ForegroundColor Yellow
        }
    } Catch {
        Write-Host "[Error] メタデータ取得中にエラーが発生しました。" -ForegroundColor Red
    }

    # --- ステップ2: 本番クエリの実行 ---
    $MainSql = @"
SET PAGESIZE 100
SET LINESIZE 500
SET FEEDBACK OFF
SET HEADING ON
SET WRAP OFF
COLUMN CS_CPROPERTYNAME FORMAT A40
COLUMN CS_CPROPERTYVALUE FORMAT A60
COLUMN CS_CPROPERTYDESC FORMAT A60
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $FinalFullTable;
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "取得失敗" -FullDetail "Error: $Output"
        } Else {
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $Output
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $_.Exception.Message
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
