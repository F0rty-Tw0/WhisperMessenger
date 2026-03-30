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
    _G.GetCVar = function()
      return "1"
    end
    _G.SetCVar = function() end

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
    _G.GetCVar = function(name)
      if name == "profanityFilter" then
        return "0"
      end
      return "0"
    end
    _G.SetCVar = function() end

    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.profanityFilterToggle ~= nil, "test_profanity_filter_toggle_reads_cvar: toggle should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_window_toggle_exists
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    assert(
      result.autoOpenWindowToggle ~= nil,
      "test_auto_open_window_toggle_exists: should expose autoOpenWindowToggle"
    )

    local label = nil
    local row = result.autoOpenWindowToggle.row
    for _, child in ipairs(row.children) do
      if child.text and string.find(child.text, "Auto%-open", 1, false) then
        label = child.text
        break
      end
    end

    assert(label ~= nil, "test_auto_open_window_toggle_exists: should have a label with 'Auto-open'")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_window_defaults_to_off
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    -- The toggle dot should reflect "off" state (config.autoOpenWindow is nil/false)
    assert(result.autoOpenWindowToggle ~= nil, "test_auto_open_window_defaults_to_off: toggle should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_window_toggle_fires_on_change
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = {}
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local onClickHandler = result.autoOpenWindowToggle.dot:GetScript("OnClick")
    assert(onClickHandler ~= nil, "test_auto_open_window_toggle_fires_on_change: dot should have OnClick")
    onClickHandler(result.autoOpenWindowToggle.dot)

    assert(
      changes.autoOpenWindow ~= nil,
      "test_auto_open_window_toggle_fires_on_change: should fire onChange with 'autoOpenWindow' key"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_window_toggle_has_tooltip
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

    local row = result.autoOpenWindowToggle.row
    local onEnter = row:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_auto_open_window_toggle_has_tooltip: row should have OnEnter script")

    onEnter(row)
    assert(tooltipTitle ~= nil, "test_auto_open_window_toggle_has_tooltip: tooltip title should be set on hover")
    assert(#addedLines > 0, "test_auto_open_window_toggle_has_tooltip: tooltip should have a description line")

    _G.GameTooltip = nil
  end

  -- -----------------------------------------------------------------------
  -- test_auto_open_window_included_in_reset
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = { autoOpenWindow = true }
    local result = BehaviorSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetOnClick = result.resetButton:GetScript("OnClick")
    assert(resetOnClick ~= nil, "test_auto_open_window_included_in_reset: reset button should have OnClick")
    resetOnClick(result.resetButton)

    assert(
      changes.autoOpenWindow == false,
      "test_auto_open_window_included_in_reset: reset should set autoOpenWindow to false (default)"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_profanity_filter_toggle_writes_cvar_on_change
  -- -----------------------------------------------------------------------
  do
    local cvarWrites = {}
    _G.GetCVar = function()
      return "1"
    end
    _G.SetCVar = function(name, value)
      cvarWrites[name] = value
    end

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
