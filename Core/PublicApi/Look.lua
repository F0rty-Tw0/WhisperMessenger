local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

-- GetLook(): WM's current look, so an addon panel can draw to match it.
-- Returns a new table each call: { hud = "off" | "classic" | "retail",
-- colors = { <key> = { r, g, b, a }, ... } }. hud is the style this session
-- runs (a change applies after /reload). colors holds copies of the keys in
-- LOOK_KEYS, read at call time so they follow theme switches; a key the
-- theme lacks is left out. Any internal error returns nil; it never throws.
local Look = {}

local LOOK_KEYS = {
  "bg_primary",
  "bg_secondary",
  "bg_header",
  "bg_input",
  "divider",
  "contacts_divider",
  "bg_contact_selected",
  "bg_contact_hover",
  "scrollbar",
  "scrollbar_hover",
}

local function read()
  local colors = {}
  for _, key in ipairs(LOOK_KEYS) do
    local color = Theme.COLORS[key]
    if color then
      colors[key] = { color[1], color[2], color[3], color[4] }
    end
  end
  return { hud = Hud.Style(), colors = colors }
end

function Look.Install(api, _runtime)
  api.GetLook = function()
    local ok, look = pcall(read)
    return ok and look or nil
  end
end

ns.PublicApiLook = Look
return Look
