local FakeUI = require("tests.helpers.fake_ui")
local Composer = require("WhisperMessenger.UI.Composer.Composer")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Theme = require("WhisperMessenger.UI.Theme")
local ReactionPicker = require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local SettingsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")

local function makeComposer(onSend)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 52)
  local selectedContact = {
    conversationKey = "me::WOW::test-realm",
    displayName = "Test-Realm",
    channel = "WOW",
  }
  local composer = Composer.Create(factory, parent, selectedContact, onSend or function() end, function() end)
  return composer, factory, parent
end

return function()
  local sendCount = 0
  local composer, factory, parent = makeComposer(function()
    sendCount = sendCount + 1
  end)
  local picker = composer.emojiPicker

  assert(composer.emojiButton ~= nil, "expected emoji button beside Send")
  assert(picker ~= nil, "expected composer emoji picker")
  assert(#picker.buttons == #ReactionAssets.KEYS, "picker should expose every reaction key")
  for index, key in ipairs(ReactionAssets.KEYS) do
    assert(picker.buttons[index]._emojiKey == key, "picker order must come from ReactionAssets.KEYS")
  end

  local emojiButton = composer.emojiButton
  local emojiIcon = emojiButton.icon
  local iconSize = ReactionAssets.GetIconSize() * 2
  assert(emojiIcon ~= nil, "launcher should expose its icon visual state")
  assert(emojiIcon.width == iconSize and emojiIcon.height == iconSize, "launcher icon should be exactly twice the base reaction size")
  assert(emojiButton.width >= iconSize and emojiButton.height >= iconSize, "launcher hit area should contain the enlarged icon")
  local laughCoords = ReactionAssets.GetTexCoords("laugh")
  for index = 1, 4 do
    assert(emojiIcon.texCoords[index] == laughCoords[index], "launcher should use laugh atlas coordinates")
  end
  assert(emojiButton.bg.fills[1].color[4] == 0, "launcher should be backgroundless at rest")
  local savedGameTooltip = _G.GameTooltip
  local tooltip = {
    shown = false,
  }
  function tooltip:SetOwner(owner, anchor)
    self.owner = owner
    self.anchor = anchor
  end
  function tooltip:SetText(text)
    self.text = text
  end
  function tooltip:Show()
    self.shown = true
  end
  function tooltip:Hide()
    self.shown = false
  end
  _G.GameTooltip = tooltip

  emojiButton.scripts.OnEnter(emojiButton)
  assert(tooltip.owner == emojiButton, "launcher hover should own tooltip")
  assert(tooltip.anchor == "ANCHOR_TOP", "launcher tooltip should anchor above launcher")
  assert(tooltip.text == "Emojis", "launcher hover should show Emojis label")
  assert(tooltip.shown, "launcher hover should show tooltip")
  composer.frame:Hide()
  assert(not tooltip.shown, "composer pane hide should hide tooltip")
  composer.frame:Show()
  emojiButton.scripts.OnLeave(emojiButton)
  assert(not tooltip.shown, "launcher leave should hide tooltip")

  assert(picker:open(), "picker should open before showing emoji tooltips")
  for index, key in ipairs(ReactionAssets.KEYS) do
    local pickerButton = picker.buttons[index]
    pickerButton.scripts.OnEnter(pickerButton)
    assert(tooltip.owner == pickerButton, "picker hover should own tooltip")
    assert(tooltip.anchor == "ANCHOR_TOP", "picker tooltip should anchor above picker button")
    assert(tooltip.text == ":" .. key .. ":", "picker hover should show exact emoji token")
    assert(tooltip.shown, "picker hover should show tooltip")
    pickerButton.scripts.OnLeave(pickerButton)
    assert(not tooltip.shown, "picker leave should hide tooltip")
  end
  picker.buttons[1].scripts.OnEnter(picker.buttons[1])
  picker:close()
  assert(not tooltip.shown, "picker close should hide tooltip")
  assert(picker:open(), "picker should reopen before disable tooltip check")
  picker.buttons[1].scripts.OnEnter(picker.buttons[1])
  picker:setEnabled(false)
  assert(not tooltip.shown, "picker disable should hide tooltip")
  picker:setEnabled(true)

  emojiButton.scripts.OnEnter(emojiButton)
  emojiButton.scripts.OnClick(emojiButton)
  assert(not tooltip.shown, "launcher click should hide tooltip")

  emojiButton.scripts.OnEnter(emojiButton)
  composer.setEnabled(false)
  assert(not tooltip.shown, "launcher disable should hide tooltip")
  composer.setEnabled(true)

  emojiButton.scripts.OnEnter(emojiButton)
  local hoverColor = Theme.COLORS.option_button_hover or Theme.COLORS.bg_contact_hover
  local launcherHover = emojiButton.bg.fills[1].color
  assert(
    launcherHover[1] == hoverColor[1]
      and launcherHover[2] == hoverColor[2]
      and launcherHover[3] == hoverColor[3]
      and launcherHover[4] == (hoverColor[4] or 1),
    "launcher hover should use picker highlight color"
  )
  emojiButton.scripts.OnLeave(emojiButton)
  assert(emojiButton.bg.fills[1].color[4] == 0, "launcher should remove its background after hover")

  local savedUIParent = _G.UIParent
  _G.UIParent = parent
  local reactionAnchor = factory.CreateFrame("Frame", nil, parent)
  assert(ReactionPicker.Open(factory, reactionAnchor, {
    kind = "user",
    direction = "in",
    text = "picker theme",
  }, function() end, function() end), "reaction picker should open for theme comparison")
  local reactionPicker = ReactionPicker.GetFrame()
  local reactionBackground = reactionPicker._background.color
  local composerBackground = picker.frame._background.color
  assert(
    reactionBackground[1] == composerBackground[1]
      and reactionBackground[2] == composerBackground[2]
      and reactionBackground[3] == composerBackground[3]
      and reactionBackground[4] == composerBackground[4],
    "picker panels should resolve identical theme backgrounds"
  )
  reactionPicker._reactionButtons[1].scripts.OnEnter(reactionPicker._reactionButtons[1])
  picker.buttons[1].scripts.OnEnter(picker.buttons[1])
  local reactionHighlight = reactionPicker._reactionButtons[1]._selectedMark.color
  local composerHighlight = picker.buttons[1]._highlight.color
  assert(
    reactionHighlight[1] == composerHighlight[1]
      and reactionHighlight[2] == composerHighlight[2]
      and reactionHighlight[3] == composerHighlight[3],
    "picker highlights should resolve identical theme colors"
  )
  picker.buttons[1].scripts.OnLeave(picker.buttons[1])
  reactionPicker._reactionButtons[1].scripts.OnLeave(reactionPicker._reactionButtons[1])
  ReactionPicker.Close()
  _G.UIParent = savedUIParent

  local savedOptionHover = Theme.COLORS.option_button_hover
  local refreshedHover = { 0.71, 0.62, 0.53, 0.64 }
  local activeHighlight = picker.buttons[1]._highlight
  local inactiveHighlight = picker.buttons[2]._highlight
  emojiButton.mouseOver = true
  emojiButton.scripts.OnEnter(emojiButton)
  assert(picker:open(), "picker should open before refreshing its hover texture")
  picker.buttons[1].mouseOver = true
  picker.buttons[1].scripts.OnEnter(picker.buttons[1])
  assert(activeHighlight:IsShown(), "hovered picker highlight should be visible before theme refresh")
  assert(not inactiveHighlight:IsShown(), "non-hovered picker highlight should stay hidden before theme refresh")

  Theme.COLORS.option_button_hover = refreshedHover
  picker:refreshTheme()
  assert(
    activeHighlight.color[1] == refreshedHover[1]
      and activeHighlight.color[2] == refreshedHover[2]
      and activeHighlight.color[3] == refreshedHover[3]
      and activeHighlight.color[4] == refreshedHover[4],
    "picker refresh should repaint hovered highlight with current shared color"
  )
  assert(activeHighlight:IsShown(), "picker refresh should preserve visible highlight state")
  assert(not inactiveHighlight:IsShown(), "picker refresh should preserve hidden highlight state")

  composer.refreshTheme()
  local refreshedLauncherHover = emojiButton.bg.fills[1].color
  assert(
    refreshedLauncherHover[1] == refreshedHover[1]
      and refreshedLauncherHover[2] == refreshedHover[2]
      and refreshedLauncherHover[3] == refreshedHover[3]
      and refreshedLauncherHover[4] == refreshedHover[4],
    "launcher refresh should retain hover using current shared color"
  )
  assert(
    activeHighlight.color[1] == refreshedHover[1]
      and activeHighlight.color[2] == refreshedHover[2]
      and activeHighlight.color[3] == refreshedHover[3]
      and activeHighlight.color[4] == refreshedHover[4],
    "composer refresh should repaint picker hover with current shared color"
  )

  emojiButton.mouseOver = false
  composer.refreshTheme()
  assert(emojiButton.bg.fills[1].color[4] == 0, "non-hovered launcher should remain transparent after refresh")
  picker.buttons[1].mouseOver = false
  picker.buttons[1].scripts.OnLeave(picker.buttons[1])
  picker:close()
  Theme.COLORS.option_button_hover = savedOptionHover
  composer.refreshTheme()

  local savedFontSize = Fonts.GetFontSize()
  local settingsOnChange
  local expectedFontSize
  local themeRefreshes = 0
  local runtime = SettingsRuntime.Create(factory, {
    settingsPanelsCreate = function(_, options)
      settingsOnChange = options.onSettingChanged
      return {
        refreshTheme = function(_, targets)
          themeRefreshes = themeRefreshes + 1
          if targets.composer then
            assert(Fonts.GetFontSize() == expectedFontSize, "delegated font handler must run before theme refresh")
            targets.composer.refreshTheme()
          end
        end,
      }
    end,
    onSettingChanged = function(key, value)
      if key == "fontSize" then
        Fonts.SetFontSize(value)
      end
    end,
  })
  runtime.setThemeTargets(nil, composer)

  local function assertSettingsFontSize(fontSize, label)
    expectedFontSize = fontSize
    settingsOnChange("fontSize", fontSize)
    local iconSize = ReactionAssets.GetIconSize() * 2
    local buttonSize = math.max(30, iconSize)
    local inputWidth = parent.width - 24 - composer.sendButton.width - buttonSize - 16
    assert(emojiIcon.width == iconSize and emojiIcon.height == iconSize, label .. " settings event should resize launcher icon to twice base size")
    assert(emojiButton.width == buttonSize and emojiButton.height == buttonSize, label .. " settings event should resize launcher hit area")
    assert(composer.input.width == inputWidth and composer.inputBg.width == inputWidth, label .. " settings event should reserve launcher width from input")
  end

  assertSettingsFontSize(17, "maximum")
  assertSettingsFontSize(9, "minimum")

  local refreshesBeforeThemePreset = themeRefreshes
  settingsOnChange("themePreset", "default")
  assert(themeRefreshes == refreshesBeforeThemePreset + 1, "themePreset should continue to refresh theme visuals")

  local refreshesBeforeUnrelatedSetting = themeRefreshes
  settingsOnChange("unrelatedSetting", true)
  assert(themeRefreshes == refreshesBeforeUnrelatedSetting, "unrelated settings must not refresh theme visuals")

  Fonts.SetFontSize(savedFontSize)
  composer.refreshTheme()

  composer.input:SetText("hello")
  composer.input:SetCursorPosition(2)
  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  assert(picker.frame:IsShown(), "button click should open picker")

  picker.buttons[1].scripts.OnClick(picker.buttons[1])
  assert(composer.input:GetText() == "he:heart:llo", "heart should insert literal token at cursor")
  assert(composer.input:GetCursorPosition() == 9, "cursor should move after inserted token")
  assert(composer.input:HasFocus(), "selection should focus composer input")
  assert(not picker.frame:IsShown(), "picker should close after selection")
  assert(sendCount == 0, "emoji selection must not send")

  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  picker.frame.scripts.OnUpdate(picker.frame)
  picker.frame.mouseOver = false
  picker.frame.scripts.OnEvent(picker.frame, "GLOBAL_MOUSE_DOWN")
  assert(not picker.frame:IsShown(), "outside click should close picker")

  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  picker.frame.scripts.OnUpdate(picker.frame)
  picker.frame.mouseOver = false
  composer.emojiButton.mouseOver = true
  picker.frame.scripts.OnEvent(picker.frame, "GLOBAL_MOUSE_DOWN")
  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  assert(not picker.frame:IsShown(), "anchor click should own toggle after its mouse-down")
  composer.emojiButton.mouseOver = false

  local token = ":heart:"
  local prefix = string.rep("a", 124)
  local suffix = string.rep("b", 124)
  composer.input:SetText(prefix .. suffix)
  composer.input:SetCursorPosition(#prefix)
  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  picker.buttons[1].scripts.OnClick(picker.buttons[1])
  assert(composer.input:GetText() == prefix .. token .. suffix, "emoji token should insert at an exact 255-byte fit")
  assert(composer.input:GetCursorPosition() == #prefix + #token, "exact-fit insertion should place cursor after complete token")

  local oneByteTooLong = prefix .. string.rep("b", 125)
  composer.input:SetText(oneByteTooLong)
  composer.input:SetCursorPosition(#prefix)
  composer.input:ClearFocus()
  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  picker.buttons[1].scripts.OnClick(picker.buttons[1])
  assert(composer.input:GetText() == oneByteTooLong, "over-limit insertion must preserve the entire draft and suffix")
  assert(composer.input:GetCursorPosition() == #prefix, "over-limit insertion must preserve cursor position")
  assert(composer.input:HasFocus(), "over-limit insertion should focus composer input")

  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  composer.setEnabled(false)
  assert(composer.emojiButton.disabled, "disabling composer should disable emoji button")
  assert(not picker.frame:IsShown(), "disabling composer should close picker")
  assert(emojiButton.bg.fills[1].color[4] == 0, "disabled launcher should remain backgroundless")

  local textBeforeDisabledActions = composer.input:GetText()
  composer.emojiButton.scripts.OnClick(composer.emojiButton)
  picker.buttons[1].scripts.OnClick(picker.buttons[1])
  assert(composer.input:GetText() == textBeforeDisabledActions, "disabled picker actions must not mutate input")
  assert(sendCount == 0, "disabled picker actions must not send")
  _G.GameTooltip = savedGameTooltip
end
