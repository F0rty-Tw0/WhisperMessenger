local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

local function buildLayout(useNativeChrome, dropTemplateInset)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = useNativeChrome })
  local frame = chrome.frame
  if dropTemplateInset then
    -- The live client's template exposes no Inset frame.
    frame.Inset = nil
  end
  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})
  return layout, frame
end

local function topOffset(pane)
  return pane.points[1][5]
end

local function isTransparent(texture)
  return texture.color ~= nil and texture.color[4] == 0
end

return function()
  local L = Theme.LAYOUT
  local hudExtra = L.HUD_INSET_BOTTOM + L.HUD_CONTENT_INSET + L.HUD_CONTENT_TOP_INSET
  local hudExtraWidth = L.HUD_INSET_LEFT + L.HUD_INSET_RIGHT + 2 * L.HUD_CONTENT_INSET

  -- test_native_chrome_panes_live_in_content_area_without_template_inset
  do
    local layout, frame = buildLayout(true, true)
    assert(layout.contactsPane.parent == frame.contentArea, "HUD: contacts pane should parent to the content area")
    assert(layout.contentPane.parent == frame.contentArea, "HUD: content pane should parent to the content area")
    assert(layout.optionsPanel.parent == frame.contentArea, "HUD: options panel should parent to the content area")
    assert(topOffset(layout.contactsPane) == 0, "HUD: contacts pane should start at the content area top")
    local br = layout.contentPane.points[2]
    assert(br[2] == frame.contentArea, "HUD: content pane bottom-right should anchor to the content area")
  end

  -- test_native_chrome_relayout_keeps_content_area_anchor
  do
    local layout, frame = buildLayout(true, true)
    LayoutBuilder.Relayout(layout, 800, 500)
    assert(topOffset(layout.contactsPane) == 0, "HUD relayout: contacts pane should stay at the content area top")
    assert(layout.contactsPane.points[1][2] == frame.contentArea, "HUD relayout: contacts pane anchored to content area")
    assert(layout.contentPane.points[2][2] == frame.contentArea, "HUD relayout: content pane anchored to content area")
  end

  -- test_native_chrome_contacts_height_matches_content_area
  do
    local layout = buildLayout(true, true)
    local result = LayoutBuilder.Relayout(layout, 800, 500)
    local expected = 500 - Theme.TOP_BAR_HEIGHT - hudExtra
    assert(expected == 470, "HUD: content area should be 4px taller than before (470), got " .. expected)
    assert(result.contactsHeight == expected, "HUD: contactsHeight should be " .. expected .. ", got " .. tostring(result.contactsHeight))
  end

  -- test_native_chrome_contacts_background_transparent_after_theme_apply
  do
    local layout = buildLayout(true, true)
    layout.applyTheme(Theme)
    assert(isTransparent(layout.contactsPaneBg), "HUD: contacts pane bg should stay transparent after theme apply")
  end

  -- test_native_chrome_options_panel_flush_to_content_area
  do
    local layout, frame = buildLayout(true, true)
    local tl, br = layout.optionsPanel.points[1], layout.optionsPanel.points[2]
    assert(tl[2] == frame.contentArea and tl[4] == 0 and tl[5] == 0, "HUD: options panel TOPLEFT flush, got y=" .. tostring(tl[5]))
    assert(br[2] == frame.contentArea and br[4] == 0 and br[5] == 0, "HUD: options panel BOTTOMRIGHT flush, got y=" .. tostring(br[5]))
  end

  -- test_native_chrome_options_content_pane_flush_top_right
  do
    local layout, frame = buildLayout(true, true)
    local pane = layout.optionsContentPane
    local tl, br = pane.points[1], pane.points[2]
    assert(tl[5] == 0, "HUD: options content pane top gap should be 0, got " .. tostring(tl[5]))
    assert(br[4] == 0 and br[5] == 0, "HUD: options content pane BOTTOMRIGHT should be flush, got x=" .. tostring(br[4]))
    local buildWidth = 920 - hudExtraWidth - layout.contactsWidth - Theme.DIVIDER_THICKNESS
    assert(pane.width == buildWidth, "HUD build: options pane width should be " .. buildWidth .. ", got " .. tostring(pane.width))
    assert(layout.optionsScrollView.totalWidth == buildWidth, "HUD build: options scroll width should fill the pane")
    local result = LayoutBuilder.Relayout(layout, 800, 500)
    local width = 800 - hudExtraWidth - result.contactsWidth - Theme.DIVIDER_THICKNESS
    assert(pane.width == width, "HUD relayout: options pane width should be " .. width .. ", got " .. tostring(pane.width))
    assert(
      layout.optionsScrollView.totalWidth == width,
      "HUD relayout: options scroll width should fill the pane, got " .. tostring(layout.optionsScrollView.totalWidth)
    )
    assert(frame.contentArea ~= nil, "HUD: content area expected")
  end

  -- test_native_chrome_options_viewport_fits_content_pane
  do
    local layout = buildLayout(true, true)
    local osv = layout.optionsScrollView
    local buildExpected = 580 - Theme.TOP_BAR_HEIGHT - hudExtra
    assert(
      osv.scrollFrame.height == buildExpected,
      "HUD build: options viewport should be " .. buildExpected .. ", got " .. tostring(osv.scrollFrame.height)
    )
    LayoutBuilder.Relayout(layout, 800, 500)
    local expected = 500 - Theme.TOP_BAR_HEIGHT - hudExtra
    assert(
      osv.scrollFrame.height == expected,
      "HUD relayout: options viewport should be " .. expected .. ", got " .. tostring(osv.scrollFrame.height)
    )
    assert(osv.viewportHeight == expected, "HUD relayout: options viewportHeight should match")
    assert(osv.scrollBar.height == expected, "HUD relayout: options scrollbar height should match")
  end

  -- test_modern_chrome_options_unchanged
  do
    local layout, frame = buildLayout(false)
    local tl, br = layout.optionsPanel.points[1], layout.optionsPanel.points[2]
    assert(tl[2] == frame and tl[4] == 0 and tl[5] == -20, "modern: options panel TOPLEFT unchanged")
    assert(br[2] == frame and br[4] == 0 and br[5] == 5, "modern: options panel BOTTOMRIGHT unchanged")
    local osv = layout.optionsScrollView
    assert(osv.scrollFrame.height == 580 - Theme.TOP_BAR_HEIGHT - 28 - 2, "modern build: options viewport unchanged")
    assert(osv.totalWidth == 920 - layout.contactsWidth - Theme.DIVIDER_THICKNESS - 4, "modern build: options content width unchanged")
    LayoutBuilder.Relayout(layout, 800, 500)
    assert(osv.scrollFrame.height == 500 - Theme.TOP_BAR_HEIGHT, "modern relayout: options viewport unchanged")
    assert(osv.viewportHeight == 500 - Theme.TOP_BAR_HEIGHT, "modern relayout: options viewportHeight unchanged")
    local pane = layout.optionsContentPane
    assert(pane.points[1][5] == -2, "modern: options content pane top gap unchanged")
    assert(pane.points[2][4] == -4 and pane.points[2][5] == 0, "modern: options content pane BOTTOMRIGHT unchanged")
    local width = (800 - 20) - layout.contactsWidth - Theme.DIVIDER_THICKNESS
    assert(pane.width == width and osv.totalWidth == width, "modern relayout: options content width unchanged")
  end

  -- test_modern_chrome_layout_unchanged
  do
    local layout, frame = buildLayout(false)
    assert(layout.contactsPane.parent == frame, "modern: contacts pane parents to the frame")
    assert(layout.contentPane.parent == frame, "modern: content pane parents to the frame")
    local tl = layout.contactsPane.points[1]
    assert(tl[4] == L.CONTACTS_PANE_LEFT_INSET and tl[5] == -Theme.TOP_BAR_HEIGHT, "modern: contacts pane TOPLEFT unchanged")
    local bl = layout.contactsPane.points[2]
    assert(bl[4] == L.CONTACTS_PANE_BOTTOM_LEFT_INSET and bl[5] == L.CONTACTS_PANE_BOTTOM_INSET, "modern: contacts pane BOTTOMLEFT unchanged")
    local br = layout.contentPane.points[2]
    assert(
      br[2] == frame and br[4] == -L.CONTENT_PANE_RIGHT_INSET and br[5] == L.CONTENT_PANE_BOTTOM_INSET,
      "modern: content pane BOTTOMRIGHT unchanged"
    )
    local result = LayoutBuilder.Relayout(layout, 800, 500)
    assert(topOffset(layout.contactsPane) == -Theme.TOP_BAR_HEIGHT, "modern relayout: contacts pane should clear the title bar")
    assert(result.contactsHeight == 500 - Theme.TOP_BAR_HEIGHT, "modern: contactsHeight should be height - TOP_BAR_HEIGHT")
    layout.applyTheme(Theme)
    local c = layout.contactsPaneBg.color
    local want = Theme.COLORS.bg_secondary
    assert(c[1] == want[1] and c[2] == want[2] and c[3] == want[3] and c[4] == (want[4] or 1), "modern: contacts pane bg should be bg_secondary")
  end
end
