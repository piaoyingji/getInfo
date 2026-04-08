# Module_Oracle.ps1
# Version: 3.3.0
# Description: Oracle 調査モジュール (垂直整列・改行強化版 v3.3.0)

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

    $TmpSql = Join-Path $env:TEMP "invest_ora.sq"
    
    Write-Host "`n$(T 'Ora_Connect')" -ForegroundColor Gray

    # ご指定のテーブル: {ユーザー名}.CONF_SYSCONTROL
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    # 改行と整列を重視したSQL
    # RPADで項目名(NAME, VALUE, DESC)を6文字に固定し、コロンを揃えます
    # CHR(13)||CHR(10) でWindows標準の改行コードを挿入します
    $MainSql = @"
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET TERMOUT ON
SET ECHO OFF
SET VERIFY OFF
SET LINESIZE 2000
SELECT 
RPAD('NAME', 6)  || ': ' || NVL(CS_CPROPERTYNAME, ' ') || CHR(13) || CHR(10) ||
RPAD('VALUE', 6) || ': ' || NVL(CS_CPROPERTYVALUE, ' ') || CHR(13) || CHR(10) ||
RPAD('DESC', 6)  || ': ' || NVL(CS_CPROPERTYDESC, ' ') || CHR(13) || CHR(10) ||
'------------------------------------------------------------'
FROM $TargetTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
EXIT;
"@
    # ASCII保存 + 一時ファイル実行で安定動作を確保
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        # ご要望通り実行時のSQL文をログに含めます
        $LogContent = "Executed SQL:`n$MainSql`n`nResults:`n"

        $Output = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        
        If ($Output -like "*ORA-*") {
            Log-Info -Title "Oracle Database" -ShortResult "エラー" -FullDetail ($LogContent + $Output)
        } Else {
            $CleanOutput = $Output.Trim()
            If ([string]::IsNullOrWhiteSpace($CleanOutput)) { $CleanOutput = "該当データなし" }
            Log-Info -Title "Oracle Database" -ShortResult "成功" -FullDetail ($LogContent + $CleanOutput)
        }
    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "実行時例外" -FullDetail "Msg: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
