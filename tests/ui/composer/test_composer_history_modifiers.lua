local FakeUI = require("tests.helpers.fake_ui")
local ComposerHistory = require("WhisperMessenger.UI.Composer.ComposerHistory")

-- Up/Down with Shift, Ctrl or Alt held belong to the game, never the recall.
local function build()
  local input = FakeUI.NewFactory().CreateFrame("EditBox", nil, nil)
  input:SetText("")
  local got = { asked = 0, calls = {} }
  input:SetScript("OnKeyDown", function(_self, key)
    got.calls[#got.calls + 1] = key
  end)
  ComposerHistory.Create(input, {
    getSentHistory = function()
      got.asked = got.asked + 1
      return { "e1", "e2", "e3" }
    end,
    fits = function()
      return true
    end,
    refresh = function() end,
  })
  local function press(key)
    input.scripts.OnKeyDown(input, key)
  end
  return input, press, got
end

local function pressModified(press, key)
  local saved = rawget(_G, "IsModifierKeyDown")
  rawset(_G, "IsModifierKeyDown", function()
    return true
  end)
  local ok, err = pcall(press, key)
  rawset(_G, "IsModifierKeyDown", saved)
  assert(ok, err)
end

return function()
  -- test_modified_up_on_empty_box_keeps_the_default
  do
    local input, press = build()
    pressModified(press, "UP")
    assert(input:GetText() == "", "Shift+Up on an empty box recalls nothing")
  end

  -- test_modified_up_does_not_build_the_list
  do
    local _, press, got = build()
    pressModified(press, "UP")
    assert(got.asked == 0, "Shift+Up never asks for the sent lines")
  end

  -- test_modified_up_during_a_recall_does_not_step
  do
    local input, press = build()
    press("UP")
    pressModified(press, "UP")
    assert(input:GetText() == "e1", "Shift+Up keeps the recalled line")
  end

  -- test_modified_down_during_a_recall_does_not_step
  do
    local input, press = build()
    press("UP")
    press("UP")
    pressModified(press, "DOWN")
    assert(input:GetText() == "e2", "Shift+Down keeps the recalled line")
  end

  -- test_modified_up_reaches_the_old_handler
  do
    local _, press, got = build()
    pressModified(press, "UP")
    assert(got.calls[1] == "UP", "Shift+Up is passed on to the game")
  end

  -- test_modified_down_reaches_the_old_handler
  do
    local _, press, got = build()
    pressModified(press, "DOWN")
    assert(got.calls[1] == "DOWN", "Shift+Down is passed on to the game")
  end
end
