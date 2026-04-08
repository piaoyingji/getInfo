# Module_Oracle.ps1
# Version: 2.3.3
# Description: Oracle 調査モジュール (SQL実行ログ出力機能付き)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    # PowerShellの出力をShift-JISに合わせる
    $OriginalEncoding = [Console]::OutputEncoding
    Try {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(932)
    } Catch {}

    Write-Host "`n$(T 'Ora_Header')" -ForegroundColor Cyan
    Write-Host (T "Ora_User") -NoNewline;   $User = Read-Host
    Write-Host (T "Ora_Pass") -NoNewline;   $Pass = Read-Host -AsSecureString
    Write-Host (T "Ora_Inst") -NoNewline;   $Instance = Read-Host
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "ユーザー名または接続先が空です。調査をスキップします。" -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $TargetTable = "CS_PROPERTY_CNF"
    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # --- 1. メタデータ探索 (SQLログ用) ---
    $MetaSql = "SET HEAD OFF`nSET FEEDBACK OFF`nSELECT OWNER FROM ALL_TABLES WHERE UPPER(TABLE_NAME) = '$TargetTable' AND ROWNUM = 1;`nEXIT;"
    $MetaSql | Set-Content -Path $TmpSql -Encoding ASCII
    
    $Owner = ""
    Try {
        $Owner = (sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql").Trim()
    } Catch {}

    $FinalTable = $TargetTable
    If (-not [string]::IsNullOrWhiteSpace($Owner) -and $Owner -notlike "*ORA-*" -and $Owner -notlike "*SP2-*") {
        $FinalTable = "$($Owner).$TargetTable"
        Write-Host "[Info] 自動検知されたテーブル: $FinalTable" -ForegroundColor Cyan
    }

    # --- 2. メインクエリ実行 ---
    # レイアウトを排除した純粋なクエリ (原因特定のため)
    $MainSql = @"
SET FEEDBACK OFF
SET HEADING ON
SET PAGESIZE 100
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $FinalTable;
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    # 実行ログの構築
    $LogDetail = "--- SQL Execution Log ---`n"
    $LogDetail += "Metadata Search SQL:`n$MetaSql`n"
    $LogDetail += "Detected Owner: $Owner`n"
    $LogDetail += "Final Script to Execute:`n$MainSql`n"
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
        $LogDetail += "PowerShell Exception: $($_.Exception.Message)"
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $LogDetail
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
