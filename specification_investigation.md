# 服务器一键调查脚本需求说明书

## 1. 目的
本文件旨在定义一个用于 AP 服务器（Windows 环境）的一键调查脚本。该脚本将自动收集中间件、证书及数据库的相关信息，并生成一份文本格式的调查报告。

## 2. 调查项及详细要求

### 2.1 中间件调查 (AP Server)
- **Apache HTTP Server**: 
    - 获取 Apache 的版本号（默认路径：`D:\` 盘相关目录）。
    - 检查是否启用了 SSL 证书。
    - 如果启用了 SSL：
        - 调查证书对应的域名 (Common Name / SAN)。
        - 调查证书的到期日期。
        - 调查“シナリオ番号”（场景编号，作为非必要项）。
- **Apache Tomcat**:
    - 获取 Tomcat 的版本号（默认路径：`D:\` 盘相关目录）。
    - 统计 Tomcat 上部署的环境数量（Webapps 下的应用数或配置文件中的 Context 数）。

### 2.2 数据库调查 (DB Server)
- **DB 类型与版本**: 
    - **当前仅限 Oracle**。
    - 记录数据库的产品版本。
- **系统环境内部版本 (SQL 查询)**: 
    - 执行以下查询语句：
      ```sql
      SELECT CS_CPROPERTYNAME, CS_CPROPERTYVALUE, CS_CPROPERTYDESC 
      FROM UHR.CONF_SYSCONTROL 
      WHERE CS_CPROPERTYNAME LIKE '%Version%'
      ```
    - 脚本需处理连接至远程 DB Server 的情况（可能需要输入 DB Server IP）。

## 3. 技术限制与实施方案

### 3.1 脚本架构
- **模块化设计**: 脚本将分为多个独立文件，而不是一个庞大的单一脚本。
    - `Main_Menu.ps1`: 主程序入口，提供子母菜单导航。
    - `Module_Apache.ps1`: Apache 专项调查脚本。
    - `Module_Tomcat.ps1`: Tomcat 专项调查脚本。
    - `Module_Oracle.ps1`: Oracle 专项调查脚本。
    - `Module_Utils.ps1`: 公用工具（如报告生成、路径搜索）。
- **启动初始化**: 在显示主菜单前，脚本将提示用户输入 **报告文件名**，并以此作为本次调查的全量记录文件。
- **稳定性与异常处理**:
    - **防止闪退**: 主脚本采用 `try...catch` 结构，在发生严重错误时会显示报错信息并暂停，防止窗口无故关闭。
    - **路径动态解析**: 使用稳健方式获取脚本目录，确保子模块加载成功。
- **兼容性要求**: 主要使用 **PowerShell 5.0 或更低版本**。

### 3.2 自动化逻辑
1. **子母菜单导航**: 用户通过主菜单选择要调查的项（如：全部调查、仅调查 Apache 等）。
2. **优先路径**: 重点扫描 **D 盘**。
3. **交互式 Oracle 连接**: 通过子菜单进入 Oracle 调查时，提示输入凭据。

## 4. 详细实施方案

### 4.1 Apache 调查逻辑
- **版本获取**: 
    - 运行 `httpd.exe -v`。
    - 若无法运行，解析 `CHANGES.txt`, `README.txt` 或 `VER.txt`。
- **SSL 证书解析**: 
    - 扫描 `httpd.conf` 或 `extra/httpd-ssl.conf` 中的 `SSLCertificateFile` 关键字。
    - 使用 PowerShell 的 `.NET` 类库 `[System.Security.Cryptography.X509Certificates.X509Certificate2]` 加载证书。
    - 提取 **域名 (Subject)** 和 **有效期 (NotAfter)**。

### 4.2 Tomcat 调查逻辑
- **版本获取**: 
    - 调用 `bin/version.bat` 并提取 `Server version` 行。
    - 若无 bat，解析 `lib/catalina.jar` 中的版本信息。
- **环境统计**: 
    - 统计 `webapps` 下非默认目录的数量。
    - 结合 `conf/server.xml` 中的 `<Host>` 和 `<Context>` 配置综合确认。

### 4.3 数据库 (Oracle) 调查逻辑
- **连接方式**: 
    - 确认为通过 **Oracle Client (sqlplus)** 连接。
- **交互要求**: 
    - 脚本运行时需提示用户输入 **用户名 (Username)**、**密码 (Password)** 以及 **实例/SID (Instance)**。
- **业务查询**: 
    - 查询 `UHR.CONF_SYSCONTROL` 表获取系统版本。
    - 结果以格式化表格形式输出到报告中。

## 5. 输出结果
- **文件名**: `Investigation_Report.txt`
- **格式**: 纯文本报表。

## 6. 核心逻辑确认
- [x] **Oracle 连接**: 使用 sqlplus，支持交互式输入凭据。
- [x] **安装路径**: 默认 D 盘搜索。
- [x] **版本调查**: Apache/Tomcat 自动版本识别。
- [x] **业务 SQL**: 
  ```sql
  SELECT * FROM UHR.CONF_SYSCONTROL WHERE CS_CPROPERTYNAME LIKE '%Version%'
  ```

## 7. 待办项进度
- [x] 确认数据库类型 (Oracle) 与连接方式。
- [x] 完善说明文档。
- [ ] 编写符合 PS 5.0 的 `Investigate-AP-Server.ps1` 脚本。
