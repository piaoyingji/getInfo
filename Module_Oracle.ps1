# Module_Oracle.ps1
# Version: 2.3.0
# Description: Oracle 調査モジュール (ORA-00942 対策: サイレント・自動Recovery版)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    Write-Host "`n$(T 'Ora_Header')" -ForegroundColor Cyan
    
    # 入力プロンプト (スキーマ名入力を廃止し、以前のシンプルさに戻す)
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
    $CurrentTableToQuery = $TargetTable

    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # SQLの実行用スクリプト作成関数
    Function Run-Sql {
        Param([String]$Sql)
        $Script = @"
SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
COLUMN CS_CPROPERTYNAME FORMAT A30
COLUMN CS_CPROPERTYVALUE FORMAT A40
COLUMN CS_CPROPERTYDESC FORMAT A50
$Sql
EXIT;
"@
        return $Script | sqlplus -S "${User}/${UnsecurePass}@${Instance}"
    }

    Try {
        # 1. まずは通常のクエリを試行
        $Result = Run-Sql "SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $CurrentTableToQuery;"
        
        # ORA-00942 (表が存在しない) が発生した場合の自動リカバリ
        If ($Result -like "*ORA-00942*") {
            Write-Host "[Info] テーブルが見つからないため、所有者を自動探索中..." -ForegroundColor Yellow
            
            # ALL_TABLES から所有者を特定
            $OwnerQuery = "SET HEAD OFF`nSELECT OWNER FROM ALL_TABLES WHERE TABLE_NAME = '$TargetTable' AND ROWNUM = 1;`nEXIT;"
            $Owner = ($OwnerQuery | sqlplus -S "${User}/${UnsecurePass}@${Instance}").Trim()
            
            If (-not [string]::IsNullOrWhiteSpace($Owner) -and $Owner -notlike "*ORA-*") {
                Write-Host "[Auto-Fix] 所有者 '$Owner' を検出しました。再試行します。" -ForegroundColor Cyan
                $CurrentTableToQuery = "$Owner.$TargetTable"
                $Result = Run-Sql "SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $CurrentTableToQuery;"
            }
        }

        If ($Result -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "エラー発生" -FullDetail "Error: $Result"
        } Else {
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $Result
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $_.Exception.Message
    }
}
