-- The AddOns list shows the TOC title, so it must carry the spaced name.
return function()
  -- test_toc_title_is_spaced_addon_name
  do
    local title = nil
    for line in io.lines("WhisperMessenger.toc") do
      title = title or string.match(line, "^## Title: (.-)%s*$")
    end
    assert(title == "Whisper Messenger", "TOC title should be Whisper Messenger, got: " .. tostring(title))
  end
end
