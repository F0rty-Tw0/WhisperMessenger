local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Builder = {}

function Builder.Rgb(r, g, b)
  return { r, g, b }
end

function Builder.WithAlpha(baseRgb, alpha)
  return { baseRgb[1], baseRgb[2], baseRgb[3], alpha }
end

function Builder.MakeDividerRoles(baseRgb, baseAlpha, strongAlpha, hoverRgb, hoverAlpha)
  return {
    divider = Builder.WithAlpha(baseRgb, baseAlpha),
    divider_strong = Builder.WithAlpha(baseRgb, strongAlpha),
    divider_hover = Builder.WithAlpha(hoverRgb, hoverAlpha),
  }
end

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
