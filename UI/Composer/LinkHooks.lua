local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LinkHooks = {}
local registeredLinkHooks = false
local linkedInputs = {}

local function canInsertLink(input)
  if input == nil or type(input.Insert) ~= "function" then
    return false
  end

  if type(input.HasFocus) == "function" and not input:HasFocus() then
    return false
  end

  if type(input.IsShown) == "function" and not input:IsShown() then
    return false
  end

  return true
end

local function tryInsertLink(link)
  if link == nil then
    return false
  end

  for _, input in ipairs(linkedInputs) do
    if canInsertLink(input) then
      input:Insert(link)
      return true
    end
  end

  return false
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  _G.hooksecurefunc("HandleModifiedItemClick", function(link)
    if _G._wmSuspended then
      return
    end
    tryInsertLink(link)
  end)

  local originalSetItemRef = _G.SetItemRef
  _G.hooksecurefunc("SetItemRef", function(link)
    if _G._wmSuspended then
      return
    end
    if link == nil then
      return
    end
    tryInsertLink(link)
  end)

  registeredLinkHooks = true
end

function LinkHooks.RegisterInput(input)
  table.insert(linkedInputs, 1, input)
  registerLinkHooks()
end

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
