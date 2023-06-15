
-- Open Debug -> "Attach to Process by PID or Name…", enter "com.duckduckgo.m" and choose Attach as "root" and click Attach

on run argv
  -- "com.duckduckgo.m"
  set processName to item 1 of argv

  tell application "System Events"
    tell process "Xcode"
      set frontmost to true

      tell menu bar 1 to tell menu bar item "Debug"
        -- detach first
        try
          click menu item ("Detach from " & processName) of menu "Debug"
        on error
        end try

        click menu item "Attach to Process by PID or Name…" of menu "Debug"
      end tell

      repeat with i from 1 to 5

        if exists (sheet 1 of window 1) then
          tell sheet 1 of window 1

            -- click the Attach as "root" radio button
            set radioGroup to first radio group
            if value of (radio button "root" of radioGroup) is 0 then
              click radio button "root" of radioGroup
            end if

            -- enter the process name
            set textField to first text field
            set value of textField to processName

            -- click Attach
            set attachButton to button "Attach"
            click attachButton

            return
          end tell
        end if
        delay 0.5

      end repeat

      log "Attach to Process sheet not found"
    end tell

  end tell

end run


