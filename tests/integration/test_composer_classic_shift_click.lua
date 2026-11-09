local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

-- Regression: in WoW Classic, a quest shift-click calls Blizzard's
-- `ChatEdit_InsertLink` with plain `[Name (id)]` text. Our post-hook on it
-- must rewrite that to a real quest hyperlink before it reaches the composer,
-- and Blizzard's own `ChatEdit_InsertLink` must stay in place (never assigned).
return function()
  local savedHooksecurefunc = _G.hooksecurefunc
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink

  -- Post-hooks like the real hooksecurefunc: Blizzard's function runs first,
  -- then ours.
  rawset(_G, "hooksecurefunc", function(name, hook)
    local original = type(name) == "string" and rawget(_G, name) or nil
    if type(original) ~= "function" then
      return
    end
    rawset(_G, name, function(...)
      local result = original(...)
      hook(...)
      return result
    end)
  end)

  -- Simulate Blizzard's real ChatEdit_InsertLink: no Blizzard chat box is
  -- open, so it finds no active window and inserts nothing itself.
  _G.ChatEdit_GetActiveWindow = function()
    return nil
  end
  _G.ChatEdit_InsertLink = function(text)
    local activeWindow = _G.ChatEdit_GetActiveWindow()
    if text ~= nil and activeWindow ~= nil then
      activeWindow:Insert(text)
      return true
    end
    return false
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
  _G.ChatEdit_InsertLink("[Apprentice's Duties (471)]")
  local expected = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  assert(
    composer.input:GetText() == expected,
    "expected classic shift-click plain text to be rewritten to a real hyperlink, got: " .. tostring(composer.input:GetText())
  )

  rawset(_G, "hooksecurefunc", savedHooksecurefunc)
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
end
