local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = {}
local ROW_HEIGHT = 48

local function compareItems(left, right)
  if left.lastActivityAt ~= right.lastActivityAt then
    return left.lastActivityAt > right.lastActivityAt
  end

  return (left.displayName or "") < (right.displayName or "")
end

local function buildItem(conversationKey, conversation)
  return {
    conversationKey = conversationKey,
    displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
    lastPreview = conversation.lastPreview or "",
    unreadCount = conversation.unreadCount or 0,
    lastActivityAt = conversation.lastActivityAt or 0,
    channel = conversation.channel or "WOW",
    guid = conversation.guid,
    bnetAccountID = conversation.bnetAccountID,
    gameAccountName = conversation.gameAccountName,
    className = conversation.className,
    classTag = conversation.classTag,
    raceName = conversation.raceName,
    raceTag = conversation.raceTag,
    factionName = conversation.factionName,
  }
end

function ContactsList.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, buildItem(conversationKey, conversation))
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.BuildItemsForProfile(savedState, localProfileId)
  local items = {}

  for conversationKey, conversation in pairs(savedState.conversations or {}) do
    if string.find(conversationKey, localProfileId .. "::", 1, true) == 1 then
      table.insert(items, buildItem(conversationKey, conversation))
    end
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.SetSelected(rows, selectedConversationKey)
  for _, row in ipairs(rows or {}) do
    row.selected = row.item ~= nil and row.item.conversationKey == selectedConversationKey
  end

  return selectedConversationKey
end

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

local function bindRow(factory, parent, row, index, item, options)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 260)
  row = row or factory.CreateFrame("Button", nil, parent)
  row.item = item
  row:SetSize(parentWidth, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
  if row.EnableMouse then
    row:EnableMouse(true)
  end

  if row.title == nil then
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("LEFT", row, "LEFT", 12, 0)
  end
  row.title:SetText(item.displayName)

  if row.preview == nil then
    row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.preview:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
  end
  row.preview:SetText("")

  if row.unread == nil then
    row.unread = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.unread:SetPoint("RIGHT", row, "RIGHT", -12, 0)
  end
  row.unread:SetText(item.unreadCount > 0 and tostring(item.unreadCount) or "")

  if row.channel == nil then
    row.channel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.channel:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 8)
  end
  row.channel:SetText("")

  if row.SetScript then
    row:SetScript("OnClick", function()
      if row.item ~= nil and options.onSelect then
        options.onSelect(row.item)
      end
    end)
  end

  if row.Show then
    row:Show()
  end

  return row
end

function ContactsList.Refresh(factory, parent, rows, items, options)
  rows = rows or {}
  items = items or {}
  options = options or {}

  for index, item in ipairs(items) do
    rows[index] = bindRow(factory, parent, rows[index], index, item, options)
  end

  for index = #items + 1, #rows do
    local row = rows[index]
    row.item = nil
    row.selected = false

    if row.title then
      row.title:SetText("")
    end
    if row.preview then
      row.preview:SetText("")
    end
    if row.unread then
      row.unread:SetText("")
    end
    if row.channel then
      row.channel:SetText("")
    end
    if row.Hide then
      row:Hide()
    end
  end

  local parentWidth = sizeValue(parent, "GetWidth", "width", 260)
  local viewport = parent and parent.parent or nil
  local viewportHeight = sizeValue(viewport, "GetHeight", "height", #items * ROW_HEIGHT)
  local contentHeight = math.max(viewportHeight, #items * ROW_HEIGHT)

  if parent and parent.SetSize then
    parent:SetSize(parentWidth, contentHeight)
  end

  if viewport and type(viewport.UpdateScrollChildRect) == "function" then
    viewport:UpdateScrollChildRect()
  end

  parent.rows = rows
  ContactsList.SetSelected(rows, options.selectedConversationKey)
  return rows
end

function ContactsList.Render(factory, parent, items, options)
  return ContactsList.Refresh(factory, parent, {}, items, options)
end

ns.ContactsList = ContactsList

return ContactsList