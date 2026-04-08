# Module_Oracle.ps1
# Version: 2.3.1
# Description: Oracle 調査モジュール (文字化け・バインド変数エラー対策済 安定版)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    # PowerShellの出力を一時的にShift-JISに合わせる(sqlplusの日本語出力を正しく受け取るため)
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

    $TargetTable = "CS_PROPERTY_CNF"
    $TmpSql = Join-Path $env:TEMP "invest_ora.sql"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # 所有者を事前にチェックするクエリ
    $CheckSql = "SET HEAD OFF`nSET FEEDBACK OFF`nSELECT OWNER FROM ALL_TABLES WHERE TABLE_NAME = '$TargetTable' AND ROWNUM = 1;`nEXIT;"
    $CheckSql | Set-Content -Path $TmpSql -Encoding ASCII
    
    $Owner = ""
    Try {
        $Owner = (sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql").Trim()
    } Catch {}

    # 最終的なテーブル名を決定 (Ownerが見つかればプレフィックスを付ける)
    $FinalTable = $TargetTable
    If (-not [string]::IsNullOrWhiteSpace($Owner) -and $Owner -notlike "*ORA-*" -and $Owner -notlike "*SP2-*") {
        $FinalTable = "$($Owner).$TargetTable"
        Write-Host "[Info] 所有者 '$Owner' を自動検知しました。" -ForegroundColor Gray
    }

    # メインクエリの作成
    $MainSql = @"
SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
COLUMN CS_CPROPERTYNAME FORMAT A30
COLUMN CS_CPROPERTYVALUE FORMAT A40
COLUMN CS_CPROPERTYDESC FORMAT A50
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $FinalTable;
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "エラー発生" -FullDetail "Error: $Output"
        } Else {
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $Output
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $_.Exception.Message
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        # エンコーディングを元に戻す
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
