local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_auto_focus_toggle_label_says_chat_input
  -- -----------------------------------------------------------------------
  do
    local config = { dimWhenMoving = true, autoFocusComposer = false, autoSelectUnread = true }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = nil
    local row = result.autoFocusToggle.row
    for _, child in ipairs(row.children) do
      if child.text and string.find(child.text, "focus", 1, true) then
        label = child.text
        break
      end
    end

    assert(label ~= nil, "test_auto_focus_toggle_label: should have a label with 'focus'")
    assert(
      string.find(label, "chat input", 1, true) ~= nil,
      "test_auto_focus_toggle_label: label should say 'chat input', got: " .. tostring(label)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_auto_focus_toggle_has_tooltip
  -- -----------------------------------------------------------------------
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

    local row = result.autoFocusToggle.row
    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_auto_focus_toggle_has_tooltip: row should have OnEnter script")

    onEnter(row)
    assert(tooltipTitle ~= nil, "test_auto_focus_toggle_has_tooltip: tooltip title should be set on hover")
    assert(#addedLines > 0, "test_auto_focus_toggle_has_tooltip: tooltip should have a description line")

    _G.GameTooltip = nil
  end

  -- -----------------------------------------------------------------------
  -- test_hide_from_default_chat_toggle_exists
  -- -----------------------------------------------------------------------
  do
    local config = { hideFromDefaultChat = true }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(
      result.hideFromDefaultChatToggle ~= nil,
      "test_hide_from_default_chat_toggle: should expose hideFromDefaultChatToggle"
    )

    local label = nil
    local row = result.hideFromDefaultChatToggle.row
    for _, child in ipairs(row.children) do
      if child.text and string.find(child.text, "default chat", 1, true) then
        label = child.text
        break
      end
    end

    assert(label ~= nil, "test_hide_from_default_chat_toggle: should have a label with 'default chat'")
  end

  -- -----------------------------------------------------------------------
  -- test_hide_from_default_chat_defaults_to_on
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(
      result.hideFromDefaultChatToggle ~= nil,
      "test_hide_from_default_chat_defaults: toggle should exist even with empty config"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_profanity_filter_toggle_exists
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function() end)

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(
      result.profanityFilterToggle ~= nil,
      "test_profanity_filter_toggle_exists: should expose profanityFilterToggle"
    )

    local label = nil
    local row = result.profanityFilterToggle.row
    for _, child in ipairs(row.children) do
      if child.text and string.find(child.text, "profanity", 1, true) then
        label = child.text
        break
      end
    end

    assert(label ~= nil, "test_profanity_filter_toggle_exists: should have a label with 'profanity'")
  end

  -- -----------------------------------------------------------------------
  -- test_profanity_filter_toggle_reads_cvar
  -- -----------------------------------------------------------------------
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

    assert(result.profanityFilterToggle ~= nil, "test_profanity_filter_toggle_reads_cvar: toggle should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_incoming_toggle_exists
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(
      result.autoOpenIncomingToggle ~= nil,
      "test_auto_open_incoming_toggle_exists: should expose autoOpenIncomingToggle"
    )
    assert(
      result.autoOpenOutgoingToggle ~= nil,
      "test_auto_open_outgoing_toggle_exists: should expose autoOpenOutgoingToggle"
    )

    local incomingLabel = nil
    local inRow = result.autoOpenIncomingToggle.row
    for _, child in ipairs(inRow.children) do
      if child.text and string.find(child.text, "incoming", 1, false) then
        incomingLabel = child.text
        break
      end
    end
    assert(incomingLabel ~= nil, "test_auto_open_incoming_toggle_exists: should have label with 'incoming'")

    local outgoingLabel = nil
    local outRow = result.autoOpenOutgoingToggle.row
    for _, child in ipairs(outRow.children) do
      if child.text and string.find(child.text, "outgoing", 1, false) then
        outgoingLabel = child.text
        break
      end
    end
    assert(outgoingLabel ~= nil, "test_auto_open_outgoing_toggle_exists: should have label with 'outgoing'")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_toggles_default_to_off
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.autoOpenIncomingToggle ~= nil, "test_auto_open_defaults_to_off: incoming toggle should exist")
    assert(result.autoOpenOutgoingToggle ~= nil, "test_auto_open_defaults_to_off: outgoing toggle should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_toggles_fire_on_change
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local inClick = result.autoOpenIncomingToggle.dot:GetScript("OnClick")
    assert(inClick ~= nil, "test_auto_open_incoming_fires: dot should have OnClick")
    inClick(result.autoOpenIncomingToggle.dot)
    assert(
      changes.autoOpenIncoming ~= nil,
      "test_auto_open_incoming_fires: should fire onChange with 'autoOpenIncoming' key"
    )

    local outClick = result.autoOpenOutgoingToggle.dot:GetScript("OnClick")
    assert(outClick ~= nil, "test_auto_open_outgoing_fires: dot should have OnClick")
    outClick(result.autoOpenOutgoingToggle.dot)
    assert(
      changes.autoOpenOutgoing ~= nil,
      "test_auto_open_outgoing_fires: should fire onChange with 'autoOpenOutgoing' key"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_incoming_toggle_has_tooltip
  -- -----------------------------------------------------------------------
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

    local row = result.autoOpenIncomingToggle.row
    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_auto_open_incoming_tooltip: row should have OnEnter script")

    onEnter(row)
    assert(tooltipTitle ~= nil, "test_auto_open_incoming_tooltip: tooltip title should be set on hover")
    assert(#addedLines > 0, "test_auto_open_incoming_tooltip: tooltip should have a description line")

    _G.GameTooltip = nil
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_toggles_included_in_reset
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = { autoOpenIncoming = true, autoOpenOutgoing = true }
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetOnClick = result.resetButton:GetScript("OnClick")
    assert(resetOnClick ~= nil, "test_auto_open_included_in_reset: reset button should have OnClick")
    resetOnClick(result.resetButton)

    assert(
      changes.autoOpenIncoming == false,
      "test_auto_open_included_in_reset: reset should set autoOpenIncoming to false (default)"
    )
    assert(
      changes.autoOpenOutgoing == false,
      "test_auto_open_included_in_reset: reset should set autoOpenOutgoing to false (default)"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_profanity_filter_toggle_writes_cvar_on_change
  -- -----------------------------------------------------------------------
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
    local onClickHandler = result.profanityFilterToggle.dot:GetScript("OnClick")
    assert(onClickHandler ~= nil, "test_profanity_filter_toggle_writes_cvar: toggle dot should have OnClick")
    onClickHandler(result.profanityFilterToggle.dot)

    assert(
      cvarWrites.profanityFilter ~= nil,
      "test_profanity_filter_toggle_writes_cvar: should have called SetCVar('profanityFilter', ...)"
    )
  end
end
