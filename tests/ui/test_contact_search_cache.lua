local ContactSearch = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

-- Runs fn and returns how many times it lowered a string, plus fn's result.
local function countLowers(fn)
  local originalLower = string.lower
  local calls = 0
  rawset(string, "lower", function(value)
    calls = calls + 1
    return originalLower(value)
  end)
  local ok, result = pcall(fn)
  rawset(string, "lower", originalLower)
  if not ok then
    error(result, 0)
  end
  return calls, result
end

local function makeItem(name, texts)
  local messages = {}
  for index, text in ipairs(texts) do
    messages[index] = { text = text, playerName = name }
  end
  return {
    conversationKey = "me::WOW::" .. string.lower(name),
    displayName = name,
    lastPreview = texts[#texts],
    conversation = { messages = messages },
  }
end

local function addMessage(item, text)
  local messages = item.conversation.messages
  messages[#messages + 1] = { text = text, playerName = item.displayName }
  item.lastPreview = text
end

local function names(visible)
  local out = {}
  for index, item in ipairs(visible) do
    out[index] = item.displayName
  end
  return table.concat(out, ",")
end

local function makeContacts()
  return {
    makeItem("Arthas", { "Meet in Stormwind", "Bring flasks" }),
    makeItem("Jaina", { "Portal is up", "See you in Dalaran" }),
    makeItem("Thrall", { "For the Horde", "Lok'tar" }),
  }
end

return function()
  -- test_refresh_with_same_query_does_not_rescan_unchanged_conversations
  do
    local items = makeContacts()
    local cache = {}

    local firstLowers, first = countLowers(function()
      return ContactSearch.BuildVisibleContacts(items, "dalaran", cache)
    end)
    assert(firstLowers > 0, "the first pass has to read the history")
    assert(names(first) == "Jaina", "first pass should find the one match; got " .. names(first))

    local secondLowers, second = countLowers(function()
      return ContactSearch.BuildVisibleContacts(items, "dalaran", cache)
    end)
    assert(secondLowers == 0, "an unchanged list must not be searched again; lowered " .. secondLowers .. " strings")
    assert(names(second) == "Jaina", "the cached pass must return the same contacts; got " .. names(second))
    assert(second ~= first, "each pass returns its own list")
  end

  -- test_new_message_rescans_only_its_own_conversation
  do
    local items = makeContacts()
    local cache = {}
    ContactSearch.BuildVisibleContacts(items, "zzz", cache)

    addMessage(items[2], "One more line")
    local lowers = countLowers(function()
      return ContactSearch.BuildVisibleContacts(items, "zzz", cache)
    end)
    -- Jaina alone: display name, conversation key, preview, three texts and one sender.
    assert(lowers == 7, "only the changed conversation should be searched again; lowered " .. lowers .. " strings")
  end

  -- test_new_matching_message_makes_hidden_contact_visible
  do
    local items = makeContacts()
    local cache = {}
    assert(names(ContactSearch.BuildVisibleContacts(items, "naxxramas", cache)) == "", "nothing matches yet")

    addMessage(items[3], "Naxxramas tonight?")
    local visible = ContactSearch.BuildVisibleContacts(items, "naxxramas", cache)
    assert(names(visible) == "Thrall", "a new matching message must show its contact; got " .. names(visible))
  end

  -- test_changing_query_discards_cached_matches
  do
    local items = makeContacts()
    local cache = {}
    assert(names(ContactSearch.BuildVisibleContacts(items, "stormwind", cache)) == "Arthas", "first query")
    assert(names(ContactSearch.BuildVisibleContacts(items, "horde", cache)) == "Thrall", "a new query must not reuse the old answers")
    assert(names(ContactSearch.BuildVisibleContacts(items, "stormwind", cache)) == "Arthas", "going back to the first query")

    local lowers = countLowers(function()
      return ContactSearch.BuildVisibleContacts(items, "stormwind", cache)
    end)
    assert(lowers == 0, "the cache should serve the query it was last filled for; lowered " .. lowers .. " strings")
  end

  -- test_cached_pass_keeps_contact_order
  do
    local items = makeContacts()
    local cache = {}
    assert(names(ContactSearch.BuildVisibleContacts(items, "a", cache)) == "Arthas,Jaina,Thrall", "first pass order")

    items[1], items[3] = items[3], items[1]
    local visible = ContactSearch.BuildVisibleContacts(items, "a", cache)
    assert(names(visible) == "Thrall,Jaina,Arthas", "a cached pass must follow the order it is given; got " .. names(visible))
  end

  -- test_empty_query_returns_everything_and_drops_cached_matches
  do
    local items = makeContacts()
    local cache = {}
    ContactSearch.BuildVisibleContacts(items, "stormwind", cache)

    local lowers, visible = countLowers(function()
      return ContactSearch.BuildVisibleContacts(items, "", cache)
    end)
    assert(#visible == 3, "an empty query shows every contact")
    assert(lowers == 0, "an empty query must not search anything")
    assert(next(cache.entries) == nil, "clearing the search box should free the cached matches")
  end

  -- test_contact_without_a_key_is_searched_every_pass
  do
    local items = { { displayName = "Arthas", conversation = { messages = { { text = "Meet in Stormwind" } } } } }
    local cache = {}
    assert(#ContactSearch.BuildVisibleContacts(items, "stormwind", cache) == 1, "a keyless contact still matches")

    items[1].conversation.messages[1].text = "Meet in Ironforge"
    assert(#ContactSearch.BuildVisibleContacts(items, "stormwind", cache) == 0, "a keyless contact is never served from the cache")
  end

  -- test_non_table_items_are_skipped_with_a_cache
  do
    local cache = {}
    local visible = ContactSearch.BuildVisibleContacts({ "junk", makeItem("Arthas", { "Meet in Stormwind" }) }, "stormwind", cache)
    assert(names(visible) == "Arthas", "junk rows never match a query")
  end
end
