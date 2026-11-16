-- Finds every read and assignment of a namespace key (`ns.Key`) in one
-- shipped file's source, for tests/integration/test_ns_require_pairs.lua.
--
-- The release build strips comments, renames locals and drops spaces before
-- the tests run again, so nothing here may rely on a local's name or on
-- spacing.

local NsScan = {}

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

-- Two copies of the source, each character still at its own position and
-- line: `code` has comments and string literals blanked, `text` comments
-- only. A key named only in a comment is not a read, and the release build
-- strips comments, so both builds must see the same reads. Names are looked
-- up in `code`, so a string that merely spells one is not a match; `text`
-- is for reading a string literal that `code` has located.
local function blankLiterals(source)
  local code, text = {}, {}
  local pos = 1
  local start = string.find(source, "[%-\"'%[]", pos)
  while start do
    local stop = literalEnd(source, start)
    local plain = string.sub(source, pos, stop and start - 1 or start)
    local literal = stop and string.sub(source, start, stop) or ""
    local blank = string.gsub(literal, "[^\n]", " ")
    local isComment = string.sub(literal, 1, 2) == "--"
    code[#code + 1] = plain .. blank
    text[#text + 1] = plain .. (isComment and blank or literal)
    pos = (stop or start) + 1
    start = string.find(source, "[%-\"'%[]", pos)
  end
  local rest = string.sub(source, pos)
  return table.concat(code) .. rest, table.concat(text) .. rest
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

-- Is the name at this position a field of some other table? `x.ns` is a
-- field that only shares the name; `x..ns` is a concatenation, which the
-- release build writes without spaces.
local function isFieldAt(code, at)
  local before = string.sub(code, at - 1, at - 1)
  return before == ":" or (before == "." and string.sub(code, at - 2, at - 2) ~= ".")
end

-- What follows the `[` of `ns["Key"]`: the key, then `=` when it is assigned.
local INDEXED_KEY = "^%s*[\"']([%a_][%w_]*)[\"']%s*%]%s*(=?=?)"

-- Sorts every `ns.<Key>` and `ns["<Key>"]` in the file into use.assigned
-- (`ns.Key =`) or use.reads (everything else, the fallback pairs included).
--
-- The release build hands a local's name to another local wherever the first
-- is not needed, so past the first place the namespace's name is declared
-- again `name.Key` may be a field of some other table. Reads count only up
-- to there. Shipped source never declares `ns` twice (luacheck rejects
-- shadowing), so in source every read counts. Assignments count everywhere:
-- a stray extra key can hide a problem but never invent one.
local function scanNamespaceKeys(file, code, text, use)
  local _, headerEnd, namespace = string.find(code, NAMESPACE_HEADER)
  assert(namespace, file .. ": no `local addonName, ns = ...` header")
  local redeclaredAt = firstDeclaration(code, namespace, headerEnd)
  local function note(at, key, operator)
    if isFieldAt(code, at) then
      return
    end
    if operator == "=" then
      use.assigned[key] = true
    elseif at < redeclaredAt then
      use.reads[#use.reads + 1] = { file = file, key = key, code = code, at = at }
    end
  end
  for at, key, operator in string.gmatch(code, "()%f[%w_]" .. namespace .. "%.([%a_][%w_]*)%s*(=?=?)") do
    note(at, key, operator)
  end
  for at, keyAt in string.gmatch(code, "()%f[%w_]" .. namespace .. "%s*%[()") do
    local key, operator = string.match(text, INDEXED_KEY, keyAt)
    if key then
      note(at, key, operator)
    end
  end
end

-- The loader hands back `ns.Key` for `loadModule(path, "Key")`, so that key
-- is a read of the namespace too. Two shapes find it, because the release
-- build renames the local most calls go through (`a("WhisperMessenger.P","Key")`)
-- and keeps only field names (`deps.loadModule`, `Loader.LoadModule`):
--
-- a call of the loader by name, whatever the path argument is,
local LOADER_CALL = "%f[%w_][lL]oadModule%s*()%b()()"
-- which ends in a string literal (`, "Key")`, with where the literal opens);
local LAST_ARGUMENT_KEY = ",%s*()[\"']([%a_][%w_]*)[\"']%s*%)$"
-- and a module path with a key right after it, whatever they are handed to.
local PATH_THEN_KEY = "[\"']WhisperMessenger%.[%w_%.]+[\"']%s*,%s*()[\"']([%a_][%w_]*)[\"']"

-- Adds every loader key in the file to use.reads, once each.
local function scanLoaderKeys(file, code, text, use)
  local seen = {}
  local function note(keyAt, key)
    if not seen[keyAt] then
      seen[keyAt] = true
      use.loaderKeys = use.loaderKeys + 1
      use.reads[#use.reads + 1] = { file = file, key = key, code = code, at = keyAt, isLoaderKey = true }
    end
  end
  -- The call is found in `code`, where a bracket inside a string cannot
  -- unbalance the argument list; the key is then read from `text`.
  for open, close in string.gmatch(code, LOADER_CALL) do
    -- Position captures are numbers; LuaLS types every gmatch capture as a string.
    ---@diagnostic disable-next-line: param-type-mismatch
    local keyOffset, key = string.match(string.sub(text, open, close - 1), LAST_ARGUMENT_KEY)
    if key then
      note(open + keyOffset - 1, key)
    end
  end
  for keyAt, key in string.gmatch(text, PATH_THEN_KEY) do
    note(keyAt, key)
  end
end

function NsScan.newUse()
  return { reads = {}, assigned = {}, loaderKeys = 0 }
end

-- Adds one shipped file's reads and assignments of namespace keys to use.
function NsScan.scan(file, source, use)
  local code, text = blankLiterals(source)
  scanNamespaceKeys(file, code, text, use)
  scanLoaderKeys(file, code, text, use)
end

-- One `file:line: ns.Key` line per read of a key that nothing assigns.
function NsScan.unassigned(use)
  local lines = {}
  for _, read in ipairs(use.reads) do
    if not use.assigned[read.key] then
      local how = read.isLoaderKey and " (module loader key)" or ""
      lines[#lines + 1] = read.file .. ":" .. lineAt(read.code, read.at) .. ": ns." .. read.key .. how
    end
  end
  return lines
end

return NsScan
