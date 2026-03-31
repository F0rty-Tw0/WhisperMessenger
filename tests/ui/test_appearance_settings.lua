local FakeUI = require("tests.helpers.fake_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_font_selector_exists
  -- -----------------------------------------------------------------------
  do
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.fontSelector ~= nil, "test_font_selector_exists: should expose fontSelector")
    assert(result.fontSelector.buttons ~= nil, "test_font_selector_exists: fontSelector should have buttons")
    assert(
      #result.fontSelector.buttons == 2,
      "test_font_selector_exists: should have 2 font buttons, got: " .. tostring(#result.fontSelector.buttons)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_font_selector_labels
  -- -----------------------------------------------------------------------
  do
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local labels = {}
    for _, btn in ipairs(result.fontSelector.buttons) do
      if btn.label and btn.label.text then
        table.insert(labels, btn.label.text)
      end
    end

    local found = { default = false, system = false }
    for _, text in ipairs(labels) do
      local lower = string.lower(text)
      if string.find(lower, "default", 1, true) then
        found.default = true
      end
      if string.find(lower, "system", 1, true) then
        found.system = true
      end
    end

    assert(found.default, "test_font_selector_labels: should have a 'Default' button")
    assert(found.system, "test_font_selector_labels: should have a 'System' button")
  end

  -- -----------------------------------------------------------------------
  -- test_font_selector_fires_on_change
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "System" button (second one)
    local systemBtn = result.fontSelector.buttons[2]
    local onClick = systemBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_font_selector_fires_on_change: button should have OnClick")
    onClick(systemBtn)

    assert(
      changes.fontFamily == "system",
      "test_font_selector_fires_on_change: should fire onChange with fontFamily=system, got: "
        .. tostring(changes.fontFamily)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_font_selector_default_highlights_initial
  -- -----------------------------------------------------------------------
  do
    local config = { fontFamily = "system" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    -- The system button (index 2) should be the selected one
    local systemBtn = result.fontSelector.buttons[2]
    assert(
      systemBtn._selected == true,
      "test_font_selector_default_highlights_initial: system button should be selected when fontFamily=system"
    )

    local defaultBtn = result.fontSelector.buttons[1]
    assert(
      defaultBtn._selected ~= true,
      "test_font_selector_default_highlights_initial: default button should NOT be selected when fontFamily=system"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_reset_resets_font_to_default
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = { fontFamily = "system", windowOpacityInactive = 0.72, windowOpacityActive = 1.0 }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click reset
    local resetClick = result.resetButton:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_resets_font: resetButton should have OnClick")
    resetClick(result.resetButton)

    assert(
      changes.fontFamily == "default",
      "test_reset_resets_font: reset should fire onChange with fontFamily=default, got: "
        .. tostring(changes.fontFamily)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_font_buttons_show_tooltip_on_enter
  -- -----------------------------------------------------------------------
  do
    _G.GameTooltip = {
      _owner = nil,
      _text = nil,
      _shown = false,
      SetOwner = function(self, owner, anchor)
        self._owner = owner
        self._anchor = anchor
      end,
      SetText = function(self, text)
        self._text = text
      end,
      AddLine = function(self, text)
        self._addedLine = text
      end,
      Show = function(self)
        self._shown = true
      end,
      Hide = function(self)
        self._shown = false
        self._text = nil
        self._addedLine = nil
      end,
    }

    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    -- Hover over the "System" button (2nd)
    local systemBtn = result.fontSelector.buttons[2]
    local onEnter = systemBtn:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_font_tooltip: button should have OnEnter")
    onEnter(systemBtn)

    assert(_G.GameTooltip._shown == true, "test_font_tooltip: GameTooltip should be shown on hover")
    assert(
      _G.GameTooltip._text ~= nil and _G.GameTooltip._text ~= "",
      "test_font_tooltip: GameTooltip should have text, got: " .. tostring(_G.GameTooltip._text)
    )

    -- Leave should hide
    local onLeave = systemBtn:GetScript("OnLeave")
    onLeave(systemBtn)
    assert(_G.GameTooltip._shown == false, "test_font_tooltip: GameTooltip should be hidden on leave")

    _G.GameTooltip = nil
  end

  -- -----------------------------------------------------------------------
  -- test_each_font_button_has_distinct_tooltip
  -- -----------------------------------------------------------------------
  do
    local tooltipTexts = {}
    _G.GameTooltip = {
      _text = nil,
      _shown = false,
      SetOwner = function() end,
      SetText = function(self, text)
        self._text = text
      end,
      AddLine = function() end,
      Show = function(self)
        self._shown = true
      end,
      Hide = function(self)
        self._shown = false
        self._text = nil
      end,
    }

    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    for _, btn in ipairs(result.fontSelector.buttons) do
      local onEnter = btn:GetScript("OnEnter")
      onEnter(btn)
      table.insert(tooltipTexts, _G.GameTooltip._text)
      local onLeave = btn:GetScript("OnLeave")
      onLeave(btn)
    end

    assert(#tooltipTexts == 2, "test_distinct_tooltips: should have 2 tooltips")
    assert(tooltipTexts[1] ~= tooltipTexts[2], "test_distinct_tooltips: each button should have a distinct tooltip")

    _G.GameTooltip = nil
  end

  print("  All appearance settings tests passed")
end
