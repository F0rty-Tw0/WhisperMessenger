-- Locates the Whispers / Groups segments of a TabToggle through its frame
-- tree (see tests/helpers/find_ui.lua) instead of handles on the return value.
-- Each segment button owns, in creation order: hover texture, label,
-- underline texture and the unread badge frame.

local FindUI = require("tests.helpers.find_ui")

local TabToggleParts = {}

local function segment(toggle, index)
  local btn = FindUI.ofType(toggle.frame, "Button")[index]
  local textures = FindUI.ofType(btn, "Texture")
  return {
    btn = btn,
    hover = textures[1],
    underline = textures[2],
    label = FindUI.ofType(btn, "FontString")[1],
    badge = FindUI.ofType(btn, "Frame")[1],
  }
end

function TabToggleParts.whispers(toggle)
  return segment(toggle, 1)
end

function TabToggleParts.groups(toggle)
  return segment(toggle, 2)
end

-- Bar textures, in creation order: top divider, bg fill, footer tint.
function TabToggleParts.divider(toggle)
  return FindUI.ofType(toggle.frame, "Texture")[1]
end

function TabToggleParts.footerTint(toggle)
  return FindUI.ofType(toggle.frame, "Texture")[3]
end

-- Unread badge circle and count of a badge frame.
function TabToggleParts.badgeBg(badge)
  return FindUI.ofType(badge, "Texture")[1]
end

function TabToggleParts.badgeLabel(badge)
  return FindUI.ofType(badge, "FontString")[1]
end

return TabToggleParts
