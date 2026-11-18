-- A production runtime always carries both restriction predicates
-- (RuntimeFactory sets defaults, Bootstrap.Initialize points them at the
-- restriction instance), so production code calls them without a guard.
-- Hand-built test runtimes get the same two fields here. A predicate the test
-- already set is kept; a missing one answers false.
local RestrictionPredicates = {}

local function returnFalse()
  return false
end

function RestrictionPredicates.Add(runtime)
  runtime.isCompetitiveContent = runtime.isCompetitiveContent or returnFalse
  runtime.isMythicLockdown = runtime.isMythicLockdown or returnFalse
  return runtime
end

return RestrictionPredicates
