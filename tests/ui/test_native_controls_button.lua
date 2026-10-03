local FakeUI = require("tests.helpers.fake_ui")
local NativeControls = require("WhisperMessenger.UI.Helpers.NativeControls")

-- A Blizzard panel button that comes back without its hover glow (seen on
-- the live Retail client) gets the template's own highlight art.
local HIGHLIGHT_FILE = "Interface\\Buttons\\UI-Panel-Button-Highlight"

return function()
  -- test_button_without_hover_art_gets_the_panel_highlight
  do
    local factory = FakeUI.NewFactory()
    local button = assert(NativeControls.CreateButton(factory, factory.CreateFrame("Frame", nil, nil), "Cancel", 130, 22))
    local highlight = button.highlightTexture
    assert(type(highlight) == "table", "hover texture set")
    assert(highlight.texturePath == HIGHLIGHT_FILE, "Blizzard's panel-button highlight, got " .. tostring(highlight.texturePath))
    assert(highlight.blendMode == "ADD", "additive glow like the template")
  end

  -- test_button_with_hover_art_keeps_it
  do
    local factory = FakeUI.NewFactory()
    local own = { tag = "template highlight" }
    local realCreate = factory.CreateFrame
    factory.CreateFrame = function(...)
      local frame = realCreate(...)
      if select(4, ...) == NativeControls.BUTTON_TEMPLATE then
        frame.GetHighlightTexture = function()
          return own
        end
      end
      return frame
    end
    local button = assert(NativeControls.CreateButton(factory, realCreate("Frame", nil, nil), "Cancel", 130, 22))
    assert(button.highlightTexture == nil, "template highlight left alone")
  end
end
