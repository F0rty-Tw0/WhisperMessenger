local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")

local Hyperlinks = {}

local function resolveManualCopy()
  if type(ns.ChatBubbleContextMenuManualCopy) == "table" then
    return ns.ChatBubbleContextMenuManualCopy
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, "WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy")
    if ok and type(loaded) == "table" then
      return loaded
    end
  end

  return nil
end

local function copyExternalUrl(url)
  -- LaunchURL APIs are protected in addon context and trigger
  -- ADDON_ACTION_FORBIDDEN. Safe fallback is copy-to-clipboard.
  local manualCopy = resolveManualCopy()
  if type(manualCopy) == "table" and type(manualCopy.CopyText) == "function" then
    return manualCopy.CopyText(url) == true
  end

  return false
end

function Hyperlinks.FormatTextForDisplay(text)
  local value = QuestLinkClassic.Rewrite(tostring(text or ""))
  if value == "" then
    return ""
  end

  local output = {}
  local cursor = 1

  while cursor <= #value do
    local hyperlinkStart, hyperlinkEnd = string.find(value, "|H.-|h.-|h", cursor)
    if hyperlinkStart == nil then
      table.insert(output, UrlFormatter.FormatPlainSegment(string.sub(value, cursor)))
      break
    end

    if hyperlinkStart > cursor then
      table.insert(output, UrlFormatter.FormatPlainSegment(string.sub(value, cursor, hyperlinkStart - 1)))
    end

    table.insert(output, string.sub(value, hyperlinkStart, hyperlinkEnd))
    cursor = hyperlinkEnd + 1
  end

  return table.concat(output)
end

function Hyperlinks.HandleClick(link, text, button, sourceFrame)
  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    if copyExternalUrl(externalUrl) then
      return true
    end

    return false
  end

  if type(_G.SetItemRef) == "function" then
    _G.SetItemRef(link, text, button, sourceFrame)
    return true
  end

  return false
end

function Hyperlinks.HandleEnter(owner, link)
  local tooltip = _G.GameTooltip
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end

  tooltip:SetOwner(owner, "ANCHOR_CURSOR")

  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(externalUrl)
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
    return
  end

  if type(tooltip.SetHyperlink) == "function" then
    local ok = pcall(tooltip.SetHyperlink, tooltip, link)
    if ok then
      if type(tooltip.Show) == "function" then
        tooltip:Show()
      end
      return
    end
  end

  if type(tooltip.SetText) == "function" then
    tooltip:SetText(tostring(link or ""))
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

function Hyperlinks.HandleLeave()
  if type(_G.GameTooltip) == "table" and type(_G.GameTooltip.Hide) == "function" then
    _G.GameTooltip:Hide()
  end
end

ns.UIHyperlinks = Hyperlinks
return Hyperlinks
