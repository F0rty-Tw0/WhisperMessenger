local FakeUI = require("tests.helpers.fake_ui")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local MAX_MESSAGES = "Max Messages Per Contact"
local MAX_CONTACTS = "Max Contacts"
local RETENTION = "Message Retention (hours)"

local function slider(settings, label)
  return FindUI.slider(settings.frame, label)
end

-- Min and max range labels hang under the slider, in that order.
local function rangeLabels(settings, label)
  local labels = FindUI.ofType(slider(settings, label), "FontString")
  return labels[1], labels[2]
end

local function languageButtons(settings, language)
  return FindUI.selectorButtons(settings.frame, Localization.Text("Interface Language", language))
end

local function resetButton(settings)
  return FindUI.byLabel(settings.frame, "Reset to Defaults")
end

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
    assert(slider(settings, MAX_MESSAGES) ~= nil, "should render a max messages slider")
    assert(slider(settings, MAX_CONTACTS) ~= nil, "should render a max contacts slider")
    assert(slider(settings, RETENTION) ~= nil, "should render a retention slider")
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

  -- test_language_selector_supports_russian_setting

  do
    local lastChange = nil
    local settings = GeneralSettings.Create(factory, parent, {
      interfaceLanguage = "ruRU",
    }, {
      onChange = function(key, value)
        lastChange = { key = key, value = value }
      end,
    })

    local buttons = languageButtons(settings, "ruRU")
    assert(#buttons > 0, "should render the language selector in Russian")

    local ruRUButton = nil
    for _, button in ipairs(buttons) do
      if button._key == "ruRU" then
        ruRUButton = button
        break
      end
    end
    assert(ruRUButton ~= nil, "should expose Russian language option")
    assert(ruRUButton._selected == true, "ruRU option should be selected")

    local texts = {}
    for _, child in ipairs(settings.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["Общие настройки"], "Russian language should translate the General Settings header")

    local englishButton = buttons[2]
    assert(englishButton.scripts and englishButton.scripts.OnClick, "English language button needs OnClick")
    englishButton.scripts.OnClick(englishButton)
    assert(lastChange ~= nil, "language selector click should fire onChange")
    assert(lastChange.key == "interfaceLanguage", "language selector should persist interfaceLanguage")
    assert(lastChange.value == "enUS", "language selector should select enUS")

    settings.setLanguage("enUS")
    buttons = languageButtons(settings, "enUS")
    assert(buttons[2]._selected == true, "setLanguage should select enUS")
    assert(buttons[2].label.text == "English", "setLanguage should update English button label")

    ruRUButton = nil
    for _, button in ipairs(buttons) do
      if button._key == "ruRU" then
        ruRUButton = button
        break
      end
    end
    assert(ruRUButton ~= nil, "should still expose Russian option after setLanguage")
    assert(ruRUButton.label.text == "Русский", "setLanguage should keep the Russian autonym label")

    texts = {}
    for _, child in ipairs(settings.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["General Settings"], "setLanguage should update the existing General Settings header")
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

    local maxMessages = slider(settings, MAX_MESSAGES):GetValue()
    local maxContacts = slider(settings, MAX_CONTACTS):GetValue()
    local retention = slider(settings, RETENTION):GetValue()
    assert(maxMessages == 150, "maxMessagesSlider should start at 150, got: " .. tostring(maxMessages))
    assert(maxContacts == 100, "maxConversationsSlider should start at 100, got: " .. tostring(maxContacts))
    -- Retention slider uses hours: 43200 / 3600 = 12
    assert(retention == 12, "retentionSlider should start at 12h, got: " .. tostring(retention))
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
    slider(settings, MAX_MESSAGES):SetValue(300)
    assert(lastChange ~= nil, "onChange should fire on slider change")
    assert(lastChange.key == "maxMessagesPerConversation", "key should be maxMessagesPerConversation")
    assert(lastChange.value == 300, "value should be 300, got: " .. tostring(lastChange.value))

    lastChange = nil
    slider(settings, RETENTION):SetValue(48)
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
    local messagesMin, messagesMax = rangeLabels(settings, MAX_MESSAGES)
    assert(messagesMin and messagesMin.text == "50", "min label should be '50', got: " .. tostring(messagesMin and messagesMin.text))
    assert(messagesMax and messagesMax.text == "500", "max label should be '500', got: " .. tostring(messagesMax and messagesMax.text))

    local contactsMin, contactsMax = rangeLabels(settings, MAX_CONTACTS)
    assert(contactsMin and contactsMin.text == "10", "min label should be '10', got: " .. tostring(contactsMin and contactsMin.text))
    assert(contactsMax and contactsMax.text == "100", "max label should be '100', got: " .. tostring(contactsMax and contactsMax.text))

    local retentionMin, retentionMax = rangeLabels(settings, RETENTION)
    assert(retentionMin and retentionMin.text == "1", "min label should be '1', got: " .. tostring(retentionMin and retentionMin.text))
    assert(retentionMax and retentionMax.text == "168", "max label should be '168', got: " .. tostring(retentionMax and retentionMax.text))
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

    local reset = resetButton(settings)
    assert(reset.frameType == "Button", "should render a Reset to Defaults button")
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
    local maxMessages = slider(settings, MAX_MESSAGES)
    local maxContacts = slider(settings, MAX_CONTACTS)
    local retention = slider(settings, RETENTION)
    assert(maxMessages:GetValue() == 300, "should start at 300")
    assert(maxContacts:GetValue() == 50, "should start at 50")
    assert(retention:GetValue() == 2, "should start at 2h")

    -- Click reset
    FindUI.click(resetButton(settings))

    -- Sliders should be back to defaults
    assert(maxMessages:GetValue() == 200, "maxMessages should reset to 200, got: " .. tostring(maxMessages:GetValue()))
    assert(maxContacts:GetValue() == 100, "maxConversations should reset to 100, got: " .. tostring(maxContacts:GetValue()))
    assert(retention:GetValue() == 24, "retention should reset to 24h, got: " .. tostring(retention:GetValue()))

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

    local dot = FindUI.toggle(settings.frame, "Clear on logout")
    -- Second texture of the switch = the rounded track's second fill.
    local track = FindUI.ofType(dot, "Texture")[2]
    local offDefault = Theme.COLORS.option_toggle_off
    assert(colorsMatch(track.color, offDefault), "expected unchecked toggle to use option_toggle_off")

    local onClick = dot:GetScript("OnClick")
    assert(onClick ~= nil, "expected toggle dot click handler")
    onClick(dot)

    local onDefault = Theme.COLORS.option_toggle_on
    assert(colorsMatch(track.color, onDefault), "expected checked toggle to use option_toggle_on")

    if Theme.SetPreset then
      Theme.SetPreset("plumber_warm")
      settings.refreshTheme(Theme)
    end

    local onPlumber = Theme.COLORS.option_toggle_on
    assert(colorsMatch(track.color, onPlumber), "expected checked toggle to repaint with preset option_toggle_on")

    onClick(dot)
    local offPlumber = Theme.COLORS.option_toggle_off
    assert(colorsMatch(track.color, offPlumber), "expected unchecked toggle to repaint with preset option_toggle_off")

    if Theme.SetPreset and previousPreset then
      Theme.SetPreset(previousPreset)
    end
  end
end
