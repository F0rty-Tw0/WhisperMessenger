local QuestLinkClassic = require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")

local QUEST_PREFIX = "|cffffff00|Hquest:"
local QUEST_END = "|h|r"

local function buildExpectedLink(name, questId)
  return QUEST_PREFIX .. tostring(questId) .. ":0|h[" .. name .. "]" .. QUEST_END
end

local function buildExpectedLinkWithLevel(name, questId, level)
  return QUEST_PREFIX .. tostring(questId) .. ":" .. tostring(level) .. "|h[" .. name .. "]" .. QUEST_END
end

return function()
  -- nil / empty / non-string passthrough
  assert(QuestLinkClassic.Rewrite(nil) == nil, "nil should pass through")
  assert(QuestLinkClassic.Rewrite("") == "", "empty should pass through")
  assert(QuestLinkClassic.Rewrite(123) == 123, "non-string should pass through unchanged")

  -- Plain text without bracketed quest: passes through unchanged
  assert(QuestLinkClassic.Rewrite("hello world") == "hello world", "plain text unchanged")
  assert(QuestLinkClassic.Rewrite("[just a label]") == "[just a label]", "bracket without (id) unchanged")

  -- Classic vanilla shift-click format: [Name (id)]
  do
    local input = "look at [Apprentice's Duties (471)]"
    local expected = "look at " .. buildExpectedLink("Apprentice's Duties", 471)
    local out = QuestLinkClassic.Rewrite(input)
    assert(out == expected, "expected single rewrite, got: " .. tostring(out))
  end

  -- Multiple quests in one string
  do
    local input = "[Foo (1)] and [Bar Baz (42)]"
    local expected = buildExpectedLink("Foo", 1) .. " and " .. buildExpectedLink("Bar Baz", 42)
    assert(QuestLinkClassic.Rewrite(input) == expected, "expected multi rewrite")
  end

  -- Already-formatted hyperlink must not be re-wrapped
  do
    local existing = "|cffffff00|Hquest:1234:60|h[Some Quest]|h|r"
    assert(QuestLinkClassic.Rewrite(existing) == existing, "real hyperlink left alone")

    -- Mixed: a real link plus a Classic-format string in the same message
    local mixed = existing .. " also [Apprentice's Duties (471)]"
    local expectedMixed = existing .. " also " .. buildExpectedLink("Apprentice's Duties", 471)
    assert(QuestLinkClassic.Rewrite(mixed) == expectedMixed, "mixed: link kept, plain rewritten")
  end

  -- Classic with-level shift-click format: [[L] Name (id)]
  do
    local input = "look at [[2] Cutting Teeth (788)]"
    local expected = "look at " .. buildExpectedLinkWithLevel("Cutting Teeth", 788, 2)
    local out = QuestLinkClassic.Rewrite(input)
    assert(out == expected, "expected level-prefixed rewrite, got: " .. tostring(out))
  end

  do
    local input = "[[1] Vile Familiars (1485)] and [[2] Cutting Teeth (788)]"
    local expected = buildExpectedLinkWithLevel("Vile Familiars", 1485, 1)
      .. " and "
      .. buildExpectedLinkWithLevel("Cutting Teeth", 788, 2)
    assert(QuestLinkClassic.Rewrite(input) == expected, "expected multi level-prefixed rewrite")
  end

  -- Item links should not be touched even if they contain digits
  do
    local item = "|cff0070dd|Hitem:19019::::::::|h[Thunderfury (Blessed)]|h|r"
    -- Note: not a Classic quest format (no "(digits)" inside the visible label
    -- in the canonical sense), and the bracket lives inside |H...|h envelope.
    assert(QuestLinkClassic.Rewrite(item) == item, "item link untouched")
  end
end
