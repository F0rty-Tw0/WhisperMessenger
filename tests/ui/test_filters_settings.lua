local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local FiltersSettingsUI = require("tests.helpers.filters_settings_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local IgnoreListSection = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreListSection")

local NOW = 1000000
local DAY = 24 * 60 * 60

local function entry(name, extra)
  local value = { name = name, addedAt = NOW, blocked = 0 }
  for key, field in pairs(extra or {}) do
    value[key] = field
  end
  return value
end

local function create(filters)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return FiltersSettings.Create(factory, parent, { filters = filters }, { onChange = function() end })
end

-- Shown FontString with exactly `text` (pooled rows keep stale text hidden).
local function visibleText(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node.parent:IsShown()
  end)
end

local function visibleContaining(root, fragment)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString"
      and type(node.text) == "string"
      and string.find(node.text, fragment, 1, true) ~= nil
      and node.parent:IsShown()
  end)
end

local trashButtons = FiltersSettingsUI.trashButtons
local stubPopups = FiltersSettingsUI.stubPopups

local function filtersWith(names)
  local filters = { ignored = {}, rules = {} }
  for _, name in ipairs(names) do
    filters.ignored[string.lower(name)] = entry(name)
  end
  return filters
end

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", function()
    return NOW
  end)

  -- test_many_ignored_players_build_at_most_visible_rows
  do
    local names = {}
    for index = 1, 300 do
      names[index] = string.format("Player%03d", index)
    end
    local result = create(filtersWith(names))
    local rows = #trashButtons(result.frame)
    assert(rows > 0 and rows <= IgnoreListSection.VISIBLE_ROWS, "expected at most " .. IgnoreListSection.VISIBLE_ROWS .. " rows, got " .. rows)
    assert(visibleText(result.frame, "Player001") ~= nil, "first page starts at the top")

    -- test_mouse_wheel_rebinds_rows
    local list = visibleText(result.frame, "Player001").parent:GetParent()
    list:GetScript("OnMouseWheel")(list, -1)
    assert(visibleText(result.frame, "Player001") == nil, "scrolled past the first entry")
    assert(visibleText(result.frame, "Player002") ~= nil, "next entry bound to a pooled row")
    assert(#trashButtons(result.frame) <= IgnoreListSection.VISIBLE_ROWS, "scrolling reuses rows")
  end

  -- test_remove_button_unignores_and_redraws
  do
    local filters = filtersWith({ "Bob" })
    local result = create(filters)
    FindUI.click(trashButtons(result.frame)[1])
    assert(next(filters.ignored) == nil, "Bob removed from the ignore list")
    assert(visibleText(result.frame, "Bob") == nil, "row redrawn without Bob")
  end

  -- test_remove_works_for_an_entry_added_on_another_realm
  do
    local savedRealm = rawget(_G, "GetNormalizedRealmName")
    rawset(_G, "GetNormalizedRealmName", function()
      return "Illidan"
    end)
    local filters = { ignored = { ["bob-area52"] = entry("Bob") }, rules = {} }
    local result = create(filters)
    FindUI.click(trashButtons(result.frame)[1])
    rawset(_G, "GetNormalizedRealmName", savedRealm)
    assert(filters.ignored["bob-area52"] == nil, "the stored entry is removed, not this realm's Bob")
  end

  -- test_title_counts_every_ignored_player
  do
    local result = create(filtersWith({ "A", "B", "C", "D", "E", "F", "G", "H" }))
    assert(FindUI.text(result.frame, "Blocked players (8)") ~= nil, "title shows the full count while rows scroll")
  end

  -- test_row_shows_reason_blocked_count_and_last_text
  do
    local filters = { ignored = {}, rules = {} }
    filters.ignored.bob = entry("Bob", { reason = "gold spam", blocked = 3, lastText = "cheap gold", lastChannel = "CHAT_MSG_WHISPER" })
    local result = create(filters)
    assert(visibleContaining(result.frame, "gold spam") ~= nil, "reason shown")
    assert(visibleText(result.frame, "Blocked 3") ~= nil, "blocked count shown")
    assert(visibleContaining(result.frame, "Last: ") ~= nil, "last blocked line shown")
    assert(visibleContaining(result.frame, "cheap gold") ~= nil, "last blocked text shown")
    assert(visibleContaining(result.frame, "Whisper") ~= nil, "event shown as a friendly word")
    assert(visibleContaining(result.frame, "CHAT_MSG") == nil, "raw event names never shown")
  end

  -- test_channel_base_name_shown_as_is
  do
    local filters = { ignored = {}, rules = {} }
    filters.ignored.bob = entry("Bob", { blocked = 1, lastText = "wts", lastChannel = "Trade" })
    local result = create(filters)
    assert(visibleContaining(result.frame, "Trade") ~= nil, "channel name shown")
  end

  -- test_expired_entries_are_swept_before_drawing
  do
    local filters = { ignored = {}, rules = {} }
    filters.ignored.old = entry("Old", { expiresAt = NOW - 1 })
    local result = create(filters)
    assert(filters.ignored.old == nil, "expired entry swept")
    assert(visibleText(result.frame, "Old") == nil, "expired entry not listed")
  end

  -- test_add_player_asks_name_then_reason
  do
    local filters = { ignored = {}, rules = {} }
    local result = create(filters)
    local shown = stubPopups({ "Spammer-Realm", "gold spam" })
    FindUI.click(FindUI.byLabel(result.frame, "Add player…"))
    assert(#shown == 2, "name dialog, then reason dialog")
    local added = filters.ignored["spammer-realm"]
    assert(added ~= nil and added.reason == "gold spam", "entry added with the reason")
    assert(added.expiresAt == nil, "Forever by default")
    assert(visibleText(result.frame, "Spammer-Realm") ~= nil, "new entry listed")
  end

  -- test_ignore_for_one_day_sets_expiry
  do
    local filters = { ignored = {}, rules = {} }
    local result = create(filters)
    FindUI.click(FindUI.byLabel(result.frame, "1 day"))
    stubPopups({ "Spammer-Realm", "" })
    FindUI.click(FindUI.byLabel(result.frame, "Add player…"))
    local added = filters.ignored["spammer-realm"]
    assert(added.expiresAt == NOW + DAY, "expires a day later")
    assert(added.reason == nil, "empty reason saved as none")
  end

  -- test_add_rule_creates_a_rule
  do
    local filters = { ignored = {}, rules = {} }
    local result = create(filters)
    stubPopups({ "WTS boost" })
    FindUI.click(FindUI.byLabel(result.frame, "Add rule…"))
    assert(#filters.rules == 1, "rule created")
    assert(filters.rules[1].words[1] == "wts" and filters.rules[1].words[2] == "boost", "words saved lowercased")
    assert(visibleText(result.frame, "wts + boost") ~= nil, "rule listed with its words joined")
  end

  -- test_rule_row_toggles_and_removes
  do
    local filters = { ignored = {}, rules = { { words = { "wts" }, enabled = true, blocked = 5 } } }
    local result = create(filters)
    assert(visibleText(result.frame, "Blocked 5") ~= nil, "rule blocked count shown")
    FindUI.click(FindUI.toggle(result.frame, "wts"))
    assert(filters.rules[1].enabled == false, "toggle disables the rule")
    FindUI.click(trashButtons(result.frame)[1])
    assert(#filters.rules == 0, "remove deletes the rule")
    assert(#trashButtons(result.frame) == 0, "rule list redrawn without the rule")
  end

  -- test_preset_rule_shows_its_name
  do
    local filters = { ignored = {}, rules = { { name = "WTS / WTB", words = { "wts/wtb" }, enabled = false, blocked = 0 } } }
    local result = create(filters)
    assert(visibleText(result.frame, "WTS / WTB") ~= nil, "named rule listed by its name")
    assert(visibleText(result.frame, "wts/wtb") == nil, "its words stay out of the list")
  end

  -- test_clicking_a_rule_edits_its_words
  do
    local filters = { ignored = {}, rules = { { name = "WTS / WTB", words = { "wts/wtb" }, enabled = true, blocked = 2 } } }
    local result = create(filters)
    local primed
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    rawset(_G, "StaticPopup_Show", function(name, _textArg, _textArg2, value)
      primed = value
      _G.StaticPopupDialogs[name].OnAccept({
        editBox = {
          frameType = "EditBox",
          GetText = function()
            return "WTS/wtb + gold"
          end,
          SetText = function() end,
        },
      })
    end)
    local row = visibleText(result.frame, "WTS / WTB").parent:GetParent()
    FindUI.click(row.editButton)
    assert(primed == "wts/wtb", "dialog opens with the current words")
    local rule = filters.rules[1]
    assert(rule.words[1] == "wts/wtb" and rule.words[2] == "gold", "edited words saved")
    assert(rule.blocked == 2 and rule.enabled == true, "count and state kept")
  end

  -- test_reset_rules_confirms_then_restores_presets
  do
    local RulePresets = require("WhisperMessenger.Model.Filters.RulePresets")
    local filters = { ignored = {}, rules = { { words = { "mine" }, enabled = true, blocked = 1 } } }
    local result = create(filters)
    local asked
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    rawset(_G, "StaticPopup_Show", function(name)
      asked = name
      _G.StaticPopupDialogs[name].OnAccept()
    end)
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(asked ~= nil, "asks before resetting")
    assert(#filters.rules == #RulePresets.LIST, "own rule gone, presets back")
    assert(visibleText(result.frame, "mine") == nil, "list redrawn without the own rule")
    assert(visibleText(result.frame, "WTS / WTB") ~= nil, "presets listed")
  end

  -- test_reset_rules_cancelled_keeps_rules
  do
    local filters = { ignored = {}, rules = { { words = { "mine" }, enabled = true, blocked = 1 } } }
    local result = create(filters)
    rawset(_G, "StaticPopup_Show", function() end)
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(#filters.rules == 1 and filters.rules[1].words[1] == "mine", "nothing changes until confirmed")
  end

  -- test_russian_localizes_filters_panel
  do
    Localization.Configure({ language = "ruRU" })
    local result = create({ ignored = {}, rules = {} })
    assert(Localization.Text("Filters") ~= "Filters", "title translated")
    assert(FindUI.text(result.frame, Localization.Text("Filters")) ~= nil, "title shown")
    assert(FindUI.text(result.frame, Localization.Text("Keyword rules")) ~= nil, "rules section shown")
    Localization.Configure({ language = "enUS" })
  end

  rawset(_G, "time", nil)
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
