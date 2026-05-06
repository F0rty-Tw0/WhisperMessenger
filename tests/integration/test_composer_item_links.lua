local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedHooksecurefunc = _G.hooksecurefunc
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink
  local savedCQuestLog = _G.C_QuestLog
  local registeredHooks = {}

  rawset(_G, "hooksecurefunc", function(target, methodOrHandler, maybeHandler)
    if type(target) == "string" and type(methodOrHandler) == "function" then
      registeredHooks[target] = methodOrHandler
      return
    end
    if type(target) == "table" and type(methodOrHandler) == "string" and type(maybeHandler) == "function" then
      registeredHooks["method:" .. methodOrHandler] = maybeHandler
    end
  end)

  _G.C_QuestLog = {
    SetSelectedQuest = function() end,
    GetQuestLink = function()
      return nil
    end,
    GetLogIndexForQuestID = function()
      return nil
    end,
  }

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    if frameType == "EditBox" then
      local originalSetText = frame.SetText
      frame._textValue = ""
      frame._hasFocus = false

      rawset(frame, "SetText", function(self, value)
        originalSetText(self, value)
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

  -- Overrides must NOT be installed at module load — Blizzard's OPENCHAT /
  -- UpdateHeader arithmetic crashes with WhisperMessenger taint attribution
  -- otherwise. They install on composer focus-gained, restore on focus-lost.
  local preLoadGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local preLoadInsertLink = _G.ChatEdit_InsertLink

  local composer = Composer.Create(factory, parent, {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }, function() end)

  assert(_G.ChatEdit_GetActiveWindow == preLoadGetActiveWindow, "ChatEdit_GetActiveWindow must not be overridden before focus")
  assert(_G.ChatEdit_InsertLink == preLoadInsertLink, "ChatEdit_InsertLink must not be overridden before focus")

  -- ChatEdit_GetActiveWindow returns our input when focused (installs override)
  parent:Show()
  composer.frame:Show()
  composer.input:Show()
  composer.input:SetFocus()

  assert(_G.ChatEdit_GetActiveWindow ~= preLoadGetActiveWindow, "ChatEdit_GetActiveWindow should install on focus-gained")

  local activeWindow = _G.ChatEdit_GetActiveWindow()
  assert(activeWindow == composer.input, "expected ChatEdit_GetActiveWindow to return our composer input when visible")

  -- ChatEdit_GetActiveWindow returns nil when composer is hidden
  composer.input:Hide()
  assert(_G.ChatEdit_GetActiveWindow() == nil, "expected ChatEdit_GetActiveWindow to return nil when composer hidden")

  -- Restore visible state
  composer.input:Show()

  -- ChatEdit_InsertLink routes item links to our composer and returns true
  composer.input:SetText("")
  local itemLink = "|cff0070dd|Hitem:19019::::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
  local insertResult = _G.ChatEdit_InsertLink(itemLink)
  assert(insertResult == true, "expected ChatEdit_InsertLink to return true")
  assert(composer.input:GetText() == itemLink, "expected item link inserted into our composer")

  -- ChatEdit_InsertLink routes quest links to our composer and returns true
  local questLink = "|cffffff00|Hquest:78307:80|h[To Khaz Algar!]|h|r"
  composer.input:SetText("")
  local questResult = _G.ChatEdit_InsertLink(questLink)
  assert(questResult == true, "expected ChatEdit_InsertLink to return true for quest link")
  assert(composer.input:GetText() == questLink, "expected quest link inserted into our composer")

  -- Classic vanilla shift-click inserts plain `[Name (id)]` text. Our composer
  -- must rewrite that on the way in to a real quest hyperlink, so the
  -- recipient gets a clickable link and the user's bubble shows it correctly.
  composer.input:SetText("")
  local classicShiftClick = "[Apprentice's Duties (471)]"
  local classicResult = _G.ChatEdit_InsertLink(classicShiftClick)
  assert(classicResult == true, "expected ChatEdit_InsertLink to return true for classic plain-text quest")
  local expectedClassic = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  assert(
    composer.input:GetText() == expectedClassic,
    "expected classic quest text to be rewritten to hyperlink, got: " .. tostring(composer.input:GetText())
  )

  -- ChatEdit_InsertLink returns false when composer is hidden (no target)
  composer.input:Hide()
  assert(_G.ChatEdit_InsertLink(itemLink) == false, "expected false when no visible input")
  composer.input:Show()

  -- ChatEdit_InsertLink returns false when parent window is hidden
  -- (input itself is still "shown" but not visible because ancestor is hidden)
  composer.input:SetText("")
  parent:Hide()
  assert(_G.ChatEdit_InsertLink(itemLink) == false, "expected false when parent window is hidden")
  assert(composer.input:GetText() == "", "expected no link inserted when parent hidden")
  parent:Show()

  -- ChatEdit_GetActiveWindow returns nil when parent window is hidden
  parent:Hide()
  assert(_G.ChatEdit_GetActiveWindow() == nil, "expected nil active window when parent hidden")
  parent:Show()

  -- SetItemRef hook for clicking hyperlinks in transcript
  assert(registeredHooks.SetItemRef ~= nil, "expected SetItemRef hook registered")
  composer.input:SetText("")
  local questTextFromChat = "|cffffff00|Hquest:78307:80|h[To Khaz Algar!]|h|r"
  registeredHooks.SetItemRef("quest:78307:80", questTextFromChat, "LeftButton")
  assert(composer.input:GetText() == questTextFromChat, "expected SetItemRef to insert quest hyperlink text")

  -- Cleanup
  rawset(_G, "hooksecurefunc", savedHooksecurefunc)
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
  _G.C_QuestLog = savedCQuestLog
end
