local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local World = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local OwnMenu = require("WhisperMessenger.UI.ContactsList.OwnMenu")

-- WM's own contact popup on WoW: Forever: title, Open chat, Copy name, the
-- WM section, then Report.

local NAME = "Arthas-Area52"

local function wmSection(root)
  root:CreateDivider()
  root:CreateTitle("|cffffd100Whisper Messenger|r")
  root:CreateButton("Mute", function() end)
end

local function noop() end

local function labels()
  return table.concat(Probe.Labels(), ",")
end

local function wowItem()
  return { channel = "WOW", displayName = NAME, guid = "Player-1-A" }
end

-- Runs fn(anchor, copied) with the copy dialog replaced by a recorder:
-- copied.text and copied.prompt hold the last call.
local function withCopyDialog(fn)
  local savedShow = PopupUI.ShowManualCopyDialog
  local copied = {}
  rawset(PopupUI, "ShowManualCopyDialog", function(text, options)
    copied.text = text
    copied.prompt = options and options.prompt
  end)
  local ok, err = pcall(World.With, function(_factory, anchor)
    fn(anchor, copied)
  end)
  rawset(PopupUI, "ShowManualCopyDialog", savedShow)
  if not ok then
    error(err, 0)
  end
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_rows_in_spec_order
  World.With(function(_factory, anchor)
    assert(OwnMenu.Open(wowItem(), anchor, NAME, { onSelect = noop }, wmSection) == true, "popup opens")
    local got = labels()
    assert(got == "title:Arthas-Area52,button:Open chat,button:Copy name,divider,title:Whisper Messenger,button:Mute", "rows in order, got " .. got)
  end)

  -- test_open_touches_no_blizzard_menu
  World.With(function(_factory, anchor)
    BannedMenuApis.AssertNone(function()
      OwnMenu.Open(wowItem(), anchor, NAME, { onSelect = noop }, wmSection)
    end)
  end)

  -- test_open_chat_calls_onSelect_with_item
  World.With(function(_factory, anchor)
    local item = wowItem()
    local selected
    OwnMenu.Open(item, anchor, NAME, {
      onSelect = function(it)
        selected = it
      end,
    }, noop)
    Probe.Click("Open chat")
    assert(selected == item, "Open chat selects the row's item")
  end)

  -- test_no_open_chat_without_rowActions
  World.With(function(_factory, anchor)
    OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
    assert(labels() == "title:Arthas-Area52,button:Copy name", "no Open chat without rowActions, got " .. labels())
  end)

  -- test_no_open_chat_without_onSelect
  World.With(function(_factory, anchor)
    OwnMenu.Open(wowItem(), anchor, NAME, { onPin = noop }, noop)
    assert(labels() == "title:Arthas-Area52,button:Copy name", "no Open chat without onSelect, got " .. labels())
  end)

  -- test_copy_name_keeps_realm_on_retail
  Flavor.With(true, false, function()
    withCopyDialog(function(anchor, copied)
      OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
      Probe.Click("Copy name")
      assert(copied.text == "Arthas-Area52", "Retail copies the full name, got " .. tostring(copied.text))
    end)
  end)

  -- test_copy_name_cuts_realm_on_forever
  Flavor.With(true, true, function()
    withCopyDialog(function(anchor, copied)
      OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
      Probe.Click("Copy name")
      assert(copied.text == "Arthas", "Forever cuts the realm, got " .. tostring(copied.text))
    end)
  end)

  -- test_copy_name_prompt
  withCopyDialog(function(anchor, copied)
    OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
    Probe.Click("Copy name")
    assert(copied.prompt == "Press Ctrl+C to copy the name.", "copy prompt, got " .. tostring(copied.prompt))
  end)

  -- test_copy_name_absent_on_bn_contact
  World.With(function(_factory, anchor)
    OwnMenu.Open({ channel = "BN", displayName = "Jaina", battleTag = "Jaina#1" }, anchor, "Jaina", nil, noop)
    assert(Probe.Find("Copy name") == nil, "no Copy name on a BN contact")
  end)

  -- test_empty_wm_section_adds_nothing
  World.With(function(_factory, anchor)
    OwnMenu.Open(wowItem(), anchor, NAME, { onSelect = noop }, noop)
    assert(not string.find(labels(), "divider", 1, true), "empty WM section adds no divider, got " .. labels())
  end)
end
