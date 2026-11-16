-- The one place tests set the restricted-content flags. Today the flags are
-- three fields on the Bootstrap table; when they move, only this file changes.
local RestrictionState = {}

RestrictionState.FIELDS = {
  mythic = "_inMythicContent",
  competitive = "_inCompetitiveContent",
  encounter = "_inEncounter",
}

-- flags: { mythic =, competitive =, encounter = }. All three are written, so
-- a flag left out is cleared.
function RestrictionState.Set(Bootstrap, flags)
  flags = flags or {}
  for name, field in pairs(RestrictionState.FIELDS) do
    Bootstrap[field] = flags[name]
  end
end

return RestrictionState
