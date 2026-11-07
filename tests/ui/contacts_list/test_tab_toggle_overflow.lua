local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

-- Both skins on the tab scroller; each gives the same shown sets.
-- Fake text is 7px per character.
-- Modern tab = 7 * len + 30: Whispers 86, Groups 72, Channels 86, Requests 86,
-- Alerts 72; spacing 2, arrows 16, no end reserve. At 260 the room between
-- the arrows is 260 - 2 * 16 - 0 - 2 * 2 = 224.
-- Native tab = 7 * len + 20: 76, 62, 76, 76, 62; spacing 1, arrows 24, 7px
-- end reserve (the last tab's art overhang). At 260 the room is 203.
-- Visible order: Whispers, Groups, Channels, Requests, Alerts (a panel tab).
-- Wide strip (500): every tab fits. Narrow strip (260): Whispers + Groups.

local SKINS = {
  { native = false, spacing = 2, arrow = 16, reserve = 0 },
  { native = true, spacing = 1, arrow = 24, reserve = 7 },
}
local ALL_MODES = { "whispers", "groups", "channels", "requests" }
local LABELS = { "Whispers", "Groups", "Channels", "Requests", "Alerts" }
local STRIP_HEIGHT = 32

local function noop() end

local function build(skin)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local toggle = TabToggle.Create(factory, window, {
    initialMode = "whispers",
    nativeChrome = skin.native,
    windowFrame = window,
  })
  toggle.setModes(ALL_MODES)
  toggle.addPanelTab("ca", "Alerts", noop)
  return toggle
end

local function resize(toggle, width)
  toggle.frame:SetWidth(width)
  toggle.frame.scripts.OnSizeChanged(toggle.frame, width, STRIP_HEIGHT)
end

-- Errors when no tab carries the label.
local function tab(toggle, skin, label)
  if not skin.native then
    return FindUI.byLabel(toggle.frame, label)
  end
  for _, btn in ipairs(FindUI.ofType(toggle.frame, "Button")) do
    if btn.text == label then
      return btn
    end
  end
  error("no tab labelled " .. label)
end

-- prev, next.
local function arrows(toggle)
  local holder = FindUI.ofType(toggle.frame, "Frame")[1]
  local buttons = FindUI.ofType(holder, "Button")
  return buttons[1], buttons[2]
end

-- Labels of the shown tabs, in visible order.
local function shownLabels(toggle, skin)
  local labels = {}
  for _, label in ipairs(LABELS) do
    if tab(toggle, skin, label).shown then
      labels[#labels + 1] = label
    end
  end
  return labels
end

local function shown(toggle, skin)
  return table.concat(shownLabels(toggle, skin), ",")
end

local function name(skin)
  return skin.native and "native" or "modern"
end

for _, skin in ipairs(SKINS) do
  local skinName = name(skin)

  -- test_narrow_strip_shows_whole_tabs_and_arrows
  do
    local toggle = build(skin)
    resize(toggle, 260)
    assert(shown(toggle, skin) == "Whispers,Groups", skinName .. ": got " .. shown(toggle, skin))
    local prev, nextBtn = arrows(toggle)
    assert(prev.shown and nextBtn.shown, skinName .. ": arrows show on overflow")
  end

  -- test_no_shown_tab_passes_the_strip_edge
  do
    local toggle = build(skin)
    resize(toggle, 260)
    local labels = shownLabels(toggle, skin)
    local used = (#labels - 1) * skin.spacing + 2 * skin.spacing + 2 * skin.arrow + skin.reserve
    for _, label in ipairs(labels) do
      used = used + tab(toggle, skin, label):GetWidth()
    end
    assert(used <= 260, skinName .. ": shown tabs and arrows fit in 260, used " .. used)
  end

  -- test_wide_strip_looks_as_before
  do
    local toggle = build(skin)
    resize(toggle, 500)
    assert(shown(toggle, skin) == "Whispers,Groups,Channels,Requests,Alerts", skinName .. ": got " .. shown(toggle, skin))
    local prev, nextBtn = arrows(toggle)
    assert(prev.shown == false and nextBtn.shown == false, skinName .. ": no arrows when everything fits")
    local whispers, groups = tab(toggle, skin, "Whispers"), tab(toggle, skin, "Groups")
    local first, second = whispers.points[1], groups.points[1]
    assert(
      first[1] == "TOPLEFT" and first[2] == toggle.frame and first[3] == "TOPLEFT" and first[4] == 0 and first[5] == 0,
      skinName .. ": Whispers at the strip's left"
    )
    assert(
      second[1] == "TOPLEFT" and second[2] == whispers and second[3] == "TOPRIGHT" and second[4] == skin.spacing and second[5] == 0,
      skinName .. ": Groups right of Whispers"
    )
    assert(toggle.frame.mouseWheelEnabled == false, skinName .. ": wheel off while everything fits")
  end

  -- test_opening_a_hidden_panel_reveals_its_tab
  do
    local toggle = build(skin)
    resize(toggle, 260)
    toggle.setSelectedPanel("ca")
    assert(shown(toggle, skin) == "Requests,Alerts", skinName .. ": got " .. shown(toggle, skin))
  end

  -- test_mode_switch_reveals_its_tab
  do
    local toggle = build(skin)
    resize(toggle, 260)
    toggle.setMode("requests")
    assert(shown(toggle, skin) == "Channels,Requests", skinName .. ": got " .. shown(toggle, skin))
  end

  -- test_repaint_keeps_a_manual_scroll
  do
    local toggle = build(skin)
    resize(toggle, 260)
    local _, nextBtn = arrows(toggle)
    nextBtn.scripts.OnClick(nextBtn)
    assert(shown(toggle, skin) == "Groups,Channels", skinName .. ": next scrolls one tab, got " .. shown(toggle, skin))
    toggle.setMode(toggle.getMode())
    assert(shown(toggle, skin) == "Groups,Channels", skinName .. ": a repaint keeps the scroll, got " .. shown(toggle, skin))
  end

  -- test_set_modes_keeps_scrolled_out_tabs_hidden
  do
    local toggle = build(skin)
    resize(toggle, 260)
    toggle.setModes(ALL_MODES)
    assert(shown(toggle, skin) == "Whispers,Groups", skinName .. ": got " .. shown(toggle, skin))
  end

  -- test_panel_tab_shows_again_when_the_strip_widens
  do
    local toggle = build(skin)
    resize(toggle, 260)
    resize(toggle, 500)
    assert(tab(toggle, skin, "Alerts").shown, skinName .. ": the panel tab shows again")
  end

  -- test_theme_repaint_recolours_arrows (modern only)
  if not skin.native then
    local toggle = build(skin)
    resize(toggle, 260)
    local prev = arrows(toggle)
    local icon = FindUI.ofType(prev, "Texture")[1]
    icon.vertexColor = nil
    toggle.setMode(toggle.getMode())
    assert(icon.vertexColor ~= nil, "modern: a repaint recolours the arrows")
  end
end

print("PASS: test_tab_toggle_overflow")
