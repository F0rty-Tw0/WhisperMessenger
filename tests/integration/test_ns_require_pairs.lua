-- Every `ns.X or require("WhisperMessenger.P")` fallback in a shipped file
-- must name a module P that assigns `ns.X`. A typo in either half still
-- passes in tests (require succeeds) but leaves `ns.X` nil in game, where
-- the fallback require throws.
local PREFIX = "WhisperMessenger."

local PAIR_PATTERNS = {
  'ns%.([%w_]+)%s*or%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
  'ns%.([%w_]+)%s*or%s*%(%s*type%(require%)%s*==%s*"function"%s*and%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
  'ns%.([%w_]+)%s*or%s*%(%s*rawget%(%s*_G%s*,%s*"require"%s*%)%s*and%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
}

local function readFile(path)
  local handle = io.open(path, "rb")
  if not handle then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function shippedFiles()
  local files = {}
  for line in io.lines("WhisperMessenger.toc") do
    line = string.gsub(line, "%s+$", "")
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and string.match(line, "%.lua$") then
      files[#files + 1] = line
    end
  end
  return files
end

-- Module "UI.Theme" lives in UI/Theme.lua, or in UI/Theme/init.lua, which
-- only forwards to the real file with `return require(...)`.
local function resolveModulePath(moduleName)
  local base = string.gsub(moduleName, "%.", "/")
  local direct = base .. ".lua"
  if readFile(direct) then
    return direct
  end
  local initPath = base .. "/init.lua"
  local initSource = readFile(initPath)
  if not initSource then
    return nil
  end
  local forwarded = string.match(initSource, 'return%s+require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)')
  if forwarded then
    return resolveModulePath(forwarded)
  end
  return initPath
end

local function assignsKey(source, key)
  return string.find("\n" .. source, "\nns%." .. key .. "%s*=") ~= nil
end

return function()
  local files = shippedFiles()
  assert(#files > 300, "expected the TOC to list the shipped files, got " .. #files)

  local pairCount = 0
  local problems = {}
  for _, file in ipairs(files) do
    local source = assert(readFile(file), "TOC lists a missing file: " .. file)
    for _, pattern in ipairs(PAIR_PATTERNS) do
      for key, moduleName in string.gmatch(source, pattern) do
        pairCount = pairCount + 1
        local target = resolveModulePath(moduleName)
        local targetSource = target and readFile(target)
        if not targetSource then
          problems[#problems + 1] = file .. ": ns." .. key .. " -> " .. PREFIX .. moduleName .. " (no such file)"
        elseif not assignsKey(targetSource, key) then
          problems[#problems + 1] = file .. ": ns." .. key .. " -> " .. target .. " (never assigns ns." .. key .. ")"
        end
      end
    end
  end

  assert(pairCount > 1000, "expected to find the ns/require fallback pairs, found " .. pairCount)
  assert(#problems == 0, "mismatched ns/require pairs:\n" .. table.concat(problems, "\n"))
end
