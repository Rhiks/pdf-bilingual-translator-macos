on run
    set appBundle to POSIX path of (path to me)
    set launcherPath to appBundle & "Contents/Resources/start-webui.sh"
    do shell script "/bin/zsh " & quoted form of launcherPath & " >/dev/null 2>&1 &"
end run
