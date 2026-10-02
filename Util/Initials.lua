local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One or two letters of a shown name for a contact avatar. UTF-8 safe in
-- Lua 5.1: characters are taken whole, never split mid-byte.
local Initials = {}

-- One UTF-8 character: a lead byte plus its continuation bytes.
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
-- CJK and Hangul characters take 3+ bytes; one fills the avatar.
local WIDE_CHAR_BYTES = 3

-- Only ASCII changes case; other scripts keep the character as written.
local function upperAscii(char)
  if char ~= nil and #char == 1 then
    return string.upper(char)
  end
  return char
end

local function firstChar(word)
  return string.match(word, "^" .. UTF8_CHAR)
end

local function secondChar(word)
  local first = firstChar(word)
  return string.match(word, "^" .. UTF8_CHAR, #first + 1)
end

-- "Jaina" -> "JA", "Big Bob" -> "BB", "李小龙" -> "李". A realm suffix
-- ("-Realm") or BattleTag number ("#1234") is not part of the name.
function Initials.FromName(name)
  if type(name) ~= "string" then
    return ""
  end
  local base = string.match(name, "^[^%-#]*")
  local first, second = string.match(base, "^%s*(%S+)%s+(%S+)")
  if first == nil then
    first = string.match(base, "^%s*(%S+)")
  end
  if first == nil then
    return ""
  end

  local lead = firstChar(first)
  if #lead >= WIDE_CHAR_BYTES then
    return lead
  end
  local follow = second and firstChar(second) or secondChar(first)
  return upperAscii(lead) .. (upperAscii(follow) or "")
end

ns.Initials = Initials
return Initials
