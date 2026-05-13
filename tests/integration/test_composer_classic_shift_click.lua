local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- Regression: in WoW Classic, Blizzard's `ChatEdit_InsertLink` exists at module
-- load and routes inserts through `ChatEdit_GetActiveWindow()`. When our
-- composer is focused, our `wmGetActiveWindow` returns our editbox, and the
-- original `ChatEdit_InsertLink` directly inserts the plain `[Name (id)]`
-- text via `editbox:Insert(text)` — bypassing our rewrite. The rewrite must
-- happen before delegating to the original so the editbox sees a real link.
return function()
  local savedHooksecurefunc = _G.hooksecurefunc
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink

  rawset(_G, "hooksecurefunc", function() end)

  -- Simulate Blizzard's real ChatEdit_InsertLink: looks up the global
  -- ChatEdit_GetActiveWindow at call time, and inserts directly when an
  -- active window is found.
  _G.ChatEdit_InsertLink = function(text)
    if text == nil then
      return false
    end
    local getActive = _G.ChatEdit_GetActiveWindow
    local activeWindow = getActive and getActive()
    if activeWindow ~= nil then
      activeWindow:Insert(text)
      return true
    end
    return false
  end
  _G.ChatEdit_GetActiveWindow = function()
    return nil
  end

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    if frameType == "EditBox" then
      frame._textValue = ""
      frame._hasFocus = false
      rawset(frame, "SetText", function(self, value)
        self._textValue = value
      end)
      rawset(frame, "GetText", function(self)
        return self._textValue
      end)
      rawset(frame, "HasFocus", function(self)
        return self._hasFocus == true
      end)
      local baseSetFocus = frame.SetFocus
      rawset(frame, "SetFocus", function(self)
        self._hasFocus = true
        if baseSetFocus then
          baseSetFocus(self)
        end
      end)
      local baseClearFocus = frame.ClearFocus
      rawset(frame, "ClearFocus", function(self)
        self._hasFocus = false
        if baseClearFocus then
          baseClearFocus(self)
        end
      end)
      rawset(frame, "Insert", function(self, text)
        self:SetText((self:GetText() or "") .. text)
      end)
    end
    return frame
  end

  local parent = factory.CreateFrame("Frame", "ComposerParent", nil)
  parent:SetSize(600, 200)

  local composer = Composer.Create(factory, parent, {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }, function() end)

  parent:Show()
  composer.frame:Show()
  composer.input:Show()
  composer.input:SetFocus()

  composer.input:SetText("")
  local plainText = "[Apprentice's Duties (471)]"
  local handled = _G.ChatEdit_InsertLink(plainText)
  assert(handled == true, "expected ChatEdit_InsertLink to return true")
  local expected = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  assert(
    composer.input:GetText() == expected,
    "expected classic shift-click plain text to be rewritten to a real hyperlink, got: " .. tostring(composer.input:GetText())
  )

  rawset(_G, "hooksecurefunc", savedHooksecurefunc)
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
end
