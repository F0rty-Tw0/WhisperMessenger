-- Runs a test body as if on a given game flavor by flipping the shared
-- FlavorCompat flags, then restores them.
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local Flavor = {}

function Flavor.With(isRetail, isForever, fn)
  local savedRetail, savedForever = FlavorCompat.isRetail, FlavorCompat.isForever
  FlavorCompat.isRetail, FlavorCompat.isForever = isRetail, isForever
  local ok, err = pcall(fn)
  FlavorCompat.isRetail, FlavorCompat.isForever = savedRetail, savedForever
  if not ok then
    error(err, 0)
  end
end

return Flavor
