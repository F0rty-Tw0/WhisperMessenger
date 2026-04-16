local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

local function makeComposer(getDoubleEscape, onEscape)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }
  local composer = Composer.Create(factory, parent, selectedContact, function() end, onEscape, getDoubleEscape)
  return composer
end

return function()
  -- test_double_escape_off_preserves_single_escape_close
  do
    local escapes = 0
    local composer = makeComposer(function()
      return false
    end, function()
      escapes = escapes + 1
    end)

    composer.input:SetFocus()
    assert(composer.input:HasFocus() == true, "pre: composer input should be focused")

    composer.input.scripts.OnEscapePressed(composer.input)

    assert(escapes == 1, "double-escape OFF: first ESC should invoke onEscape (close), got " .. tostring(escapes))
  end

  -- test_double_escape_on_first_escape_clears_focus_only
  do
    local escapes = 0
    local composer = makeComposer(function()
      return true
    end, function()
      escapes = escapes + 1
    end)

    composer.input:SetFocus()
    assert(composer.input:HasFocus() == true, "pre: composer input should be focused")

    composer.input.scripts.OnEscapePressed(composer.input)

    assert(
      escapes == 0,
      "double-escape ON: first ESC should NOT invoke onEscape (only clear focus), got " .. tostring(escapes)
    )
    assert(composer.input:HasFocus() == false, "double-escape ON: first ESC should clear composer focus")
  end

  -- test_double_escape_on_does_not_close_when_input_unfocused
  -- (WoW's UISpecialFrames handles the unfocused case; OnEscapePressed does not fire.)
  -- This test asserts that when the handler IS invoked while focused, it does not close.
  do
    local escapes = 0
    local composer = makeComposer(function()
      return true
    end, function()
      escapes = escapes + 1
    end)

    composer.input:SetFocus()
    composer.input.scripts.OnEscapePressed(composer.input)
    assert(composer.input:HasFocus() == false, "first ESC should unfocus input")
    assert(escapes == 0, "first ESC must not close when double-escape is enabled")
  end

  -- test_double_escape_getter_absent_falls_back_to_close
  do
    local escapes = 0
    local composer = makeComposer(nil, function()
      escapes = escapes + 1
    end)

    composer.input:SetFocus()
    composer.input.scripts.OnEscapePressed(composer.input)

    assert(escapes == 1, "absent getter: ESC should call onEscape (backward compatible), got " .. tostring(escapes))
  end

  print("PASS: test_double_escape")
end
