local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ToastCard = ns.WhisperToastsToastCard or require("WhisperMessenger.UI.WhisperToasts.ToastCard")
local PreviewAutoDismiss = ns.ToggleIconPreviewAutoDismiss or require("WhisperMessenger.UI.ToggleIcon.PreviewAutoDismiss")

-- Up to MAX_CARDS pop-up cards in one screen corner, one per conversation.
-- A new line in a chat that has a card rewrites that card and restarts its
-- timer; a chat without one takes a free card, else the card updated least
-- recently, which moves to the end. Cards stack away from the corner in the
-- order their chats appeared.
local ToastStack = {}

local MAX_CARDS = 3
local VISIBLE_SECONDS = 6
local EDGE_MARGIN = 16
local CARD_GAP = 6
local DEFAULT_CORNER = "TOPRIGHT"

-- Sign of the x and y offsets that move a card inward from each corner.
local CORNER_DIRECTIONS = {
  TOPLEFT = { x = 1, y = -1 },
  TOPRIGHT = { x = -1, y = -1 },
  BOTTOMLEFT = { x = 1, y = 1 },
  BOTTOMRIGHT = { x = -1, y = 1 },
}

ToastStack.DEFAULT_CORNER = DEFAULT_CORNER

function ToastStack.IsCorner(corner)
  return CORNER_DIRECTIONS[corner] ~= nil
end

-- options.onOpen(conversationKey): a card was clicked.
function ToastStack.Create(factory, parent, options)
  local onOpen = options.onOpen
  local cards = {}
  -- Shown cards, in the order they appeared.
  local active = {}
  local corner = DEFAULT_CORNER
  local updateCount = 0
  local stack = {}

  local function layout()
    local direction = CORNER_DIRECTIONS[corner]
    for index, card in ipairs(active) do
      local offsetY = EDGE_MARGIN + (index - 1) * (ToastCard.HEIGHT + CARD_GAP)
      card.frame:ClearAllPoints()
      card.frame:SetPoint(corner, parent, corner, direction.x * EDGE_MARGIN, direction.y * offsetY)
    end
  end

  local function detach(card)
    for index, shown in ipairs(active) do
      if shown == card then
        table.remove(active, index)
        return
      end
    end
  end

  local function remove(card)
    detach(card)
    card.timer.cancel()
    card.dismiss()
    layout()
  end

  local function newCard()
    local card
    card = ToastCard.Create(factory, parent, function()
      local conversationKey = card.conversationKey
      remove(card)
      if conversationKey ~= nil then
        onOpen(conversationKey)
      end
    end)
    card.timer = PreviewAutoDismiss.New({
      getSeconds = function()
        return VISIBLE_SECONDS
      end,
      isShown = function()
        return card.conversationKey ~= nil
      end,
      onExpire = function()
        remove(card)
      end,
    })
    cards[#cards + 1] = card
    return card
  end

  local function findActive(conversationKey)
    for _, card in ipairs(active) do
      if card.conversationKey == conversationKey then
        return card
      end
    end
    return nil
  end

  local function leastRecentlyUpdated()
    local oldest = active[1]
    for _, card in ipairs(active) do
      if card.updatedAt < oldest.updatedAt then
        oldest = card
      end
    end
    return oldest
  end

  local function takeCard()
    if #active >= MAX_CARDS then
      -- The replaced card now shows the newest chat, so it moves to the end.
      local oldest = leastRecentlyUpdated()
      detach(oldest)
      active[#active + 1] = oldest
      return oldest
    end
    for _, card in ipairs(cards) do
      if card.conversationKey == nil then
        active[#active + 1] = card
        return card
      end
    end
    local card = newCard()
    active[#active + 1] = card
    return card
  end

  -- entry: { conversationKey, senderName, messageText, classTag }.
  function stack.show(entry, nextCorner)
    corner = ToastStack.IsCorner(nextCorner) and nextCorner or DEFAULT_CORNER
    local card = findActive(entry.conversationKey) or takeCard()
    updateCount = updateCount + 1
    card.updatedAt = updateCount
    card.render(entry)
    card.show()
    card.timer.schedule()
    layout()
  end

  function stack.clear()
    while #active > 0 do
      remove(active[#active])
    end
  end

  return stack
end

ns.WhisperToastsToastStack = ToastStack
return ToastStack
