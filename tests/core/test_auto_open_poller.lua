local Poller = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.Poller")
local Flavor = require("tests.helpers.flavor")

local function makeEditBox()
  local box = { text = "", scripts = {}, attributes = { chatType = "SAY", stickyType = "SAY" } }
  function box:GetText()
    return self.text
  end
  function box:SetText(text)
    self.text = text
  end
  function box:GetAttribute(key)
    return self.attributes[key]
  end
  function box:SetAttribute(key, value)
    self.attributes[key] = value
  end
  function box:HookScript(scriptName, handler)
    self.scripts[scriptName] = handler
  end
  function box:Hide() end
  return box
end

-- Installs the poller on one chat edit box and returns a typer that sets the
-- box text as user input, plus the list of names routed to onSendTell.
local function installPoller()
  local editBox = makeEditBox()
  local sendTellCalls = {}
  local hooks = {
    onSendTell = function(target)
      table.insert(sendTellCalls, target)
      return true
    end,
  }
  local deps = {
    isSuspended = function()
      return false
    end,
    getNumChatWindows = function()
      return 1
    end,
    getEditBox = function()
      return editBox
    end,
    deactivateChat = function() end,
  }
  Poller.Install({}, hooks, deps)

  local function typeText(text)
    editBox.text = text
    editBox.scripts.OnTextChanged(editBox, true)
  end
  return typeText, sendTellCalls
end

return function()
  -- test_forever_slash_whisper_waits_for_last_name
  -- WoW: Forever characters have two names ("John Doe"). The space after the
  -- first name is part of the target, so `/w John ` must stay in default chat.
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John ")
    typeText("/w John D")
    assert(#sendTellCalls == 0, "expected '/w John ' not to route on Forever, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_routes_full_two_part_name
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w John Doe ")
    assert(sendTellCalls[1] == "John Doe", "expected full Forever name routed, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_forever_slash_whisper_keeps_battletag_one_word
  -- A BattleTag ("Name#1234") is a whole target on its own; the next word is
  -- the message, not a last name.
  Flavor.With(false, true, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w Artiom#1234 ")
    assert(sendTellCalls[1] == "Artiom#1234", "expected BattleTag routed alone on Forever, got " .. tostring(sendTellCalls[1]))
  end)

  -- test_retail_slash_whisper_routes_after_first_space
  Flavor.With(true, false, function()
    local typeText, sendTellCalls = installPoller()
    typeText("/w Thrall ")
    assert(sendTellCalls[1] == "Thrall", "expected one-word name routed on Retail, got " .. tostring(sendTellCalls[1]))
  end)
end
