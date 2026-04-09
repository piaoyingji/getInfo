# Investigation Report

- **Start Time**: 2026-04-09 16:36:58


## Oracle Database
- **結果概略**: 取得完了
### 詳細情報
#### Oracle ログイン情報
| Item | Value |
| :--- | :--- |
| User | UHR |
| Password | UHR |
| SID/Service | 192.168.22.124:1521/UHR2 |

#### Oracle DB バージョン
> Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production

#### システム設定表 (System.Object[])
| CS_ID        | CS_CCUSTOMERID | CS_CPROPERTYNAME    | CS_CPROPERTYVALUE     | CS_CPROPERTYDESC          |
| :----------- | :------------- | :------------------ | :-------------------- | :------------------------ |
| CS_CCATEGORY | CS             | CS_CMODIFIERUSERID  | CS_DMODI              | VERSIONNO                 |
| 1000000159   | 00             | Version             | 2,3,1,8               | HGSEALEDのバ-ジョン            |
| hgsealed     | 0              | BAT                 | 15-04-17              | 1                         |
| 1000000016   | 00             | FrameVersion        | 4.18.4                | SmartCompanyフレームのバージョン    |
|              | 1              | BAT                 | 24-07-02              | 1                         |
| 201          | 01             | UhrSalary_Version   | 2.11                  | U-PDS HR Web給与明細システムバージョン |
| uhr_salary   | 0              | SALARY_v2.11        | 24-07-02              | 0                         |
| 202          | 01             | UhrCore_Version     | 2.11                  | U-PDS HR コアシステムバージョン      |
| uhr          | 0              | COMMON_v2.11        | 24-07-02              | 0                         |
| 271          | 01             | UhrShoteate_Version | 2.11+genkyo2.11       | U-PDS HR 諸手当申請システムバージョン   |
| uhr_shote    | 0              | GENKYO_v2.11        | 24-07-02              | 0                         |
| 262          | 01             | UhrNencho_Version   | 2.11.4+reigetsu2.11.4 | U-PDS HR 年末調整申請システムバージョン  |
| uhr_nencho   | 0              | REIGETSU_v2.11.4    | 25-09-18              | 6                         |
| 351          | 01             | UhrShinjo_Version   | 2.9                   | U-PDS HR 身上調書システムバージョン    |
| uhr_shinjo   | 0              | INIT                | 22-05-02              | 1                         |


#### データベース文字コード (NLS_CHARACTERSET)
> JA16SJIS

#### ディレクトリ情報 (ALL_DIRECTORIES)
| OWNER | NAME                     | PATH                                                   |
| :---- | :----------------------- | :----------------------------------------------------- |
| SYS   | MST_CSV_DIR              | C:\project\demo\data\mst                               |
| SYS   | TRX_CSV_DIR              | C:\project\demo\data\trx                               |
| SYS   | TEMP_OUTPUT_DIR          | C:\temp\MASTER_DATA                                    |
| SYS   | DIR_DATAIMPORT           | C:\app\oracle\admin\UHR2\DIR_DATAIMPORT                |
| SYS   | DIR_UHR_IF               | C:\app\oracle\admin\UHR2\DIR_UHR_IF                    |
| SYS   | ORACLECLRDIR             | C:\app\oracle\product\19.0.0\dbhome_1\bin\clr          |
| SYS   | SDO_DIR_WORK             |                                                        |
| SYS   | SDO_DIR_ADMIN            | C:\app\oracle\product\19.0.0\dbhome_1/md/admin         |
| SYS   | XMLDIR                   | C:\app\oracle\product\19.0.0\dbhome_1\rdbms\xml        |
| SYS   | XSDDIR                   | C:\app\oracle\product\19.0.0\dbhome_1\rdbms\xml\schema |
| SYS   | OPATCH_INST_DIR          | C:\app\oracle\product\19.0.0\dbhome_1\OPatch           |
| SYS   | ORACLE_OCM_CONFIG_DIR2   | C:\app\oracle\product\19.0.0\dbhome_1\ccr\state        |
| SYS   | ORACLE_BASE              | C:\app\oracle                                          |
| SYS   | ORACLE_HOME              | C:\app\oracle\product\19.0.0\dbhome_1                  |
| SYS   | ORACLE_OCM_CONFIG_DIR    | C:\app\oracle\product\19.0.0\dbhome_1\ccr\state        |
| SYS   | DATA_PUMP_DIR            | C:\app\oracle\admin\uhr2\dpdump/                       |
| SYS   | OPATCH_SCRIPT_DIR        | C:\app\oracle\product\19.0.0\dbhome_1\QOpatch          |
| SYS   | OPATCH_LOG_DIR           | C:\app\oracle\product\19.0.0\dbhome_1\rdbms\log        |
| SYS   | JAVA$JOX$CUJS$DIRECTORY$ | C:\APP\ORACLE\PRODUCT\19.0.0\DBHOME_1\JAVAVM\ADMIN\    |


#### メモリ使用状況・設定
| PARAMETER            | VALUE      |
| :------------------- | :--------- |
| sga_target           | 2147483648 |
| memory_target        | 0          |
| pga_aggregate_target | 1932525568 |


