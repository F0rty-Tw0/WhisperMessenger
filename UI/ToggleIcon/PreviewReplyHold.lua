local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PreviewReplyRow = ns.ToggleIconPreviewReplyRow or require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

-- Decides what the preview card does with each update while the player
-- types a reply under it: the row "holds" the card on one conversation
-- (focused or non-empty input), and updates for anything else wait until
-- the hold ends.
local PreviewReplyHold = {}

local function noop(_) end

local function alwaysApply()
  return "apply"
end

local function never()
  return false
end

local function zero()
  return 0
end

-- No quickReply: the card behaves as it always has and no frame is made.
local function inertHold()
  return {
    route = alwaysApply,
    onApplied = noop,
    onCleared = noop,
    onDismiss = never,
    onOpen = never,
    isRowShown = never,
    rowHeight = zero,
    applyTheme = noop,
  }
end

-- options = { theme, quickReply, autoDismiss, hideCard }
function PreviewReplyHold.Create(factory, previewFrame, options)
  local quickReply = options.quickReply
  if quickReply == nil then
    return inertHold()
  end
  local autoDismiss = options.autoDismiss
  local hideCard = options.hideCard
  local theme = options.theme

  local hold = {}
  ---@type table?
  local heldMeta = nil
  -- An update was ignored during the hold; the hold end fetches the latest.
  local stale = false
  local submitting = false
  -- The runtime saves the draft itself before it opens the chat.
  local opening = false
  -- The hold ends inside a step that settles the card itself: no refresh.
  local settling = false
  local locked = false
  local lockedReason = nil

  local function holding()
    local row = hold.row
    return row ~= nil and row.isShown() and row.isHolding()
  end

  local function clearRow(suppress)
    settling = suppress
    hold.row.clear()
    settling = false
  end

  local function stash(suppress)
    local text = hold.row.getText()
    if text ~= "" and not opening then
      quickReply.onSaveDraft(heldMeta, text)
    end
    clearRow(suppress)
  end

  -- Only keyboard focus holds the timer: text left in the box keeps the card
  -- on its chat, but the card still closes on time (the text becomes a draft).
  local function onFocusChanged(focused)
    autoDismiss.setHeld("focus", focused)
  end

  local function hideRow()
    local row = hold.row
    if row == nil then
      return
    end
    row.setShown(false)
    -- The engine may drop a hidden box's focus without a focus-lost script.
    onFocusChanged(false)
    if locked then
      row.setEnabled(true)
      locked = false
    end
  end

  local function checkLock()
    local reason = quickReply.getLockReasonText()
    if reason ~= nil then
      -- The first lock already stashed the text and dropped focus; a repeat is a no-op.
      if locked and reason == lockedReason and not holding() then
        return
      end
      if holding() then
        stash(false)
      end
      hold.row.setEnabled(false, reason)
      locked = true
      lockedReason = reason
    elseif locked then
      hold.row.setEnabled(true)
      locked = false
    end
  end

  local function onHoldChanged(isHolding)
    if isHolding then
      return
    end
    if stale and not settling then
      stale = false
      quickReply.onRefresh()
    end
  end

  local function onDisabledClick()
    local reason = quickReply.getLockReasonText()
    if reason ~= nil then
      hold.row.setEnabled(false, reason)
      lockedReason = reason
      return
    end
    hold.row.setEnabled(true)
    locked = false
    hold.row.focus()
  end

  -- HandleSend refreshes the icons synchronously, so the card is re-entered
  -- while submitting; route() ignores those updates and marks the card stale.
  local function submit(text)
    if heldMeta == nil then
      return false
    end
    submitting = true
    local ok, result = pcall(quickReply.onSubmit, heldMeta, text)
    submitting = false
    if not ok then
      error(result, 0)
    end
    if result ~= true then
      return false
    end
    stale = false
    clearRow(true)
    hideCard()
    quickReply.onRefresh()
    return true
  end

  local function ensureRow()
    if hold.row == nil then
      hold.row = PreviewReplyRow.Create(factory, previewFrame, {
        theme = theme,
        onSubmit = submit,
        onHoldChanged = onHoldChanged,
        onFocusChanged = onFocusChanged,
        onFocusGained = checkLock,
        onDisabledClick = onDisabledClick,
      })
    end
    return hold.row
  end

  function hold.route(meta, isExternal)
    if submitting then
      stale = true
      return "ignore"
    end
    if not quickReply.isEnabled() and hold.isRowShown() then
      stale = false
      stash(true)
      hideRow()
      return "apply"
    end
    local otherChat = meta ~= nil and heldMeta ~= nil and meta.conversationKey ~= heldMeta.conversationKey
    if holding() and (isExternal or otherChat) then
      stale = true
      return "ignore"
    end
    return "apply"
  end

  function hold.onCleared()
    if holding() then
      stale = false
      stash(true)
    end
    hideRow()
    heldMeta = nil
  end

  function hold.onApplied(meta)
    if meta == nil or not quickReply.isEnabled() then
      hold.onCleared()
      return
    end
    -- An applied update is the current truth.
    stale = false
    local row = ensureRow()
    if heldMeta == nil or heldMeta.conversationKey ~= meta.conversationKey then
      row.setTarget(meta.channel)
    end
    heldMeta = meta
    row.setShown(true)
    checkLock()
  end

  -- While holding, ack only through the held whisper so a newer one still shows.
  function hold.onDismiss()
    if not holding() then
      return false
    end
    local meta = heldMeta
    stale = false
    stash(true)
    hideCard()
    quickReply.onDismissThrough(meta)
    return true
  end

  -- The open re-enters the card (selectConversation -> refresh -> clear),
  -- whose stash must not write the runtime's draft a second time.
  -- Returns handled (the hold owned the click) and opened (the chat opened).
  function hold.onOpen()
    if not holding() then
      return false
    end
    opening = true
    local ok, result = pcall(quickReply.onOpen, heldMeta, hold.row.getText())
    opening = false
    if not ok then
      error(result, 0)
    end
    local opened = result == true
    if opened then
      stale = false
      clearRow(true)
    end
    return true, opened
  end

  function hold.isRowShown()
    return hold.row ~= nil and hold.row.isShown()
  end

  function hold.rowHeight()
    if hold.isRowShown() then
      return hold.row.height()
    end
    return 0
  end

  function hold.applyTheme(activeTheme)
    theme = activeTheme or theme
    if hold.row ~= nil then
      hold.row.applyTheme(theme)
    end
  end

  return hold
end

ns.ToggleIconPreviewReplyHold = PreviewReplyHold

return PreviewReplyHold
