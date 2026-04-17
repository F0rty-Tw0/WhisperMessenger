local FakeUI = require("tests.helpers.fake_ui")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local Theme = require("WhisperMessenger.UI.Theme")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  local epsilon = 0.0001
  for i = 1, 4 do
    local a = actual[i] or (i == 4 and 1 or nil)
    local b = expected[i] or (i == 4 and 1 or nil)
    if a == nil or b == nil or math.abs(a - b) > epsilon then
      return false
    end
  end
  return true
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 500)

  -- test_create_returns_settings_refs

  do
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 200,
      maxConversations = 200,
      messageMaxAge = 86400,
    }, {
      onChange = function() end,
    })

    assert(settings ~= nil, "Create should return a table")
    assert(settings.frame ~= nil, "should have a frame")
    assert(settings.maxMessagesSlider ~= nil, "should have maxMessagesSlider")
    assert(settings.maxConversationsSlider ~= nil, "should have maxConversationsSlider")
    assert(settings.retentionSlider ~= nil, "should have retentionSlider")
  end

  -- test_has_labels_for_each_setting

  do
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 200,
      maxConversations = 200,
      messageMaxAge = 86400,
    }, {
      onChange = function() end,
    })

    local frame = settings.frame
    local texts = {}
    for _, child in ipairs(frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["General Settings"], "should have 'General Settings' title")
  end

  -- test_slider_initial_values

  do
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 150,
      maxConversations = 100,
      messageMaxAge = 43200,
    }, {
      onChange = function() end,
    })

    assert(
      settings.maxMessagesSlider:GetValue() == 150,
      "maxMessagesSlider should start at 150, got: " .. tostring(settings.maxMessagesSlider:GetValue())
    )
    assert(
      settings.maxConversationsSlider:GetValue() == 100,
      "maxConversationsSlider should start at 100, got: " .. tostring(settings.maxConversationsSlider:GetValue())
    )
    -- Retention slider uses hours: 43200 / 3600 = 12
    assert(
      settings.retentionSlider:GetValue() == 12,
      "retentionSlider should start at 12h, got: " .. tostring(settings.retentionSlider:GetValue())
    )
  end

  -- test_on_change_fires_with_updated_values

  do
    local lastChange = nil
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 200,
      maxConversations = 200,
      messageMaxAge = 86400,
    }, {
      onChange = function(key, value)
        lastChange = { key = key, value = value }
      end,
    })

    -- Simulate slider change
    settings.maxMessagesSlider:SetValue(300)
    assert(lastChange ~= nil, "onChange should fire on slider change")
    assert(lastChange.key == "maxMessagesPerConversation", "key should be maxMessagesPerConversation")
    assert(lastChange.value == 300, "value should be 300, got: " .. tostring(lastChange.value))

    lastChange = nil
    settings.retentionSlider:SetValue(48)
    assert(lastChange ~= nil, "onChange should fire on retention change")
    assert(lastChange.key == "messageMaxAge", "key should be messageMaxAge")
    -- 48 hours = 172800 seconds
    assert(lastChange.value == 172800, "value should be 172800, got: " .. tostring(lastChange.value))
  end

  -- test_slider_rows_have_min_max_labels

  do
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 200,
      maxConversations = 200,
      messageMaxAge = 86400,
    }, {
      onChange = function() end,
    })

    -- Each slider row should have min and max labels
    assert(settings.maxMessagesMinLabel ~= nil, "should have maxMessagesMinLabel")
    assert(settings.maxMessagesMaxLabel ~= nil, "should have maxMessagesMaxLabel")
    assert(
      settings.maxMessagesMinLabel.text == "50",
      "min label should be '50', got: " .. tostring(settings.maxMessagesMinLabel.text)
    )
    assert(
      settings.maxMessagesMaxLabel.text == "500",
      "max label should be '500', got: " .. tostring(settings.maxMessagesMaxLabel.text)
    )

    assert(settings.maxConversationsMinLabel ~= nil, "should have maxConversationsMinLabel")
    assert(settings.maxConversationsMaxLabel ~= nil, "should have maxConversationsMaxLabel")
    assert(
      settings.maxConversationsMinLabel.text == "10",
      "min label should be '10', got: " .. tostring(settings.maxConversationsMinLabel.text)
    )
    assert(
      settings.maxConversationsMaxLabel.text == "100",
      "max label should be '100', got: " .. tostring(settings.maxConversationsMaxLabel.text)
    )

    assert(settings.retentionMinLabel ~= nil, "should have retentionMinLabel")
    assert(settings.retentionMaxLabel ~= nil, "should have retentionMaxLabel")
    assert(
      settings.retentionMinLabel.text == "1",
      "min label should be '1', got: " .. tostring(settings.retentionMinLabel.text)
    )
    assert(
      settings.retentionMaxLabel.text == "168",
      "max label should be '168', got: " .. tostring(settings.retentionMaxLabel.text)
    )
  end

  -- test_reset_button_exists

  do
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 200,
      maxConversations = 200,
      messageMaxAge = 86400,
    }, {
      onChange = function() end,
    })

    assert(settings.resetButton ~= nil, "should have a resetButton")

    -- Check it has a label
    local foundLabel = false
    for _, child in ipairs(settings.resetButton.children) do
      if child.text and string.find(child.text, "Reset", 1, true) then
        foundLabel = true
        break
      end
    end
    assert(foundLabel, "resetButton should have a label containing 'Reset'")
  end

  -- test_reset_button_restores_defaults

  do
    local changes = {}
    local settings = GeneralSettings.Create(factory, parent, {
      maxMessagesPerConversation = 300,
      maxConversations = 50,
      messageMaxAge = 7200,
    }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Verify sliders start at non-default values
    assert(settings.maxMessagesSlider:GetValue() == 300, "should start at 300")
    assert(settings.maxConversationsSlider:GetValue() == 50, "should start at 50")
    assert(settings.retentionSlider:GetValue() == 2, "should start at 2h")

    -- Click reset
    assert(settings.resetButton.scripts and settings.resetButton.scripts.OnClick, "resetButton needs OnClick")
    settings.resetButton.scripts.OnClick(settings.resetButton)

    -- Sliders should be back to defaults
    assert(
      settings.maxMessagesSlider:GetValue() == 200,
      "maxMessages should reset to 200, got: " .. tostring(settings.maxMessagesSlider:GetValue())
    )
    assert(
      settings.maxConversationsSlider:GetValue() == 100,
      "maxConversations should reset to 100, got: " .. tostring(settings.maxConversationsSlider:GetValue())
    )
    assert(
      settings.retentionSlider:GetValue() == 24,
      "retention should reset to 24h, got: " .. tostring(settings.retentionSlider:GetValue())
    )

    -- onChange should have fired for each
    assert(changes.maxMessagesPerConversation == 200, "should fire onChange for maxMessagesPerConversation=200")
    assert(changes.maxConversations == 100, "should fire onChange for maxConversations=100")
    assert(changes.messageMaxAge == 86400, "should fire onChange for messageMaxAge=86400")
  end

  -- test_toggle_checked_state_uses_option_toggle_theme_tokens

  do
    local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
    if Theme.SetPreset then
      Theme.SetPreset("wow_default")
    end

    local settings = GeneralSettings.Create(factory, parent, {
      clearOnLogout = false,
      hideMessagePreview = false,
    }, {
      onChange = function() end,
    })

    local offDefault = Theme.COLORS.option_toggle_off
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBg.color, offDefault),
      "expected unchecked toggle to use option_toggle_off"
    )
    local borderDefault = Theme.COLORS.option_toggle_border
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBorder.color, borderDefault),
      "expected toggle border to use option_toggle_border"
    )

    local onClick = settings.clearOnLogoutToggle.dot:GetScript("OnClick")
    assert(onClick ~= nil, "expected toggle dot click handler")
    onClick(settings.clearOnLogoutToggle.dot)

    local onDefault = Theme.COLORS.option_toggle_on
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBg.color, onDefault),
      "expected checked toggle to use option_toggle_on"
    )
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBorder.color, onDefault),
      "expected checked toggle border to use option_toggle_on for stronger visibility"
    )

    if Theme.SetPreset then
      Theme.SetPreset("plumber_warm")
      settings.refreshTheme(Theme)
    end

    local onPlumber = Theme.COLORS.option_toggle_on
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBg.color, onPlumber),
      "expected checked toggle to repaint with preset option_toggle_on"
    )
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBorder.color, onPlumber),
      "expected checked toggle border to repaint with preset option_toggle_on"
    )

    onClick(settings.clearOnLogoutToggle.dot)
    local offPlumber = Theme.COLORS.option_toggle_off
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBg.color, offPlumber),
      "expected unchecked toggle to repaint with preset option_toggle_off"
    )
    local borderPlumber = Theme.COLORS.option_toggle_border
    assert(
      colorsMatch(settings.clearOnLogoutToggle.dotBorder.color, borderPlumber),
      "expected toggle border to repaint with preset option_toggle_border"
    )

    if Theme.SetPreset and previousPreset then
      Theme.SetPreset(previousPreset)
    end
  end
end
