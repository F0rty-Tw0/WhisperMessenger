local ContactSearch = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

-- Every case fills the cache, changes something the search reads, and then
-- expects the cached pass to answer exactly like a pass with no cache.

local function makeItem(texts)
  local messages = {}
  for index, text in ipairs(texts) do
    messages[index] = { text = text, playerName = "Khadgar" }
  end
  return {
    conversationKey = "me::WOW::arthas",
    displayName = "Arthas",
    lastPreview = texts[#texts],
    conversation = { messages = messages },
  }
end

local function isVisible(items, query, cache)
  return #ContactSearch.BuildVisibleContacts(items, query, cache) == 1
end

-- Fills the cache for query, applies change, and checks the next cached pass.
-- messages (optional) replaces the default three-message history.
local function expectAfterChange(label, query, visibleBefore, visibleAfter, change, messages)
  local item = makeItem({ "Meet in Stormwind", "Bring flasks", "See you there" })
  if messages then
    item.conversation.messages = messages
  end
  local items = { item }
  local cache = {}
  assert(isVisible(items, query, cache) == visibleBefore, label .. ": wrong answer before the change")
  assert(isVisible(items, query, cache) == visibleBefore, label .. ": wrong cached answer before the change")

  change(item, items)

  assert(isVisible(items, query) == visibleAfter, label .. ": the test's own expectation is wrong")
  assert(isVisible(items, query, cache) == visibleAfter, label .. ": cached answer is stale")
end

-- Deterministic pseudo-random numbers, the same on every Lua version.
local function makeRandom(seed)
  local state = seed
  return function(limit)
    state = (state * 1103515245 + 12345) % 2147483648
    return (math.floor(state / 65536) % limit) + 1
  end
end

local WORDS = { "stormwind", "flasks", "raid", "portal", "horde", "dalaran", "invite", "gold" }
local NAMES = { "Arthas", "Jaina", "Thrall", "Khadgar" }
local QUERIES = { "raid", "gold portal", "arthas", "horde flasks dalaran", "stormwind invite", "zzz" }

local function randomText(random)
  return WORDS[random(#WORDS)] .. " " .. WORDS[random(#WORDS)]
end

local function mutate(random, items, nextKey)
  local item = items[random(#items)]
  local messages = item.conversation.messages
  local action = random(9)
  if action == 1 then
    messages[#messages + 1] = { text = randomText(random), playerName = NAMES[random(#NAMES)] }
    item.lastPreview = messages[#messages].text
  elseif action == 2 then
    messages[#messages + 1] = { text = randomText(random), playerName = NAMES[random(#NAMES)] }
  elseif action == 3 and #messages > 0 then
    messages[random(#messages)].text = randomText(random)
  elseif action == 4 and #messages > 0 then
    table.remove(messages, random(#messages))
  elseif action == 5 and #messages > 0 then
    messages[random(#messages)].playerName = NAMES[random(#NAMES)]
  elseif action == 6 then
    item.displayName = NAMES[random(#NAMES)]
    item.note = (random(2) == 1) and randomText(random) or nil
  elseif action == 7 and #items > 1 then
    table.remove(items, random(#items))
  elseif action == 8 then
    table.insert(items, random(#items + 1), {
      conversationKey = "key" .. nextKey,
      displayName = NAMES[random(#NAMES)],
      conversation = { messages = { { text = randomText(random), playerName = NAMES[random(#NAMES)] } } },
    })
  elseif action == 9 then
    item.conversation = { messages = { { text = randomText(random), playerName = NAMES[random(#NAMES)] } } }
  end
end

local function sameList(left, right)
  if #left ~= #right then
    return false
  end
  for index, item in ipairs(left) do
    if right[index] ~= item then
      return false
    end
  end
  return true
end

return function()
  -- test_message_edited_in_place_is_rechecked
  expectAfterChange("edit adds a match", "ironforge", false, true, function(item)
    item.conversation.messages[1].text = "Meet in Ironforge"
  end)
  expectAfterChange("edit removes a match", "stormwind", true, false, function(item)
    item.conversation.messages[1].text = "Meet in Ironforge"
  end)

  -- test_appended_message_is_rechecked_when_the_preview_stays_the_same
  expectAfterChange("matching message appended", "ironforge", false, true, function(item)
    local messages = item.conversation.messages
    messages[#messages + 1] = { text = "Now in Ironforge", playerName = "Khadgar" }
  end)
  expectAfterChange("matching sender appended", "medivh", false, true, function(item)
    local messages = item.conversation.messages
    messages[#messages + 1] = { text = "See you there", playerName = "Medivh" }
  end)

  -- test_removed_message_is_rechecked
  expectAfterChange("only matching message removed", "flasks", true, false, function(item)
    table.remove(item.conversation.messages, 2)
  end)

  -- test_trimmed_and_appended_history_with_same_count_is_rechecked
  expectAfterChange("oldest trimmed, one appended", "stormwind", true, false, function(item)
    local messages = item.conversation.messages
    table.remove(messages, 1)
    messages[#messages + 1] = { text = "On my way", playerName = "Khadgar" }
  end)

  -- test_long_whisper_parts_merged_into_an_older_message_are_rechecked
  expectAfterChange("late part folded into its first part", "stormwind keep", false, true, function(item)
    local messages = item.conversation.messages
    -- The second part arrives, is folded into the first, and is removed
    -- again: same count, same last message, new text on an older one.
    messages[#messages + 1] = { text = " Keep", playerName = "Khadgar" }
    messages[1].text = messages[1].text .. messages[#messages].text
    messages[#messages] = nil
  end)

  -- test_history_cut_short_before_the_match_is_rechecked
  expectAfterChange("empty first message removed, leaving a gap", "flasks", true, false, function(item)
    item.conversation.messages[1] = nil
  end, { {}, { text = "Bring flasks", playerName = "Khadgar" } })

  -- test_sender_name_change_is_rechecked
  expectAfterChange("sender renamed", "medivh", false, true, function(item)
    item.conversation.messages[2].playerName = "Medivh"
  end)

  -- test_contact_field_change_is_rechecked
  expectAfterChange("note added", "tuesdays", false, true, function(item)
    item.note = "Raids on Tuesdays"
  end)
  expectAfterChange("renamed away from the match", "arthas", true, false, function(item)
    item.displayName = "Menethil"
    item.conversationKey = "me::WOW::menethil"
  end)
  expectAfterChange("battle tag filled in later", "1234", false, true, function(item)
    item.battleTag = "Arthas#1234"
  end)

  -- test_replaced_history_is_rechecked
  expectAfterChange("messages table swapped", "stormwind", true, false, function(item)
    item.conversation.messages = { { text = "Fresh start", playerName = "Khadgar" } }
  end)
  expectAfterChange("conversation dropped from the contact", "stormwind", true, false, function(item)
    item.conversation = nil
  end)

  -- test_deleted_conversation_is_gone_and_forgotten
  do
    local item = makeItem({ "Meet in Stormwind" })
    local items = { item }
    local cache = {}
    assert(isVisible(items, "stormwind", cache), "contact matches before it is deleted")

    items[1] = nil
    assert(#ContactSearch.BuildVisibleContacts(items, "stormwind", cache) == 0, "a deleted contact must not come back from the cache")
    assert(cache.entries[item.conversationKey] == nil, "a deleted contact's cached match should be dropped")

    -- The same player whispers again: a new conversation under the old key.
    items[1] = makeItem({ "Meet in Ironforge" })
    assert(not isVisible(items, "stormwind", cache), "a recreated conversation must be searched fresh")
    assert(isVisible(items, "ironforge", cache), "a recreated conversation must match its own history")
  end

  -- test_cached_results_equal_uncached_results_under_random_changes
  do
    local random = makeRandom(215)
    local items = {}
    for index = 1, 6 do
      items[index] = {
        conversationKey = "key" .. index,
        displayName = NAMES[random(#NAMES)],
        conversation = { messages = {} },
      }
    end

    local cache = {}
    local query = QUERIES[1]
    for step = 1, 600 do
      mutate(random, items, 6 + step)
      if random(12) == 1 then
        query = QUERIES[random(#QUERIES)]
      end
      local expected = ContactSearch.BuildVisibleContacts(items, query)
      local cached = ContactSearch.BuildVisibleContacts(items, query, cache)
      assert(sameList(expected, cached), "step " .. step .. ", query '" .. query .. "': cached list differs from a fresh search")
      local again = ContactSearch.BuildVisibleContacts(items, query, cache)
      assert(sameList(expected, again), "step " .. step .. ", query '" .. query .. "': repeated cached list differs")
    end
  end
end
