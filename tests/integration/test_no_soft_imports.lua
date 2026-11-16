-- `ns.X or (type(require) == "function" and require(...)) or nil` yields nil
-- when the module is missing, so a load-order mistake becomes a silent
-- feature loss. Shipped files use the plain `ns.X or require(...)` form,
-- which fails loudly and is covered by test_toc_load_order.lua.

-- The release build renames locals, so `ns` can be any identifier.
local SOFT_IMPORT_PATTERN =
  '[%a_][%w_]*%.([%w_]+)%s*or%s*%(%s*type%(require%)%s*==%s*"function"%s*and%s*require%(%s*"WhisperMessenger%.([%w_%.]+)"%s*%)'

local function readFile(path)
  local handle = assert(io.open(path, "rb"), "TOC lists a missing file: " .. path)
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

local function test_shipped_files_have_no_soft_imports()
  local files = shippedFiles()
  assert(#files > 300, "expected the TOC to list the shipped files, got " .. #files)

  local problems = {}
  for _, file in ipairs(files) do
    for key, moduleName in string.gmatch(readFile(file), SOFT_IMPORT_PATTERN) do
      problems[#problems + 1] = file .. ": ns." .. key .. " -> WhisperMessenger." .. moduleName
    end
  end

  assert(#problems == 0, #problems .. " soft imports, use `ns.X or require(...)`:\n" .. table.concat(problems, "\n"))
end

return function()
  test_shipped_files_have_no_soft_imports()
end
