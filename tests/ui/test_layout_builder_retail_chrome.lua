local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

local function buildLayout(factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
  local layout = LayoutBuilder.Build(factory, chrome.frame, { width = 920, height = 580 }, {})
  return layout, chrome.frame
end

local function assertPinned(inset, pane, label)
  local tl, br = inset.points[1], inset.points[2]
  assert(tl[1] == "TOPLEFT" and tl[2] == pane and tl[3] == "TOPLEFT", label .. ": TOPLEFT pinned to the pane")
  assert(br[1] == "BOTTOMRIGHT" and br[2] == pane and br[3] == "BOTTOMRIGHT", label .. ": BOTTOMRIGHT pinned to the pane")
end

return function()
  local L = Theme.LAYOUT
  local extraHeight = L.RETAIL_HUD_INSET_TOP + L.RETAIL_HUD_INSET_BOTTOM
  local extraWidth = L.RETAIL_HUD_INSET_LEFT + L.RETAIL_HUD_INSET_RIGHT

  -- test_retail_panes_live_in_the_content_area_not_the_inset
  RetailHud.With(function()
    local layout, frame = buildLayout()
    assert(layout.contactsPane.parent == frame.contentArea, "retail: contacts pane parents to the content area")
    assert(layout.contentPane.parent == frame.contentArea, "retail: content pane parents to the content area")
    assert(layout.optionsPanel.parent == frame.contentArea, "retail: options panel parents to the content area")
    assert(layout.contentPane.points[2][2] == frame.contentArea, "retail: content pane anchors to the content area")
  end)

  -- test_retail_insets_cover_their_panes
  RetailHud.With(function()
    local layout, frame = buildLayout()
    assertPinned(frame.contactsInset, layout.contactsPane, "contacts inset")
    assertPinned(frame.Inset, layout.contentPane, "conversation inset")
  end)

  -- test_retail_insets_follow_the_split_after_relayout
  RetailHud.With(function()
    local layout, frame = buildLayout()
    LayoutBuilder.Relayout(layout, 800, 500, 260)
    assert(layout.contactsWidth == 260, "retail relayout: contacts width moved")
    assertPinned(frame.contactsInset, layout.contactsPane, "contacts inset after relayout")
    assertPinned(frame.Inset, layout.contentPane, "conversation inset after relayout")
    local tl = layout.contentPane.points[1]
    assert(tl[2] == layout.contactsPane and tl[3] == "TOPRIGHT", "retail relayout: conversation side starts at the split")
  end)

  -- test_retail_search_box_sits_inside_the_contacts_inset
  RetailHud.With(function()
    local layout = buildLayout()
    local searchParent = layout.contactsSearchFrame.parent
    assert(searchParent == layout.contactsPane, "retail: search box lives in the contacts pane the inset covers")
  end)

  -- test_retail_metrics_use_the_retail_insets
  RetailHud.With(function()
    local layout = buildLayout()
    local result = LayoutBuilder.Relayout(layout, 800, 500)
    local expected = 500 - extraHeight
    assert(result.contactsHeight == expected, "retail: contacts height " .. expected .. ", got " .. tostring(result.contactsHeight))
    local width = 800 - extraWidth - result.contactsWidth - Theme.DIVIDER_THICKNESS - Theme.LAYOUT.HUD_PANEL_PADDING
    assert(layout.optionsContentPane.width == width, "retail: options width " .. width .. ", got " .. tostring(layout.optionsContentPane.width))
  end)

  -- test_retail_without_inset_children_builds_the_layout
  RetailHud.With(function()
    local factory = RetailHud.Factory(FakeUI, {
      missing = { InsetFrameTemplate = true },
      decorate = function(frame, template)
        if template == "ButtonFrameTemplate" then
          frame.Inset = nil
        end
      end,
    })
    local layout = buildLayout(factory)
    LayoutBuilder.Relayout(layout, 800, 500)
  end)

  -- test_classic_inset_is_not_reanchored
  do
    local _, frame = buildLayout()
    assert(frame.Inset.points == nil, "classic: the template Inset keeps the template's own anchors")
    assert(frame.contactsInset == nil, "classic: no contacts inset")
  end
end
