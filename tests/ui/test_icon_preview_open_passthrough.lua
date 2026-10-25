local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- Both icons show a whisper preview; left-clicking either asks the runtime to open it.
return function()
  local function clickPreview(icon)
    icon.setIncomingPreview("Jaina", "Need help?", "MAGE")
    icon.previewFrame:GetScript("OnMouseUp")(icon.previewFrame, "LeftButton")
  end

  local function test_widget_preview_left_click_calls_the_open_callback()
    local factory = FakeUI.NewFactory()
    local opened = 0
    local icon = ToggleIcon.Create(factory, {
      onOpenPreview = function()
        opened = opened + 1
      end,
    })
    clickPreview(icon)
    assert(opened == 1, "widget preview left-click opens once, got " .. opened)
  end

  local function test_minimap_preview_left_click_calls_the_open_callback()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "Minimap", nil)
    parent:SetSize(140, 140)
    local opened = 0
    local icon = MinimapIcon.Create(factory, {
      parent = parent,
      onOpenPreview = function()
        opened = opened + 1
      end,
    })
    clickPreview(icon)
    assert(opened == 1, "minimap preview left-click opens once, got " .. opened)
  end

  test_widget_preview_left_click_calls_the_open_callback()
  test_minimap_preview_left_click_calls_the_open_callback()
end
