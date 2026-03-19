local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = {}

local function compareItems(left, right)
  if left.lastActivityAt ~= right.lastActivityAt then
    return left.lastActivityAt > right.lastActivityAt
  end

  return (left.displayName or "") < (right.displayName or "")
end

function ContactsList.BuildItems(conversations)
  local items = {}

  for conversationKey, conversation in pairs(conversations or {}) do
    table.insert(items, {
      conversationKey = conversationKey,
      displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
      lastPreview = conversation.lastPreview or "",
      unreadCount = conversation.unreadCount or 0,
      lastActivityAt = conversation.lastActivityAt or 0,
      channel = conversation.channel or "WOW",
    })
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.BuildItemsForProfile(savedState, localProfileId)
  local items = {}

  for conversationKey, conversation in pairs(savedState.conversations or {}) do
    if string.find(conversationKey, localProfileId .. "::", 1, true) == 1 then
      table.insert(items, {
        conversationKey = conversationKey,
        displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
        lastPreview = conversation.lastPreview or "",
        unreadCount = conversation.unreadCount or 0,
        lastActivityAt = conversation.lastActivityAt or 0,
        channel = conversation.channel or "WOW",
      })
    end
  end

  table.sort(items, compareItems)
  return items
end

function ContactsList.Render(factory, parent, items)
  local rows = {}

  for index, item in ipairs(items or {}) do
    local row = factory.CreateFrame("Button", nil, parent)
    row.item = item
    row:SetSize(parent.width or 260, 56)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * 56))

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText(item.displayName)
    row.title = title

    local preview = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preview:SetText(item.lastPreview)
    row.preview = preview

    local unread = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unread:SetText(item.unreadCount > 0 and tostring(item.unreadCount) or "")
    row.unread = unread

    local channel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channel:SetText(item.channel)
    row.channel = channel

    table.insert(rows, row)
  end

  parent.rows = rows
  return rows
end

ns.ContactsList = ContactsList

return ContactsList
