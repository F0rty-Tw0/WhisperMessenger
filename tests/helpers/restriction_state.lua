-- The one place tests set and read the restricted-content flags. They go
-- through the restriction instance of the given Bootstrap table (the real
-- module or a fake); a table without one gets one, as in production.
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local RestrictionState = {}

RestrictionState.NAMES = { "mythic", "competitive", "encounter" }

-- flags: { mythic =, competitive =, encounter = }. All three are written, so
-- a flag left out is cleared. Returns Bootstrap, so a fake can be built and
-- flagged in one expression.
function RestrictionState.Set(Bootstrap, flags)
  flags = flags or {}
  local restrictions = RestrictedActions.For(Bootstrap)
  for _, name in ipairs(RestrictionState.NAMES) do
    restrictions.setFlag(name, flags[name])
  end
  return Bootstrap
end

function RestrictionState.Flag(Bootstrap, name)
  return RestrictedActions.For(Bootstrap).flag(name)
end

-- The mythic suspend is one addon-wide state, so no Bootstrap is needed.
-- Tests that set it restore it with SetSuspended(saved) or SetSuspended(false).
function RestrictionState.SetSuspended(value)
  RestrictedActions.New().setSuspended(value)
end

function RestrictionState.Suspended()
  return RestrictedActions.IsSuspended()
end

return RestrictionState
