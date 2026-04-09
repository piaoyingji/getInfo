# Module_Oracle.ps1
# Version: 4.0.0
# Description: Oracle 調査モジュール (v4.0.0 Markdown テーブル出力対応版)

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

    # Markdown テーブルとバージョン取得のための SQL
    $TargetTable = "${User}.CONF_SYSCONTROL"
    
    $MainSql = @"
SET PAGESIZE 1000
SET FEEDBACK OFF
SET HEADING ON
SET LINESIZE 1000
SET TERMOUT ON
SET ECHO OFF
SET VERIFY OFF
SET TRIMSPOOL ON
SET COLSEP ' | '
SET UNDERLINE OFF

PROMPT [VERSION_START]
SELECT BANNER FROM V`$VERSION;
PROMPT [VERSION_END]

PROMPT [DATA_START]
COLUMN PROPERTY_NAME FORMAT A30
COLUMN VALUE         FORMAT A30
COLUMN DESCRIPTION   FORMAT A60

SELECT 
    CS_CPROPERTYNAME  AS PROPERTY_NAME, 
    CS_CPROPERTYVALUE AS VALUE, 
    CS_CPROPERTYDESC  AS DESCRIPTION
FROM $TargetTable 
WHERE CS_CPROPERTYNAME LIKE '%Version%';
PROMPT [DATA_END]
EXIT;
"@
    $MainSql | Set-Content -Path $TmpSql -Encoding ASCII

    Try {
        $RawOutput = sqlplus -S "${User}/${UnsecurePass}@${Instance}" "@$TmpSql"
        $OutputStr = $RawOutput -join "`r`n"

        # バージョン情報の抽出
        $OraVer = "取得失敗"
        If ($OutputStr -match "\[VERSION_START\]`r`n(.*?)`r`n\[VERSION_END\]") {
            $OraVer = $Matches[1].Trim()
        }

        # データの抽出と Markdown テーブル変換
        $MDTable = ""
        If ($OutputStr -match "\[DATA_START\]`r`n(.*?)`r`n\[DATA_END\]") {
            $DataBlock = $Matches[1].Trim()
            $Lines = $DataBlock -split "`r`n" | Where-Object { $_.Trim() -ne "" }
            
            If ($Lines.Count -ge 1) {
                # 1行目はヘッダー
                $Header = "| " + ($Lines[0].Trim() -replace '\s+\|\s+', ' | ') + " |"
                $MDTable += $Header + "`r`n"
                # セパレーターを挿入 (3列固定)
                $MDTable += "| :--- | :--- | :--- |`r`n"
                # 2行目以降がデータ
                For ($i = 1; $i -lt $Lines.Count; $i++) {
                    $MDTable += "| " + ($Lines[$i].Trim() -replace '\s+\|\s+', ' | ') + " |`r`n"
                }
            }
        }

        If ([string]::IsNullOrWhiteSpace($MDTable)) { $MDTable = "該当データなし" }

        # Markdown 用の整形
        $FinalMD = "#### Oracle DB バージョン`n"
        $FinalMD += "> $OraVer`n`n"
        $FinalMD += "#### システム設定表 ($TargetTable)`n"
        $FinalMD += $MDTable

        Log-Info -Title "Oracle Database" -ShortResult "取得完了" -FullDetail $FinalMD

    } Catch {
        Log-Info -Title "Oracle Database" -ShortResult "例外発生" -FullDetail "Msg: $($_.Exception.Message)"
    } Finally {
        If (Test-Path $TmpSql) { Remove-Item $TmpSql }
        [Console]::OutputEncoding = $OriginalEncoding
    }
}
