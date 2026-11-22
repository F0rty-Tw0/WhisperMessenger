local FakeUI = require("tests.helpers.fake_ui")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")

-- WM's own right-click popup: a Blizzard-like builder, drawn without the
-- game's menus.

local function noop() end

return function()
  local factory = FakeUI.NewFactory()
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, _G.CreateFrame, _G.UISpecialFrames
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  local anchorA = factory.CreateFrame("Button", nil, _G.UIParent)
  local anchorB = factory.CreateFrame("Button", nil, _G.UIParent)
  anchorA:Show()
  anchorB:Show()

  -- test_builder_makes_rows_in_order_without_blizzard_menus
  BannedMenuApis.With(function(calls)
    assert(MenuPopup.Open(anchorA, function(root)
      root:CreateTitle("Arthas")
      root:CreateButton("Open chat", noop)
      root:CreateDivider()
      root:CreateCheckbox("Notify", function()
        return true
      end, noop)
    end) == true, "popup opens")
    assert(MenuPopup.IsShown(), "popup shown")
    local labels = table.concat(Probe.Labels(), ",")
    assert(labels == "title:Arthas,button:Open chat,divider,checkbox:Notify", "rows in order, got " .. labels)
    assert(Probe.Find("Arthas").region:GetObjectType() == "FontString", "title is a FontString")
    assert(Probe.Find("Open chat").region:GetObjectType() == "Button", "button row is a Button")
    assert(MenuPopup.Rows()[3].region:GetObjectType() == "Texture", "divider is a Texture")
    assert(Probe.Find("Notify").checked == true, "checkbox tick follows isSelected")
    assert(#calls == 0, "touched " .. table.concat(calls, ", "))
  end)

  -- test_click_runs_handler_with_no_args_then_closes
  do
    local argc
    MenuPopup.Open(anchorA, function(root)
      root:CreateButton("Go", function(...)
        argc = select("#", ...)
      end)
    end)
    Probe.Click("Go")
    assert(argc == 0, "handler gets no arguments, got " .. tostring(argc))
    assert(not MenuPopup.IsShown(), "click closes the popup")
  end

  -- test_submenu_call_errors
  do
    local element
    MenuPopup.Open(anchorA, function(root)
      element = root:CreateButton("Copy profile link")
    end)
    local ok, err = pcall(function()
      element:CreateButton("Raider.IO")
    end)
    assert(not ok and string.find(tostring(err), "MenuPopup: no submenus", 1, true), "submenu raises, got " .. tostring(err))
  end

  -- test_checkbox_click_calls_onSelect_then_closes
  do
    local selected = 0
    MenuPopup.Open(anchorA, function(root)
      root:CreateCheckbox("Notify", function()
        return false
      end, function()
        selected = selected + 1
      end)
    end)
    Probe.Click("Notify")
    assert(selected == 1, "onSelect runs once, ran " .. selected)
    assert(not MenuPopup.IsShown(), "checkbox click closes the popup")
  end

  -- test_disabled_row_ignores_click
  do
    local clicked = 0
    MenuPopup.Open(anchorA, function(root)
      local element = root:CreateButton("Invite", function()
        clicked = clicked + 1
      end)
      element:SetEnabled(false)
    end)
    Probe.Click("Invite")
    assert(clicked == 0, "disabled row runs nothing")
    assert(MenuPopup.IsShown(), "disabled row keeps the popup open")
    assert(Probe.Find("Invite").enabled == false, "row reports disabled")
    assert(Probe.Find("Invite").region:GetObjectType() == "Button", "disabled row is still a Button")
    MenuPopup.Close()
  end

  -- test_reopen_refills_and_reanchors_one_popup
  do
    MenuPopup.Open(anchorA, function(root)
      root:CreateButton("One", noop)
      root:CreateButton("Two", noop)
      root:CreateButton("Three", noop)
    end)
    local first = MenuPopup.GetFrame()
    MenuPopup.Open(anchorB, function(root)
      root:CreateButton("Only", noop)
    end)
    assert(MenuPopup.GetFrame() == first, "one popup frame")
    assert(#MenuPopup.Rows() == 1, "rows refilled, got " .. #MenuPopup.Rows())
    assert(select(2, first:GetPoint(1)) == anchorB, "popup moves to the new anchor")
    local buttons = { first:GetChildren() }
    local seen = 0
    for _, child in ipairs(buttons) do
      if child:GetObjectType() == "Button" then
        seen = seen + 1
        if seen > 1 then
          assert(not child:IsShown(), "row past the fill is hidden")
        end
      end
    end
    assert(seen >= 3, "pooled rows kept, saw " .. seen)
  end

  -- test_long_title_stays_inside_panel
  do
    local text = string.rep("x", 60)
    MenuPopup.Open(anchorA, function(root)
      root:CreateTitle(text)
      root:CreateButton("Go", noop)
    end)
    local region = Probe.Find(text).region
    assert(region.wordWrap == false, "title does not wrap")
    assert(region:GetWidth() <= MenuPopup.GetFrame():GetWidth(), "title fits the panel")
  end

  -- test_open_refuses_without_anchor_build_or_rows
  do
    assert(MenuPopup.Open(nil, function(root)
      root:CreateButton("Go", noop)
    end) == false, "no anchor")
    assert(MenuPopup.Open(anchorA, nil) == false, "no build")
    assert(MenuPopup.Open(anchorA, noop) == false, "no rows")
    assert(not MenuPopup.IsShown(), "nothing shown")
  end

  -- test_popup_sits_beside_anchor
  do
    MenuPopup.Open(anchorA, function(root)
      root:CreateButton("Go", noop)
    end)
    assert(select(2, MenuPopup.GetFrame():GetPoint(1)) == anchorA, "anchored to the clicked frame")
    MenuPopup.Close()
  end

  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
end
