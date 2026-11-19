local RowSignature = require("WhisperMessenger.UI.ContactsList.RowSignature")
local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Localization = require("WhisperMessenger.Locale.Localization")
local TimeFormat = require("WhisperMessenger.Util.TimeFormat")
local FakeUI = require("tests.helpers.fake_ui")

local function newItem()
  return {
    conversationKey = "me::WOW::alice",
    displayName = "Alice-Realm",
    nickname = "Al",
    lastPreview = "hello",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    classTag = "MAGE",
    raceTag = "Human",
    factionName = "Alliance",
    pinned = false,
    muted = false,
    hasUnreadMention = false,
    draft = "unsent",
    isTyping = false,
    areaName = "Stormwind",
    ownerClassTag = "PRIEST",
    availability = { status = "CanWhisper", canWhisper = true },
    relationship = { primary = "friend" },
    conversation = { messages = {} },
  }
end

-- A different value of the same type for each field.
local function changed(value)
  if type(value) == "string" then
    return value .. "x"
  elseif type(value) == "number" then
    return value + 1
  elseif type(value) == "boolean" then
    return not value
  end
  return { changed = true }
end

local function copyItem(item)
  local copy = {}
  for key, value in pairs(item) do
    copy[key] = value
  end
  return copy
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  ---@type table<string, any>
  local options = { selectedConversationKey = "me::WOW::bob" }

  local function stored(item, opts)
    local row = {}
    RowSignature.Store(row, item, RowSignature.Context(parent, opts or options))
    return row
  end

  local function matches(row, item, opts)
    return RowSignature.Matches(row, item, RowSignature.Context(parent, opts or options))
  end

  -- test_matches_after_store_with_same_values
  do
    local item = newItem()
    local row = stored(item)
    assert(matches(row, item) == true, "an unchanged item should match its stored signature")
  end

  -- test_matches_a_new_item_table_with_equal_values
  do
    local item = newItem()
    local row = stored(item)
    local copy = copyItem(item)
    copy.availability = { status = "CanWhisper", canWhisper = true }
    assert(matches(row, copy) == true, "an equal copy (fresh availability table) should match")
  end

  -- test_never_matches_a_row_without_a_stored_signature
  do
    assert(matches({}, newItem()) == false, "a fresh row has nothing to match")
  end

  -- test_cleared_row_does_not_match
  do
    local item = newItem()
    local row = stored(item)
    RowSignature.Clear(row)
    assert(matches(row, item) == false, "a cleared row should not match")
  end

  -- test_each_item_field_change_breaks_the_match
  for key, value in pairs(newItem()) do
    if key ~= "conversation" then
      local item = newItem()
      local row = stored(item)
      item[key] = changed(value)
      assert(matches(row, item) == false, "changing item." .. key .. " should break the match")
    end
  end

  -- test_removed_field_breaks_the_match
  for key in pairs(newItem()) do
    local item = newItem()
    local row = stored(item)
    item[key] = nil
    assert(matches(row, item) == false, "removing item." .. key .. " should break the match")
  end

  -- test_added_field_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    item.note = "new"
    assert(matches(row, item) == false, "a new item field should break the match")
  end

  -- test_nested_availability_change_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    item.availability = { status = "Offline", canWhisper = false }
    assert(matches(row, item) == false, "a new availability status should break the match")
  end

  -- test_nested_field_added_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    item.relationship = { primary = "friend", guildName = "Guild" }
    assert(matches(row, item) == false, "a new relationship field should break the match")
  end

  -- test_nested_field_removed_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    item.availability = { status = "CanWhisper" }
    assert(matches(row, item) == false, "a dropped availability field should break the match")
  end

  -- test_greeting_tag_on_the_last_line_breaks_the_match
  do
    local item = newItem()
    item.lastPreview = "made by craftscan"
    item.conversation = { messages = { { text = "made by craftscan" } } }
    local row = stored(item)
    item.conversation.messages[1].addonGreeting = "CraftScan"
    assert(matches(row, item) == false, "the shown preview changed, so the match should break")
  end

  -- test_parent_width_change_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    parent:SetSize(300, 400)
    local ok = matches(row, item)
    parent:SetSize(260, 400)
    assert(ok == false, "a wider list should break the match")
  end

  -- test_option_changes_break_the_match
  -- The contacts controller edits one options table in place.
  do
    local optionChanges = {
      { "compact", true },
      { "hideMessagePreview", true },
      { "selectedConversationKey", "me::WOW::alice" },
    }
    for _, change in ipairs(optionChanges) do
      local key, value = change[1], change[2]
      local item = newItem()
      local row = stored(item)
      local saved = options[key]
      options[key] = value
      local ok = matches(row, item)
      options[key] = saved
      assert(ok == false, "changing options." .. key .. " should break the match")
    end
  end

  -- test_selection_of_another_row_keeps_the_match
  do
    local item = newItem()
    local row = stored(item)
    options.selectedConversationKey = "me::WOW::cara"
    local ok = matches(row, item)
    options.selectedConversationKey = "me::WOW::bob"
    assert(ok == true, "selecting another row should not rebind this one")
  end

  -- test_another_options_table_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    assert(matches(row, item, { selectedConversationKey = "me::WOW::bob" }) == false, "new row callbacks should break the match")
  end

  -- test_theme_preset_switch_breaks_the_match
  do
    local previous = Theme.GetPreset()
    local item = newItem()
    local row = stored(item)
    Theme.SetPreset(previous == "wow_default" and "elvui_dark" or "wow_default")
    local ok = matches(row, item)
    Theme.SetPreset(previous)
    assert(ok == false, "a preset switch should break the match")
  end

  -- test_font_size_change_breaks_the_match
  do
    local previous = Fonts.GetFontSize()
    local item = newItem()
    local row = stored(item)
    Fonts.SetFontSize(previous + 2)
    local ok = matches(row, item)
    Fonts.SetFontSize(previous)
    assert(ok == false, "a font size change should break the match")
  end

  -- test_language_change_breaks_the_match
  do
    local item = newItem()
    local row = stored(item)
    Localization.Configure({ language = "deDE" })
    local ok = matches(row, item)
    Localization.Configure({ language = "auto" })
    assert(ok == false, "a language change should break the match")
  end

  -- test_hud_change_breaks_the_match
  do
    local isOn = Hud.IsOn
    local item = newItem()
    local row = stored(item)
    Hud.IsOn = function()
      return not isOn()
    end
    local ok = matches(row, item)
    Hud.IsOn = isOn
    assert(ok == false, "turning the Native WoW HUD on or off should break the match")
  end

  -- test_player_class_or_faction_change_breaks_the_match
  -- Group titles take the player's class color; same-faction contacts hide the faction icon.
  for _, global in ipairs({ "UnitClass", "UnitFactionGroup" }) do
    local saved = rawget(_G, global)
    local value = "MAGE"
    rawset(_G, global, function()
      return value, value
    end)
    local item = newItem()
    local row = stored(item)
    value = "Horde"
    local ok = matches(row, item)
    rawset(_G, global, saved)
    assert(ok == false, "a new " .. global .. " result should break the match")
  end

  -- test_time_format_change_breaks_the_match
  do
    local format = TimeFormat.GetConfig()
    local item = newItem()
    local row = stored(item)
    TimeFormat.Configure({ timeFormat = format == "12h" and "24h" or "12h" })
    local ok = matches(row, item)
    TimeFormat.Configure({ timeFormat = format })
    assert(ok == false, "a time format change should break the match")
  end

  -- test_time_label_tick_breaks_the_match
  do
    local timeText = RowElements.TimeText
    local shown = "now"
    RowElements.TimeText = function()
      return shown
    end
    local item = newItem()
    local row = stored(item)
    local sameLabel = matches(row, item)
    shown = "5m"
    local ticked = matches(row, item)
    RowElements.TimeText = timeText
    assert(sameLabel == true, "the same shown time should still match")
    assert(ticked == false, "'now' turning into '5m' should break the match")
  end
end
