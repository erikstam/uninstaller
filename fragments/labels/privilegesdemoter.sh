privilegesdemoter)
      appTitle="Privileges Demoter"
      appFiles+=("/private/etc/newsyslog.d/blog.mostlymac.PrivilegesDemoter.conf")
      appFiles+=("/usr/local/mostlymac/")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.check.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.demote.plist")
      ;;
