local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local NativeTabToggle = require("WhisperMessenger.UI.ContactsList.NativeTabToggle")

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
    windowFrame = window,
    onModeChanged = onModeChanged,
  })
  return toggle, window, pane
end

local function tabs(toggle)
  return FindUI.ofType(toggle.frame, "Button")
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
  rawset(_G, "PanelTemplates_TabResize", function(tab, padding, _absoluteSize, _minWidth, maxWidth)
    calls.resized[#calls.resized + 1] = { tab = tab, padding = padding, maxWidth = maxWidth }
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
    assert(#buttons == 4, "HUD: four tabs, got " .. #buttons)
    assert(buttons[3].shown == false, "HUD: the Requests tab stays hidden until the inbox is on")
    assert(buttons[4].shown == false, "HUD: the Channels tab stays hidden until a channel is ticked")
    assert(buttons[1].template == "PanelTabButtonTemplate", "HUD: whispers tab should use PanelTabButtonTemplate")
    assert(buttons[2].template == "PanelTabButtonTemplate", "HUD: groups tab should use PanelTabButtonTemplate")
    assert(buttons[1].text == "Whispers" and buttons[2].text == "Groups", "HUD: tab labels via SetText")
  end

  -- test_hud_tabs_hang_below_the_window_bottom_left
  do
    -- Blizzard's own tabs (CharacterFrameTab1): TOPLEFT to the frame's
    -- BOTTOMLEFT, 11px in, overlapping the bottom border by 2px.
    local toggle, window = createToggle(FakeUI.NewFactory(), true)
    local point = toggle.frame.points[1]
    assert(point[1] == "TOPLEFT" and point[2] == window and point[3] == "BOTTOMLEFT", "HUD: strip hangs from the window bottom-left")
    assert(point[4] == 11 and point[5] == 2, "HUD: Blizzard tab offsets (11, 2), got " .. tostring(point[4]) .. ", " .. tostring(point[5]))
    assert(toggle.frame.height == NativeTabToggle.HEIGHT, "HUD: strip is one tab tall")
  end

  -- test_hud_tabs_stay_in_the_contacts_pane_hierarchy
  do
    -- Parented to the pane so they hide with it (options view), anchored
    -- to the window so they sit outside it; nothing on the way clips.
    local toggle, _, pane = createToggle(FakeUI.NewFactory(), true)
    assert(toggle.frame:GetParent() == pane, "HUD: strip parented to the contacts pane")
  end

  -- test_hud_tabs_reserve_no_list_height
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    toggle.setModes({ "whispers", "groups", "requests" })
    assert(toggle.reservedHeightFor == nil, "HUD: hanging tabs never take list height")
  end

  -- test_hud_tabs_chain_left_to_right_at_natural_width
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    toggle.setModes({ "whispers", "groups", "requests" })
    local buttons = tabs(toggle)
    local p1, p2, p3 = buttons[1].points, buttons[2].points, buttons[3].points
    assert(#p1 == 1 and p1[1][1] == "TOPLEFT" and p1[1][2] == toggle.frame and p1[1][3] == "TOPLEFT", "HUD: first tab at the strip start")
    assert(#p2 == 1 and p2[1][1] == "TOPLEFT" and p2[1][2] == buttons[1] and p2[1][3] == "TOPRIGHT", "HUD: second tab follows the first")
    assert(#p3 == 1 and p3[1][2] == buttons[2] and p3[1][4] == 1, "HUD: Blizzard 1px tab spacing")
    toggle.setModes({ "whispers", "requests" })
    assert(buttons[3].points[1][2] == buttons[1], "HUD: a hidden tab leaves no gap")
  end

  -- test_hud_tabs_size_themselves_on_every_flavor
  do
    -- Classic clients' PanelTemplates_TabResize adds both edge pieces on top
    -- of label + 24 and caps only the label, so tabs size themselves with
    -- Retail's rule instead: label + 20.
    local calls = stubPanelTemplates()
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local whispers = tabs(toggle)[1]
    assert(#calls.resized == 0, "HUD: Blizzard's flavor-specific TabResize is never used")
    assert(whispers.width == whispers:GetTextWidth() + 20, "HUD: tab is label + 20, got " .. tostring(whispers.width))
    clearPanelTemplates()
  end

  -- test_hud_tab_never_narrower_than_its_edge_art
  do
    local factory = FakeUI.NewFactory()
    local toggle = createToggle(factory, true)
    local groups = tabs(toggle)[2]
    groups.Left = factory.CreateFrame("Frame", nil, nil)
    groups.Left:SetWidth(35)
    groups.Right = factory.CreateFrame("Frame", nil, nil)
    groups.Right:SetWidth(37)
    toggle.setLanguage()
    assert(groups.width == 72, "HUD: short label still fits both edge pieces, got " .. tostring(groups.width))
  end

  -- test_hud_tabs_shrink_to_fit_the_window
  do
    -- Each visible tab is capped at an equal share of the strip, less the
    -- last tab's 7px of art overhang and the 1px gaps.
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local strip = toggle.frame
    strip:SetWidth(260)
    strip.scripts.OnSizeChanged(strip, 260, NativeTabToggle.HEIGHT)
    toggle.setModes({ "whispers", "groups", "channels", "requests" })
    assert(strip.maxTabWidth == 62, "HUD: four tabs share 260px, got " .. tostring(strip.maxTabWidth))
    local whispers = tabs(toggle)[1]
    assert(whispers.width == 62, "HUD: a long tab is capped, got " .. tostring(whispers.width))
    assert(whispers.Text == nil or whispers.Text.width == 42, "HUD: its label shortens to fit")
    toggle.setModes({ "whispers", "groups" })
    assert(strip.maxTabWidth == 126, "HUD: two tabs get a wider cap, got " .. tostring(strip.maxTabWidth))
    assert(whispers.width == whispers:GetTextWidth() + 20, "HUD: under the cap a tab keeps its natural width")
    strip:SetWidth(160)
    strip.scripts.OnSizeChanged(strip, 160, NativeTabToggle.HEIGHT)
    assert(strip.maxTabWidth == 76 and whispers.width == 76, "HUD: a narrower window shrinks the cap, got " .. tostring(strip.maxTabWidth))
  end

  -- test_hud_tab_show_keeps_our_size
  do
    -- The template's own OnShow would re-run the flavor's TabResize.
    local calls = stubPanelTemplates()
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local whispers = tabs(toggle)[1]
    whispers:SetWidth(999)
    whispers.scripts.OnShow(whispers)
    assert(whispers.width == whispers:GetTextWidth() + 20, "HUD: showing a tab re-applies our size, got " .. tostring(whispers.width))
    assert(#calls.resized == 0, "HUD: no Blizzard resize on show")
    clearPanelTemplates()
  end

  -- test_hud_unread_badge_sits_on_the_tab_corner
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    local tab = tabs(toggle)[1]
    local point = FindUI.ofType(tab, "Frame")[1].points[1]
    assert(point[1] == "CENTER" and point[2] == tab and point[3] == "TOPRIGHT", "HUD: badge centred on the tab's top-right corner")
    assert(point[4] < 0, "HUD: badge pulled in from the corner so it stays over its own tab, got x " .. tostring(point[4]))
  end

  -- test_hud_unread_badge_draws_above_the_window_border
  do
    -- The badge straddles the window's bottom edge; the template's border
    -- art sits on a high frame level and would hide its top half.
    local factory = FakeUI.NewFactory()
    local window = factory.CreateFrame("Frame", nil, nil, "ButtonFrameTemplate")
    window.NineSlice:SetFrameLevel(500)
    local pane = factory.CreateFrame("Frame", nil, window)
    local toggle = TabToggle.Create(factory, pane, { initialMode = "whispers", nativeChrome = true, windowFrame = window })
    local badge = FindUI.ofType(tabs(toggle)[1], "Frame")[1]
    assert(badge:GetFrameLevel() > 500, "HUD: badge above the border art, got level " .. tostring(badge:GetFrameLevel()))
  end

  -- test_hud_unread_badge_never_sinks_below_its_own_tab
  do
    -- A flavor whose border art sits low must not pull the badge under its tab.
    -- Like the game, a new frame starts one level above its parent.
    local factory = FakeUI.NewFactory()
    local createFrame = factory.CreateFrame
    factory.CreateFrame = function(frameType, name, parent, template)
      local frame = createFrame(frameType, name, parent, template)
      if parent and parent.GetFrameLevel then
        frame:SetFrameLevel(parent:GetFrameLevel() + 1)
      end
      return frame
    end
    local window = factory.CreateFrame("Frame", nil, nil, "ButtonFrameTemplate")
    window:SetFrameLevel(10)
    window.NineSlice:SetFrameLevel(10)
    local pane = factory.CreateFrame("Frame", nil, window)
    local toggle = TabToggle.Create(factory, pane, { initialMode = "whispers", nativeChrome = true, windowFrame = window })
    local tab = tabs(toggle)[1]
    local badge = FindUI.ofType(tab, "Frame")[1]
    assert(
      badge:GetFrameLevel() > tab:GetFrameLevel(),
      "HUD: badge above its own tab, got badge " .. tostring(badge:GetFrameLevel()) .. " tab " .. tostring(tab:GetFrameLevel())
    )
  end

  -- test_hud_tab_width_fallback_without_tab_resize
  do
    local buttons = tabs(createToggle(FakeUI.NewFactory(), true))
    assert(buttons[1].width > buttons[1]:GetTextWidth(), "HUD: tab wider than its label without PanelTemplates_TabResize")
  end

  -- test_hud_tabs_draw_no_custom_lines
  do
    local toggle = createToggle(FakeUI.NewFactory(), true)
    assert(#FindUI.ofType(toggle.frame, "Texture") == 0, "HUD: no custom paint on the strip")
    for _, child in ipairs(FindUI.ofType(toggle.frame, "Frame")) do
      assert(child:GetParent() ~= toggle.frame, "HUD: no overlay line layer, Blizzard tabs have no seams")
    end
  end

  -- test_hud_clamp_counts_the_hanging_tabs
  do
    local factory = FakeUI.NewFactory()
    local window = factory.CreateFrame("Frame", nil, nil)
    window:SetClampRectInsets(-5, 5, 7, 3)
    local pane = factory.CreateFrame("Frame", nil, window)
    local toggle = TabToggle.Create(factory, pane, { nativeChrome = true, windowFrame = window })
    toggle.setShown(true)
    local hang = NativeTabToggle.HEIGHT - 2
    local l, r, t, b = window:GetClampRectInsets()
    assert(l == -5 and r == 5 and t == 7, "HUD: other clamp insets kept")
    assert(b == 3 - hang, "HUD: bottom clamp extends by the visible tab height, got " .. tostring(b))
    toggle.setShown(false)
    assert(select(4, window:GetClampRectInsets()) == 3, "HUD: hidden tabs restore the window's own clamp")
    toggle.setShown(true)
    assert(select(4, window:GetClampRectInsets()) == 3 - hang, "HUD: shown again re-extends the clamp")
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
    assert(tabs(toggle)[1].template == nil, "fallback: modern tab buttons")
  end

  -- test_modern_tabs_hang_below_the_window_too
  do
    local toggle, window, pane = createToggle(FakeUI.NewFactory(), false)
    local pt = toggle.frame.points[1]
    assert(pt[1] == "TOPLEFT" and pt[2] == window and pt[3] == "BOTTOMLEFT", "modern: tabs hang from the window bottom-left")
    assert(toggle.frame:GetParent() == pane, "modern: tabs hide with the contacts pane")
    assert(toggle.frame.height == TabToggle.HEIGHT, "modern: one tab tall")
    assert(tabs(toggle)[1].template == nil, "modern: plain buttons")
    assert(#FindUI.ofType(toggle.frame, "Texture") == 0, "modern: no in-pane footer bar")
  end
end
