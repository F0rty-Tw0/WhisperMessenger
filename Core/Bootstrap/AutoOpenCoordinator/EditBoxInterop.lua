local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EditBoxInterop = {}

-- External tracking table: keyed by edit box reference, never written to the
-- edit box itself. Writing to Blizzard's secure frame tables from addon code
-- taints them, causing their OnUpdate to run in a tainted context where
-- SetText() with WoW's secret values then errors.
local combatDraftBoxes = {}
function EditBoxInterop.readEditBoxState(editBox, key)
  local direct = editBox[key]
  if direct ~= nil and direct ~= "" then
    return direct
  end

  if type(editBox.GetAttribute) == "function" then
    local attribute = editBox:GetAttribute(key)
    if attribute ~= nil and attribute ~= "" then
      return attribute
    end
  end

  return nil
end

local function readEditBoxText(editBox)
  if type(editBox) == "table" and type(editBox.GetText) == "function" then
    local ok, text = pcall(editBox.GetText, editBox)
    -- If GetText fails the value is secret (tainted execution); treat as non-empty.
    if not ok then
      return nil -- sentinel: secret value present
    end
    return text or ""
  end
  return ""
end

function EditBoxInterop.markCombatDraft(editBox)
  local chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
  if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
    return
  end

  local typed = readEditBoxText(editBox)
  -- nil means secret value (tainted); treat same as non-empty.
  if typed == nil or typed ~= "" then
    combatDraftBoxes[editBox] = true
  end
end

function EditBoxInterop.shouldPreserveCombatDraft(editBox)
  if type(editBox) ~= "table" then
    return false
  end

  local typed = readEditBoxText(editBox)
  -- nil means secret value (tainted) — text is definitely present.
  if typed == "" then
    combatDraftBoxes[editBox] = nil
    return false
  end

  if not combatDraftBoxes[editBox] then
    return false
  end

  local chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
  if chatType == "WHISPER" or chatType == "BN_WHISPER" then
    return true
  end

  combatDraftBoxes[editBox] = nil
  return false
end

function EditBoxInterop.closeEditBox(runtime, editBox, deactivateChat)
  local typed = readEditBoxText(editBox)
  -- typed == nil means secret value: skip copying to composer (can't read it).
  if typed ~= nil and typed ~= "" and runtime.setComposerText then
    runtime.setComposerText(typed)
  end

  -- When sticky is a non-whisper mode, restore chatType to that sticky type
  -- and clear tellTarget — the user's next Enter should land in Say/Party/etc.
  --
  -- When sticky IS whisper (WHISPER/BN_WHISPER), leave Blizzard's state alone.
  -- Clearing tellTarget while chatType stays WHISPER leaves the edit box in
  -- an invalid state — Blizzard's SendText will then call SendChatMessage
  -- with target=nil and throw "Chat type requires a target player". Blizzard
  -- already manages whisper-sticky target cleanup on its own.
  if type(editBox.SetAttribute) == "function" then
    local stickyType = EditBoxInterop.readEditBoxState(editBox, "stickyType")
    if stickyType and stickyType ~= "WHISPER" and stickyType ~= "BN_WHISPER" then
      pcall(editBox.SetAttribute, editBox, "chatType", stickyType)
      pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
    end
  end
  -- Only clear text when readable (non-secret). When text is secret, skip
  -- SetText entirely — calling it with a secret value or triggering its
  -- deferred-apply path crashes Blizzard's own OnUpdate.
  if typed ~= nil then
    pcall(editBox.SetText, editBox, "")
  end
  combatDraftBoxes[editBox] = nil

  if type(deactivateChat) == "function" then
    deactivateChat(editBox)
  elseif editBox.Hide then
    editBox:Hide()
  end
end

function EditBoxInterop.findBattleNetAccountInfo(target, bnetApi, getNumFriends)
  if not bnetApi or not bnetApi.GetFriendAccountInfo then
    return nil
  end

  local numFriends = type(getNumFriends) == "function" and getNumFriends() or 0
  for friendIndex = 1, numFriends do
    local accountInfo = bnetApi.GetFriendAccountInfo(friendIndex)
    if accountInfo then
      local characterName = accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName
      local battleTag = accountInfo.battleTag
      local battleTagBase = battleTag and string.match(battleTag, "^([^#]+)")
      local accountName = accountInfo.accountName
      if
        (characterName and characterName == target)
        or (battleTag and battleTag == target)
        or (battleTagBase and battleTagBase == target)
        or (accountName and accountName == target)
      then
        return accountInfo
      end
    end
  end

  return nil
end

function EditBoxInterop.interceptEditBox(runtime, hooks, deps, editBox)
  if EditBoxInterop.shouldPreserveCombatDraft(editBox) then
    return false
  end

  local chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
  local target = EditBoxInterop.readEditBoxState(editBox, "tellTarget")

  if chatType == "BN_WHISPER" and target then
    local opened = false
    pcall(function()
      local accountInfo = EditBoxInterop.findBattleNetAccountInfo(target, deps.bnetApi, deps.getNumFriends)
      if not accountInfo then
        return
      end
      local conversationKey = deps.ensureBattleNetConversation(runtime, deps.identity, accountInfo)
      if conversationKey and hooks.onOutgoingWhisper(conversationKey) then
        opened = true
      end
    end)
    if opened then
      EditBoxInterop.closeEditBox(runtime, editBox, deps.deactivateChat)
    end
    return true
  end

  if chatType == "WHISPER" and target and target ~= "" then
    if hooks.onSendTell(target) then
      EditBoxInterop.closeEditBox(runtime, editBox, deps.deactivateChat)
    end
    return true
  end

  return false
end

function EditBoxInterop.findFocusedEditBox(deps)
  for index = 1, deps.getNumChatWindows() do
    local editBox = deps.getEditBox(index)
    if editBox and type(editBox.HasFocus) == "function" then
      -- HasFocus() may return a secret (tainted) boolean during Mythic+
      -- lockdown. The boolean test must happen inside pcall so the taint
      -- error is caught instead of propagating.
      local ok, focused = pcall(function()
        if editBox:HasFocus() then
          return true
        end
        return false
      end)
      if ok and focused then
        return editBox
      end
    end
  end
  return nil
end

ns.BootstrapAutoOpenEditBoxInterop = EditBoxInterop

return EditBoxInterop
