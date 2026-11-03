local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Font families other addons register with LibSharedMedia-3.0.
local FontFamilies = {}

local function sharedMedia()
  local libStub = _G and _G.LibStub
  if type(libStub) ~= "table" then
    return nil
  end

  local ok, lsm = pcall(libStub, "LibSharedMedia-3.0", true)
  if ok and type(lsm) == "table" then
    return lsm
  end
  return nil
end

function FontFamilies.FetchPath(name)
  if type(name) ~= "string" or name == "" or name == "default" or name == "system" or name == "morpheus" then
    return nil
  end

  local lsm = sharedMedia()
  if not lsm or type(lsm.Fetch) ~= "function" then
    return nil
  end

  local ok, path = pcall(lsm.Fetch, lsm, "font", name, true)
  if ok and type(path) == "string" and path ~= "" then
    return path
  end
  return nil
end

function FontFamilies.List()
  local families = { { key = "default", label = "Default" } }
  local lsm = sharedMedia()
  if not lsm or type(lsm.List) ~= "function" then
    return families
  end

  local ok, names = pcall(lsm.List, lsm, "font")
  if not ok or type(names) ~= "table" then
    return families
  end

  local unique = {}
  local sortedNames = {}
  for _, name in ipairs(names) do
    if type(name) == "string" and name ~= "" and name ~= "default" and name ~= "system" and name ~= "morpheus" and not unique[name] then
      unique[name] = true
      sortedNames[#sortedNames + 1] = name
    end
  end

  table.sort(sortedNames, function(a, b)
    local lowerA, lowerB = string.lower(a), string.lower(b)
    if lowerA == lowerB then
      return a < b
    end
    return lowerA < lowerB
  end)

  for _, name in ipairs(sortedNames) do
    families[#families + 1] = { key = name, label = name }
  end
  return families
end

ns.ThemeFontFamilies = FontFamilies
return FontFamilies
