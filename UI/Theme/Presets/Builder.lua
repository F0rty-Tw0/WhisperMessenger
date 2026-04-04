local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Builder = {}

function Builder.CloneColor(color)
  return { color[1], color[2], color[3], color[4] }
end

function Builder.ClonePalette(palette)
  local copy = {}
  for key, color in pairs(palette) do
    copy[key] = Builder.CloneColor(color)
  end

  return copy
end

function Builder.BuildPreset(tokenRoles, roleSet)
  local preset = {}

  for token, role in pairs(tokenRoles) do
    local color = roleSet[role]
    if type(color) ~= "table" then
      error(("missing theme role '%s' for token '%s'"):format(tostring(role), tostring(token)))
    end
    preset[token] = Builder.CloneColor(color)
  end

  return preset
end

ns.ThemePresetsBuilder = Builder

return Builder
