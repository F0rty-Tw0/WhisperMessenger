local FakeUI = require("tests.helpers.fake_ui")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

-- While the button sits on the open window the card would cover the title
-- bar, so it stays hidden. WM's own whisper is in the window's list (and
-- acknowledged when it closes); another addon's card comes back once the
-- button is home.

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  return IncomingPreview.Create(factory, parent, {})
end

local function external(log)
  return {
    sender = "Crafter",
    text = "Needs Plate Belt",
    onClick = function() end,
    onDismiss = function() end,
    onShown = function()
      log[#log + 1] = "shown"
    end,
  }
end

return function()
  -- test_docking_drops_the_own_whisper_card
  do
    local p = build()
    p.setIncomingPreview("Jaina", "hello", "MAGE")
    p.setSuppressed(true)
    assert(not p.frame.shown, "hidden while docked")
    p.setSuppressed(false)
    assert(not p.frame.shown, "the whisper was on screen in the window, so it does not pop at home")
  end

  -- test_a_whisper_while_docked_never_shows
  do
    local p = build()
    p.setSuppressed(true)
    p.setIncomingPreview("Jaina", "hello", "MAGE")
    assert(not p.frame.shown, "hidden while docked")
    p.setSuppressed(false)
    assert(not p.frame.shown, "and not after")
  end

  -- test_an_external_card_hides_while_docked_and_returns_home
  do
    local p = build()
    local log = {}
    p.setExternalPreview(external(log))
    p.setSuppressed(true)
    assert(not p.frame.shown and p.isExternalShown() == false, "hidden while docked")
    p.setSuppressed(false)
    assert(p.frame.shown and p.isExternalShown() == true, "back once home")
    assert(table.concat(log, ",") == "shown,shown", "its owner hears it showed again: " .. table.concat(log, ","))
  end

  -- test_an_external_card_set_while_docked_shows_once_home
  do
    local p = build()
    local log = {}
    p.setSuppressed(true)
    p.setExternalPreview(external(log))
    assert(not p.frame.shown and #log == 0, "not shown while docked")
    p.setSuppressed(false)
    assert(p.frame.shown and table.concat(log, ",") == "shown", "shown once home")
  end
end
