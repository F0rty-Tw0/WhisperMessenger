local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local World = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")

-- On WoW: Forever with the gamepad UI on the contact and group menus are
-- WM's own popup; Retail, and Forever with the mouse, keep Blizzard's player
-- menu and MenuUtil.

local STUBBED = { "Menu", "MenuUtil", "UnitPopup_OpenMenu" }

local function noop() end

local function contact()
  return { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas", conversation = { messages = {} } }
end

local function group()
  return { channel = "PARTY", displayName = "Party", conversation = { messages = {} } }
end

local function hasTitle(labels)
  for _, label in ipairs(labels) do
    if string.sub(label, 1, 6) == "title:" then
      return true
    end
  end
  return false
end

-- Runs fn(anchor) on Forever with the pad UI on in a popup world; no Blizzard
-- menu may be hit.
local function onForever(fn)
  Flavor.With(true, true, function()
    Flavor.WithPadUI(true, function()
      World.With(function(_factory, anchor)
        BannedMenuApis.AssertNone(function()
          fn(anchor)
        end)
      end)
    end)
  end)
end

-- Runs fn(anchor) in a popup world on Retail (isForever false) or on Forever
-- with the mouse (isForever true, pad UI off), restoring the menu globals.
local function onBlizzardMenus(isForever, fn)
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = rawget(_G, name)
  end
  local ok, err = pcall(Flavor.With, true, isForever, function()
    Flavor.WithPadUI(false, function()
      World.With(function(_factory, anchor)
        fn(anchor)
      end)
    end)
  end)
  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  if not ok then
    error(err, 0)
  end
end

local function runForeverCases()
  -- test_forever_contact_rows_come_first
  onForever(function(anchor)
    assert(ContextMenu.Open(contact(), anchor, noop, noop, { onSelect = noop, onPin = noop }) == true, "menu opens")
    local labels = Probe.Labels()
    assert(labels[1] == "title:Arthas-Area52" and labels[2] == "button:Open chat" and labels[3] == "button:Copy name", "contact rows first")
  end)

  -- test_forever_wm_section_follows_contact_rows
  onForever(function(anchor)
    ContextMenu.Open(contact(), anchor, noop, noop, { onSelect = noop, onPin = noop })
    local labels = Probe.Labels()
    assert(labels[4] == "divider" and labels[5] == "title:Whisper Messenger", "WM section after them")
    for _, text in ipairs({ "Mark last messages as unread", "Export conversation", "Mute", "Pin to top" }) do
      assert(Probe.Find(text) ~= nil, "WM entry " .. text)
    end
  end)

  -- test_forever_mark_unread_disabled_without_unanswered
  onForever(function(anchor)
    ContextMenu.Open(contact(), anchor, noop, noop)
    assert(Probe.Find("Mark last messages as unread").enabled == false, "nothing unanswered: Mark unread disabled")
  end)

  -- test_forever_contact_without_handlers_has_no_wm_section
  onForever(function(anchor)
    assert(ContextMenu.Open(contact(), anchor) == true, "menu opens")
    local got = table.concat(Probe.Labels(), ",")
    assert(got == "title:Arthas-Area52,button:Copy name", "no WM section, got " .. got)
  end)

  -- test_forever_contact_without_anchor_opens_nothing
  onForever(function()
    assert(ContextMenu.Open(contact(), nil) == false, "no anchor: no menu")
    assert(not MenuPopup.IsShown(), "no popup without an anchor")
  end)

  -- test_forever_group_row_opens_own_popup
  onForever(function(anchor)
    assert(ContextMenu.Open(group(), anchor, nil, noop) == true, "group menu opens")
    assert(Probe.Find("Mute") ~= nil, "group Mute")
    assert(Probe.Find("Export conversation") ~= nil, "group Export")
  end)

  -- test_forever_group_popup_has_no_title
  onForever(function(anchor)
    ContextMenu.Open(group(), anchor, nil, noop)
    assert(not hasTitle(Probe.Labels()), "group popup has no title, got " .. table.concat(Probe.Labels(), ","))
  end)
end

-- test_retail_contact_still_opens_unit_popup, test_forever_pad_off_contact_opens_unit_popup
-- test_retail_group_still_uses_menu_util, test_forever_pad_off_group_uses_menu_util
local function runBlizzardMenuCases(label, isForever)
  onBlizzardMenus(isForever, function(anchor)
    local which
    rawset(_G, "Menu", { ModifyMenu = noop })
    rawset(_G, "UnitPopup_OpenMenu", function(menuName)
      which = menuName
    end)
    assert(ContextMenu.Open(contact(), anchor, noop, noop) == true, label .. ": menu opens")
    assert(which == "FRIEND", label .. ": opens the FRIEND player menu, got " .. tostring(which))
    assert(not MenuPopup.IsShown(), label .. ": never shows WM's popup")
  end)

  onBlizzardMenus(isForever, function(anchor)
    local created = 0
    rawset(_G, "MenuUtil", {
      CreateContextMenu = function()
        created = created + 1
      end,
    })
    assert(ContextMenu.Open(group(), anchor, nil, noop) == true, label .. ": group menu opens")
    assert(created == 1, label .. ": MenuUtil.CreateContextMenu called once, got " .. created)
    assert(not MenuPopup.IsShown(), label .. ": never shows WM's popup")
  end)
end

return function()
  Localization.Configure({ language = "enUS" })
  runForeverCases()
  runBlizzardMenuCases("retail", false)
  runBlizzardMenuCases("forever with the mouse", true)
end
