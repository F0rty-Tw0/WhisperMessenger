local SentHistory = require("WhisperMessenger.Model.SentHistory")
local SecretValue = require("WhisperMessenger.Util.SecretValue")
local MessageMetadata = require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

-- The collect-and-sort Build that the merge replaced, kept as the reference
-- the merge must match line for line.
local function usableText(text, fits)
  if SecretValue.Is(text) or type(text) ~= "string" or text == "" then
    return false
  end
  return fits == nil or fits(text)
end

local function referenceBuild(conversations, fits)
  if type(conversations) ~= "table" then
    return {}
  end
  local entries = {}
  for key, conversation in pairs(conversations) do
    if type(conversation) == "table" and type(conversation.messages) == "table" then
      for index, message in ipairs(conversation.messages) do
        if MessageMetadata.IsOutgoingUser(message) and usableText(message.text, fits) then
          entries[#entries + 1] = { text = message.text, sentAt = tonumber(message.sentAt) or 0, key = key, index = index }
        end
      end
    end
  end
  table.sort(entries, function(left, right)
    if left.sentAt ~= right.sentAt then
      return left.sentAt > right.sentAt
    end
    if left.key ~= right.key then
      return tostring(left.key) < tostring(right.key)
    end
    return left.index > right.index
  end)
  local list = {}
  for _, entry in ipairs(entries) do
    if entry.text ~= list[#list] then
      list[#list + 1] = entry.text
      if #list >= SentHistory.MAX_ENTRIES then
        break
      end
    end
  end
  return list
end

local TEXTS = { "ok", "ok", "hm", "abc", "SECRET", "", "a longer line", "lol" }
local SENT_AT_FORMS = { "number", "number", "number", "number", "string", "garbage", "missing" }

-- The test's own generator (Lehmer, exact in doubles), so every platform
-- builds the same stores. math.random follows the C runtime: on Windows the
-- first draw after a small seed is near 0, and every store came out empty.
local RANDOM_MODULUS, RANDOM_MULTIPLIER, RANDOM_WARM_UP = 2147483647, 16807, 3
local randomState = 1

-- random(high) is 1..high, random(low, high) is low..high, as math.random.
local function random(low, high)
  randomState = (randomState * RANDOM_MULTIPLIER) % RANDOM_MODULUS
  if high == nil then
    low, high = 1, low
  end
  return low + math.floor(randomState / RANDOM_MODULUS * (high - low + 1))
end

-- seed: 1 or more. The first draws after a small seed are small too, so
-- they are thrown away.
local function seedRandom(seed)
  randomState = seed
  for _ = 1, RANDOM_WARM_UP do
    random(1)
  end
end

local function pick(list)
  return list[random(#list)]
end

local function sentAtValue(sentAt)
  local form = pick(SENT_AT_FORMS)
  if form == "string" then
    return tostring(sentAt)
  elseif form == "garbage" then
    return "soon"
  elseif form == "missing" then
    return nil
  end
  return sentAt
end

local function randomLine(sentAt)
  local roll = random(10)
  local direction = roll <= 7 and "out" or "in"
  local kind = roll == 10 and "system" or "user"
  local text = random(20) == 1 and 42 or pick(TEXTS)
  return { kind = kind, direction = direction, text = text, sentAt = sentAt }
end

-- Times climb by 0 to 2 per line, so same-second ties are common; one chat
-- in four is shuffled out of time order, and some sentAt values are strings,
-- garbage or missing.
local function randomChat()
  local messages = {}
  local sentAt = random(5)
  local shuffled = random(4) == 1
  local messy = random(3) == 1
  for index = 1, random(0, 45) do
    sentAt = sentAt + random(0, 2)
    local line = randomLine(shuffled and random(60) or sentAt)
    if messy then
      line.sentAt = sentAtValue(line.sentAt)
    end
    messages[index] = line
  end
  if random(8) == 1 then
    messages[#messages + 2] = randomLine(sentAt + 1)
  end
  return { messages = messages }
end

local function randomStore()
  local conversations = {}
  for index = 1, random(0, 7) do
    conversations["me::WOW::c" .. index] = randomChat()
  end
  if random(6) == 1 then
    conversations["me::WOW::broken"] = "not a chat"
  end
  if random(6) == 1 then
    conversations["me::WOW::empty"] = { messages = "not a list" }
  end
  return conversations
end

local function shortOnly(text)
  return #text <= 3
end

local function sameList(actual, expected, label)
  assert(#actual == #expected, label .. ": expected " .. #expected .. " entries, got " .. #actual)
  for index = 1, #expected do
    assert(
      actual[index] == expected[index],
      label .. ": entry " .. index .. " expected " .. tostring(expected[index]) .. ", got " .. tostring(actual[index])
    )
  end
end

local function withSecretFake(run)
  local saved = rawget(_G, "issecretvalue")
  rawset(_G, "issecretvalue", function(value)
    return value == "SECRET"
  end)
  local ok, err = pcall(run)
  rawset(_G, "issecretvalue", saved)
  assert(ok, err)
end

local function bigStore(chats, linesPerChat)
  local conversations = {}
  local sentAt = 0
  for chat = 1, chats do
    local messages = {}
    for index = 1, linesPerChat do
      sentAt = sentAt + 1
      local direction = index % 2 == 0 and "out" or "in"
      messages[index] = { kind = "user", direction = direction, text = "a sent line of typical length " .. sentAt, sentAt = sentAt }
    end
    conversations["wow::WOW::c" .. chat] = { messages = messages }
  end
  return conversations
end

return function()
  -- test_build_matches_collect_and_sort_on_random_histories
  do
    local capped = 0
    withSecretFake(function()
      for seed = 1, 400 do
        seedRandom(seed)
        local conversations = randomStore()
        local fits = random(3) == 1 and shortOnly or nil
        local expected = referenceBuild(conversations, fits)
        if #expected == SentHistory.MAX_ENTRIES then
          capped = capped + 1
        end
        sameList(SentHistory.Build(conversations, fits), expected, "seed " .. seed)
      end
    end)
    assert(capped >= 20, "too few random stores reach the cap, got " .. capped)
  end

  -- test_build_does_not_allocate_per_stored_line
  do
    local conversations = bigStore(100, 200)
    SentHistory.Build(conversations)
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    SentHistory.Build(conversations)
    local grownKB = collectgarbage("count") - before
    collectgarbage("restart")
    assert(grownKB < 64, "Build allocated " .. string.format("%.0f", grownKB) .. " KB for 20,000 stored lines")
  end
end
