local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local Initials = ns.Initials or require("WhisperMessenger.Util.Initials")

-- Rail-only contact avatar: the row's own class icon (same art, shape and
-- size as the full list), dimmed, with one or two letters of the shown name
-- in white on top. The status dot and unread badge keep their corners.
local RailAvatar = {}

-- Brightness of the class art under the initials.
local DIMMED_ART = 0.6
local INITIALS_COLOR = { 1, 1, 1, 1 }
-- Dark edge so the white letters read on bright art (priest, rogue).
local INITIALS_SHADOW = { 0, 0, 0, 1 }
local INITIALS_SHADOW_OFFSET = 1

-- r, g, b of a class's colour, or nil for an unknown class.
function RailAvatar.ClassColor(classTag)
  local classColors = _G.RAID_CLASS_COLORS
  local color = classTag and classColors and classColors[string.upper(classTag)]
  if color and color.r then
    return color.r, color.g, color.b
  end
  return nil
end

-- The label lives on the icon frame: a child frame always draws above the
-- row's own regions, so text on the row would sit under the icon art.
local function ensure(row)
  if row.railAvatar then
    return row.railAvatar
  end
  local host = row.classIconFrame or row
  local label = host:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
  label:SetPoint("CENTER", host, "CENTER", 0, 0)
  label:SetTextColor(INITIALS_COLOR[1], INITIALS_COLOR[2], INITIALS_COLOR[3], INITIALS_COLOR[4])
  if label.SetShadowColor then
    label:SetShadowColor(INITIALS_SHADOW[1], INITIALS_SHADOW[2], INITIALS_SHADOW[3], INITIALS_SHADOW[4])
  end
  if label.SetShadowOffset then
    label:SetShadowOffset(INITIALS_SHADOW_OFFSET, -INITIALS_SHADOW_OFFSET)
  end
  row.railAvatar = { label = label }
  return row.railAvatar
end

-- The player's nickname wins over the contact's own (formatted) name. The
-- class art itself was set by the bind and is only dimmed here.
function RailAvatar.update(row, item)
  local avatar = ensure(row)
  if row.classIcon then
    row.classIcon:SetVertexColor(DIMMED_ART, DIMMED_ART, DIMMED_ART, 1)
  end
  local name = item.nickname or DisplayName.Format(item.displayName)
  if avatar.name ~= name then
    avatar.name = name
    avatar.label:SetText(Initials.FromName(name))
  end
  avatar.label:Show()
end

-- Drops the initials and shows the art at full brightness again.
function RailAvatar.hide(row)
  if row.railAvatar then
    row.railAvatar.label:Hide()
  end
  if row.classIcon then
    row.classIcon:SetVertexColor(1, 1, 1, 1)
  end
end

ns.ContactsListRailAvatar = RailAvatar
return RailAvatar
