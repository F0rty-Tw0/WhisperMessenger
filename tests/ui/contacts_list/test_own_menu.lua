local FakeUI = require("tests.helpers.fake_ui")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local Localization = require("WhisperMessenger.Locale.Localization")
local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
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

return function()
  local factory = FakeUI.NewFactory()
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, rawget(_G, "CreateFrame"), _G.UISpecialFrames
  local savedShow = PopupUI.ShowManualCopyDialog
  Localization.Configure({ language = "enUS" })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  anchor:Show()
  local copied, prompt
  rawset(PopupUI, "ShowManualCopyDialog", function(text, options)
    copied = text
    prompt = options and options.prompt
  end)

  local ok, err = pcall(function()
    -- test_rows_in_spec_order
    BannedMenuApis.With(function(calls)
      local item = wowItem()
      assert(OwnMenu.Open(item, anchor, NAME, { onSelect = noop }, wmSection) == true, "popup opens")
      local got = labels()
      assert(got == "title:Arthas-Area52,button:Open chat,button:Copy name,divider,title:Whisper Messenger,button:Mute", "rows in order, got " .. got)
      assert(#calls == 0, "touched " .. table.concat(calls, ", "))
    end)

    -- test_open_chat_calls_onSelect_with_item
    do
      local item = wowItem()
      local selected
      OwnMenu.Open(item, anchor, NAME, {
        onSelect = function(it)
          selected = it
        end,
      }, noop)
      Probe.Click("Open chat")
      assert(selected == item, "Open chat selects the row's item")
    end

    -- test_no_open_chat_without_onSelect
    OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
    assert(labels() == "title:Arthas-Area52,button:Copy name", "no Open chat without rowActions, got " .. labels())
    OwnMenu.Open(wowItem(), anchor, NAME, { onPin = noop }, noop)
    assert(labels() == "title:Arthas-Area52,button:Copy name", "no Open chat without onSelect, got " .. labels())

    -- test_copy_name_opens_copy_dialog
    Flavor.With(true, false, function()
      copied, prompt = nil, nil
      OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
      Probe.Click("Copy name")
      assert(copied == "Arthas-Area52", "Retail copies the full name, got " .. tostring(copied))
      assert(prompt == "Press Ctrl+C to copy the name.", "copy prompt")
    end)
    Flavor.With(true, true, function()
      copied, prompt = nil, nil
      OwnMenu.Open(wowItem(), anchor, NAME, nil, noop)
      Probe.Click("Copy name")
      assert(copied == "Arthas", "Forever cuts the realm, got " .. tostring(copied))
      assert(prompt == "Press Ctrl+C to copy the name.", "copy prompt")
    end)

    -- test_copy_name_absent_on_bn_contact
    OwnMenu.Open({ channel = "BN", displayName = "Jaina", battleTag = "Jaina#1" }, anchor, "Jaina", nil, noop)
    assert(Probe.Find("Copy name") == nil, "no Copy name on a BN contact")

    -- test_empty_wm_section_adds_nothing
    OwnMenu.Open(wowItem(), anchor, NAME, { onSelect = noop }, noop)
    assert(not string.find(labels(), "divider", 1, true), "empty WM section adds no divider, got " .. labels())
  end)

  MenuPopup.Close()
  rawset(PopupUI, "ShowManualCopyDialog", savedShow)
  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
  assert(ok, err)
end
