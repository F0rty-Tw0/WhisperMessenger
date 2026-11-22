local FakeUI = require("tests.helpers.fake_ui")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")

-- On WoW: Forever the contact and group menus are WM's own popup; Retail
-- keeps Blizzard's player menu and MenuUtil.

local function noop() end

local function contact()
  return { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas", conversation = { messages = {} } }
end

local function hasTitle(labels)
  for _, label in ipairs(labels) do
    if string.sub(label, 1, 6) == "title:" then
      return true
    end
  end
  return false
end

return function()
  local factory = FakeUI.NewFactory()
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, rawget(_G, "CreateFrame"), _G.UISpecialFrames
  local savedMenu, savedMenuUtil, savedUnitPopup = rawget(_G, "Menu"), rawget(_G, "MenuUtil"), rawget(_G, "UnitPopup_OpenMenu")
  Localization.Configure({ language = "enUS" })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  anchor:Show()

  local ok, err = pcall(function()
    -- test_forever_contact_opens_own_popup_and_no_blizzard_menu
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        local rowActions = { onSelect = noop, onPin = noop }
        assert(ContextMenu.Open(contact(), anchor, noop, noop, rowActions) == true, "menu opens")
        local labels = Probe.Labels()
        assert(labels[1] == "title:Arthas-Area52" and labels[2] == "button:Open chat" and labels[3] == "button:Copy name", "contact rows first")
        assert(labels[4] == "divider" and labels[5] == "title:Whisper Messenger", "WM section after them")
        for _, text in ipairs({ "Mark last messages as unread", "Export conversation", "Mute", "Pin to top" }) do
          assert(Probe.Find(text) ~= nil, "WM entry " .. text)
        end
        assert(Probe.Find("Mark last messages as unread").enabled == false, "nothing unanswered: Mark unread disabled")
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_forever_contact_without_handlers_has_no_wm_section
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        assert(ContextMenu.Open(contact(), anchor) == true, "menu opens")
        local got = table.concat(Probe.Labels(), ",")
        assert(got == "title:Arthas-Area52,button:Copy name", "no WM section, got " .. got)
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_forever_group_row_opens_own_popup
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        local group = { channel = "PARTY", displayName = "Party", conversation = { messages = {} } }
        assert(ContextMenu.Open(group, anchor, nil, noop) == true, "group menu opens")
        assert(Probe.Find("Mute") ~= nil, "group Mute")
        assert(Probe.Find("Export conversation") ~= nil, "group Export")
        assert(not hasTitle(Probe.Labels()), "group popup has no title, got " .. table.concat(Probe.Labels(), ","))
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_retail_contact_still_opens_unit_popup
    Flavor.With(true, false, function()
      local which
      rawset(_G, "Menu", { ModifyMenu = noop })
      rawset(_G, "UnitPopup_OpenMenu", function(menuName)
        which = menuName
      end)
      assert(ContextMenu.Open(contact(), anchor, noop, noop) == true, "retail menu opens")
      assert(which == "FRIEND", "retail opens the FRIEND player menu, got " .. tostring(which))
      assert(not MenuPopup.IsShown(), "retail never shows WM's popup")
    end)

    -- test_retail_group_still_uses_menu_util
    Flavor.With(true, false, function()
      local created = 0
      rawset(_G, "MenuUtil", {
        CreateContextMenu = function()
          created = created + 1
        end,
      })
      local group = { channel = "PARTY", displayName = "Party", conversation = { messages = {} } }
      assert(ContextMenu.Open(group, anchor, nil, noop) == true, "retail group menu opens")
      assert(created == 1, "MenuUtil.CreateContextMenu called once, got " .. created)
      assert(not MenuPopup.IsShown(), "retail never shows WM's popup")
    end)
  end)

  MenuPopup.Close()
  rawset(_G, "Menu", savedMenu)
  rawset(_G, "MenuUtil", savedMenuUtil)
  rawset(_G, "UnitPopup_OpenMenu", savedUnitPopup)
  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
  if not ok then
    error(err, 0)
  end
end
