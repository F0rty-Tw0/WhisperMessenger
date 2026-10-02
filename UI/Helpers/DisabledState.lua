local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Shared disabled look: the target fades to ALPHA and a transparent cover on
-- top swallows clicks and explains why on hover. The owning control also
-- checks isEnabled() in its handlers, so scripted clicks are ignored too.
local DisabledState = {}

DisabledState.ALPHA = 0.4
local COVER_LEVEL_OFFSET = 10

local function showReason(cover, reason)
  local tooltip = _G.GameTooltip
  if not (reason and tooltip and tooltip.SetOwner) then
    return
  end
  tooltip:SetOwner(cover, "ANCHOR_TOP")
  tooltip:SetText(reason)
  tooltip:Show()
end

local function hideReason()
  if _G.GameTooltip and _G.GameTooltip.Hide then
    _G.GameTooltip:Hide()
  end
end

-- Returns { set(enabled, reason), isEnabled() }.
function DisabledState.Attach(factory, target)
  local enabled = true
  local reason = nil
  local cover = nil

  local function ensureCover()
    if cover then
      return cover
    end
    cover = factory.CreateFrame("Frame", nil, target)
    cover:SetAllPoints(target)
    if cover.SetFrameLevel and target.GetFrameLevel then
      cover:SetFrameLevel((target:GetFrameLevel() or 1) + COVER_LEVEL_OFFSET)
    end
    cover:EnableMouse(true)
    cover:SetScript("OnEnter", function()
      showReason(cover, reason)
    end)
    cover:SetScript("OnLeave", hideReason)
    return cover
  end

  local state = {}

  function state.isEnabled()
    return enabled
  end

  function state.set(nextEnabled, nextReason)
    enabled = nextEnabled ~= false
    reason = nextReason
    if target.SetAlpha then
      target:SetAlpha(enabled and 1 or DisabledState.ALPHA)
    end
    if enabled then
      if cover then
        cover:Hide()
      end
    else
      ensureCover():Show()
    end
  end

  return state
end

ns.UIHelpersDisabledState = DisabledState
return DisabledState
