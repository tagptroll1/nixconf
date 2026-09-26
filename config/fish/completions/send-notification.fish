complete -c send-notification -f
complete -c send-notification -s i -l icon -r -F -a '(send-notification --list-icons)' -d 'Lucide name or image path'
complete -c send-notification -l type -x -a 'info warning error' -d 'Notification type'
complete -c send-notification -s t -l expire-time -x -d 'Timeout in milliseconds'
complete -c send-notification -l list-icons -d 'List shared Lucide icons'
complete -c send-notification -s h -l help -d 'Show help'
