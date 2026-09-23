local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

-- Text of the first FontString in the panel containing `fragment`.
local function labelContaining(result, fragment)
  local label = FindUI.find(result.frame, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.find(node.text, fragment, 1, true) ~= nil
  end)
  return label and label.text
end

local function resetButton(result)
  return FindUI.byLabel(result.frame, "Reset to Defaults")
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_auto_focus_toggle_label_says_chat_input

  do
    local config = { dimWhenMoving = true, autoFocusComposer = false }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = labelContaining(result, "focus")

    assert(label ~= nil, "test_auto_focus_toggle_label: should have a label with 'focus'")
    assert(string.find(label, "chat input", 1, true) ~= nil, "test_auto_focus_toggle_label: label should say 'chat input', got: " .. tostring(label))
  end

  -- test_auto_focus_toggle_has_tooltip

  do
    local tooltipTitle = nil
    local addedLines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipTitle = text
      end,
      AddLine = function(_self, text)
        addedLines[#addedLines + 1] = text
      end,
      Show = function() end,
      Hide = function() end,
    }

    local config = { autoFocusComposer = false }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local row = FindUI.byLabel(result.frame, "Auto-focus chat input")
    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_auto_focus_toggle_has_tooltip: row should have OnEnter script")

    onEnter(row)
    assert(tooltipTitle ~= nil, "test_auto_focus_toggle_has_tooltip: tooltip title should be set on hover")
    assert(#addedLines > 0, "test_auto_focus_toggle_has_tooltip: tooltip should have a description line")

    _G.GameTooltip = nil
  end

  -- test_hide_from_default_chat_toggle_exists

  do
    local config = { hideFromDefaultChat = true }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = labelContaining(result, "default chat")

    assert(label ~= nil, "test_hide_from_default_chat_toggle: should have a label with 'default chat'")
  end

  -- test_hide_from_default_chat_defaults_to_on

  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local toggle = FindUI.toggle(result.frame, "Hide whispers from default chat")
    assert(toggle ~= nil, "test_hide_from_default_chat_defaults: toggle should exist even with empty config")
    assert(FindUI.isToggleOn(toggle) == false, "test_hide_from_default_chat_defaults: empty config should leave the toggle off")
  end

  -- test_profanity_filter_toggle_exists

  do
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function() end)

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = labelContaining(result, "profanity")

    assert(label ~= nil, "test_profanity_filter_toggle_exists: should have a label with 'profanity'")
  end

  -- test_profanity_filter_toggle_reads_cvar

  do
    rawset(_G, "GetCVar", function(name)
      if name == "profanityFilter" then
        return "0"
      end
      return "0"
    end)
    rawset(_G, "SetCVar", function() end)

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local toggle = FindUI.toggle(result.frame, "Enable profanity filter")
    assert(toggle ~= nil, "test_profanity_filter_toggle_reads_cvar: toggle should exist")
    assert(FindUI.isToggleOn(toggle) == false, "test_profanity_filter_toggle_reads_cvar: CVar 0 should leave the toggle off")
  end

  -- test_auto_open_incoming_toggle_exists

  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local incomingLabel = labelContaining(result, "incoming")
    assert(incomingLabel ~= nil, "test_auto_open_incoming_toggle_exists: should have label with 'incoming'")

    local outgoingLabel = labelContaining(result, "outgoing")
    assert(outgoingLabel ~= nil, "test_auto_open_outgoing_toggle_exists: should have label with 'outgoing'")
  end

  -- test_auto_open_toggles_default_to_off

  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local incoming = FindUI.toggle(result.frame, "Auto-open on incoming whisper")
    local outgoing = FindUI.toggle(result.frame, "Auto-open on outgoing whisper")
    assert(FindUI.isToggleOn(incoming) == false, "test_auto_open_defaults_to_off: incoming toggle should default off")
    assert(FindUI.isToggleOn(outgoing) == false, "test_auto_open_defaults_to_off: outgoing toggle should default off")
  end

  -- test_auto_open_toggles_fire_on_change

  do
    local changes = {}
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local inDot = FindUI.toggle(result.frame, "Auto-open on incoming whisper")
    local inClick = inDot:GetScript("OnClick")
    assert(inClick ~= nil, "test_auto_open_incoming_fires: dot should have OnClick")
    inClick(inDot)
    assert(changes.autoOpenIncoming ~= nil, "test_auto_open_incoming_fires: should fire onChange with 'autoOpenIncoming' key")

    local outDot = FindUI.toggle(result.frame, "Auto-open on outgoing whisper")
    local outClick = outDot:GetScript("OnClick")
    assert(outClick ~= nil, "test_auto_open_outgoing_fires: dot should have OnClick")
    outClick(outDot)
    assert(changes.autoOpenOutgoing ~= nil, "test_auto_open_outgoing_fires: should fire onChange with 'autoOpenOutgoing' key")
  end

  -- test_auto_open_incoming_toggle_has_tooltip

  do
    local tooltipTitle = nil
    local addedLines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipTitle = text
      end,
      AddLine = function(_self, text)
        addedLines[#addedLines + 1] = text
      end,
      Show = function() end,
      Hide = function() end,
    }

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local row = FindUI.byLabel(result.frame, "Auto-open on incoming whisper")
    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_auto_open_incoming_tooltip: row should have OnEnter script")

    onEnter(row)
    assert(tooltipTitle ~= nil, "test_auto_open_incoming_tooltip: tooltip title should be set on hover")
    assert(#addedLines > 0, "test_auto_open_incoming_tooltip: tooltip should have a description line")

    _G.GameTooltip = nil
  end

  -- test_auto_open_toggles_included_in_reset

  do
    local changes = {}
    local config = { autoOpenIncoming = true, autoOpenOutgoing = true }
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local reset = resetButton(result)
    local resetOnClick = reset:GetScript("OnClick")
    assert(resetOnClick ~= nil, "test_auto_open_included_in_reset: reset button should have OnClick")
    resetOnClick(reset)

    assert(changes.autoOpenIncoming == false, "test_auto_open_included_in_reset: reset should set autoOpenIncoming to false (default)")
    assert(changes.autoOpenOutgoing == false, "test_auto_open_included_in_reset: reset should set autoOpenOutgoing to false (default)")
  end

  -- test_double_escape_toggle_exists_and_defaults_off

  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = labelContaining(result, "Double ESC")
    assert(label ~= nil, "test_double_escape_toggle_exists: label should say 'Double ESC'")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, label)) == false, "test_double_escape_toggle_exists: should default off")
  end

  -- test_double_escape_toggle_fires_on_change

  do
    local changes = {}
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local dot = FindUI.toggle(result.frame, "Double ESC to close")
    local onClick = dot:GetScript("OnClick")
    assert(onClick ~= nil, "test_double_escape_fires: dot should have OnClick")
    onClick(dot)
    assert(changes.doubleEscapeToClose ~= nil, "test_double_escape_fires: should fire onChange with 'doubleEscapeToClose' key")
  end

  -- test_double_escape_included_in_reset

  do
    local changes = {}
    local config = { doubleEscapeToClose = true }
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local reset = resetButton(result)
    local resetOnClick = reset:GetScript("OnClick")
    assert(resetOnClick ~= nil, "test_double_escape_reset: reset button should have OnClick")
    resetOnClick(reset)

    assert(changes.doubleEscapeToClose == false, "test_double_escape_reset: reset should set doubleEscapeToClose to false (default)")
  end

  -- test_profanity_filter_toggle_writes_cvar_on_change

  do
    local cvarWrites = {}
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function(name, value)
      cvarWrites[name] = value
    end)

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    -- Simulate toggling off via the dot button
    local dot = FindUI.toggle(result.frame, "Enable profanity filter")
    local onClickHandler = dot:GetScript("OnClick")
    assert(onClickHandler ~= nil, "test_profanity_filter_toggle_writes_cvar: toggle dot should have OnClick")
    onClickHandler(dot)

    assert(cvarWrites.profanityFilter ~= nil, "test_profanity_filter_toggle_writes_cvar: should have called SetCVar('profanityFilter', ...)")
  end

  -- test_hide_on_combat_toggle_defaults_off_and_persists
  do
    local changes = {}
    local tooltipTitle = nil
    local tooltipLines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_, value)
        tooltipTitle = value
      end,
      AddLine = function(_, value)
        tooltipLines[#tooltipLines + 1] = value
      end,
      Show = function() end,
      Hide = function() end,
    }

    local result = BehaviorSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local row = FindUI.byLabel(result.frame, "Hide on entering combat")
    local dot = FindUI.toggle(result.frame, "Hide on entering combat")
    assert(FindUI.isToggleOn(dot) == false, "hideOnCombat should default off")

    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "hideOnCombat row should have a tooltip")
    onEnter(row)
    assert(tooltipTitle == "Hide on entering combat", "hideOnCombat tooltip should use its label")
    assert(
      tooltipLines[1]
        == "Hides the messenger when combat starts. You can reopen it manually during combat. It does not reopen automatically after combat.",
      "hideOnCombat tooltip should explain its one-shot behavior"
    )

    local onClick = dot:GetScript("OnClick")
    assert(onClick ~= nil, "hideOnCombat dot should have OnClick")
    onClick(dot)
    assert(changes.hideOnCombat == true, "hideOnCombat should persist enabled value")

    local reset = resetButton(result)
    local resetOnClick = reset:GetScript("OnClick")
    assert(resetOnClick ~= nil, "hideOnCombat reset button should have OnClick")
    resetOnClick(reset)
    assert(changes.hideOnCombat == false, "hideOnCombat reset should restore default off")

    _G.GameTooltip = nil
  end

  -- test_russian_localizes_behavior_panel

  do
    Localization.Configure({ language = "ruRU" })
    local result = BehaviorSettings.Create(factory, parent, {}, { onChange = function() end })

    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["Поведение"], "Russian behavior panel should translate title")
    assert(texts["Настройте поведение окна мессенджера."], "Russian behavior panel should translate hint")
    assert(FindUI.toggle(result.frame, "Автофокус ввода чата") ~= nil, "Auto-focus toggle should be localized")
    assert(
      FindUI.toggle(result.frame, "Скрывать шепот из стандартного чата") ~= nil,
      "Default chat toggle should be localized"
    )
    assert(FindUI.toggle(result.frame, "Показывать групповые чаты") ~= nil, "Group chats toggle should be localized")
    assert(FindUI.byLabel(result.frame, "Сбросить настройки").frameType == "Button", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end
end
