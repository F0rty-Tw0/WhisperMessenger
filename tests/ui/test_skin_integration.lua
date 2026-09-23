local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")
local ScrollViewFactory = require("WhisperMessenger.UI.ScrollView.Factory")

local function makeSelectedContact()
  return {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }
end

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_send_button_is_square_glyph_on_every_preset
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent_" .. key, nil)
    parent:SetSize(600, 50)

    local btn = Composer.Create(factory, parent, makeSelectedContact(), function() end).sendButton
    assert(btn.normalTexture == nil, key .. ": send button sets no template textures")
    assert(btn.width == Theme.LAYOUT.COMPOSER_BUTTON_SIZE, key .. ": square send button width")
    assert(btn.height == Theme.LAYOUT.COMPOSER_BUTTON_SIZE, key .. ": square send button height")
  end

  -- test_scrollbar_thumb_is_slim_color_paint_on_every_preset
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scroll_" .. key, nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    assert(view.scrollBar.thumb.texturePath == nil, key .. ": no knob texture")
    assert(colorsMatch(view.scrollBar.thumb.color, Theme.COLORS.scrollbar), key .. ": thumb uses the scrollbar token")
  end

  -- test_refresh_skin_repaints_thumb_after_preset_switch
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollRefreshParent", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    Theme.SetPreset("wow_native")
    view.refreshSkin()
    assert(colorsMatch(view.scrollBar.thumb.color, Theme.COLORS.scrollbar), "thumb repainted with the new preset's scrollbar token")
  end

  -- test_scroll_no_overflow_hides_thumb
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "scrollNoOverflow", nil)
    parent:SetSize(400, 300)

    local view = ScrollViewFactory.Create(factory, parent, { width = 380, height = 280 })
    assert(view.scrollBar.shown == false, "scrollBar hidden when there's no overflow")
    assert(view.scrollBar.thumb.shown == false, "thumb hidden when there's no overflow")
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All skin integration tests passed")
end
