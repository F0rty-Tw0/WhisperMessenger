-- Baked patch notes must stay in sync with the shipped addon version.
local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  assert(FakeUI ~= nil, "expected fake UI harness to load")

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  local PatchNotes = ns.PatchNotes
  assert(type(PatchNotes) == "table", "expected ns.PatchNotes to be registered by the TOC")

  assert(
    type(PatchNotes.version) == "string" and string.match(PatchNotes.version, "^v%d+%.%d+%.%d+$") ~= nil,
    "expected a v-prefixed semver version, got " .. tostring(PatchNotes.version)
  )
  assert(
    PatchNotes.version == ns.Constants.VERSION,
    "expected patch notes version " .. tostring(PatchNotes.version) .. " to equal Constants.VERSION " .. tostring(ns.Constants.VERSION)
  )

  assert(type(PatchNotes.lines) == "table", "expected PatchNotes.lines table")
  assert(#PatchNotes.lines > 0, "expected at least one patch note line")
  for index, line in ipairs(PatchNotes.lines) do
    assert(type(line) == "string", "expected line " .. index .. " to be a string")
    assert(line ~= "", "expected line " .. index .. " to be non-empty")
  end
end
