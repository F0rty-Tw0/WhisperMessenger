-- On WoW: Forever a right-click on one of our encoded player name links opens
-- WM's own contact popup; Blizzard's chat-frame handler would open a Blizzard
-- menu there, which taints from addon code. Every other click is unchanged.
local FakeUI = require("tests.helpers.fake_ui")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local LinkClicks = require("WhisperMessenger.UI.Hyperlinks.LinkClicks")
local ContactsContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")

local TEMPLATE = "InlineHyperlinkFrameTemplate"
local LINK = "addon:WhisperMessenger:player:Gurkan Warbringer-Realm:42:CHANNEL:Trade"
local WHISPER_LINK = "addon:WhisperMessenger:player:Arthas:7:WHISPER:Arthas"
local GM_LINK = "addon:WhisperMessenger:playerGM:GM:1"
local STUBBED = { "ChatFrameMixin", "IsModifiedClick" }

-- Runs fn(opened) with ContextMenu.Open replaced by a spy that records each
-- { item, anchor } it gets, and IsModifiedClick answering false.
local function withMenuSpy(fn)
  local savedOpen = rawget(ContactsContextMenu, "Open")
  local savedModified = rawget(_G, "IsModifiedClick")
  local opened = {}
  rawset(ContactsContextMenu, "Open", function(item, anchor)
    table.insert(opened, { item = item, anchor = anchor })
    return true
  end)
  rawset(_G, "IsModifiedClick", function()
    return false
  end)
  local ok, err = pcall(fn, opened)
  rawset(ContactsContextMenu, "Open", savedOpen)
  rawset(_G, "IsModifiedClick", savedModified)
  if not ok then
    error(err, 0)
  end
end

-- Runs fn(mixinCalls) with a recording ChatFrameMixin.OnHyperlinkClick.
local function withChatHandler(fn)
  local saved = {}
  for _, key in ipairs(STUBBED) do
    saved[key] = rawget(_G, key)
  end
  local mixinCalls = {}
  rawset(_G, "ChatFrameMixin", {
    OnHyperlinkClick = function(_self, link)
      table.insert(mixinCalls, link)
    end,
  })
  local ok, err = pcall(fn, mixinCalls)
  for _, key in ipairs(STUBBED) do
    rawset(_G, key, saved[key])
  end
  if not ok then
    error(err, 0)
  end
end

local function newTemplatedFrame(factory)
  local frame = factory.CreateFrame("Button", nil, nil, TEMPLATE)
  frame._wmSecureLinks = true
  return frame
end

-- Only the post-hooks: the template's own click script is Blizzard code.
local function runPostHooks(frame, link, text, button)
  local hooks = frame._hookScripts and frame._hookScripts.OnHyperlinkClick or {}
  for _, hook in ipairs(hooks) do
    hook(frame, link, text, button)
  end
  return #hooks
end

local function clickPlain(factory, link, button)
  local frame = factory.CreateFrame("Frame", nil, nil)
  LinkClicks.BindClick(frame)
  frame:GetScript("OnHyperlinkClick")(frame, link, "[Name]", button)
  return frame
end

local function runSpyCases(factory)
  -- test_forever_right_click_on_player_link_opens_contact_menu
  Flavor.With(true, true, function()
    withMenuSpy(function(opened)
      BannedMenuApis.With(function(calls)
        local frame = clickPlain(factory, LINK, "RightButton")
        assert(#opened == 1, "contact menu opens once, got " .. #opened)
        local entry = opened[1]
        assert(entry ~= nil and entry.item ~= nil, "Open gets an item")
        local item = entry.item
        assert(item.channel == "WOW" and item.displayName == "Gurkan Warbringer-Realm", "name with a space kept, got " .. tostring(item.displayName))
        assert(item.lineID == 42 and item.chatType == "CHANNEL", "line and chat type for Report")
        assert(entry.anchor == frame, "anchored to the link's frame")
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
  end)

  -- test_whisper_chat_type_is_dropped
  Flavor.With(true, true, function()
    withMenuSpy(function(opened)
      BannedMenuApis.With(function(calls)
        clickPlain(factory, WHISPER_LINK, "RightButton")
        assert(#opened == 1, "contact menu opens once, got " .. #opened)
        local entry = opened[1]
        assert(entry ~= nil and entry.item ~= nil, "Open gets an item")
        assert(entry.item.displayName == "Arthas", "name, got " .. tostring(entry.item.displayName))
        assert(entry.item.chatType == nil, "a whisper chat type is dropped, got " .. tostring(entry.item.chatType))
        assert(entry.item.lineID == 7, "line ID kept, got " .. tostring(entry.item.lineID))
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
  end)

  -- test_secure_frame_post_hook_opens_contact_menu
  Flavor.With(true, true, function()
    withMenuSpy(function(opened)
      BannedMenuApis.With(function(calls)
        local frame = newTemplatedFrame(factory)
        LinkClicks.BindClick(frame)
        assert(runPostHooks(frame, LINK, "[Gurkan Warbringer]", "RightButton") == 1, "BindClick post-hooks the template")
        assert(#opened == 1, "contact menu opens once, got " .. #opened)
        local entry = opened[1]
        assert(entry ~= nil and entry.anchor == frame, "anchored to the link's frame")
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
  end)

  -- test_forever_left_click_unchanged
  Flavor.With(true, true, function()
    withMenuSpy(function(opened)
      withChatHandler(function(mixinCalls)
        clickPlain(factory, LINK, "LeftButton")
        assert(#opened == 0, "a left click opens no contact menu, got " .. #opened)
        assert(#mixinCalls == 1 and mixinCalls[1] == "player:Gurkan Warbringer-Realm:42:CHANNEL:Trade", "the chat handler gets the decoded link")
      end)
    end)
  end)

  -- test_retail_right_click_unchanged
  Flavor.With(true, false, function()
    withMenuSpy(function(opened)
      withChatHandler(function(mixinCalls)
        clickPlain(factory, LINK, "RightButton")
        assert(#opened == 0, "Retail opens no contact menu, got " .. #opened)
        assert(#mixinCalls == 1, "the chat handler runs on Retail, ran " .. #mixinCalls)
      end)
    end)
  end)

  -- test_player_gm_link_falls_through
  Flavor.With(true, true, function()
    withMenuSpy(function(opened)
      withChatHandler(function(mixinCalls)
        clickPlain(factory, GM_LINK, "RightButton")
        assert(#opened == 0, "a GM link opens no contact menu, got " .. #opened)
        assert(#mixinCalls == 1 and mixinCalls[1] == "playerGM:GM:1", "the chat handler gets the GM link")
      end)
    end)
  end)
end

-- test_forever_full_path_shows_own_popup
local function runFullPath(factory)
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, rawget(_G, "CreateFrame"), _G.UISpecialFrames
  local savedModified = rawget(_G, "IsModifiedClick")
  Localization.Configure({ language = "enUS" })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  rawset(_G, "IsModifiedClick", function()
    return false
  end)

  local ok, err = pcall(function()
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        local frame = factory.CreateFrame("Frame", nil, _G.UIParent)
        frame:Show()
        LinkClicks.BindClick(frame)
        frame:GetScript("OnHyperlinkClick")(frame, LINK, "[Gurkan Warbringer]", "RightButton")
        assert(MenuPopup.IsShown(), "WM's own popup opens")
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
  end)

  MenuPopup.Close()
  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
  rawset(_G, "IsModifiedClick", savedModified)
  if not ok then
    error(err, 0)
  end
end

return function()
  local factory = FakeUI.NewFactory()
  runSpyCases(factory)
  runFullPath(factory)
end
