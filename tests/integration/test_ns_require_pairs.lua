-- Every `ns.X or require("WhisperMessenger.P")` fallback in a shipped file
-- must name a module P that assigns `ns.X`. A typo in either half still
-- passes in tests (require succeeds) but leaves `ns.X` nil in game, where
-- the fallback require throws.
--
-- A bare `ns.X` read with no fallback (most sit inside functions, reading a
-- module that loads later) has nothing to pair with, so it is checked against
-- every shipped file instead: some file must assign `ns.X`.
local PREFIX = "WhisperMessenger."

-- The release build renames locals, so `ns` can be any identifier.
local PAIR_PATTERNS = {
  '[%a_][%w_]*%.([%w_]+)%s*or%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
  '[%a_][%w_]*%.([%w_]+)%s*or%s*%(%s*type%(require%)%s*==%s*"function"%s*and%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
  '[%a_][%w_]*%.([%w_]+)%s*or%s*%(%s*rawget%(%s*_G%s*,%s*"require"%s*%)%s*and%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)',
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
  for rawLine in io.lines("WhisperMessenger.toc") do
    local line = string.gsub(rawLine, "%s+$", "")
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
  return string.find("\n" .. source, "\n[%a_][%w_]*%." .. key .. "%s*=") ~= nil
end

-- Every shipped file opens with `local addonName, ns = ...`; the release
-- build renames both, so the namespace is whatever the second name is.
local NAMESPACE_HEADER = "^%s*local%s+[%a_][%w_]*%s*,%s*([%a_][%w_]*)%s*=%s*%.%.%."

-- Index of the last character of the quoted string that opens at start.
local function quotedEnd(source, start, quote)
  local pos = start + 1
  while true do
    local hit = string.find(source, "[\\" .. quote .. "]", pos)
    if not hit then
      return #source
    end
    if string.sub(source, hit, hit) == quote then
      return hit
    end
    pos = hit + 2
  end
end

-- Index of the last character of the comment or string literal that opens at
-- start, or nil when the character there is plain code.
local function literalEnd(source, start)
  local char = string.sub(source, start, start)
  if char == '"' or char == "'" then
    return quotedEnd(source, start, char)
  end
  local isComment = string.sub(source, start, start + 1) == "--"
  if char == "-" and not isComment then
    return nil
  end
  local level = string.match(source, "^%[(=*)%[", isComment and start + 2 or start)
  if level then
    local _, stop = string.find(source, "]" .. level .. "]", start, true)
    return stop or #source
  end
  if not isComment then
    return nil
  end
  return (string.find(source, "\n", start, true) or #source + 1) - 1
end

-- The source with comments and string literals blanked and line breaks kept:
-- a key named only in a comment is not a read, and the release build strips
-- comments, so both builds must see the same reads.
local function codeOnly(source)
  local parts = {}
  local pos = 1
  local start = string.find(source, "[%-\"'%[]", pos)
  while start do
    local stop = literalEnd(source, start)
    if stop then
      local lineBreaks = string.gsub(string.sub(source, start, stop), "[^\n]+", "")
      parts[#parts + 1] = string.sub(source, pos, start - 1) .. " " .. lineBreaks
      pos = stop + 1
    else
      parts[#parts + 1] = string.sub(source, pos, start)
      pos = start + 1
    end
    start = string.find(source, "[%-\"'%[]", pos)
  end
  parts[#parts + 1] = string.sub(source, pos)
  return table.concat(parts)
end

local function lineAt(code, at)
  local _, lineBreaks = string.gsub(string.sub(code, 1, at), "\n", "")
  return lineBreaks + 1
end

-- Where the declared names start after `local`, `local function`, `for` and
-- in a function's parameter list.
local DECLARATIONS = {
  "%f[%w_]local%f[^%w_]()",
  "%f[%w_]local%s+function%f[^%w_]()",
  "%f[%w_]for%f[^%w_]()",
  "%f[%w_]function%f[^%w_][%s%w_%.:]*%(()",
}

-- Does the name list that opens at pos (`a, b, c`) hold name?
local function nameListHolds(code, pos, name)
  while pos do
    local found, stop = string.match(code, "^%s*([%a_][%w_]*)()", pos)
    if found == name then
      return true
    end
    pos = found and string.match(code, "^%s*,()", stop)
  end
  return false
end

-- Position of the first declaration of name at or after from, or one past
-- the end of the code when there is none.
local function firstDeclaration(code, name, from)
  local first = #code + 1
  for _, pattern in ipairs(DECLARATIONS) do
    local _, _, namesAt = string.find(code, pattern, from)
    while namesAt and namesAt < first do
      if nameListHolds(code, namesAt, name) then
        first = namesAt
      end
      _, _, namesAt = string.find(code, pattern, namesAt)
    end
  end
  return first
end

-- Sorts every `ns.<Key>` in the file's code into use.assigned (`ns.Key =`)
-- or use.reads (everything else, the fallback pairs included).
--
-- The release build hands a local's name to another local wherever the first
-- is not needed, so past the first place the namespace's name is declared
-- again `name.Key` may be a field of some other table. Reads count only up
-- to there. Shipped source never declares `ns` twice (luacheck rejects
-- shadowing), so in source every read counts. Assignments count everywhere:
-- a stray extra key can hide a problem but never invent one.
local function scanNamespaceUse(file, source, use)
  local code = codeOnly(source)
  local _, headerEnd, namespace = string.find(code, NAMESPACE_HEADER)
  assert(namespace, file .. ": no `local addonName, ns = ...` header")
  local redeclaredAt = firstDeclaration(code, namespace, headerEnd)
  for at, key, operator in string.gmatch(code, "()%f[%w_]" .. namespace .. "%.([%a_][%w_]*)%s*(=?=?)") do
    local before = string.sub(code, at - 1, at - 1)
    -- `x.ns.Key` is a field that only shares the namespace's name; `x..ns.Key`
    -- is a concatenation, which the release build writes without spaces.
    local isField = before == ":" or (before == "." and string.sub(code, at - 2, at - 2) ~= ".")
    if not isField then
      if operator == "=" then
        use.assigned[key] = true
      elseif at < redeclaredAt then
        use.reads[#use.reads + 1] = { file = file, key = key, code = code, at = at }
      end
    end
  end
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

  local use = { reads = {}, assigned = {} }
  for _, file in ipairs(files) do
    scanNamespaceUse(file, readFile(file), use)
  end

  local assignedCount = 0
  for _ in pairs(use.assigned) do
    assignedCount = assignedCount + 1
  end
  local unassigned = {}
  for _, read in ipairs(use.reads) do
    if not use.assigned[read.key] then
      unassigned[#unassigned + 1] = read.file .. ":" .. lineAt(read.code, read.at) .. ": ns." .. read.key
    end
  end

  assert(#use.reads > 1000, "expected to find the ns reads, found " .. #use.reads)
  assert(assignedCount > 500, "expected to find the assigned ns keys, found " .. assignedCount)
  assert(
    #unassigned == 0,
    "ns reads of a key that no shipped file assigns ("
      .. #use.reads
      .. " reads, "
      .. assignedCount
      .. " assigned keys):\n"
      .. table.concat(unassigned, "\n")
  )
end
