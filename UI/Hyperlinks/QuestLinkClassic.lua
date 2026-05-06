local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local QuestLinkClassic = {}

-- Classic shift-click of a quest from the quest log inserts a plain string of
-- the form `[Quest Name (questID)]` (no |H...|h hyperlink envelope). Detect
-- that pattern and rewrite to a real quest hyperlink so the link is clickable
-- both in the composer (sender side) and in the recipient's chat.
--
-- The pattern intentionally rejects nested brackets and pipes so an existing
-- `|H...|h[Label]|h|r` envelope is never a candidate. We additionally walk
-- |H...|h...|h envelopes as opaque so anything inside a real hyperlink is
-- left untouched.
local CLASSIC_QUEST_PATTERN = "%[([^%[%]|]+) %((%d+)%)%]"
local QUEST_HYPERLINK_FORMAT = "|cffffff00|Hquest:%s:0|h[%s]|h|r"

local function rewriteSegment(segment)
  local rewritten = string.gsub(segment, CLASSIC_QUEST_PATTERN, function(name, questId)
    return string.format(QUEST_HYPERLINK_FORMAT, questId, name)
  end)
  return rewritten
end

function QuestLinkClassic.Rewrite(text)
  if type(text) ~= "string" then
    return text
  end
  if text == "" or string.find(text, "%[") == nil then
    return text
  end

  local output = {}
  local cursor = 1

  while cursor <= #text do
    local hyperlinkStart, hyperlinkEnd = string.find(text, "|H.-|h.-|h", cursor)
    if hyperlinkStart == nil then
      table.insert(output, rewriteSegment(string.sub(text, cursor)))
      break
    end

    if hyperlinkStart > cursor then
      table.insert(output, rewriteSegment(string.sub(text, cursor, hyperlinkStart - 1)))
    end

    table.insert(output, string.sub(text, hyperlinkStart, hyperlinkEnd))
    cursor = hyperlinkEnd + 1
  end

  return table.concat(output)
end

ns.UIHyperlinksQuestLinkClassic = QuestLinkClassic
return QuestLinkClassic
