local ContactsSearchController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")

-- The controller with the real contact search: a query left in the box must
-- not search unchanged conversations again on every window refresh.

local function countLowers(fn)
  local originalLower = string.lower
  local calls = 0
  rawset(string, "lower", function(value)
    calls = calls + 1
    return originalLower(value)
  end)
  local ok, err = pcall(fn)
  rawset(string, "lower", originalLower)
  if not ok then
    error(err, 0)
  end
  return calls
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

local function buildHarness()
  local input = { text = "", scripts = {} }
  function input:SetScript(name, handler)
    self.scripts[name] = handler
  end
  function input:GetText()
    return self.text
  end

  local shown = {}
  local items = {
    makeItem("Arthas", { "Meet in Stormwind", "Bring flasks" }),
    makeItem("Jaina", { "Portal is up", "See you in Dalaran" }),
  }
  local controller = ContactsSearchController.Create({
    contacts = {},
    contactsController = {
      refresh = function(rows)
        local names = {}
        for index, item in ipairs(rows) do
          names[index] = item.displayName
        end
        shown[#shown + 1] = table.concat(names, ",")
        return rows
      end,
    },
    contactsSearchInput = input,
    initialContacts = items,
  })
  controller.bindInputScripts()

  return {
    items = items,
    controller = controller,
    lastShown = function()
      return shown[#shown]
    end,
    typeText = function(text)
      input.text = text
      input.scripts.OnTextChanged(input, true)
    end,
  }
end

-- No C_Timer: typing filters immediately, so each case reads top to bottom.
local function withoutTimer(fn)
  local previousTimer = _G.C_Timer
  rawset(_G, "C_Timer", nil)
  local ok, err = pcall(fn)
  rawset(_G, "C_Timer", previousTimer)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_refresh_with_same_query_does_not_rescan_unchanged_conversations
  withoutTimer(function()
    local h = buildHarness()
    h.typeText("dalaran")
    assert(h.lastShown() == "Jaina", "typing should filter the list; got " .. tostring(h.lastShown()))

    local lowers = countLowers(function()
      h.controller.refresh(nil, nil)
    end)
    assert(lowers == 0, "a refresh with the query unchanged must not search again; lowered " .. lowers .. " strings")
    assert(h.lastShown() == "Jaina", "the refresh must show the same contacts; got " .. tostring(h.lastShown()))

    -- A window refresh hands over a new list holding the same contact cards.
    local sameCards = { h.items[1], h.items[2] }
    lowers = countLowers(function()
      h.controller.refresh(sameCards, nil)
    end)
    assert(lowers == 0, "a rebuilt list of unchanged contacts must not be searched again; lowered " .. lowers .. " strings")
  end)

  -- test_new_matching_message_makes_hidden_contact_visible
  withoutTimer(function()
    local h = buildHarness()
    h.typeText("naxxramas")
    assert(h.lastShown() == "", "nothing matches yet; got " .. tostring(h.lastShown()))

    local arthas = h.items[1]
    local messages = arthas.conversation.messages
    messages[#messages + 1] = { text = "Naxxramas tonight?", playerName = "Arthas" }
    arthas.lastPreview = "Naxxramas tonight?"
    h.controller.refresh(nil, nil)
    assert(h.lastShown() == "Arthas", "a whisper that matches the query must show its contact; got " .. tostring(h.lastShown()))
  end)

  -- test_changing_query_discards_cached_matches
  withoutTimer(function()
    local h = buildHarness()
    h.typeText("stormwind")
    assert(h.lastShown() == "Arthas", "first query; got " .. tostring(h.lastShown()))
    h.typeText("portal")
    assert(h.lastShown() == "Jaina", "a new query must not reuse the old matches; got " .. tostring(h.lastShown()))
    h.typeText("")
    assert(h.lastShown() == "Arthas,Jaina", "clearing the box shows everyone; got " .. tostring(h.lastShown()))
  end)
end
