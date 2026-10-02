-- Under the Native WoW HUD the game draws each panel's border inside the
-- panel. Scroll areas keep clear of it so text and scrollbars never ride
-- over the border.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

local function buildLayout(useNativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = useNativeChrome })
  return LayoutBuilder.Build(factory, chrome.frame, { width = 920, height = 580 }, {})
end

-- The last anchor set for `point` on `region`.
local function anchor(region, point)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == point then
      found = pt
    end
  end
  return assert(found, "no " .. point .. " anchor")
end

local function padding()
  local pad = Theme.LAYOUT.HUD_PANEL_PADDING
  assert(type(pad) == "number" and pad > 0, "HUD panel padding is set, got " .. tostring(pad))
  return pad
end

return function()
  -- test_hud_options_panel_clears_the_top_and_bottom_border
  do
    local layout = buildLayout(true)
    local top, bottom = anchor(layout.optionsPanel, "TOPLEFT"), anchor(layout.optionsPanel, "BOTTOMRIGHT")
    assert(top[5] == -padding(), "HUD: options start below the top border, got " .. tostring(top[5]))
    assert(bottom[5] == padding(), "HUD: options end above the bottom border, got " .. tostring(bottom[5]))
  end

  -- test_hud_options_menu_scrollbar_clears_the_divider
  do
    local layout = buildLayout(true)
    local pt = anchor(layout.optionsMenuScrollView.scrollBar, "TOPRIGHT")
    assert(pt[2] == layout.optionsMenu and pt[4] == -padding(), "HUD: menu scrollbar sits inside the panel border, got x " .. tostring(pt[4]))
  end

  -- test_hud_contacts_list_clears_the_bottom_border
  do
    local layout = buildLayout(true)
    LayoutBuilder.Relayout(layout, 920, 500)
    local pt = anchor(layout.contactsView.scrollFrame, "BOTTOMRIGHT")
    assert(pt[5] == padding(), "HUD: contact list ends above the bottom border, got " .. tostring(pt[5]))
    assert(pt[4] == -padding(), "HUD: contact scrollbar clears the divider, got " .. tostring(pt[4]))
  end

  -- test_hud_options_page_scrollbar_clears_the_right_border
  do
    local layout = buildLayout(true)
    local pt = anchor(layout.optionsContentPane, "BOTTOMRIGHT")
    assert(pt[4] == -padding(), "HUD: options page ends inside the right border, got " .. tostring(pt[4]))
  end

  -- test_hud_options_page_width_leaves_the_right_padding
  do
    local layout = buildLayout(true)
    local sizes = LayoutBuilder.Relayout(layout, 900, 500)
    local expected = sizes.contentWidth - padding()
    assert(
      layout.optionsContentPane:GetWidth() == expected,
      "HUD: page width matches its padded anchors, got " .. tostring(layout.optionsContentPane:GetWidth())
    )
  end

  -- test_options_page_scrollbar_stays_on_the_page_after_resize
  for _, native in ipairs({ true, false }) do
    local layout = buildLayout(native)
    local osv = layout.optionsScrollView
    ScrollView.RefreshMetrics(osv, 2000)
    LayoutBuilder.Relayout(layout, 900, 500)
    local barRight = osv.scrollFrame:GetWidth() + osv.scrollBar:GetWidth()
    local pageWidth = layout.optionsContentPane:GetWidth()
    assert(barRight <= pageWidth, (native and "HUD" or "modern") .. ": bar ends on the page, got " .. barRight .. " > " .. pageWidth)
  end

  -- test_modern_window_keeps_its_layout
  do
    local layout = buildLayout(false)
    assert(anchor(layout.optionsPanel, "TOPLEFT")[5] == -20, "modern: options keep their top offset")
    assert(anchor(layout.optionsMenuScrollView.scrollBar, "TOPRIGHT")[4] == 0, "modern: menu scrollbar stays flush")
    LayoutBuilder.Relayout(layout, 920, 500)
    local listEdge = anchor(layout.contactsView.scrollFrame, "BOTTOMRIGHT")
    assert(listEdge[4] == 0 and listEdge[5] == 0, "modern: contact list stays flush")
  end
end
