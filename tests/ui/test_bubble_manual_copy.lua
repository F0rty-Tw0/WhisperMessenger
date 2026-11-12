-- Manual copy tests: Clipboard popup routing and PopupUI styling/teardown.
--
-- The orchestrator (ContextMenu.Open) lives in test_bubble_context_menu.lua.
-- This file owns:
--   * Clipboard.lua             - NormalizeText + CopyText popup routing
--   * PopupUI.lua / Resolvers   - manual-popup show + editbox discovery shapes
--   * PopupUI/Styling           - apply / restore on shared StaticPopup frames

local FakeUI = require("tests.helpers.fake_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local Theme = require("WhisperMessenger.UI.Theme")

-- Snapshot/restore the globals each case overwrites. WoW addons stub many
-- top-level functions, and tests must leave them as they found them so the
-- next test in the suite isn't poisoned.
local function snapshotGlobals()
  return {
    CreateFrame = _G.CreateFrame,
    UIParent = _G.UIParent,
    CopyToClipboard = _G.CopyToClipboard,
    C_Clipboard = _G.C_Clipboard,
    C_Timer = _G.C_Timer,
    securecallfunction = _G.securecallfunction,
    StaticPopup_Show = _G.StaticPopup_Show,
    StaticPopupDialogs = _G.StaticPopupDialogs,
  }
end

local function restoreGlobals(saved)
  rawset(_G, "CreateFrame", saved.CreateFrame)
  _G.UIParent = saved.UIParent
  rawset(_G, "CopyToClipboard", saved.CopyToClipboard)
  _G.C_Clipboard = saved.C_Clipboard
  _G.C_Timer = saved.C_Timer
  _G.securecallfunction = saved.securecallfunction
  rawset(_G, "StaticPopup_Show", saved.StaticPopup_Show)
  _G.StaticPopupDialogs = saved.StaticPopupDialogs
end

-- Minimal popup show that delegates to the dialog's OnShow with the same
-- (dialog, data) call WoW makes. Each case constructs the fake dialog it needs.
local function installFakePopupShow(makeDialog)
  local shown = { count = 0 }
  rawset(_G, "StaticPopup_Show", function(which, _t1, _t2, data)
    shown.count = shown.count + 1
    shown.which = which
    shown.data = data
    local def = _G.StaticPopupDialogs[which]
    local dialog = makeDialog and makeDialog(data) or { data = data }
    if def and def.OnShow then
      def.OnShow(dialog, data)
    end
    shown.dialog = dialog
    return dialog
  end)
  return shown
end

return function()
  local saved = snapshotGlobals()

  -- ===== Clipboard.lua =====

  -- NormalizeText rejects nil and empty strings, returns the value otherwise.
  do
    -- Indirect via CopyText: nil/empty short-circuit before the popup opens.
    local shown = installFakePopupShow()
    _G.StaticPopupDialogs = {}
    assert(ContextMenu.CopyText(nil) == false, "CopyText(nil) should return false")
    assert(ContextMenu.CopyText("") == false, "CopyText('') should return false")
    assert(shown.count == 0, "nil/empty text must not open the manual copy popup")
  end

  -- CopyText always opens the manual copy popup with the text.
  do
    local shown = installFakePopupShow()
    _G.StaticPopupDialogs = {}
    assert(ContextMenu.CopyText("manual") == true, "CopyText should open the manual copy popup")
    assert(shown.count == 1 and shown.data == "manual", "popup should be shown with the text")
  end

  -- A C_Clipboard namespace, if one ever appears, is never called: a protected
  -- clipboard call would raise ADDON_ACTION_FORBIDDEN, which pcall cannot stop.
  do
    local shown = installFakePopupShow()
    local clipboardCalled = false
    local function markCalled()
      clipboardCalled = true
    end
    _G.C_Clipboard = {
      SetClipboard = markCalled,
      SetClipboardText = markCalled,
      SetText = markCalled,
      CopyText = markCalled,
      CopyToClipboard = markCalled,
    }
    _G.StaticPopupDialogs = {}
    assert(ContextMenu.CopyText("popup only") == true, "CopyText should open the popup even with C_Clipboard present")
    assert(shown.count == 1 and shown.data == "popup only", "popup should be shown with the text")
    assert(clipboardCalled == false, "CopyText must not call C_Clipboard methods")
    _G.C_Clipboard = saved.C_Clipboard
  end

  -- The legacy CopyToClipboard global is intentionally never called from addon
  -- code (it's protected and triggers a forbidden-action toast).
  do
    local shown = installFakePopupShow()
    local protectedAttempted = false
    rawset(_G, "CopyToClipboard", function()
      protectedAttempted = true
      error("forbidden")
    end)
    _G.StaticPopupDialogs = {}
    assert(ContextMenu.CopyText("safe") == true, "CopyText should succeed without protected fallback")
    assert(shown.data == "safe", "manual copy popup should still receive the text")
    assert(protectedAttempted == false, "CopyText must never call protected CopyToClipboard from addon code")
    rawset(_G, "CopyToClipboard", nil)
  end

  -- ===== PopupUI Resolvers: editbox discovery shapes =====

  -- The OnShow callback receives (dialog, data); when WoW omits the data arg
  -- the resolver still finds it on dialog.data and primes the editbox.
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.StaticPopupDialogs = {}
    installFakePopupShow(function(data)
      return {
        data = data,
        editBox = {
          SetText = function(_self, value)
            popupText = value
          end,
          HighlightText = function() end,
          SetFocus = function() end,
        },
      }
    end)
    ContextMenu.CopyText("from-data")
    assert(popupText == "from-data", "popup should prime editbox from dialog.data when OnShow's data arg is missing")
  end

  -- Capitalized field name (`EditBox`) is also recognized.
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.StaticPopupDialogs = {}
    installFakePopupShow(function(data)
      return {
        data = data,
        EditBox = {
          SetText = function(_self, value)
            popupText = value
          end,
          HighlightText = function() end,
          SetFocus = function() end,
        },
      }
    end)
    ContextMenu.CopyText("from-EditBox")
    assert(popupText == "from-EditBox", "popup should recognize capitalized EditBox field")
  end

  -- When neither field is present, GetChildren is searched; the first
  -- editbox-shaped child wins.
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.StaticPopupDialogs = {}
    installFakePopupShow(function(data)
      local child = {
        SetText = function(_self, value)
          popupText = value
        end,
        HighlightText = function() end,
        SetFocus = function() end,
      }
      return {
        data = data,
        GetChildren = function()
          return child
        end,
      }
    end)
    ContextMenu.CopyText("from-child")
    assert(popupText == "from-child", "popup should discover editbox via GetChildren")
  end

  -- When children are mixed (button-like + real editbox), the editbox wins
  -- regardless of declaration order.
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.StaticPopupDialogs = {}
    installFakePopupShow(function(data)
      local buttonLike = { SetText = function() end }
      local realEditBox = {
        SetText = function(_self, value)
          popupText = value
        end,
        HighlightText = function() end,
        SetFocus = function() end,
        GetObjectType = function()
          return "EditBox"
        end,
      }
      return {
        data = data,
        GetChildren = function()
          return buttonLike, realEditBox
        end,
      }
    end)
    ContextMenu.CopyText("ordered")
    assert(popupText == "ordered", "popup should pick the editbox child even when it's not first")
  end

  -- ===== PopupUI / Styling: apply, restore, reuse =====

  local function buildStyledPopupScaffold()
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local dialog = factory.CreateFrame("Frame", "StaticPopup1", uiParent)
    dialog:SetWidth(420)
    local dialogText = dialog:CreateFontString(nil, "OVERLAY")
    local editBox = factory.CreateFrame("EditBox", "StaticPopup1EditBox", dialog)
    local button1 = factory.CreateFrame("Button", "StaticPopup1Button1", dialog)
    local buttonLabel = button1:CreateFontString(nil, "OVERLAY")
    local editBoxDecoration = editBox:CreateTexture(nil, "ARTWORK")
    editBoxDecoration:SetAllPoints(editBox)
    editBoxDecoration:Show()
    local buttonDecoration = button1:CreateTexture(nil, "ARTWORK")
    buttonDecoration:SetAllPoints(button1)
    buttonDecoration:Show()
    local originalButtonTextColor = { 0.7, 0.71, 0.73, 1 }
    dialog.text = dialogText
    dialog.editBox = editBox
    dialog.button1 = button1
    button1.text = buttonLabel
    buttonLabel:SetText("OK")
    buttonLabel:SetTextColor(originalButtonTextColor[1], originalButtonTextColor[2], originalButtonTextColor[3], originalButtonTextColor[4])

    -- Blizzard exposes InputBoxTemplate borders both as parentKey attributes
    -- and as named globals. Fake both: real builds have leaked one or the
    -- other in the past.
    local function newBorder()
      local tex = { shown = true, alpha = 1, frameType = "Texture" }
      function tex:Hide()
        self.shown = false
      end
      function tex:Show()
        self.shown = true
      end
      function tex:SetAlpha(v)
        self.alpha = v
      end
      function tex:GetAlpha()
        return self.alpha
      end
      return tex
    end
    local left, mid, right = newBorder(), newBorder(), newBorder()
    editBox.Left, editBox.Middle, editBox.Right = left, mid, right

    local highlightColor = { 0, 0, 1, 0.4 }
    function editBox:GetHighlightColor()
      return highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4]
    end
    function editBox:SetHighlightColor(r, g, b, a)
      highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4] = r, g, b, a
    end

    _G.StaticPopup1 = dialog
    _G.StaticPopup1EditBox = editBox
    _G.StaticPopup1Button1 = button1
    _G.StaticPopup1EditBoxLeft, _G.StaticPopup1EditBoxMiddle, _G.StaticPopup1EditBoxRight = left, mid, right

    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    rawset(_G, "CopyToClipboard", nil)
    _G.StaticPopupDialogs = {
      WM_TEST_GENERIC_DIALOG = { text = "Generic dialog", button1 = "Logout" },
    }
    rawset(_G, "StaticPopup_Show", function(which, _t1, _t2, data)
      local def = _G.StaticPopupDialogs[which]
      dialog.which = which
      dialog.data = data
      dialog:Show()
      if def and def.OnShow then
        def.OnShow(dialog, data)
      end
      return dialog
    end)

    return {
      dialog = dialog,
      dialogText = dialogText,
      editBox = editBox,
      button1 = button1,
      buttonLabel = buttonLabel,
      editBoxDecoration = editBoxDecoration,
      buttonDecoration = buttonDecoration,
      originalButtonTextColor = originalButtonTextColor,
      borders = { left = left, mid = mid, right = right },
      highlightColor = highlightColor,
    }
  end

  -- Open: applies scoped styling, hides Blizzard input borders, and restyles the OK button.
  do
    local s = buildStyledPopupScaffold()
    assert(ContextMenu.CopyText("styled") == true, "manual popup should open when no clipboard is available")
    assert(s.dialog._wmRoundedBackground ~= nil, "dialog should get a rounded background")
    assert(s.dialog._wmRoundedBackground.fills[1].shown == true, "dialog background should be active while shown")
    assert(s.borders.left.shown == false, "InputBoxTemplate Left border must be hidden")
    assert(s.borders.mid.shown == false, "InputBoxTemplate Middle border must be hidden")
    assert(s.borders.right.shown == false, "InputBoxTemplate Right border must be hidden")
    assert(s.editBox._wmManualCopyBackground ~= nil, "editbox should get a flat rounded background")
    assert(s.editBox._wmManualCopyBackground.fills[1].shown == true, "editbox background should be active while shown")
    assert(s.editBox._wmManualCopyBorder == nil, "editbox must NOT draw a separate border")
    assert(
      s.highlightColor[1] == 1 and s.highlightColor[2] == 1 and s.highlightColor[3] == 1 and s.highlightColor[4] == 0.25,
      "selection highlight must be set to white/25% so it is visible against the dark input background"
    )
    assert(s.editBox.width == 392, "editbox should stretch to near full dialog width")
    assert(s.button1._wmManualCopySkin ~= nil, "OK button should be skinned")
    assert(s.editBoxDecoration.shown == false, "default editbox decoration should be hidden")
    assert(s.buttonDecoration.shown == false, "default button decoration should be hidden")
    assert(
      s.buttonLabel.textColor[1] == Theme.COLORS.option_button_text[1]
        and s.buttonLabel.textColor[2] == Theme.COLORS.option_button_text[2]
        and s.buttonLabel.textColor[3] == Theme.COLORS.option_button_text[3],
      "OK button should use settings-style text color"
    )
  end

  -- OnHide restores the original dialog appearance: borders, decorations, and label color.
  do
    local s = buildStyledPopupScaffold()
    ContextMenu.CopyText("styled-restore")
    local def = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    assert(def and type(def.OnHide) == "function", "manual popup should expose an OnHide handler")
    def.OnHide(s.dialog)
    s.dialog:Hide()
    assert(s.dialog._wmRoundedBackground.fills[1].shown == false, "dialog styling should hide on close")
    assert(s.editBox._wmManualCopyBackground.fills[1].shown == false, "editbox background should hide on close")
    assert(s.button1._wmManualCopySkin.fills[1].shown == false, "button skin should hide on close")
    assert(
      s.highlightColor[1] == 0 and s.highlightColor[2] == 0 and s.highlightColor[3] == 1 and s.highlightColor[4] == 0.4,
      "selection highlight color must be restored to original on close"
    )
    assert(s.editBoxDecoration.shown == true, "default editbox decoration should restore")
    assert(s.buttonDecoration.shown == true, "default button decoration should restore")
    assert(
      s.buttonLabel.textColor[1] == s.originalButtonTextColor[1]
        and s.buttonLabel.textColor[2] == s.originalButtonTextColor[2]
        and s.buttonLabel.textColor[3] == s.originalButtonTextColor[3],
      "button label color should restore"
    )
  end

  -- A reused StaticPopup frame (re-shown for an unrelated dialog after we
  -- closed our manual popup) must not leak our styling onto the generic dialog.
  do
    local s = buildStyledPopupScaffold()
    ContextMenu.CopyText("styled-leak")
    local def = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    def.OnHide(s.dialog)
    s.dialog:Hide()
    local reused = _G.StaticPopup_Show("WM_TEST_GENERIC_DIALOG")
    assert(reused == s.dialog, "test should reuse the same StaticPopup frame")
    assert(s.dialog._wmRoundedBackground.fills[1].shown == false, "manual styling must stay hidden for the generic reuse")
    assert(s.editBox._wmManualCopyBackground.fills[1].shown == false, "manual editbox background must stay hidden for the generic reuse")
    assert(s.button1._wmManualCopySkin.fills[1].shown == false, "manual button skin must stay hidden for the generic reuse")
  end

  -- Hover handlers wrap the generic OnEnter/OnLeave so the styled hover state
  -- survives across reopens, and the generic OnLeave fires exactly once on
  -- hover-exit. After OnHide, the original handlers are restored.
  do
    local s = buildStyledPopupScaffold()
    ContextMenu.CopyText("first")
    local def = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    def.OnHide(s.dialog)
    s.dialog:Hide()

    local genericLeaves = 0
    local genericEnter = function(self)
      self.genericHover = true
    end
    local genericLeave = function(self)
      self.genericHover = false
      genericLeaves = genericLeaves + 1
    end
    s.button1:SetScript("OnEnter", genericEnter)
    s.button1:SetScript("OnLeave", genericLeave)

    ContextMenu.CopyText("second")
    assert(s.button1:GetScript("OnEnter") ~= genericEnter, "manual popup should wrap OnEnter")
    assert(s.button1:GetScript("OnLeave") ~= genericLeave, "manual popup should wrap OnLeave")
    s.button1:GetScript("OnEnter")(s.button1)
    assert(s.button1._wmManualCopyHovered == true, "wrapped OnEnter should record manual hover state")
    s.button1:GetScript("OnLeave")(s.button1)
    assert(s.button1._wmManualCopyHovered == false, "wrapped OnLeave should clear manual hover state")
    assert(genericLeaves == 1, "generic OnLeave should fire exactly once during hover-exit")

    def.OnHide(s.dialog)
    s.dialog:Hide()
    assert(s.button1:GetScript("OnEnter") == genericEnter, "OnHide should restore generic OnEnter")
    assert(s.button1:GetScript("OnLeave") == genericLeave, "OnHide should restore generic OnLeave")
  end

  -- A generic OnLeave that itself triggers the manual popup's OnHide must not
  -- recurse infinitely (a real bug seen in some skinning addons).
  do
    local s = buildStyledPopupScaffold()
    ContextMenu.CopyText("priming")
    local def = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    def.OnHide(s.dialog)
    s.dialog:Hide()

    local recursiveCalls = 0
    local recursiveOnLeave
    recursiveOnLeave = function()
      recursiveCalls = recursiveCalls + 1
      if recursiveCalls > 1 then
        error("recursive teardown")
      end
      def.OnHide(s.dialog)
    end
    s.button1:SetScript("OnLeave", recursiveOnLeave)
    ContextMenu.CopyText("recursion-guard")
    s.button1:GetScript("OnEnter")(s.button1)
    local ok = pcall(function()
      s.button1:GetScript("OnLeave")(s.button1)
    end)
    assert(ok, "manual popup teardown must not recurse when generic OnLeave re-enters OnHide")
    assert(recursiveCalls <= 1, "generic OnLeave should fire at most once during recursion guard")
  end

  -- Some clients return the editbox itself from GetFontObject; the manual
  -- popup must not call SetFontObject in that case (it would loop).
  do
    local s = buildStyledPopupScaffold()
    ContextMenu.CopyText("priming")
    local def = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    def.OnHide(s.dialog)
    s.dialog:Hide()

    local origGetFontObject = s.editBox.GetFontObject
    local origSetFontObject = s.editBox.SetFontObject
    rawset(s.editBox, "GetFontObject", function()
      return s.editBox
    end)
    rawset(s.editBox, "SetFontObject", function()
      error("SetFontObject must not be called in this state")
    end)

    ContextMenu.CopyText("font-guard")
    local ok = pcall(function()
      def.OnHide(s.dialog)
    end)
    assert(ok, "open/close must not call SetFontObject when GetFontObject returns the editbox itself")

    rawset(s.editBox, "GetFontObject", origGetFontObject)
    rawset(s.editBox, "SetFontObject", origSetFontObject)
  end

  restoreGlobals(saved)
end
