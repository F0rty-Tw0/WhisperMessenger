local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local World = require("tests.helpers.menu_popup_world")

-- WM's own right-click popup: a Blizzard-like builder, drawn without the
-- game's menus.

local function noop() end

local function fourRows(root)
  root:CreateTitle("Arthas")
  root:CreateButton("Open chat", noop)
  root:CreateDivider()
  root:CreateCheckbox("Notify", function()
    return true
  end, noop)
end

local function oneButton(root)
  root:CreateButton("Go", noop)
end

-- Runs fn() with GetCursorPosition answering x, y.
local function withCursor(x, y, fn)
  local saved = rawget(_G, "GetCursorPosition")
  rawset(_G, "GetCursorPosition", function()
    return x, y
  end)
  local ok, err = pcall(fn)
  rawset(_G, "GetCursorPosition", saved)
  if not ok then
    error(err, 0)
  end
end

-- A mouse-down over `target` once the popup's dismissal is armed.
local function clickOver(target)
  local popup = MenuPopup.GetFrame()
  popup:GetScript("OnUpdate")(popup)
  target.mouseOver = true
  popup:GetScript("OnEvent")(popup, "GLOBAL_MOUSE_DOWN")
  target.mouseOver = false
end

local function runBuilderCases()
  -- test_builder_makes_rows_in_order
  World.With(function(_factory, anchor)
    assert(MenuPopup.Open(anchor, fourRows) == true, "popup opens")
    local labels = table.concat(Probe.Labels(), ",")
    assert(labels == "title:Arthas,button:Open chat,divider,checkbox:Notify", "rows in order, got " .. labels)
  end)

  -- test_open_shows_the_popup
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, fourRows)
    assert(MenuPopup.IsShown(), "popup shown")
  end)

  -- test_rows_use_game_region_types
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, fourRows)
    assert(Probe.Find("Arthas").region:GetObjectType() == "FontString", "title is a FontString")
    assert(Probe.Find("Open chat").region:GetObjectType() == "Button", "button row is a Button")
    assert(MenuPopup.Rows()[3].region:GetObjectType() == "Texture", "divider is a Texture")
  end)

  -- test_checkbox_tick_follows_isSelected
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, fourRows)
    assert(Probe.Find("Notify").checked == true, "checkbox tick follows isSelected")
  end)

  -- test_open_touches_no_blizzard_menu
  World.With(function(_factory, anchor)
    BannedMenuApis.AssertNone(function()
      MenuPopup.Open(anchor, fourRows)
    end)
  end)

  -- test_submenu_call_errors
  World.With(function(_factory, anchor)
    local element
    MenuPopup.Open(anchor, function(root)
      element = root:CreateButton("Copy profile link")
    end)
    local ok, err = pcall(function()
      element:CreateButton("Raider.IO")
    end)
    assert(not ok and string.find(tostring(err), "MenuPopup: no submenus", 1, true), "submenu raises, got " .. tostring(err))
  end)
end

local function runClickCases()
  -- test_click_runs_handler_with_no_args
  World.With(function(_factory, anchor)
    local argc
    MenuPopup.Open(anchor, function(root)
      root:CreateButton("Go", function(...)
        argc = select("#", ...)
      end)
    end)
    Probe.Click("Go")
    assert(argc == 0, "handler gets no arguments, got " .. tostring(argc))
  end)

  -- test_click_closes_the_popup
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, oneButton)
    Probe.Click("Go")
    assert(not MenuPopup.IsShown(), "click closes the popup")
  end)

  -- test_checkbox_click_calls_onSelect_then_closes
  World.With(function(_factory, anchor)
    local selected = 0
    MenuPopup.Open(anchor, function(root)
      root:CreateCheckbox("Notify", function()
        return false
      end, function()
        selected = selected + 1
      end)
    end)
    Probe.Click("Notify")
    assert(selected == 1, "onSelect runs once, ran " .. selected)
    assert(not MenuPopup.IsShown(), "checkbox click closes the popup")
  end)

  -- test_disabled_row_ignores_click
  World.With(function(_factory, anchor)
    local clicked = 0
    MenuPopup.Open(anchor, function(root)
      local element = root:CreateButton("Invite", function()
        clicked = clicked + 1
      end)
      element:SetEnabled(false)
    end)
    Probe.Click("Invite")
    assert(clicked == 0, "disabled row runs nothing")
    assert(MenuPopup.IsShown(), "disabled row keeps the popup open")
  end)

  -- test_disabled_row_reports_disabled
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, function(root)
      root:CreateButton("Invite", noop):SetEnabled(false)
    end)
    assert(Probe.Find("Invite").enabled == false, "row reports disabled")
    assert(Probe.Find("Invite").region:GetObjectType() == "Button", "disabled row is still a Button")
  end)
end

local function runLayoutCases()
  -- test_reopen_refills_and_reanchors_one_popup
  World.With(function(factory, anchor)
    local other = factory.CreateFrame("Button", nil, _G.UIParent)
    other:Show()
    MenuPopup.Open(anchor, function(root)
      root:CreateButton("One", noop)
      root:CreateButton("Two", noop)
      root:CreateButton("Three", noop)
    end)
    local first = MenuPopup.GetFrame()
    MenuPopup.Open(other, oneButton)
    assert(MenuPopup.GetFrame() == first, "one popup frame")
    assert(#MenuPopup.Rows() == 1, "rows refilled, got " .. #MenuPopup.Rows())
    assert(select(2, first:GetPoint(1)) == other, "popup moves to the new anchor")
  end)

  -- test_reopen_hides_pooled_rows_past_the_fill
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, function(root)
      root:CreateButton("One", noop)
      root:CreateButton("Two", noop)
      root:CreateButton("Three", noop)
    end)
    MenuPopup.Open(anchor, oneButton)
    local seen = 0
    for _, child in ipairs({ MenuPopup.GetFrame():GetChildren() }) do
      if child:GetObjectType() == "Button" then
        seen = seen + 1
        assert(seen == 1 or not child:IsShown(), "row past the fill is hidden")
      end
    end
    assert(seen >= 3, "pooled rows kept, saw " .. seen)
  end)

  -- test_long_title_does_not_wrap
  World.With(function(_factory, anchor)
    local text = string.rep("x", 60)
    MenuPopup.Open(anchor, function(root)
      root:CreateTitle(text)
      root:CreateButton("Go", noop)
    end)
    assert(Probe.Find(text).region.wordWrap == false, "title does not wrap")
  end)

  -- test_long_title_stays_inside_panel
  World.With(function(_factory, anchor)
    local text = string.rep("x", 60)
    MenuPopup.Open(anchor, function(root)
      root:CreateTitle(text)
      root:CreateButton("Go", noop)
    end)
    local region = Probe.Find(text).region
    local right = select(4, region:GetPoint(1)) + region:GetWidth()
    local panelWidth = MenuPopup.GetFrame():GetWidth()
    assert(right <= panelWidth, "title ends inside the panel: " .. right .. " > " .. panelWidth)
  end)

  -- test_open_refuses_without_anchor_build_or_rows
  World.With(function(_factory, anchor)
    assert(MenuPopup.Open(nil, oneButton) == false, "no anchor")
    assert(MenuPopup.Open(anchor, nil) == false, "no build")
    assert(MenuPopup.Open(anchor, noop) == false, "no rows")
    assert(not MenuPopup.IsShown(), "nothing shown")
  end)
end

local function runPlacementCases()
  -- test_popup_sits_beside_anchor
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, oneButton)
    local point, relativeTo, relativePoint = MenuPopup.GetFrame():GetPoint(1)
    assert(point == "TOPLEFT" and relativeTo == anchor and relativePoint == "TOPRIGHT", "beside the clicked frame")
  end)

  -- test_click_on_anchor_keeps_anchored_popup
  World.With(function(_factory, anchor)
    MenuPopup.Open(anchor, oneButton)
    clickOver(anchor)
    assert(MenuPopup.IsShown(), "a click on the launcher is not outside")
  end)

  -- test_at_cursor_popup_sits_at_the_cursor
  World.With(function(_factory, anchor)
    _G.UIParent:SetScale(2)
    withCursor(300, 500, function()
      MenuPopup.Open(anchor, oneButton, { atCursor = true })
    end)
    local point, relativeTo, relativePoint, x, y = MenuPopup.GetFrame():GetPoint(1)
    assert(point == "TOPLEFT" and relativeTo == _G.UIParent and relativePoint == "BOTTOMLEFT", "pinned to UIParent")
    assert(x == 150 and y == 250, "cursor in UIParent units, got " .. tostring(x) .. ", " .. tostring(y))
  end)

  -- test_at_cursor_without_cursor_sits_beside_anchor
  World.With(function(_factory, anchor)
    withCursor(nil, nil, function()
      MenuPopup.Open(anchor, oneButton, { atCursor = true })
    end)
    assert(select(2, MenuPopup.GetFrame():GetPoint(1)) == anchor, "falls back to the anchor")
  end)

  -- test_click_on_anchor_closes_cursor_popup
  World.With(function(_factory, anchor)
    withCursor(300, 500, function()
      MenuPopup.Open(anchor, oneButton, { atCursor = true })
    end)
    clickOver(anchor)
    assert(not MenuPopup.IsShown(), "a click elsewhere on a large anchor closes it")
  end)

  -- test_cursor_popup_hides_with_its_anchor
  World.With(function(_factory, anchor)
    withCursor(300, 500, function()
      MenuPopup.Open(anchor, oneButton, { atCursor = true })
    end)
    anchor:Hide()
    assert(not MenuPopup.IsShown(), "popup hides with its anchor")
  end)
end

return function()
  runBuilderCases()
  runClickCases()
  runLayoutCases()
  runPlacementCases()
end
