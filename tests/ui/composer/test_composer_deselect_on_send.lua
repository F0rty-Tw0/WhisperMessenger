local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- options.result: what onSend returns. options.getDeselectOnSend: the setting.
local function build(options)
  options = options or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local sends = { count = 0 }
  local composer = Composer.Create(factory, parent, selectedContact, function()
    sends.count = sends.count + 1
    return options.result
  end, nil, nil, nil, { getDeselectOnSend = options.getDeselectOnSend })
  return composer, sends, parent
end

local function on()
  return true
end

local function off()
  return false
end

local function pressEnter(composer, text)
  composer.input:SetFocus()
  composer.input:SetText(text)
  composer.input.scripts.OnEnterPressed(composer.input)
end

return function()
  -- test_enter_send_clears_focus
  do
    local composer = build({ getDeselectOnSend = on })
    pressEnter(composer, "hi")
    assert(composer.input._hasFocus == false, "an Enter send must clear focus when the setting is on")
  end

  -- test_send_button_clears_focus
  do
    local composer = build({ getDeselectOnSend = on })
    composer.input:SetFocus()
    composer.input:SetText("hi")
    composer.sendButton.scripts.OnClick()
    assert(composer.input._hasFocus == false, "a Send button send must clear focus when the setting is on")
  end

  -- test_send_button_without_focus_still_sends
  do
    local composer, sends = build({ getDeselectOnSend = on })
    composer.input:SetText("hi")
    composer.sendButton.scripts.OnClick()
    assert(sends.count == 1, "text in an unfocused box must still send")
  end

  -- test_rejected_send_keeps_focus_and_text
  do
    local composer = build({ getDeselectOnSend = on, result = false })
    pressEnter(composer, "hi")
    assert(composer.input._hasFocus == true, "a rejected send must keep focus")
    assert(composer.input:GetText() == "hi", "a rejected send must keep the text")
  end

  -- test_empty_text_keeps_focus
  do
    local composer, sends = build({ getDeselectOnSend = on })
    pressEnter(composer, "")
    assert(composer.input._hasFocus == true, "Enter on empty text must keep focus")
    assert(sends.count == 0, "empty text must not send")
  end

  -- test_setting_off_keeps_focus
  do
    local composer = build({ getDeselectOnSend = off })
    pressEnter(composer, "hi")
    assert(composer.input._hasFocus == true, "the setting is off: focus stays")
  end

  -- test_no_option_keeps_focus
  do
    local composer = build()
    pressEnter(composer, "hi")
    assert(composer.input._hasFocus == true, "no setting wired: focus stays")
  end

  -- test_set_enabled_releases_and_rebinds_key
  do
    local saved = {
      GetBindingKey = _G.GetBindingKey,
      SetOverrideBindingClick = _G.SetOverrideBindingClick,
      ClearOverrideBindings = _G.ClearOverrideBindings,
    }
    local bound = 0
    _G.GetBindingKey = function()
      return "ENTER"
    end
    _G.SetOverrideBindingClick = function()
      bound = bound + 1
    end
    _G.ClearOverrideBindings = function()
      bound = 0
    end

    local composer, _, parent = build({ getDeselectOnSend = on })
    parent:Show()
    composer.frame:Show()
    composer.setEnabled(false)
    local boundWhileDisabled = bound
    composer.setEnabled(true)
    local boundWhileEnabled = bound

    _G.GetBindingKey = saved.GetBindingKey
    _G.SetOverrideBindingClick = saved.SetOverrideBindingClick
    _G.ClearOverrideBindings = saved.ClearOverrideBindings

    assert(boundWhileDisabled == 0, "a disabled composer must give the key back")
    assert(boundWhileEnabled == 1, "an enabled composer takes the key again")
  end
end
