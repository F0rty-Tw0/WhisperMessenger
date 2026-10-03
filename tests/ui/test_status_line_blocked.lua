local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local Theme = require("WhisperMessenger.UI.Theme")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

-- A whisper contact on the block list leads the status detail with "Blocked",
-- in the danger colour.
return function()
  local blocked = UIHelpers.colorEscape(Theme.COLORS.danger_text) .. "Blocked|r"

  -- test_blocked_contact_leads_with_blocked
  do
    local _, line2 = StatusLine.Build({ displayName = "Arthas", isBlocked = true, areaName = "Durotar" }, { status = "CanWhisper" })
    assert(line2 == blocked .. "  -  Online  -  Durotar", "got " .. line2)
  end

  -- test_blocked_contact_without_presence_shows_only_blocked
  do
    local _, line2 = StatusLine.Build({ displayName = "Arthas", isBlocked = true }, nil)
    assert(line2 == blocked, "got " .. line2)
  end

  -- test_unblocked_contact_has_no_blocked_label
  do
    local _, line2 = StatusLine.Build({ displayName = "Arthas", isBlocked = false }, { status = "CanWhisper" })
    assert(line2 == "Online", "got " .. line2)
  end
end
