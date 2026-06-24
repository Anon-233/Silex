Silex Personal Installer / Silex 个人安装包
================================================

English
-------
1. Double-click “Install Silex.pkg”.
2. macOS Installer requests administrator authorization. Touch ID may be
   offered when macOS permits it; otherwise enter an administrator password.
3. Launch Silex from /Applications after installation.

Installing a newer package updates the existing /Applications/Silex.app and
daemon in place. It does not create another copy. Uninstalling removes all data.

Silex has no updater, telemetry, download, or other network feature.

Daemon visibility and control:

    System Settings > General > Login Items & Extensions > Allow in Background
    launchctl print system/com.anon233.Silex.Daemon

Disabling the background item stops new collection. Silex can still open
and display existing history. Console.app logs use subsystem
com.anon233.Silex.

“Uninstall Silex.app” removes the app, system service, and all user data
after administrator authorization.

简体中文
--------
1. 双击“Install Silex.pkg”。
2. macOS 安装器会请求管理员授权。系统允许时可使用 Touch ID，否则需要输入
   管理员密码。
3. 安装完成后，从“应用程序”目录启动 Silex。

安装新版本会原位更新 /Applications/Silex.app 和后台服务，不会生成多个
同名应用。卸载会移除所有数据。

Silex 不包含自动更新、遥测、下载或其他网络功能。

守护进程可见性与控制位置：

    系统设置 > 通用 > 登录项与扩展 > 允许在后台
    launchctl print system/com.anon233.Silex.Daemon

禁用后台项目后将停止新的采集，但仍可打开 Silex 查看已有历史。
Console.app 日志子系统为 com.anon233.Silex。

“Uninstall Silex.app”会在管理员授权后移除应用、系统服务及所有用户数据。
