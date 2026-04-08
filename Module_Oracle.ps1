# Module_Oracle.ps1
# Version: 2.2.0
# Description: Oracle 調査モジュール (ORA-00942 対策: スキーマ指定 + 自動Owner検知)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    Write-Host "`n$(T 'Ora_Header')" -ForegroundColor Cyan
    
    # 入力プロンプト
    Write-Host (T "Ora_User") -NoNewline;   $User = Read-Host
    Write-Host (T "Ora_Pass") -NoNewline;   $Pass = Read-Host -AsSecureString
    Write-Host (T "Ora_Inst") -NoNewline;   $Instance = Read-Host
    Write-Host (T "Ora_Schema") -NoNewline; $InputSchema = Read-Host
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "ユーザー名または接続先が空です。調査をスキップします。" -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # 実際に使用するテーブル名の決定
    $TargetTable = "CS_PROPERTY_CNF"
    If (-not [string]::IsNullOrWhiteSpace($InputSchema)) {
        $FullTableName = "$($InputSchema.ToUpper()).$TargetTable"
    } Else {
        $FullTableName = $TargetTable
    }

    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # 1. メインクエリの実行
    $SqlScript = @"
SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
COLUMN CS_CPROPERTYNAME FORMAT A30
COLUMN CS_CPROPERTYVALUE FORMAT A40
COLUMN CS_CPROPERTYDESC FORMAT A50
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM $FullTableName;
EXIT;
"@
    
    Try {
        $Output = $SqlScript | sqlplus -S "${User}/${UnsecurePass}@${Instance}"
        
        # ORA-00942 (表が存在しない) が発生した場合のリカバリロジック
        If ($Output -like "*ORA-00942*") {
            Write-Host "[Alert] $FullTableName が見つかりません。Ownerを自動探索します..." -ForegroundColor Yellow
            
            # ALL_TABLES からテーブルの所有者を検索するクエリ
            $FindOwnerSql = "SET HEAD OFF`nSELECT OWNER FROM ALL_TABLES WHERE TABLE_NAME = '$TargetTable' AND ROWNUM = 1;`nEXIT;"
            $OwnerResult = ($FindOwnerSql | sqlplus -S "${User}/${UnsecurePass}@${Instance}").Trim()
            
            If (-not [string]::IsNullOrWhiteSpace($OwnerResult) -and $OwnerResult -notlike "*ORA-*") {
                Write-Host "[Tips] テーブルはスキーマ '$OwnerResult' に存在することを確認しました。" -ForegroundColor Cyan
                Write-Host "[Action] '$OwnerResult.$TargetTable' で再試行します..." -ForegroundColor Gray
                
                $RetrySql = $SqlScript -replace "FROM $FullTableName", "FROM $OwnerResult.$TargetTable"
                $Output = $RetrySql | sqlplus -S "${User}/${UnsecurePass}@${Instance}"
            }
        }

        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "エラー発生" -FullDetail "Error: $Output"
        } Else {
            Log-Info -Title "Oracle Database" -ShortResult "データ取得完了" -FullDetail $Output
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $_.Exception.Message
    }
}
