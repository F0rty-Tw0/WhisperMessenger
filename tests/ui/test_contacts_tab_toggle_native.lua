local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Theme = require("WhisperMessenger.UI.Theme")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

local function sameColor(a, b)
  return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function hasText(root, text)
  return FindUI.find(root, function(node)
    return node.text == text
  end) ~= nil
end

local function createToggle(factory, nativeChrome, onModeChanged)
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(260, 500)
  local toggle = TabToggle.Create(factory, pane, {
    initialMode = "whispers",
    nativeChrome = nativeChrome,
    onModeChanged = onModeChanged,
  })
  return toggle, window, pane
end

local function tabs(toggle)
  return FindUI.ofType(toggle.frame, "Button")
end

-- Divider lines live on an overlay frame drawn above the tab art.
local function overlay(toggle)
  return FindUI.ofType(toggle.frame, "Frame")[1]
end

local function lines(toggle)
  return FindUI.ofType(overlay(toggle), "Texture")
end

-- Same token + fallback as the vertical contacts divider (ContactsSection).
local function dividerColor()
  return Theme.COLORS.contacts_divider or Theme.COLORS.divider
end

-- Records PanelTemplates_* calls the native tabs make on the live client.
local function stubPanelTemplates()
  local calls = { selected = {}, deselected = {}, resized = {} }
  rawset(_G, "PanelTemplates_SelectTab", function(tab)
    calls.selected[#calls.selected + 1] = tab
  end)
  rawset(_G, "PanelTemplates_DeselectTab", function(tab)
    calls.deselected[#calls.deselected + 1] = tab
  end)
  rawset(_G, "PanelTemplates_TabResize", function(tab, padding)
    calls.resized[#calls.resized + 1] = { tab = tab, padding = padding }
  end)
  return calls
end

local function clearPanelTemplates()
  rawset(_G, "PanelTemplates_SelectTab", nil)
  rawset(_G, "PanelTemplates_DeselectTab", nil)
  rawset(_G, "PanelTemplates_TabResize", nil)
end

return function()
  -- test_hud_tabs_use_panel_tab_button_template
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local buttons = tabs(toggle)
    assert(#buttons == 3, "HUD: three tabs, got " .. #buttons)
    assert(buttons[3].shown == false, "HUD: the Requests tab stays hidden until the inbox is on")
    assert(buttons[1].template == "PanelTabButtonTemplate", "HUD: whispers tab should use PanelTabButtonTemplate")
    assert(buttons[2].template == "PanelTabButtonTemplate", "HUD: groups tab should use PanelTabButtonTemplate")
    assert(buttons[1].text == "Whispers" and buttons[2].text == "Groups", "HUD: tab labels via SetText")
  end

  -- test_hud_tabs_sit_inside_the_contacts_pane_and_reserve_space
  do
    local toggle, _, pane = createToggle(FakeUI.NewFactory(), true)
    local points = toggle.frame.points
    assert(points[1][1] == "BOTTOMLEFT" and points[1][2] == pane, "HUD: strip anchored to the pane bottom-left (inside the window)")
    assert(points[2][1] == "BOTTOMRIGHT" and points[2][2] == pane, "HUD: strip spans the pane width")
    local reserved = toggle.reservedHeightFor(toggle.frame:GetWidth())
    assert(reserved == TabToggle.NATIVE_HEIGHT and reserved > 0, "HUD: list reserves the strip height")
    assert(toggle.frame.height == TabToggle.NATIVE_HEIGHT, "HUD: strip height matches the reserved space")
  end

  -- test_hud_tabs_get_explicit_width_from_anchors
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local buttons = tabs(toggle)
    local w1, w2 = buttons[1].points, buttons[2].points
    assert(#w1 == 2 and w1[1][1] == "TOPLEFT" and w1[2][1] == "BOTTOMRIGHT" and w1[2][3] == "BOTTOM", "HUD: whispers tab fills the left half")
    assert(#w2 == 2 and w2[1][1] == "TOPLEFT" and w2[1][3] == "TOP" and w2[2][3] == "BOTTOMRIGHT", "HUD: groups tab fills the right half")
  end

  -- test_hud_strip_has_top_line_in_fixed_native_colour
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    assert(#FindUI.ofType(toggle.frame, "Texture") == 0, "HUD: no custom paint on the strip itself")
    local textures = lines(toggle)
    assert(#textures == 2, "HUD: top line + seam line only, got " .. #textures)
    local line = textures[1]
    local p1, p2 = line.points[1], line.points[2]
    assert(p1[1] == "TOPLEFT" and p1[2] == toggle.frame and p2[1] == "TOPRIGHT" and p2[2] == toggle.frame, "HUD: top line spans the strip top")
    assert(line.height == UIHelpers.hairlineThickness(toggle.frame, 1), "HUD: top line is one physical pixel")
    assert(line.snapToPixelGrid == true, "HUD: top line snapped to the pixel grid")
    assert(sameColor(line.color, dividerColor()), "HUD: top line matches the contacts divider")
  end

  -- test_hud_seam_line_between_tabs
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local seam = lines(toggle)[2]
    local p1, p2 = seam.points[1], seam.points[2]
    assert(p1[1] == "TOP" and p1[2] == toggle.frame and p1[3] == "TOP", "HUD: seam starts at the strip top centre (the tab seam)")
    assert(p2[1] == "BOTTOM" and p2[2] == toggle.frame and p2[3] == "BOTTOM", "HUD: seam spans to the strip bottom centre")
    assert(seam.width == UIHelpers.hairlineThickness(toggle.frame, 1), "HUD: seam is one physical pixel wide")
    assert(seam.snapToPixelGrid == true, "HUD: seam snapped to the pixel grid")
    assert(sameColor(seam.color, dividerColor()), "HUD: seam matches the contacts divider")
  end

  -- test_hud_lines_draw_above_the_tab_art
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local layer = overlay(toggle)
    assert(layer.allPoints == toggle.frame, "HUD: overlay covers the strip")
    for _, tab in ipairs(tabs(toggle)) do
      assert(layer:GetFrameLevel() > tab:GetFrameLevel(), "HUD: lines sit above the Blizzard tab art")
    end
  end

  -- test_hud_lines_follow_divider_token_on_theme_refresh
  do
    -- Every shipped preset shares one divider colour, so swap the token to
    -- prove the lines re-read it on repaint (window.refreshTheme -> setMode).
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local original = Theme.COLORS.contacts_divider
    local changed = { 0.2, 0.4, 0.6, 0.5 }
    Theme.COLORS.contacts_divider = changed
    toggle.setMode(toggle.getMode())
    local painted = lines(toggle)
    Theme.COLORS.contacts_divider = original
    for _, line in ipairs(painted) do
      assert(sameColor(line.color, changed), "HUD: lines repaint with the current contacts divider colour")
    end
  end

  -- test_hud_selection_uses_panel_templates
  do
    local calls = stubPanelTemplates()
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local buttons = tabs(toggle)
    calls.selected, calls.deselected = {}, {}
    toggle.setMode("groups")
    assert(calls.selected[#calls.selected] == buttons[2], "HUD: groups tab selected")
    assert(calls.deselected[#calls.deselected] == buttons[1], "HUD: whispers tab deselected")
    assert(toggle.getMode() == "groups", "HUD: mode tracked")
    clearPanelTemplates()
  end

  -- test_hud_click_fires_mode_change
  do
    local changed = nil
    local toggle = createToggle(FakeUI.NewFactory(), true, function(mode)
      changed = mode
    end)
    tabs(toggle)[2].scripts.OnClick(tabs(toggle)[2])
    assert(changed == "groups", "HUD: clicking Groups fires onModeChanged('groups')")
    changed = nil
    tabs(toggle)[2].scripts.OnClick(tabs(toggle)[2])
    assert(changed == nil, "HUD: clicking the active tab is a no-op")
  end

  -- test_hud_unread_badge_on_tab
  do
    local calls = stubPanelTemplates()
    local toggle = createToggle(FakeUI.NewFactory(), true)
    toggle.setUnreadCounts(3, 0)
    local whispersBadge = FindUI.ofType(tabs(toggle)[1], "Frame")[1]
    local groupsBadge = FindUI.ofType(tabs(toggle)[2], "Frame")[1]
    assert(whispersBadge and whispersBadge.shown ~= false and hasText(whispersBadge, "3"), "HUD: whispers badge shows 3")
    assert(groupsBadge and groupsBadge.shown == false, "HUD: groups badge hidden at 0")
    assert(#calls.resized == 0, "HUD: width comes from anchors, never from TabResize")
    clearPanelTemplates()
  end

  -- test_hud_language_refresh
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    toggle.setLanguage()
    assert(tabs(toggle)[1].text == "Whispers", "HUD: setLanguage re-labels tabs")
  end

  -- test_hud_setshown
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    toggle.setShown(false)
    assert(toggle.frame:IsShown() == false, "HUD: setShown(false) hides tabs")
    toggle.setShown(true)
    assert(toggle.frame:IsShown() == true, "HUD: setShown(true) shows tabs")
  end

  -- test_hud_falls_back_to_modern_when_template_missing
  do
    local factory = TemplateFactory.missing(FakeUI.NewFactory(), "PanelTabButtonTemplate")
    local toggle = createToggle(factory, true)
    assert(tabs(toggle)[1].template == nil, "fallback: modern segment buttons")
    assert(toggle.reservedHeightFor(toggle.frame:GetWidth()) == TabToggle.HEIGHT, "fallback: modern reserves the bar height")
  end

  -- test_modern_tabs_unchanged
  do
    local toggle, _, pane = createToggle(FakeUI.NewFactory(), false)
    local pt = toggle.frame.points[1]
    assert(pt[1] == "BOTTOMLEFT" and pt[2] == pane, "modern: bar anchored inside the contacts pane bottom")
    assert(toggle.frame.height == TabToggle.HEIGHT, "modern: bar height unchanged")
    assert(tabs(toggle)[1].template == nil, "modern: plain buttons")
    assert(toggle.reservedHeightFor(toggle.frame:GetWidth()) == TabToggle.HEIGHT, "modern: reserves the bar height")
    assert(#FindUI.ofType(toggle.frame, "Texture") == 3, "modern: divider, bg and footer tint stay")
  end
end
