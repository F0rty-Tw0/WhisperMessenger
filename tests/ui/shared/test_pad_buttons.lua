-- Pad buttons: texture-glyph Buttons beside settings controls that a
-- controller can land on. They show only while the game's pad UI is on.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local PadButtons = require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")

local function noop() end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local on = true
  local savedInputUtil = rawget(_G, "InputUtil")
  rawset(_G, "InputUtil", {
    IsGamepadUIEnabled = function()
      return on
    end,
  })

  local ok, err = pcall(function()
    -- test_each_kind_is_a_button_with_its_atlas_glyph
    do
      for kind, atlas in pairs(PadButtons.ATLAS) do
        local b = PadButtons.Create(factory, parent, kind, noop)
        assert(b.frameType == "Button" and FindUI.ofType(b, "Texture")[1].atlas == atlas, kind)
        assert(#FindUI.ofType(b, "FontString") == 0, kind .. ": no text glyph")
        assert(b._wmPadButton == true, kind .. ": tagged for the nav")
      end
    end

    -- test_click_calls_on_click_with_no_arguments
    do
      local got
      local b = PadButtons.Create(factory, parent, "plus", function(...)
        got = select("#", ...)
      end)
      FindUI.click(b)
      assert(got == 0, "no arguments, got " .. tostring(got))
    end

    -- test_shown_only_while_the_pad_ui_is_on
    do
      on = true
      assert(PadButtons.Create(factory, parent, "up", noop):IsShown() == true, "pad UI on: shown")
      on = false
      assert(PadButtons.Create(factory, parent, "up", noop):IsShown() == false, "pad UI off: hidden")
    end

    -- test_refresh_follows_the_toggle
    do
      on = true
      local r = PadButtons.Create(factory, parent, "down", noop)
      on = false
      PadButtons.Refresh()
      assert(r:IsShown() == false, "toggled off: hidden")
      on = true
      PadButtons.Refresh()
      assert(r:IsShown() == true, "toggled on: shown")
    end

    -- test_on_shown_changed_fires_at_create_and_on_flip_only
    do
      local seen = {}
      on = true
      PadButtons.Create(factory, parent, "up", noop, function(s)
        seen[#seen + 1] = s
      end)
      PadButtons.Refresh()
      on = false
      PadButtons.Refresh()
      PadButtons.Refresh()
      assert(#seen == 2 and seen[1] == true and seen[2] == false, "create + one flip, no repeat")
    end

    -- test_unknown_kind_errors
    do
      local created, msg = pcall(PadButtons.Create, factory, parent, "left", noop)
      assert(not created and tostring(msg):find("unknown kind left", 1, true), "unknown kind refused")
    end
  end)

  rawset(_G, "InputUtil", savedInputUtil)
  assert(ok, err)
end
