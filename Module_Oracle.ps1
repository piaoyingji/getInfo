# Module_Oracle.ps1
# Version: 3.2.0
# Description: Oracle 調査モジュール (出力バグ修正・NVL対応 v3.2.0)

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
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    # SQL設定修正: TERMOUT ON にして出力を有効化
    # また、NVLを使用してNULLによる結合消失を防止
    $MainSql = @"
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET TERMOUT ON
SET ECHO OFF
SET VERIFY OFF
SET LINESIZE 1000
SELECT 
'NAME  : ' || NVL(CS_CPROPERTYNAME, ' ') || CHR(10) ||
'VALUE : ' || NVL(CS_CPROPERTYVALUE, ' ') || CHR(10) ||
'DESC  : ' || NVL(CS_CPROPERTYDESC, ' ') || CHR(10) ||
'------------------------------------------------------------'
FROM $TargetTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    # ASCIIで保存してSP2-0552エラーを防止
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Write-Host "[ERROR] Oracle実行中にエラーが発生しました。" -ForegroundColor Red
            Log-Info -Title "Oracle Database" -ShortResult "取得失敗" -FullDetail "Oracle Error: $Output"
        } Else {
            # 余分な空白行を取り除いて結果を判定
            $CleanOutput = $Output.Trim()
            If ([string]::IsNullOrWhiteSpace($CleanOutput)) { 
                $CleanOutput = "該当データなし" 
            }
            Log-Info -Title "Oracle Database" -ShortResult "完了" -FullDetail $CleanOutput
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "例外発生" -FullDetail "Msg: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
