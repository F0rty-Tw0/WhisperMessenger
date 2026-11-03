local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local gsub = string.gsub

-- Chat text without WoW's escape codes: colors, textures and atlases go,
-- a hyperlink keeps its "[Label]".
local PlainText = {}

function PlainText.Strip(text)
  local plain = gsub(text, "|H.-|h(.-)|h", "%1")
  plain = gsub(plain, "|c%x%x%x%x%x%x%x%x", "")
  plain = gsub(plain, "|r", "")
  plain = gsub(plain, "|T.-|t", "")
  plain = gsub(plain, "|A.-|a", "")
  return plain
end

ns.PlainText = PlainText
return PlainText
