# Module_Oracle.ps1
# Version: 1.8.1
# Description: Oracle 調査モジュール (日本語統一 + 2重Enter回避 + プロンプト改善)

Function Investigate-Oracle {
    Param([Boolean]$Silent = $false)
    
    # 画面3 (調査界面) のヘッダーを表示
    Write-Host "`n$(T 'Ora_Header')" -ForegroundColor Cyan
    
    # 入力プロンプト (コロンとスペースを明示)
    Write-Host (T "Ora_User") -NoNewline; $User = Read-Host
    Write-Host (T "Ora_Pass") -NoNewline; $Pass = Read-Host -AsSecureString
    Write-Host (T "Ora_Inst") -NoNewline; $Instance = Read-Host
    
    If ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Instance)) {
        Write-Host "ユーザー名または接続先が空です。調査をスキップします。" -ForegroundColor Yellow
        return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Pass)
    $UnsecurePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # SQL Plus 実行 (内部は英語ヘッダーが出る可能性があるため、出力を成形)
    $SqlScript = @"
SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
COLUMN CS_CPROPERTYNAME FORMAT A30
COLUMN CS_CPROPERTYVALUE FORMAT A40
COLUMN CS_CPROPERTYDESC FORMAT A50
SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC FROM CS_PROPERTY_CNF;
EXIT;
"@
    $TmpSql = Join-Path $env:TEMP "tmp_ora.sql"
    $SqlScript | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $Output = $SqlScript | sqlplus -S "${User}/${UnsecurePass}@${Instance}"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "接続エラー" -FullDetail "Error: $Output"
        } Else {
            # 出力結果の整形と記録
            $Summary = "データ取得完了"
            Log-Info -Title "Oracle Database" -ShortResult $Summary -FullDetail $Output
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行エラー" -FullDetail $_.Exception.Message
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
    }
}
