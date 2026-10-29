local FakeUI = require("tests.helpers.fake_ui")
local loaded, IconSettings = pcall(require, "WhisperMessenger.UI.MessengerWindow.IconSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local SHARE_POSITION = "Share widget position across characters"
local TRANSPARENCY = "Widget transparency"

local function modeButtons(result)
  return FindUI.selectorButtons(result.frame, "Icon Mode")
end

local function clickToggle(result, label)
  FindUI.click(FindUI.toggle(result.frame, label))
end

return function()
  assert(loaded, "test_icon_settings_module_exists: IconSettings module must be available")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_icons_owns_all_icon_and_widget_controls

  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["Icons"], "test_icons_owns_all_icon_and_widget_controls: English title should use the fallback key")
    assert(texts["Configure icon and widget settings."], "test_icons_owns_all_icon_and_widget_controls: English hint should use the fallback key")

    local modes = modeButtons(result)
    assert(#modes == 4, "test_icons_owns_all_icon_and_widget_controls: icon mode selector should offer four modes")
    assert(modes[4]._key == "none", "test_icons_owns_all_icon_and_widget_controls: fourth mode should be none")
    assert(FindUI.slider(result.frame, "Icon Size") ~= nil, "test_icons_owns_all_icon_and_widget_controls: icon size slider should exist")
    for _, label in ipairs({
      "Desaturate icon when idle",
      "Lock icon position",
      "Show unread badge",
      "Badge pulse animation",
      "Show widget message preview",
    }) do
      assert(FindUI.toggle(result.frame, label) ~= nil, "test_icons_owns_all_icon_and_widget_controls: missing toggle " .. label)
    end
    assert(
      FindUI.isToggleOn(FindUI.toggle(result.frame, SHARE_POSITION)) == false,
      "test_share_widget_position_toggle_defaults_off: shareWidgetPosition should default off"
    )
    local transparencySlider = FindUI.slider(result.frame, TRANSPARENCY)
    assert(transparencySlider ~= nil, "test_icons_owns_all_icon_and_widget_controls: widget transparency slider should use its label")
    assert(transparencySlider.minValue == 0, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider minimum should be 0")
    assert(transparencySlider.maxValue == 1, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider maximum should be 1")
    assert(transparencySlider.valueStep == 0.05, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider step should be 0.05")
    assert(transparencySlider.value == 0, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider should default to 0%")

    local savedTooltip = _G.GameTooltip
    local tooltipState = { lines = {}, shown = false, hidden = false }
    _G.GameTooltip = {
      SetOwner = function(_, owner, anchor)
        tooltipState.owner = owner
        tooltipState.anchor = anchor
      end,
      SetText = function(_, value)
        tooltipState.title = value
      end,
      AddLine = function(_, value)
        tooltipState.lines[#tooltipState.lines + 1] = value
      end,
      Show = function()
        tooltipState.shown = true
      end,
      Hide = function()
        tooltipState.hidden = true
      end,
    }

    local tooltipRow = transparencySlider.parent
    local onEnter = tooltipRow:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_widget_transparency_tooltip: slider row should have OnEnter script")
    onEnter(tooltipRow)
    assert(tooltipState.owner == tooltipRow, "test_widget_transparency_tooltip: tooltip should use the slider row as owner")
    assert(tooltipState.anchor == "ANCHOR_TOP", "test_widget_transparency_tooltip: tooltip should anchor above the slider row")
    assert(tooltipState.title == "Widget transparency", "test_widget_transparency_tooltip: tooltip should use the transparency title")
    assert(
      tooltipState.lines[1] == "Controls how transparent the widget is when not hovered.",
      "test_widget_transparency_tooltip: tooltip should explain widget transparency"
    )
    assert(tooltipState.shown == true, "test_widget_transparency_tooltip: tooltip should show on enter")

    local onLeave = tooltipRow:GetScript("OnLeave")
    assert(onLeave ~= nil, "test_widget_transparency_tooltip: slider row should have OnLeave script")
    onLeave(tooltipRow)
    assert(tooltipState.hidden == true, "test_widget_transparency_tooltip: tooltip should hide on leave")

    tooltipState.lines = {}
    tooltipState.title = nil
    tooltipState.shown = false
    tooltipState.hidden = false
    local sharePositionRow = FindUI.byLabel(result.frame, SHARE_POSITION)
    local sharePositionOnEnter = sharePositionRow:GetScript("OnEnter")
    assert(sharePositionOnEnter ~= nil, "test_share_widget_position_tooltip: toggle row should have OnEnter script")
    sharePositionOnEnter(sharePositionRow)
    assert(tooltipState.owner == sharePositionRow, "test_share_widget_position_tooltip: tooltip should use the toggle row as owner")
    assert(tooltipState.anchor == "ANCHOR_TOP", "test_share_widget_position_tooltip: tooltip should anchor above the toggle row")
    assert(
      tooltipState.title == "Share widget position across characters",
      "test_share_widget_position_tooltip: tooltip should use the localized title"
    )
    assert(
      tooltipState.lines[1] == "Uses one widget position for all characters on this WoW account.",
      "test_share_widget_position_tooltip: tooltip should explain account-wide sharing"
    )
    assert(tooltipState.shown == true, "test_share_widget_position_tooltip: tooltip should show on enter")
    local sharePositionOnLeave = sharePositionRow:GetScript("OnLeave")
    assert(sharePositionOnLeave ~= nil, "test_share_widget_position_tooltip: toggle row should have OnLeave script")
    sharePositionOnLeave(sharePositionRow)
    assert(tooltipState.hidden == true, "test_share_widget_position_tooltip: tooltip should hide on leave")
    _G.GameTooltip = savedTooltip
    assert(
      FindUI.slider(result.frame, "Auto-dismiss widget preview") ~= nil,
      "test_icons_owns_all_icon_and_widget_controls: auto-dismiss slider should exist"
    )
    assert(
      #FindUI.selectorButtons(result.frame, "Widget preview position") > 0,
      "test_icons_owns_all_icon_and_widget_controls: preview position selector should exist"
    )
    assert(
      FindUI.text(result.frame, "Play sound on new whisper") == nil,
      "test_icons_owns_all_icon_and_widget_controls: Icons should not render the play sound toggle"
    )
    assert(
      FindUI.text(result.frame, "Notification sound") == nil,
      "test_icons_owns_all_icon_and_widget_controls: Icons should not render the sound selector"
    )
    assert(result.frame._wmBottomMarker ~= nil, "test_icons_owns_all_icon_and_widget_controls: panel should retain bottom marker")
  end

  -- test_icon_and_widget_controls_fire_existing_keys

  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    FindUI.click(modeButtons(result)[3])
    FindUI.slider(result.frame, "Icon Size"):SetValue(32)
    clickToggle(result, "Desaturate icon when idle")
    clickToggle(result, "Lock icon position")
    clickToggle(result, SHARE_POSITION)
    clickToggle(result, "Show unread badge")
    clickToggle(result, "Badge pulse animation")
    clickToggle(result, "Show widget message preview")
    local transparencySlider = FindUI.slider(result.frame, TRANSPARENCY)
    transparencySlider:SetValue(0.4)
    assert(
      transparencySlider.parent.children[2].text == "40%",
      "test_icon_and_widget_controls_fire_existing_keys: widget transparency should display a percent"
    )
    FindUI.slider(result.frame, "Auto-dismiss widget preview"):SetValue(60)
    FindUI.click(FindUI.selectorButtons(result.frame, "Widget preview position")[2])

    assert(changes.iconMode == "both", "test_icon_and_widget_controls_fire_existing_keys: iconMode should be both")
    assert(changes.iconSize == 32, "test_icon_and_widget_controls_fire_existing_keys: iconSize should be 32")
    assert(changes.iconDesaturated == false, "test_icon_and_widget_controls_fire_existing_keys: iconDesaturated should be false")
    assert(changes.lockToggleIcon == true, "test_icon_and_widget_controls_fire_existing_keys: lockToggleIcon should be true")
    assert(changes.shareWidgetPosition == true, "test_icon_and_widget_controls_fire_existing_keys: shareWidgetPosition should be true")
    assert(changes.showUnreadBadge == false, "test_icon_and_widget_controls_fire_existing_keys: showUnreadBadge should be false")
    assert(changes.badgePulse == false, "test_icon_and_widget_controls_fire_existing_keys: badgePulse should be false")
    assert(changes.showWidgetMessagePreview == false, "test_icon_and_widget_controls_fire_existing_keys: showWidgetMessagePreview should be false")
    assert(changes.transparentWidget == nil, "test_icon_and_widget_controls_fire_existing_keys: transparentWidget should not be emitted")
    assert(changes.widgetTransparency == 0.4, "test_icon_and_widget_controls_fire_existing_keys: widget transparency should be 0.4")
    assert(changes.widgetPreviewAutoDismissSeconds == 60, "test_icon_and_widget_controls_fire_existing_keys: auto-dismiss should be 60")
    assert(changes.widgetPreviewPosition == "left", "test_icon_and_widget_controls_fire_existing_keys: position should be left")
  end

  -- test_none_icon_mode_fires_none_key

  do
    local selectedMode
    local result = IconSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        if key == "iconMode" then
          selectedMode = value
        end
      end,
    })

    FindUI.click(modeButtons(result)[4])
    assert(selectedMode == "none", "test_none_icon_mode_fires_none_key: iconMode should be none")
  end

  -- test_icons_reset_emits_only_icon_and_widget_defaults

  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, {
      iconMode = "both",
      iconSize = 56,
      iconDesaturated = false,
      lockToggleIcon = true,
      showUnreadBadge = false,
      badgePulse = false,
      showWidgetMessagePreview = false,
      widgetTransparency = 0.25,
      widgetPreviewAutoDismissSeconds = 60,
      widgetPreviewPosition = "top",
    }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))

    local expected = {
      iconMode = "widget",
      iconSize = 42,
      iconDesaturated = true,
      lockToggleIcon = false,
      shareWidgetPosition = false,
      showUnreadBadge = true,
      badgePulse = true,
      showWidgetMessagePreview = true,
      widgetTransparency = 0,
      widgetPreviewAutoDismissSeconds = 30,
      widgetPreviewPosition = "right",
    }
    local resetCount = 0
    for key, value in pairs(changes) do
      assert(expected[key] == value, "test_icons_reset_emits_only_icon_and_widget_defaults: unexpected reset key " .. tostring(key))
      resetCount = resetCount + 1
    end
    for key, value in pairs(expected) do
      assert(changes[key] == value, "test_icons_reset_emits_only_icon_and_widget_defaults: wrong default for " .. key)
    end
    assert(resetCount == 11, "test_icons_reset_emits_only_icon_and_widget_defaults: reset should emit eleven icon/widget keys")
  end

  -- test_icons_refresh_layout_and_language

  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    result.refreshLayout(260)
    assert(FindUI.byLabel(result.frame, "Badge pulse animation").width == 260, "test_icons_refresh_layout_and_language: toggle rows should resize")
    assert(
      FindUI.byLabel(result.frame, "Widget preview position").width == 260,
      "test_icons_refresh_layout_and_language: selector rows should resize"
    )

    Localization.Configure({ language = "ruRU" })
    result.setLanguage()
    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["Значки"], "test_icons_refresh_layout_and_language: Icons title should be localized")
    assert(
      texts["Настройте параметры значков и виджета."],
      "test_icons_refresh_layout_and_language: Icons hint should be localized"
    )
    assert(
      FindUI.toggle(result.frame, "Закрепить позицию значка") ~= nil,
      "test_icons_refresh_layout_and_language: existing labels should remain localized"
    )
    Localization.Configure({ language = "enUS" })
  end

  print("  All icon settings tests passed")
end
