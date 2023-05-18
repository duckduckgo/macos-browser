
-- find and click "Continue" in the
--   "The application “DuckDuckGo Network Protection.app” is hosting system extensions. These extensions will be removed if you continue." 
-- dialog

on run argv
  -- DuckDuckGo Network Protection.app
  set appName to item 1 of argv

  delay 1
  tell application "System Events"

    -- get localized name of the Trash
    set trashName to displayed name of trash of application "Finder"

    tell process "Finder"
      -- list windows
      set windowList to windows
      repeat with aWindow in windowList
        set windowName to name of aWindow
        log "finder_conform_dialog: inspecting " & windowName

        -- the dialog should have "Trash" title
        if windowName is trashName then

          -- descend into window -> scroll area 
          if exists (scroll area 1) of aWindow then
            tell (scroll area 1) of aWindow
              -- message text should contain the App name
              set message to static text 1
              set messageText to name of message
              if messageText contains appName then

                -- click Continue button
                set continueButton to button 2
                log "click " & (name of continueButton)
                click continueButton

                exit repeat

              else
                log "message text \"" & messageText & "\" does not contain \"" & appName & "\""
              end if
            end tell

          else
            log "scroll area not found"
          end if
        end if
      end repeat

      -- now an error message should appear: also hide it
      repeat with i from 1 to 20
        delay 0.5
        -- list windows
        set windowList to windows
        repeat with aWindow in windowList
          set windowName to name of aWindow
          log "finder_conform_dialog: inspecting " & windowName

          -- the dialog should have "Trash" title
          if windowName is trashName then

            -- descend into window -> scroll area 
            if exists (scroll area 1) of aWindow then
              tell (scroll area 1) of aWindow
                set message to static text 1
                set messageText to name of message

                -- if message text contains the App name - this is the progress dialog
                if not messageText contains appName then
                  set dialogButtons to buttons
                  if count of buttons is 1 then
                    log "click OK"
                    click button 1
                    return
                  end if
                end if
              end tell

            else
              log "scroll area not found"
            end if
          end if
        end repeat
        
      end repeat
    end tell
  end tell
end run