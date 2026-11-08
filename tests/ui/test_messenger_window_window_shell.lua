-- The window shell builds the window's static structure and returns its parts.
local FakeUI = require("tests.helpers.fake_ui")
local WindowScale = require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local RealLayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

-- Wraps the layout builder so a test can make the built layout report a
-- contacts width the geometry would not pick by itself.
local layoutContactsWidthOverride = nil
local LayoutBuilderProbe = setmetatable({
  Build = function(...)
    local layout = RealLayoutBuilder.Build(...)
    if layoutContactsWidthOverride then
      layout.expandedContactsWidth = layoutContactsWidthOverride
    end
    return layout
  end,
}, { __index = RealLayoutBuilder })
package.loaded["WhisperMessenger.UI.MessengerWindow.LayoutBuilder"] = LayoutBuilderProbe
package.loaded["UI.MessengerWindow.LayoutBuilder"] = LayoutBuilderProbe
package.loaded["WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowShell"] = nil
package.loaded["UI.MessengerWindow.MessengerWindow.WindowShell"] = nil

local WindowShell = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowShell")

local function build(options)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(1920, 1080)
  options = options or {}
  options.parent = parent
  return WindowShell.Build(factory, options), parent
end

return function()
  -- test_build_saves_the_normalized_scale_into_settings
  do
    local settingsConfig = {}
    build({ settingsConfig = settingsConfig })
    assert(settingsConfig.windowScale == WindowScale.DEFAULT, "missing scale saved as the default, got " .. tostring(settingsConfig.windowScale))
  end

  -- test_build_returns_the_settings_table_it_was_given
  do
    local settingsConfig = {}
    local shell = build({ settingsConfig = settingsConfig })
    assert(shell.settingsConfig == settingsConfig, "same settings table returned")
  end

  -- test_build_hands_the_layout_contacts_width_to_the_geometry
  do
    layoutContactsWidthOverride = 333
    local shell = build({})
    layoutContactsWidthOverride = nil
    assert(shell.contactsWidth == 333, "shell reports the layout width, got " .. tostring(shell.contactsWidth))
    local geometryWidth = shell.windowGeometry.getContactsWidth()
    assert(geometryWidth == 333, "geometry follows the layout width, got " .. tostring(geometryWidth))
  end

  -- test_build_returns_the_chrome_frame_inside_the_parent
  do
    local shell, parent = build({})
    assert(shell.parent == parent, "parent passed through")
    assert(shell.frame ~= nil and shell.frame == shell.chrome.frame, "frame is the chrome frame")
  end

  -- test_compact_layout_is_off_unless_exactly_true
  do
    assert(build({ compactLayout = "yes" }).compactLayout == false, "truthy non-true value keeps the desktop layout")
  end
end
