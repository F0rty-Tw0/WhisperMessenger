-- Runs fn(tbl) while _G[name] reads as an existing table but is not a raw
-- global, so any assignment to _G[name] is seen (as in game, where Blizzard
-- owns the table and an addon write taints it). Returns the number of
-- writes to name and the table.
local GlobalWriteSpy = {}

function GlobalWriteSpy.Writes(name, fn)
  local savedValue = rawget(_G, name)
  local savedMeta = getmetatable(_G)
  local existing = {}
  local writes = 0
  rawset(_G, name, nil)
  setmetatable(_G, {
    __index = function(_, key)
      if key == name then
        return existing
      end
      return nil
    end,
    __newindex = function(t, key, value)
      if key == name then
        writes = writes + 1
      end
      rawset(t, key, value)
    end,
  })
  local ok, err = pcall(fn, existing)
  setmetatable(_G, savedMeta)
  rawset(_G, name, savedValue)
  if not ok then
    error(err, 0)
  end
  return writes, existing
end

return GlobalWriteSpy
