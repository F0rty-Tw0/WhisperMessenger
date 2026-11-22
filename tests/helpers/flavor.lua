-- Runs a test body as if on a given game flavor by flipping the shared
-- FlavorCompat flags, then restores them.
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local Flavor = {}

-- isRetail, isForever of each flavor stub.
Flavor.ALL = {
  { name = "Retail", true, false },
  { name = "Forever", true, true },
  { name = "Classic", false, false },
}

function Flavor.With(isRetail, isForever, fn)
  local savedRetail, savedForever = FlavorCompat.isRetail, FlavorCompat.isForever
  FlavorCompat.isRetail, FlavorCompat.isForever = isRetail, isForever
  local ok, err = pcall(fn)
  FlavorCompat.isRetail, FlavorCompat.isForever = savedRetail, savedForever
  if not ok then
    error(err, 0)
  end
end

-- Runs fn with the game's gamepad UI check (InputUtil.IsGamepadUIEnabled)
-- answering on, then restores the real InputUtil.
function Flavor.WithPadUI(on, fn)
  local savedInputUtil = rawget(_G, "InputUtil")
  rawset(_G, "InputUtil", {
    IsGamepadUIEnabled = function()
      return on
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "InputUtil", savedInputUtil)
  if not ok then
    error(err, 0)
  end
end

return Flavor
