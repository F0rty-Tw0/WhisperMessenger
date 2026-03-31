local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Schema = {}

function Schema.NewAccountState()
  return {
    schemaVersion = 1,
    conversations = {},
    contacts = {},
    pendingHydration = {},
  }
end

function Schema.NewCharacterState()
  return {
    window = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 900,
      height = 560,
      contactsWidth = 300,
      minimized = false,
    },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    activeConversationKey = nil,
  }
end

ns.Schema = Schema

return Schema
