local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local gsub = string.gsub

-- A typed pipe arrives as "||"; park it so no code pattern reads past it.
local ESCAPED_PIPE = "||"
local PIPE_PLACEHOLDER = "\1"

-- Chat text without WoW's escape codes: colors, textures and atlases go,
-- a hyperlink keeps its "[Label]".
local PlainText = {}

function PlainText.Strip(text)
  local plain = gsub(text, ESCAPED_PIPE, PIPE_PLACEHOLDER)
  plain = gsub(plain, "|H.-|h(.-)|h", "%1")
  plain = gsub(plain, "|c%x%x%x%x%x%x%x%x", "")
  plain = gsub(plain, "|cn[^:|]*:", "")
  plain = gsub(plain, "|r", "")
  plain = gsub(plain, "|T.-|t", "")
  plain = gsub(plain, "|A.-|a", "")
  plain = gsub(plain, PIPE_PLACEHOLDER, ESCAPED_PIPE)
  return plain
end

ns.PlainText = PlainText
return PlainText
