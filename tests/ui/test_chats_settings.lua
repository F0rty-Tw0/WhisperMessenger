local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")
local ChatsSettings = require("WhisperMessenger.UI.MessengerWindow.ChatsSettings")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local TIP = "To hide a channel from the game's chat, right-click the chat tab, open Settings and untick it."
local BUILT_IN_LABELS = { "General", "Trade", "Trade (Services)", "Local Defense", "World Defense", "Looking for Group" }
-- Show group chats, hide channels from default chat, collapse repeated messages.
local PAGE_TOGGLES = 3

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local calls = {}
  local result = ChatsSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      calls[#calls + 1] = { key = key, value = value }
    end,
  })
  return result, calls
end

local function withGlobals(globals, fn)
  local saved = {}
  for name, value in pairs(globals) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, value)
  end
  local ok, err = pcall(fn)
  for name in pairs(globals) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

local function countKeys(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_ticking_trade_saves_a_new_enabled_channels_table
  do
    local saved = {}
    local config = { enabledChannels = saved }
    local result, calls = create(config)
    FindUI.click(FindUI.toggle(result.frame, "Trade"))
    local last = calls[#calls]
    assert(last.key == "enabledChannels", "reports enabledChannels")
    assert(last.value.trade == true and countKeys(last.value) == 1, "only Trade is enabled")
    assert(last.value ~= saved and next(saved) == nil, "the saved table is never mutated in place")

    FindUI.click(FindUI.toggle(result.frame, "General"))
    assert(calls[#calls].value.trade == true and calls[#calls].value.general == true, "the next tick builds on the last save")

    FindUI.click(FindUI.toggle(result.frame, "Trade"))
    assert(calls[#calls].value.trade == nil and calls[#calls].value.general == true, "unticking removes the channel")
  end

  -- test_saved_channels_start_ticked
  do
    local result = create({ enabledChannels = { lfg = true } })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Looking for Group")) == true, "saved LFG starts on")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Trade")) == false, "unsaved Trade starts off")
  end

  -- test_hide_channels_toggle_hidden_and_tip_shown_without_selective_hiding
  do
    rawset(ChatFilters, "SELECTIVE_HIDING", false)
    local ok, err = pcall(function()
      local result = create({})
      assert(FindUI.text(result.frame, "Hide channels from default chat") == nil, "toggle is hidden")
      local tip = FindUI.text(result.frame, TIP)
      assert(tip ~= nil, "fallback tip is shown")
    end)
    rawset(ChatFilters, "SELECTIVE_HIDING", true)
    assert(ok, err)
  end

  -- test_hide_channels_toggle_shown_with_selective_hiding
  do
    assert(ChatFilters.SELECTIVE_HIDING == true, "selective hiding is on")
    local result, calls = create({})
    local toggle = FindUI.toggle(result.frame, "Hide channels from default chat")
    assert(FindUI.isToggleOn(toggle) == false, "hiding is opt-in")
    FindUI.click(toggle)
    assert(calls[#calls].key == "hideChannelsFromDefaultChat" and calls[#calls].value == true, "reports its key")
    assert(FindUI.text(result.frame, TIP) == nil, "no tip when hiding works")
  end

  -- test_custom_channels_are_listed_from_the_game
  withGlobals({
    GetChannelList = function()
      return 1, "General", false, 5, "CraftScan", false, 6, "Community:123:1", false
    end,
    EnumerateServerChannels = function()
      return "General", "Trade"
    end,
  }, function()
    local result, calls = create({})
    FindUI.click(FindUI.toggle(result.frame, "CraftScan"))
    assert(calls[#calls].value["c:craftscan"] == true, "custom channel keyed c:craftscan")
    assert(FindUI.countToggles(result.frame) == PAGE_TOGGLES + #BUILT_IN_LABELS + 1, "server General and community channels are not listed")
    assert(FindUI.text(result.frame, "Community:123:1") == nil, "raw community channel ids are hidden")
  end)

  -- test_zone_channel_missing_from_the_server_list_is_not_custom
  -- Away from a capital the server list drops Trade while the character is
  -- still in it; the channel's own type says it is a zone channel.
  withGlobals({
    GetChannelList = function()
      return 1, "General", false, 2, "Trade", false, 5, "CraftScan", false
    end,
    EnumerateServerChannels = function()
      return "General"
    end,
    C_ChatInfo = {
      GetChannelInfoFromIdentifier = function(name)
        return { name = name, channelType = name == "CraftScan" and 3 or 1 }
      end,
    },
  }, function()
    local result = create({})
    assert(FindUI.countToggles(result.frame) == PAGE_TOGGLES + #BUILT_IN_LABELS + 1, "only CraftScan is listed as custom")
  end)

  -- test_ticked_channel_the_character_left_can_still_be_unticked
  withGlobals({
    GetChannelList = function()
      return 1, "General", false
    end,
    EnumerateServerChannels = function()
      return "General"
    end,
  }, function()
    local result, calls = create({ enabledChannels = { ["c:craftscan"] = true } })
    local toggle = FindUI.toggle(result.frame, "Craftscan")
    assert(toggle ~= nil and FindUI.isToggleOn(toggle) == true, "a ticked channel that was left keeps its row")
    FindUI.click(toggle)
    assert(calls[#calls].value["c:craftscan"] == nil, "unticking it removes the channel")
  end)

  -- test_built_ins_only_without_the_channel_api
  withGlobals({ GetChannelList = false }, function()
    rawset(_G, "GetChannelList", nil)
    local result = create({})
    for _, label in ipairs(BUILT_IN_LABELS) do
      assert(FindUI.toggle(result.frame, label) ~= nil, "built-in channel row: " .. label)
    end
    assert(FindUI.countToggles(result.frame) == PAGE_TOGGLES + #BUILT_IN_LABELS, "three page toggles plus the built-in channels")
  end)

  -- test_reset_restores_chat_defaults_and_keeps_channels
  do
    local result, calls = create({ showGroupChats = false, collapseDuplicates = false, enabledChannels = { trade = true } })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    local reset = {}
    for _, call in ipairs(calls) do
      reset[call.key] = call.value
    end
    assert(reset.showGroupChats == true, "reset shows group chats")
    assert(reset.collapseDuplicates == true, "reset collapses repeats")
    assert(reset.enabledChannels == nil, "reset keeps the picked channels")
  end

  -- test_page_toggles_report_their_keys
  do
    local result, calls = create({})
    FindUI.click(FindUI.toggle(result.frame, "Show group chats"))
    assert(calls[#calls].key == "showGroupChats" and calls[#calls].value == false, "group chats key")
    FindUI.click(FindUI.toggle(result.frame, "Collapse repeated messages"))
    assert(calls[#calls].key == "collapseDuplicates" and calls[#calls].value == false, "collapse key")
  end

  -- test_behavior_no_longer_shows_group_chats
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local behavior = BehaviorSettings.Create(factory, parent, {}, { onChange = function() end })
    assert(FindUI.text(behavior.frame, "Show group chats") == nil, "Show group chats moved to Chats")
  end

  -- test_russian_localizes_chats_panel
  do
    Localization.Configure({ language = "ruRU" })
    local result = create({})
    assert(FindUI.toggle(result.frame, "Показывать групповые чаты") ~= nil, "group chats toggle is translated")
    assert(FindUI.text(result.frame, Localization.Text("Chats")) ~= nil, "title shown")
    assert(Localization.Text("Chats") ~= "Chats", "title is translated")
    assert(FindUI.toggle(result.frame, Localization.Text("Trade")) ~= nil, "channel rows are translated")
    Localization.Configure({ language = "enUS" })
  end
end
