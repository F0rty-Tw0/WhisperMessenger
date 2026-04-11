local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EditBoxInterop = {}

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
    return editBox:GetText() or ""
  end
  return ""
end

function EditBoxInterop.markCombatDraft(editBox)
  local chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
  if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
    return
  end

  local typed = readEditBoxText(editBox)
  if typed ~= "" then
    editBox._wmTypedDuringCombat = true
  end
end

function EditBoxInterop.shouldPreserveCombatDraft(editBox)
  if type(editBox) ~= "table" then
    return false
  end

  local typed = readEditBoxText(editBox)
  if typed == "" then
    editBox._wmTypedDuringCombat = nil
    return false
  end

  if editBox._wmTypedDuringCombat ~= true then
    return false
  end

  local chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
  if chatType == "WHISPER" or chatType == "BN_WHISPER" then
    return true
  end

  editBox._wmTypedDuringCombat = nil
  return false
end

function EditBoxInterop.closeEditBox(runtime, editBox, deactivateChat)
  local typed = readEditBoxText(editBox)
  if typed ~= "" and runtime.setComposerText then
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
  editBox:SetText("")
  editBox._wmTypedDuringCombat = nil

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
    if editBox and type(editBox.HasFocus) == "function" and editBox:HasFocus() then
      return editBox
    end
  end
  return nil
end

ns.BootstrapAutoOpenEditBoxInterop = EditBoxInterop

return EditBoxInterop
