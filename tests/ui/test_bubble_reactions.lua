local FakeUI = require("tests.helpers.fake_ui")
local assetsLoaded, ReactionAssets = pcall(require, "WhisperMessenger.UI.ChatBubble.ReactionAssets")
local pickerLoaded, ReactionPicker = pcall(require, "WhisperMessenger.UI.ChatBubble.ReactionPicker")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

local function findBubble(contentFrame)
  for _, frame in ipairs(contentFrame._activeFrames or {}) do
    if frame._textFS then
      return frame
    end
  end
  return nil
end

return function()
  assert(assetsLoaded, "ReactionAssets module should load before bubble reaction behavior can pass")
  assert(pickerLoaded, "ReactionPicker module should load before bubble reaction behavior can pass")

  local savedCreateFrame = _G.CreateFrame
  local savedUIParent = _G.UIParent
  local savedTooltip = _G.GameTooltip
  local savedChatInfo = _G.C_ChatInfo
  local savedClipboard = _G.C_Clipboard

  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(1920, 1080)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UIParent = uiParent

  local tooltipText
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text)
      tooltipText = text
    end,
    Show = function() end,
    Hide = function()
      tooltipText = nil
    end,
  }

  local initialPicker
  -- WoW FontStrings require a font before SetText, and named frames begin shown.
  do
    local strictBase = FakeUI.NewFactory()
    local namedFrame
    local hiddenBeforeChild
    local enableKeyboardCalls = 0
    local keyHandlerInstalls = 0
    local strictFactory = {
      CreateFrame = function(frameType, name, parent, template)
        if parent == namedFrame and hiddenBeforeChild == nil then
          hiddenBeforeChild = namedFrame.shown == false
        end
        local frame = strictBase.CreateFrame(frameType, name, parent, template)
        frame.shown = true
        if name == "WhisperMessengerReactionPicker" then
          namedFrame = frame
          local enableKeyboard = frame.EnableKeyboard
          frame.EnableKeyboard = function(self, value)
            enableKeyboardCalls = enableKeyboardCalls + 1
            if enableKeyboard then
              return enableKeyboard(self, value)
            end
          end
          local setScript = frame.SetScript
          frame.SetScript = function(self, eventName, handler)
            if eventName == "OnKeyDown" and handler ~= nil then
              keyHandlerInstalls = keyHandlerInstalls + 1
            end
            return setScript(self, eventName, handler)
          end
        end
        local createFontString = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
          local fontString = createFontString(self, ...)
          local setText = fontString.SetText
          fontString.SetText = function(target, text)
            if target.fontObject == nil and target.font == nil then
              error("FontString:SetText(): Font not set")
            end
            return setText(target, text)
          end
          return fontString
        end
        return frame
      end,
    }
    local anchor = strictFactory.CreateFrame("Frame", nil, uiParent)
    local ok, opened = pcall(ReactionPicker.Open, strictFactory, anchor, {
      kind = "user",
      direction = "in",
      text = "strict font order",
    }, function() end, function() end)
    assert(ok, "strict FontString picker construction should succeed: " .. tostring(opened))
    assert(opened == true, "strict FontString picker should open")
    assert(hiddenBeforeChild == true, "named picker should hide before child construction")
    assert(enableKeyboardCalls == 0, "picker must not enable keyboard input")
    assert(keyHandlerInstalls == 0, "picker must not install OnKeyDown")
    local registeredSpecialFrame = false
    for _, frameName in ipairs(_G.UISpecialFrames or {}) do
      if frameName == "WhisperMessengerReactionPicker" then
        registeredSpecialFrame = true
      end
    end
    assert(registeredSpecialFrame, "picker should rely on UISpecialFrames for Escape")
    initialPicker = ReactionPicker.GetFrame()
    ReactionPicker.Close()
  end

  -- Eligible incoming messages support double-click heart and eighteen-key picker.
  do
    local parent = factory.CreateFrame("Frame", nil, uiParent)
    parent:SetSize(400, 600)
    local reactions = {}
    local message = {
      kind = "user",
      direction = "in",
      text = "React to me",
      sentAt = 100,
      playerName = "Arthas",
      channel = "WOW",
    }
    local bubble = BubbleFrame.CreateBubble(factory, parent, message, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
      onReact = function(target, key)
        table.insert(reactions, { target = target, key = key })
      end,
    })

    assert(bubble.frame.frameType == "Button", "double-click target should use WoW's Button widget")
    assert(type(bubble.frame.scripts.OnDoubleClick) == "function", "eligible bubble should wire double-click")
    bubble.frame.scripts.OnDoubleClick(bubble.frame, "LeftButton")
    assert(#reactions == 1 and reactions[1].target == message and reactions[1].key == "heart", "double-click should request heart")

    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    local picker = ReactionPicker.GetFrame()
    assert(picker == initialPicker, "factory change should reuse existing named picker")
    assert(picker and picker.shown == true, "picker should show immediately during bubble OnMouseDown")
    assert(picker._dismissArmed == false, "newly opened picker should not be armed in opening tick")
    picker.mouseOver = false
    picker.scripts.OnEvent(picker, "GLOBAL_MOUSE_DOWN")
    assert(picker.shown == true, "same-tick opening GLOBAL_MOUSE_DOWN must not close picker")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(picker._dismissLayer == nil, "picker must not create a fullscreen dismiss overlay")
    for _, child in ipairs(uiParent.children or {}) do
      assert(
        not (child.allPoints == uiParent and child.mouseEnabled == true and child.shown == true),
        "no fullscreen mouse-enabled overlay may be shown"
      )
    end
    assert(picker.events and picker.events.GLOBAL_MOUSE_DOWN == true, "picker should register GLOBAL_MOUSE_DOWN while open")
    assert(picker._anchor == bubble.frame, "picker should anchor to clicked bubble")
    assert(picker.clamped == true, "picker should clamp to screen")
    assert(#picker._reactionButtons == 18, "picker should contain exactly eighteen reaction buttons")
    local backgroundColor = Theme.COLORS.bg_header
    assert(
      picker._background.color[1] == backgroundColor[1]
        and picker._background.color[2] == backgroundColor[2]
        and picker._background.color[3] == backgroundColor[3]
        and picker._background.color[4] == 0.96,
      "picker background should preserve theme RGB with forced 0.96 alpha"
    )
    local border = picker._border
    assert(border and border.top and border.left and border.right and border.bottom, "picker should create four border edges")
    assert(border.top.height == 1 and border.bottom.height == 1, "horizontal picker border edges should be 1px")
    assert(border.left.width == 1 and border.right.width == 1, "vertical picker border edges should be 1px")
    local borderThemeColor = Theme.COLORS.contacts_border_right or Theme.COLORS.divider
    for _, edge in pairs(border) do
      assert(
        edge.color[1] == borderThemeColor[1] and edge.color[2] == borderThemeColor[2] and edge.color[3] == borderThemeColor[3] and edge.color[4] == 1,
        "picker border should use strong current theme color"
      )
    end

    local savedBackground = Theme.COLORS.bg_header
    local savedContactsBorder = Theme.COLORS.contacts_border_right
    Theme.COLORS.bg_header = { 0.11, 0.22, 0.33, 0.20 }
    local function recordPickerReaction(target, key)
      table.insert(reactions, { target = target, key = key })
    end
    Theme.COLORS.contacts_border_right = { 0.44, 0.55, 0.66, 0.10 }
    ReactionPicker.Open(factory, bubble.frame, message, recordPickerReaction, function() end)
    assert(
      picker._background.color[1] == 0.11
        and picker._background.color[2] == 0.22
        and picker._background.color[3] == 0.33
        and picker._background.color[4] == 0.96,
      "picker reopen should reapply current theme background"
    )
    for _, edge in pairs(border) do
      assert(
        edge.color[1] == 0.44 and edge.color[2] == 0.55 and edge.color[3] == 0.66 and edge.color[4] == 1,
        "picker reopen should reapply current strong border color"
      )
    end
    Theme.COLORS.bg_header = savedBackground
    Theme.COLORS.contacts_border_right = savedContactsBorder
    ReactionPicker.Open(factory, bubble.frame, message, recordPickerReaction, function() end)
    assert(#ReactionAssets.KEYS == 18, "reaction assets should expose every approved reaction key")
    for index, key in ipairs(ReactionAssets.KEYS) do
      local button = picker._reactionButtons[index]
      assert(button._reactionKey == key, "picker order should match approved key order")
      assert(button._icon.texturePath == ReactionAssets.TEXTURE, "picker icon should use bundled atlas")
      local coords = ReactionAssets.GetTexCoords(key)
      assert(type(coords) == "table" and #coords == 4, "every approved key should have atlas coordinates: " .. key)
      assert(
        type(coords[1]) == "number"
          and type(coords[2]) == "number"
          and type(coords[3]) == "number"
          and type(coords[4]) == "number"
          and coords[1] >= 0
          and coords[1] < coords[2]
          and coords[2] <= 1
          and coords[3] >= 0
          and coords[3] < coords[4]
          and coords[4] <= 1,
        "atlas coordinates should define a normalized region: " .. key
      )
      for coordIndex = 1, 4 do
        assert(type(coords[coordIndex]) == "number", "atlas coordinate should be numeric: " .. key)
        assert(button._icon.texCoords[coordIndex] == coords[coordIndex], "picker atlas coordinate should match key")
      end
      button.scripts.OnEnter(button)
      assert(tooltipText == ":" .. key .. ":", "picker tooltip should expose shortcode")
      button.scripts.OnLeave(button)
    end

    picker._reactionButtons[2].scripts.OnClick(picker._reactionButtons[2])
    assert(#reactions == 2 and reactions[2].key == "thumbsup", "picker selection should request selected key")
    assert(picker.shown == false, "selection should dismiss picker")

    message.reaction = { key = "heart", actorName = "Artio", updatedAt = 101 }
    message._pendingReaction = { token = 1, operation = "set", key = "laugh", actorName = "Artio" }
    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(picker._reactionButtons[3]._selected == true, "picker should select effective pending reaction")
    assert(picker._reactionButtons[3]._selectedMark.shown == true, "pending selected state should include a visible shape")
    assert(picker._reactionButtons[1]._selected == false, "confirmed reaction should not remain selected behind pending state")
    local hoverTheme = Theme.COLORS.option_button_hover or Theme.COLORS.bg_contact_hover
    local selectedColor = picker._reactionButtons[3]._selectedMark.color
    assert(
      selectedColor[1] == hoverTheme[1]
        and selectedColor[2] == hoverTheme[2]
        and selectedColor[3] == hoverTheme[3]
        and selectedColor[4] == (hoverTheme[4] or 1),
      "selected highlight should use full configured hover theme color"
    )
    picker._reactionButtons[1].scripts.OnEnter(picker._reactionButtons[1])
    local hoverColor = picker._reactionButtons[1]._selectedMark.color
    assert(
      hoverColor[1] == hoverTheme[1] and hoverColor[2] == hoverTheme[2] and hoverColor[3] == hoverTheme[3] and hoverColor[4] == 0.35,
      "hover highlight should use hover theme RGB with alpha 0.35"
    )
    local copyHighlight = picker._copyButton._highlight
    assert(copyHighlight, "Copy Text should expose a hover highlight")
    assert(not copyHighlight:IsShown(), "Copy Text highlight should be hidden at rest")
    picker._copyButton.scripts.OnEnter(picker._copyButton)
    assert(copyHighlight:IsShown(), "Copy Text hover should show its highlight")
    local copyColor = copyHighlight.color
    assert(
      copyColor[1] == hoverColor[1] and copyColor[2] == hoverColor[2] and copyColor[3] == hoverColor[3] and copyColor[4] == hoverColor[4],
      "Copy Text hover should use identical reaction-item highlight RGBA"
    )
    picker._copyButton.scripts.OnLeave(picker._copyButton)
    assert(not copyHighlight:IsShown(), "Copy Text leave should hide its highlight")
    picker._reactionButtons[1].scripts.OnLeave(picker._reactionButtons[1])

    local savedOptionHover = Theme.COLORS.option_button_hover
    Theme.COLORS.option_button_hover = { 0.71, 0.62, 0.53, 0.64 }
    ReactionPicker.Open(factory, bubble.frame, message, recordPickerReaction, function() end)
    selectedColor = picker._reactionButtons[3]._selectedMark.color
    assert(
      selectedColor[1] == 0.71 and selectedColor[2] == 0.62 and selectedColor[3] == 0.53 and selectedColor[4] == 0.64,
      "picker reopen should reapply selected hover theme at full alpha"
    )
    picker._reactionButtons[1].scripts.OnEnter(picker._reactionButtons[1])
    hoverColor = picker._reactionButtons[1]._selectedMark.color
    assert(
      hoverColor[1] == 0.71 and hoverColor[2] == 0.62 and hoverColor[3] == 0.53 and hoverColor[4] == 0.35,
      "picker reopen should reapply hover RGB with forced alpha"
    )
    picker._reactionButtons[1].scripts.OnLeave(picker._reactionButtons[1])
    Theme.COLORS.option_button_hover = savedOptionHover
    ReactionPicker.Open(factory, bubble.frame, message, recordPickerReaction, function() end)
    message._pendingReaction = nil

    assert(picker.scripts.OnKeyDown == nil, "picker must not capture keyboard input")
    picker:Hide()
    assert(picker.shown == false, "Blizzard UISpecialFrames Escape hide should dismiss picker")
    assert(not picker.events or picker.events.GLOBAL_MOUSE_DOWN == nil, "Escape hide should unregister GLOBAL_MOUSE_DOWN")
    assert(picker.scripts.OnUpdate == nil and picker._dismissArmed == nil, "Escape hide should clear dismissal arming")
    assert(picker._anchor == nil and picker._message == nil and picker._onReact == nil, "Escape hide should clear popup ownership")
    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(type(picker.scripts.OnEvent) == "function", "picker should handle GLOBAL_MOUSE_DOWN")
    picker.mouseOver = false
    picker.scripts.OnEvent(picker, "GLOBAL_MOUSE_DOWN")
    assert(picker.shown == true, "opening GLOBAL_MOUSE_DOWN must not immediately close picker")
    assert(type(picker.scripts.OnUpdate) == "function", "picker should arm outside dismissal on next update")
    picker.scripts.OnUpdate(picker, 0)
    picker.mouseOver = true
    picker.scripts.OnEvent(picker, "GLOBAL_MOUSE_DOWN")
    assert(picker.shown == true, "click inside picker should not dismiss it")
    picker.mouseOver = false
    picker.scripts.OnEvent(picker, "GLOBAL_MOUSE_DOWN")
    assert(picker.shown == false, "armed outside GLOBAL_MOUSE_DOWN should dismiss picker")
    assert(not picker.events or picker.events.GLOBAL_MOUSE_DOWN == nil, "hide should unregister GLOBAL_MOUSE_DOWN")

    local otherAnchor = factory.CreateFrame("Frame", nil, uiParent)
    assert(ReactionPicker.Open(factory, otherAnchor, message, function() end, function() end) == true, "another picker open should succeed")
    assert(ReactionPicker.GetFrame() == picker and picker._anchor == otherAnchor, "another open should reuse picker and replace anchor")
    ReactionPicker.Close()
    for index, key in ipairs(ReactionAssets.KEYS) do
      bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
      bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
      picker._reactionButtons[index].scripts.OnClick(picker._reactionButtons[index])
      assert(reactions[#reactions].key == key, "each picker button should dispatch its reaction key")
    end
  end
  -- Existing picker singleton recomputes exact emoji/button/panel geometry from font size.
  do
    local savedFontSize = Fonts.GetFontSize()
    local anchor = factory.CreateFrame("Frame", nil, uiParent)
    local message = { kind = "user", direction = "in", text = "dynamic picker" }
    local picker = ReactionPicker.GetFrame()
    local function assertPickerSize(fontSize)
      Fonts.SetFontSize(fontSize)
      assert(ReactionPicker.Open(factory, anchor, message, function() end, function() end) == true, "dynamic picker should reopen")
      local pickerIconSize = math.floor(fontSize * 1.5 + 0.5)
      local buttonSize = pickerIconSize + 6
      assert(ReactionPicker.GetFrame() == picker, "font change should reuse picker singleton")
      assert(picker.width == buttonSize * 9 + 12 and picker.height == buttonSize * 2 + 34, "picker frame should match two-row dynamic geometry")
      for index, button in ipairs(picker._reactionButtons) do
        local column = (index - 1) % 9
        local row = math.floor((index - 1) / 9)
        assert(button.width == buttonSize and button.height == buttonSize, "picker button should be picker icon size plus six")
        assert(button._icon.width == pickerIconSize and button._icon.height == pickerIconSize, "picker icon should be rounded 1.5x font size")
        assert(
          button.point[4] == 6 + column * buttonSize and button.point[5] == -5 - row * buttonSize,
          "picker button point should recompute in row-major order"
        )
      end
      assert(picker._copyButton.width == buttonSize * 9, "Copy Text row should span the full reaction grid width")
      assert(
        picker._copyButton.point[4] == 6 and picker._copyButton.point[5] == -(buttonSize * 2 + 8),
        "Copy Text row should sit below the second reaction row"
      )
    end
    assertPickerSize(9)
    assertPickerSize(12)
    assertPickerSize(17)
    Fonts.SetFontSize(savedFontSize or 12)
    ReactionPicker.Open(factory, anchor, message, function() end, function() end)
    ReactionPicker.Close()
  end

  -- Custom picker preserves a labeled Copy Text action.
  do
    local copied
    local savedLanguage = Localization.GetConfiguredLanguage()
    Localization.Configure({ language = "deDE" })
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copied = text
      end,
    }
    local parent = factory.CreateFrame("Frame", nil, uiParent)
    parent:SetSize(400, 600)
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      kind = "user",
      direction = "in",
      channel = "WOW",
      text = "copy this reaction target",
      sentAt = 100,
    }, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
      onReact = function() end,
    })
    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    local picker = ReactionPicker.GetFrame()
    assert(picker._copyLabel:GetText() == "Text kopieren", "picker should localize Copy text through current catalog")
    picker._copyButton.scripts.OnClick(picker._copyButton)
    assert(copied == "copy this reaction target", "Copy Text should preserve existing clipboard path")
    assert(picker.shown == false, "Copy Text should dismiss picker")
    Localization.Configure({ language = savedLanguage })
  end

  -- Censored incoming messages become eligible only after reveal.
  do
    local parent = factory.CreateFrame("Frame", nil, uiParent)
    parent:SetSize(400, 600)
    local reacted = 0
    local message = {
      kind = "user",
      direction = "in",
      channel = "WOW",
      text = "censored",
      sentAt = 100,
      lineID = 44,
      isCensored = true,
    }
    _G.C_ChatInfo = {
      UncensorChatLine = function() end,
      GetChatLineText = function()
        return "revealed"
      end,
    }
    local bubble = BubbleFrame.CreateBubble(factory, parent, message, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
      onReact = function()
        reacted = reacted + 1
      end,
    })
    if bubble.frame.scripts.OnDoubleClick then
      bubble.frame.scripts.OnDoubleClick(bubble.frame, "LeftButton")
    end
    assert(reacted == 0, "unrevealed censored bubble should not react")
    bubble.frame.scripts.OnMouseDown(bubble.frame, "LeftButton")
    assert(message.isCensored == nil and message.text == "revealed", "existing reveal action should update message")
    bubble.frame.scripts.OnDoubleClick(bubble.frame, "LeftButton")
    assert(reacted == 1, "revealed incoming bubble should become eligible")
  end

  -- Reaction badge uses atlas, tooltip, correct edge, and adds layout height.
  do
    local parent = factory.CreateFrame("Frame", nil, uiParent)
    parent:SetSize(400, 600)
    local baseMessage = { kind = "user", direction = "in", text = "height", sentAt = 100 }
    local plain = BubbleFrame.CreateBubble(factory, parent, baseMessage, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
    })
    local reactedMessage = {
      kind = "user",
      direction = "in",
      text = "height",
      sentAt = 100,
      reaction = { key = "heart", actorName = "Artio", updatedAt = 101 },
      _pendingReaction = { token = 1, operation = "set", key = "laugh", actorName = "Artio" },
    }
    local reacted = BubbleFrame.CreateBubble(factory, parent, reactedMessage, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
    })
    assert(reacted.height > plain.height, "reaction badge should increase transcript layout height")
    assert(reacted.reactionFrame and reacted.reactionFrame.shown == true, "reaction badge should render")
    assert(reacted.reactionIcon.texturePath == ReactionAssets.TEXTURE, "badge should use bundled atlas")
    assert(
      reacted.reactionFrame.point[1] == "TOPRIGHT"
        and reacted.reactionFrame.point[3] == "BOTTOMRIGHT"
        and reacted.reactionFrame.point[4] == -5
        and reacted.reactionFrame.point[5] == 7,
      "incoming badge should sit at message end with right padding"
    )
    assert(reacted.height == plain.height + math.max(0, Fonts.GetFontSize() - 7), "badge should reserve only visible overflow")
    reacted.reactionFrame.scripts.OnEnter(reacted.reactionFrame)
    assert(tooltipText == ":laugh:", "badge tooltip should identify shortcode")
    reacted.reactionFrame.scripts.OnLeave(reacted.reactionFrame)
    local pendingRemove = BubbleFrame.CreateBubble(factory, parent, {
      kind = "user",
      direction = "in",
      text = "pending remove",
      sentAt = 100,
      reaction = { key = "heart", actorName = "Artio", updatedAt = 101 },
      _pendingReaction = { token = 2, operation = "remove", key = "heart", actorName = "Artio" },
    }, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
    })
    assert(pendingRemove.reactionFrame == nil and pendingRemove.height == plain.height, "pending remove should hide badge immediately")

    local outgoing = BubbleFrame.CreateBubble(factory, parent, {
      kind = "user",
      direction = "out",
      text = "out",
      sentAt = 100,
      reaction = { key = "gg", actorName = "Other", updatedAt = 101 },
    }, {
      paneWidth = 400,
      showIcon = false,
      persistentFactory = factory,
    })
    assert(
      outgoing.reactionFrame.point[1] == "TOPRIGHT"
        and outgoing.reactionFrame.point[3] == "BOTTOMRIGHT"
        and outgoing.reactionFrame.point[4] == -5
        and outgoing.reactionFrame.point[5] == 7,
      "outgoing badge should sit at message end with right padding"
    )
  end

  -- Pooled bubble badge frame/texture and layout height follow font size on every render.
  do
    local savedFontSize = Fonts.GetFontSize()
    local content = factory.CreateFrame("Frame", nil, uiParent)
    content:SetSize(400, 600)
    local messages = {
      {
        kind = "user",
        direction = "in",
        text = "dynamic badge",
        sentAt = 100,
        reaction = { key = "heart", actorName = "Artio", updatedAt = 101 },
      },
    }
    Fonts.SetFontSize(9)
    local height9 = Layout.LayoutMessages(factory, content, messages, 400)
    local bubble9 = assert(findBubble(content), "font-size 9 layout should render bubble")
    local reactionFrame = bubble9._reactionFrame
    local reactionTexture = bubble9._reactionTexture
    assert(reactionFrame.width == 9 and reactionFrame.height == 9, "badge frame should exactly match font size 9")
    assert(reactionTexture.width == 9 and reactionTexture.height == 9, "badge texture should exactly match font size 9")
    assert(
      reactionFrame.point[1] == "TOPRIGHT"
        and reactionFrame.point[3] == "BOTTOMRIGHT"
        and reactionFrame.point[4] == -5
        and reactionFrame.point[5] == 7,
      "font-size 9 incoming pooled badge should use message-end anchor"
    )

    Fonts.SetFontSize(17)
    local height17 = Layout.LayoutMessages(factory, content, messages, 400)
    local bubble17 = assert(findBubble(content), "font-size 17 layout should render bubble")
    assert(bubble17 == bubble9 and bubble17._reactionFrame == reactionFrame, "font change should reuse pooled badge frame")
    assert(reactionFrame.width == 17 and reactionFrame.height == 17, "pooled badge frame should resize to font size 17")
    assert(reactionTexture.width == 17 and reactionTexture.height == 17, "pooled badge texture should resize to font size 17")
    assert(
      reactionFrame.point[1] == "TOPRIGHT"
        and reactionFrame.point[3] == "BOTTOMRIGHT"
        and reactionFrame.point[4] == -5
        and reactionFrame.point[5] == 7,
      "font-size 17 pooled badge should keep message-end anchor"
    )
    assert(height17 == height9 + 8, "bubble layout height should grow by font-size delta")
    messages[1].direction = "out"
    Layout.LayoutMessages(factory, content, messages, 400)
    local switched = assert(findBubble(content), "direction switch should rerender pooled bubble")
    assert(switched == bubble17 and switched._reactionFrame == reactionFrame, "direction switch should reuse pooled badge")
    assert(
      reactionFrame.point[1] == "TOPRIGHT"
        and reactionFrame.point[3] == "BOTTOMRIGHT"
        and reactionFrame.point[4] == -5
        and reactionFrame.point[5] == 7,
      "pooled incoming-to-outgoing switch should preserve message-end anchor"
    )
    Fonts.SetFontSize(savedFontSize or 12)
  end

  -- Pool reuse clears badge texture, tooltip scripts, and old reaction callbacks.
  do
    local content = factory.CreateFrame("Frame", nil, uiParent)
    content:SetSize(400, 600)
    Layout.LayoutMessages(
      factory,
      content,
      {
        {
          kind = "user",
          direction = "in",
          channel = "WOW",
          text = "with reaction",
          sentAt = 100,
          reaction = { key = "heart", actorName = "Artio", updatedAt = 101 },
        },
      },
      400,
      {
        onReact = function() end,
      }
    )
    local firstFrame = assert(findBubble(content), "first layout should create bubble")
    assert(firstFrame._reactionFrame and firstFrame._reactionFrame.shown == true, "first pooled bubble should show badge")
    firstFrame.scripts.OnMouseDown(firstFrame, "RightButton")
    firstFrame.scripts.OnMouseUp(firstFrame, "RightButton")
    assert(ReactionPicker.GetFrame().shown == true, "pooled bubble should own open picker")

    Layout.LayoutMessages(factory, content, {
      { kind = "user", direction = "in", text = "no reaction", sentAt = 102 },
    }, 400)
    local reused = assert(findBubble(content), "second layout should reuse bubble")
    assert(reused == firstFrame, "pool should reuse prior bubble frame")
    assert(
      ReactionPicker.GetFrame().shown == false and ReactionPicker.GetFrame()._anchor == nil,
      "pool release should close picker owned by recycled bubble"
    )
    assert(reused._reactionFrame.shown == false, "reused frame should hide stale badge")
    assert(reused._reactionTexture.texturePath == nil, "reused frame should clear stale atlas texture")
    assert(reused._reactionFrame.scripts.OnEnter == nil and reused._reactionFrame.scripts.OnLeave == nil, "reused badge should clear tooltip scripts")
    assert(reused.scripts.OnDoubleClick == nil, "reused reaction-disabled bubble should clear old double-click callback")
  end

  -- Pool cleanup only clears OnDoubleClick on Button widgets.
  do
    local strictBase = FakeUI.NewFactory()
    local strictFactory = {
      CreateFrame = function(frameType, name, parent, template)
        local frame = strictBase.CreateFrame(frameType, name, parent, template)
        local setScript = frame.SetScript
        frame.SetScript = function(self, scriptName, handler)
          if frameType ~= "Button" and scriptName == "OnDoubleClick" then
            error("OnDoubleClick is not supported by Frame")
          end
          return setScript(self, scriptName, handler)
        end
        return frame
      end,
    }
    local content = strictFactory.CreateFrame("Frame", nil, uiParent)
    content:SetSize(400, 600)
    local messages = { { kind = "user", direction = "in", text = "strict", sentAt = 100 } }
    Layout.LayoutMessages(strictFactory, content, messages, 400, { onReact = function() end })
    local ok, err = pcall(Layout.LayoutMessages, strictFactory, content, messages, 400, { onReact = function() end })
    assert(ok, "pool cleanup should respect widget-specific script support: " .. tostring(err))
  end

  -- ConversationPane supplies selected contact through exact UI callback contract.
  do
    local parent = factory.CreateFrame("Frame", nil, uiParent)
    parent:SetSize(640, 420)
    local selectedContact = { conversationKey = "wow::WOW::arthas", displayName = "Arthas", channel = "WOW" }
    local message = { kind = "user", direction = "in", channel = "WOW", text = "pane target", sentAt = 100 }
    local captured
    local view = ConversationPane.Create(factory, parent, selectedContact, { messages = { message } }, {
      onReact = function(contact, target, key)
        captured = { contact = contact, target = target, key = key }
      end,
    })
    local bubble = assert(findBubble(view.transcript.content), "pane should render target bubble")
    bubble.scripts.OnDoubleClick(bubble, "LeftButton")
    assert(captured and captured.contact == selectedContact, "pane should supply current selected contact")
    assert(captured.target == message and captured.key == "heart", "pane should forward target message and reaction key")
  end

  ReactionPicker.Close()
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UIParent = savedUIParent
  _G.GameTooltip = savedTooltip
  _G.C_ChatInfo = savedChatInfo
  _G.C_Clipboard = savedClipboard
end
