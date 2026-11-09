-- Stand-ins for Blizzard tables and frames that record every field write.
-- Addon code must never assign into Blizzard's tables, frames or mixins, even
-- to write Blizzard's own function back: the write taints that slot. Wrap a
-- fake in Wrap and pass the list that collects "label.field" for each write.
-- A fake hooksecurefunc installs its post-hook into Backing(proxy), a plain
-- rawset on the real table that is never recorded.
local WriteWatch = {}

local backings = setmetatable({}, { __mode = "k" })

function WriteWatch.Wrap(label, target, writes)
  local proxy = setmetatable({}, {
    __index = target,
    __newindex = function(_, key, value)
      table.insert(writes, label .. "." .. tostring(key))
      target[key] = value
    end,
  })
  backings[proxy] = target
  return proxy
end

function WriteWatch.Backing(candidate)
  return backings[candidate] or candidate
end

return WriteWatch
