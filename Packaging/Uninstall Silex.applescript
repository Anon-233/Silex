set promptText to "Remove Silex and its privileged SMART service?

移除 Silex 及其特权 SMART 服务？"
set answer to display dialog promptText buttons {"Cancel", "Uninstall"} default button "Uninstall" cancel button "Cancel" with icon caution

if button returned of answer is "Uninstall" then
    set uninstallCommand to "/bin/launchctl bootout system/com.anon233.Silex.SMARTService >/dev/null 2>&1 || true; /bin/launchctl bootout system/com.anon233.Silex.Daemon >/dev/null 2>&1 || true; /bin/rm -f /Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist; /bin/rm -f /Library/LaunchDaemons/com.anon233.Silex.Daemon.plist; /bin/rm -rf /Library/PrivilegedHelperTools/SilexSMARTService.app; /bin/rm -rf /Library/PrivilegedHelperTools/SilexDaemon.app; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.Daemon; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.smartctl; /bin/rm -rf /Applications/Silex.app; /usr/sbin/pkgutil --forget com.anon233.Silex.pkg >/dev/null 2>&1 || true"
    do shell script uninstallCommand with administrator privileges
    display dialog "Silex was removed. History remains in ~/Library/Application Support/Silex.

Silex 已移除。历史数据仍保留在 ~/Library/Application Support/Silex。" buttons {"OK"} default button "OK"
end if
