local EditBoxInterop = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")

local function makeEditBox(attributes)
  return {
    GetAttribute = function(_self, key)
      return attributes[key]
    end,
    SetAttribute = function(_self, key, value)
      attributes[key] = value
    end,
    GetText = function()
      return ""
    end,
    SetText = function() end,
    Hide = function() end,
  }
end

return function()
  -- test_close_edit_box_resets_whisper_sticky_after_messenger_takes_over
  --
  -- A whisper actually sent through Blizzard chat (e.g. /r while the addon
  -- was suspended in M+) leaves stickyType=WHISPER. Once the messenger has
  -- taken the whisper over, keeping that sticky means every later Enter
  -- re-opens the messenger and the user can never reach Say/General.
  do
    local attributes = { chatType = "WHISPER", stickyType = "WHISPER", tellTarget = "Jaina" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "SAY", "whisper sticky must reset chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "whisper sticky must reset stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(attributes.tellTarget == nil, "whisper sticky must clear tellTarget")
  end

  -- test_close_edit_box_resets_bnet_whisper_sticky_after_messenger_takes_over
  do
    local attributes = { chatType = "BN_WHISPER", stickyType = "BN_WHISPER", tellTarget = "Friend#1234" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "SAY", "BN whisper sticky must reset chatType to SAY, got " .. tostring(attributes.chatType))
    assert(attributes.stickyType == "SAY", "BN whisper sticky must reset stickyType to SAY, got " .. tostring(attributes.stickyType))
    assert(attributes.tellTarget == nil, "BN whisper sticky must clear tellTarget")
  end

  -- test_close_edit_box_keeps_non_whisper_sticky_untouched
  do
    local attributes = { chatType = "WHISPER", stickyType = "PARTY", tellTarget = "Jaina" }
    EditBoxInterop.closeEditBox({}, makeEditBox(attributes), nil)
    assert(attributes.chatType == "PARTY", "non-whisper sticky must restore chatType to sticky")
    assert(attributes.stickyType == "PARTY", "non-whisper sticky must stay as-is")
    assert(attributes.tellTarget == nil, "non-whisper sticky must clear tellTarget")
  end
end
