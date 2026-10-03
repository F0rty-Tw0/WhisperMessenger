local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

-- A deliberately naive store with the documented rules: one line per sender,
-- an older line never replaces a newer one, the oldest line (time, then
-- arrival) is evicted over the cap, and a bare name falls back to the newest
-- line from any realm. The real store must answer exactly like it.
local function newModel(maxEntries, ttl)
  return { entries = {}, count = 0, sequence = 0, maxEntries = maxEntries, ttl = ttl }
end

local function isOlder(a, b)
  if a.sentAt ~= b.sentAt then
    return a.sentAt < b.sentAt
  end
  return a.sequence < b.sequence
end

local function baseOf(key)
  return string.match(key, "^([^-]+)") or key
end

local function modelRemove(model, key)
  model.entries[key] = nil
  model.count = model.count - 1
end

local function modelEvict(model)
  while model.count > model.maxEntries do
    local oldestKey
    for key, entry in pairs(model.entries) do
      if oldestKey == nil or isOlder(entry, model.entries[oldestKey]) then
        oldestKey = key
      end
    end
    modelRemove(model, oldestKey)
  end
end

local function modelRecord(model, name, text, sentAt)
  local key = string.lower(name)
  local existing = model.entries[key]
  if existing and existing.sentAt > sentAt then
    return
  end
  model.sequence = model.sequence + 1
  if existing == nil then
    model.count = model.count + 1
  end
  model.entries[key] = { text = text, sentAt = sentAt, sequence = model.sequence }
  modelEvict(model)
end

local function modelGet(model, name, now)
  local key = string.lower(name)
  local entry = model.entries[key]
  if entry == nil then
    for candidateKey, candidate in pairs(model.entries) do
      if baseOf(candidateKey) == baseOf(key) and (entry == nil or isOlder(entry, candidate)) then
        key, entry = candidateKey, candidate
      end
    end
  end
  if entry and now and (now - entry.sentAt) > model.ttl then
    modelRemove(model, key)
    return nil
  end
  return entry
end

local function modelRestore(model, now)
  for key, entry in pairs(model.entries) do
    if (now - entry.sentAt) > model.ttl then
      modelRemove(model, key)
    end
  end
  modelEvict(model)
end

return function()
  -- test_store_matches_naive_model_over_random_traffic
  do
    local seed = 12345
    local function random(n)
      seed = (seed * 16807) % 2147483647
      return (seed % n) + 1
    end

    local bases = { "Thrall", "Jaina", "Arthas", "Vol" }
    local realms = { "Area52", "Draenor", "Kazzak" }
    local config = { maxEntries = 6, ttl = 40 }
    local state = ChannelMessageStore.New(config)
    local model = newModel(config.maxEntries, config.ttl)
    local clock = 1000

    for step = 1, 4000 do
      clock = clock + random(4) - 1
      local name = bases[random(#bases)] .. "-" .. realms[random(#realms)]
      local roll = random(100)
      local context = "step " .. step
      if roll <= 70 then
        -- one line in eight arrives with an earlier time than the clock
        local sentAt = random(8) == 1 and clock - random(30) or clock
        ChannelMessageStore.Record(state, name, "line" .. step, "Trade", sentAt)
        modelRecord(model, name, "line" .. step, sentAt)
      elseif roll <= 97 then
        local lookup = random(2) == 1 and name or bases[random(#bases)]
        local now = random(3) == 1 and clock or nil
        local actual = ChannelMessageStore.GetLatest(state, lookup, now)
        local expected = modelGet(model, lookup, now)
        assert(
          (actual and actual.text) == (expected and expected.text),
          context .. " lookup " .. lookup .. ": " .. tostring(actual and actual.text) .. " ~= " .. tostring(expected and expected.text)
        )
      else
        state = ChannelMessageStore.Restore(state, config, clock)
        modelRestore(model, clock)
      end
      assert(state.entryCount == model.count, context .. " count " .. tostring(state.entryCount) .. " ~= " .. model.count)
    end
  end
end
