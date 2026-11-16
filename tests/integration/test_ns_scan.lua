-- Pins what tests/helpers/ns_scan.lua counts as a read of a namespace key.
-- test_ns_require_pairs.lua runs that scan over the shipped files, where a
-- rule that stops matching just finds fewer reads and stays green.
local NsScan = require("tests.helpers.ns_scan")

-- A shipped file as written, and as the release build rewrites it: locals
-- renamed, spaces dropped. Both assign `Present` and nothing else.
local SOURCE = "local addonName, ns = ...\nns.Present = {}\n"
local MINIFIED = "local l,h=...\nh.Present={}\n"

local MISSING = "fixture:3: ns.Missing"
local LOADER_KEY = "fixture:3: ns.Missing (module loader key)"
local NONE = ""

local CASES = {
  { source = SOURCE .. "local a = ns.Missing", reported = MISSING },
  { source = SOURCE .. "local a = ns.Present", reported = NONE },
  { source = SOURCE .. "local a = x..ns.Missing", reported = MISSING },
  { source = SOURCE .. 'local a = "a"..ns.Missing', reported = MISSING },
  { source = MINIFIED .. 'local a="a"..h.Missing', reported = MISSING },
  { source = SOURCE .. "local a = t.ns.Field", reported = NONE },
  { source = SOURCE .. "local a = t:ns().Field", reported = NONE },
  { source = SOURCE .. "-- ns.Missing", reported = NONE },
  { source = SOURCE .. 'local a = "ns.Missing"', reported = NONE },

  -- `ns["Key"]` is the same read and the same assignment as `ns.Key`.
  { source = SOURCE .. 'local a = ns["Missing"]', reported = MISSING },
  { source = MINIFIED .. "local a=h['Missing']", reported = MISSING },
  { source = SOURCE .. 'ns["Made"] = {}\nlocal a = ns.Made', reported = NONE },
  { source = SOURCE .. 'local a = t.ns["Field"]', reported = NONE },
  { source = SOURCE .. "local a = ns[key]", reported = NONE },

  -- The loader returns `ns.Key` for the key it is handed.
  { source = SOURCE .. 'local a = loadModule("p", "Missing")', reported = LOADER_KEY },
  { source = SOURCE .. 'local a = loadModule("p", "Present")', reported = NONE },
  { source = SOURCE .. 'local a = deps.loadModule(path, "Missing")', reported = LOADER_KEY },
  { source = SOURCE .. 'local a = Loader.LoadModule(join("p", name), "Missing")', reported = LOADER_KEY },
  { source = MINIFIED .. "local a=e.loadModule(t,'Missing')", reported = LOADER_KEY },
  { source = SOURCE .. '-- loadModule("p", "Missing")', reported = NONE },
  { source = SOURCE .. [[local a = "loadModule(p, 'Missing')"]], reported = NONE },
  { source = SOURCE .. 'local a = loadModule("Missing", key)', reported = NONE },

  -- The release build renames the local the loader is called through, so
  -- there a module path with a key after it is all that marks the call. The
  -- same pair counts when it is handed to a function that calls the loader.
  { source = MINIFIED .. "local t=a('WhisperMessenger.Util.P','Missing')", reported = LOADER_KEY },
  { source = SOURCE .. 'resolve(current, "Present", loadModule, "WhisperMessenger.Util.P", "Missing")', reported = LOADER_KEY },
  -- Named call and path pair at once: the key is still reported once.
  { source = SOURCE .. 'local a = loadModule("WhisperMessenger.Util.P", "Missing")', reported = LOADER_KEY },
  { source = SOURCE .. 'local a = load("WhisperMessenger.Util.P", "Present")', reported = NONE },
  { source = SOURCE .. 'local a = load("WhisperMessenger.Util.P", key)', reported = NONE },
  { source = SOURCE .. '-- load("WhisperMessenger.Util.P", "Missing")', reported = NONE },
}

local function reportedReads(source)
  local use = NsScan.newUse()
  NsScan.scan("fixture", source, use)
  return table.concat(NsScan.unassigned(use), "\n")
end

return function()
  for _, case in ipairs(CASES) do
    local reported = reportedReads(case.source)
    assert(reported == case.reported, string.format("%s\nexpected %q, got %q", case.source, case.reported, reported))
  end
end
