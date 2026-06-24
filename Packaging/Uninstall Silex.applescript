set promptText to "Remove Silex and all data?

移除 Silex 及所有数据？"
set answer to display dialog promptText buttons {"Cancel", "Uninstall"} default button "Uninstall" cancel button "Cancel" with icon caution

if button returned of answer is "Uninstall" then
    set uninstallCommand to "/bin/launchctl bootout system/com.anon233.Silex.Daemon >/dev/null 2>&1 || true; /bin/rm -f /Library/LaunchDaemons/com.anon233.Silex.Daemon.plist; /bin/rm -rf /Library/PrivilegedHelperTools/SilexDaemon.app; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.smartctl; /bin/rm -rf /Applications/Silex.app; /usr/sbin/pkgutil --forget com.anon233.Silex.pkg >/dev/null 2>&1 || true"
    set removeDataCommand to "/bin/rm -rf ~/Library/Application\\ Support/Silex"
    do shell script uninstallCommand with administrator privileges
    do shell script removeDataCommand
    display dialog "Silex and all data were removed.

Silex 及所有数据已移除。" buttons {"OK"} default button "OK"
end if
