local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

return function()
  -- test_menu_content_fits_every_tab_above_the_footer
  -- A short window scrolls the settings nav instead of drawing the footer
  -- hint over the last tabs.
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local layout = LayoutBuilder.Build(factory, parent, { width = 640, height = 360 }, {})
    layout.refreshOptionsMenuScrollGeometry()

    local pad = Theme.CONTENT_PADDING
    local tabH = Theme.LAYOUT.OPTION_BUTTON_HEIGHT
    local tabCount = #layout.settingsTabs
    local tabsBottom = pad + tabCount * tabH + (tabCount - 1) * 4
    local hintHeight = layout.optionsHint:GetStringHeight()
    local footer = hintHeight + pad + 3 * tabH + 2 * Theme.LAYOUT.OPTION_BUTTON_SPACING + pad
    local contentHeight = layout.optionsMenuScrollView.content:GetHeight()

    assert(
      contentHeight >= tabsBottom + pad + footer,
      "expected nav content >= " .. (tabsBottom + pad + footer) .. ", got " .. tostring(contentHeight)
    )
  end
end
