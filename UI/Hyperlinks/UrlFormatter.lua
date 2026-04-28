local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UrlFormatter = {}

local URL_CHARACTER_CLASS = "[%w%-%._~:/%?#%[%]@!$&'()*+,;=%%]"
local HTTP_URL_PATTERN = "[Hh][Tt][Tt][Pp][Ss]?://" .. URL_CHARACTER_CLASS .. "+"
local WWW_URL_PATTERN = "www%." .. URL_CHARACTER_CLASS .. "+"
local URL_TRAILING_PUNCTUATION = ".,!?:;)]}"
local EXTERNAL_LINK_TYPE = "url"

UrlFormatter.EXTERNAL_LINK_TYPE = EXTERNAL_LINK_TYPE

local function hasWordCharacterBefore(text, index)
  if index <= 1 then
    return false
  end

  local previousCharacter = string.sub(text, index - 1, index - 1)
  return string.find(previousCharacter, "[%w_]", 1) ~= nil
end

local function delimiterCount(value, delimiterPattern)
  local _, count = string.gsub(value, delimiterPattern, "")
  return count
end

local function shouldTrimTrailingDelimiter(value, suffix)
  if suffix == ")" then
    return delimiterCount(value, "%)") > delimiterCount(value, "%(")
  end
  if suffix == "]" then
    return delimiterCount(value, "%]") > delimiterCount(value, "%[")
  end
  if suffix == "}" then
    return delimiterCount(value, "%}") > delimiterCount(value, "%{")
  end

  return true
end

local function trimTrailingPunctuation(url)
  local trimmed = url
  local trailing = ""

  while #trimmed > 0 do
    local suffix = string.sub(trimmed, -1)
    if string.find(URL_TRAILING_PUNCTUATION, suffix, 1, true) == nil then
      break
    end
    if not shouldTrimTrailingDelimiter(trimmed, suffix) then
      break
    end

    trailing = suffix .. trailing
    trimmed = string.sub(trimmed, 1, -2)
  end

  return trimmed, trailing
end

local function findPatternWithBoundary(text, pattern, startIndex)
  local searchIndex = startIndex

  while true do
    local matchStart, matchEnd = string.find(text, pattern, searchIndex)
    if matchStart == nil then
      return nil
    end

    if not hasWordCharacterBefore(text, matchStart) then
      return matchStart, matchEnd
    end

    searchIndex = matchStart + 1
  end
end

local function normalizeExternalUrl(rawUrl, needsScheme)
  if type(rawUrl) ~= "string" or rawUrl == "" then
    return nil
  end

  local urlWithoutPunctuation, trailing = trimTrailingPunctuation(rawUrl)
  if urlWithoutPunctuation == "" then
    return nil
  end

  local normalizedUrl = needsScheme and ("https://" .. urlWithoutPunctuation) or urlWithoutPunctuation
  local lowered = string.lower(normalizedUrl)
  if string.match(lowered, "^https?://") == nil then
    return nil
  end

  if string.find(normalizedUrl, "|", 1, true) ~= nil then
    return nil
  end

  return normalizedUrl, urlWithoutPunctuation, trailing
end

local function buildExternalUrlHyperlink(rawUrl, needsScheme)
  local normalizedUrl, displayUrl, trailing = normalizeExternalUrl(rawUrl, needsScheme)
  if normalizedUrl == nil then
    return rawUrl
  end

  local hyperlink = "|cff71d5ff|H" .. EXTERNAL_LINK_TYPE .. ":" .. normalizedUrl .. "|h" .. displayUrl .. "|h|r"
  return hyperlink .. (trailing or "")
end

local function findNextUrlCandidate(text, startIndex)
  local httpStart, httpEnd = findPatternWithBoundary(text, HTTP_URL_PATTERN, startIndex)
  local wwwStart, wwwEnd = findPatternWithBoundary(text, WWW_URL_PATTERN, startIndex)

  if httpStart == nil and wwwStart == nil then
    return nil
  end

  if httpStart ~= nil and (wwwStart == nil or httpStart <= wwwStart) then
    return httpStart, httpEnd, false
  end

  return wwwStart, wwwEnd, true
end

function UrlFormatter.FormatPlainSegment(segment)
  if segment == "" then
    return ""
  end

  local output = {}
  local cursor = 1

  while cursor <= #segment do
    local startIndex, endIndex, needsScheme = findNextUrlCandidate(segment, cursor)
    if startIndex == nil then
      table.insert(output, string.sub(segment, cursor))
      break
    end

    if startIndex > cursor then
      table.insert(output, string.sub(segment, cursor, startIndex - 1))
    end

    local rawUrl = string.sub(segment, startIndex, endIndex)
    table.insert(output, buildExternalUrlHyperlink(rawUrl, needsScheme))
    cursor = endIndex + 1
  end

  return table.concat(output)
end

function UrlFormatter.ExtractExternalUrlFromLink(link)
  if type(link) ~= "string" then
    return nil
  end

  local linkType, payload = string.match(link, "^(.-):(.*)$")
  if type(linkType) ~= "string" or type(payload) ~= "string" then
    return nil
  end

  if string.lower(linkType) ~= EXTERNAL_LINK_TYPE or payload == "" then
    return nil
  end

  local normalizedUrl = payload
  if string.match(string.lower(normalizedUrl), "^https?://") == nil then
    normalizedUrl = "https://" .. normalizedUrl
  end

  if string.match(string.lower(normalizedUrl), "^https?://") == nil then
    return nil
  end

  return normalizedUrl
end

ns.UIHyperlinksUrlFormatter = UrlFormatter
return UrlFormatter
