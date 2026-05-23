local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local QuestLinkClassic = {}

-- Classic shift-click of a quest from the quest log inserts a plain string in
-- one of two forms (no `|H...|h` envelope):
--   1. `[Quest Name (questID)]`           — older Classic
--   2. `[[level] Quest Name (questID)]`   — Anniversary / SoD / recent Classic
-- Detect both and rewrite to a real quest hyperlink so the link is clickable
-- both in the composer (sender side) and in the recipient's chat.
--
-- Pattern (1) intentionally rejects nested brackets and pipes so an existing
-- `|H...|h[Label]|h|r` envelope is never a candidate. Pattern (2) is matched
-- first so the level-prefixed form is not greedy-consumed by pattern (1).
-- We additionally walk `|H...|h...|h` envelopes as opaque so anything inside a
-- real hyperlink is left untouched.
local CLASSIC_QUEST_LEVEL_PATTERN = "%[%[(%d+)%]%s+([^%[%]|]+) %((%d+)%)%]"
local CLASSIC_QUEST_PATTERN = "%[([^%[%]|]+) %((%d+)%)%]"
local QUEST_HYPERLINK_FORMAT = "|cffffff00|Hquest:%s:%s|h[%s]|h|r"

local function rewriteSegment(segment)
  local withLevel = string.gsub(segment, CLASSIC_QUEST_LEVEL_PATTERN, function(level, name, questId)
    return string.format(QUEST_HYPERLINK_FORMAT, questId, level, name)
  end)
  local rewritten = string.gsub(withLevel, CLASSIC_QUEST_PATTERN, function(name, questId)
    return string.format(QUEST_HYPERLINK_FORMAT, questId, "0", name)
  end)
  return rewritten
end

-- Reverse of Rewrite: turn `|cffffff00|Hquest:ID:...|h[NAME]|h|r` (with or
-- without the color envelope) back into plain `[NAME (ID)]`. This is the
-- format that survives WoW Classic Era's character-whisper protocol, which
-- detects ANY `|H...|h` envelope in an outgoing whisper and strips the id
-- from the visible label. Leaving even a partial envelope behind triggers
-- that sanitization, so the pattern must consume the entire envelope.
--
-- The fields after the questID are intentionally consumed as opaque (any
-- non-pipe characters) — Classic Era variants can append extra colon
-- separated fields beyond the level (anniversary realms, Hardcore, etc.),
-- and a too-strict pattern would leave the envelope half-stripped.
local QUEST_LINK_WITH_COLOR_PATTERN = "|c%x+|Hquest:(%d+)[^|]*|h%[([^%]]+)%]|h|r"
local QUEST_LINK_BARE_PATTERN = "|Hquest:(%d+)[^|]*|h%[([^%]]+)%]|h"

function QuestLinkClassic.Serialize(text)
  if type(text) ~= "string" then
    return text
  end
  if string.find(text, "|Hquest:", 1, true) == nil then
    return text
  end

  local result = string.gsub(text, QUEST_LINK_WITH_COLOR_PATTERN, function(questId, name)
    return string.format("[%s (%s)]", name, questId)
  end)
  result = string.gsub(result, QUEST_LINK_BARE_PATTERN, function(questId, name)
    return string.format("[%s (%s)]", name, questId)
  end)
  return result
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
