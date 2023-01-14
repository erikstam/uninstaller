privilegesdemoter)
      appTitle="Privileges Demoter"
      # IBM Notifier is also installed. If running this has to be quited
      appProcesses+=("IBM Notifier")
      appFiles+=("/Applications/IBM Notifier.app")
      appFiles+=("/private/etc/newsyslog.d/blog.mostlymac.PrivilegesDemoter.conf")
      appFiles+=("/usr/local/mostlymac/")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.check.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.demote.plist")
      ;;
