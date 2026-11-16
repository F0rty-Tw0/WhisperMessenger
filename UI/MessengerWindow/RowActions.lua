local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local RowActions = {}

-- The contact row, transcript and header actions. Add a new one here: the
-- layers below forward the table, not its keys.
local ROW_ACTION_NAMES = {
  "onPin",
  "onRemove",
  "onMarkUnread",
  "onUpdatePrefs",
  "onIgnorePlayer",
  "onUnblockPlayer",
  "isPlayerBlocked",
  "whoPlayer",
  "onInviteContact",
  "canInviteContact",
}

-- Gathers the row actions from the window's flat options into one table.
-- An action the window was not given stays absent, which hides its menu entry.
function RowActions.Collect(options)
  local rowActions = {}
  for _, name in ipairs(ROW_ACTION_NAMES) do
    rowActions[name] = options[name]
  end
  return rowActions
end

ns.MessengerWindowRowActions = RowActions

return RowActions
