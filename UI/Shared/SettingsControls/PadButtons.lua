local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- Small glyph Buttons beside a settings control (slider − / +, list ▲ / ▼)
-- that a controller can land on. The glyph is a game atlas texture, never
-- text. A button shows only while the game's pad UI is on; Refresh re-reads
-- the toggle for every button made so far. GamepadSettings hands each
-- _wmPadButton to the nav as a D-pad stop.
local PadButtons = {}

PadButtons.SIZE = 20
PadButtons.GAP = 4
PadButtons.ATLAS = {
  minus = "ui-hud-minimap-zoom-out",
  plus = "ui-hud-minimap-zoom-in",
  up = "minimal-scrollbar-arrow-top",
  down = "minimal-scrollbar-arrow-bottom",
}

-- button -> { shown = last applied state, onShownChanged = fn|nil }
local created = setmetatable({}, { __mode = "k" })

local function applyShown(button, entry)
  local shown = FlavorCompat.IsGamepadUIEnabled()
  button:SetShown(shown)
  local changed = entry.shown ~= shown
  entry.shown = shown
  if changed and entry.onShownChanged then
    entry.onShownChanged(shown)
  end
end

-- kind: "minus", "plus", "up" or "down". onClick() gets no arguments.
-- onShownChanged(shown), optional: once now, then on each flip.
function PadButtons.Create(factory, parent, kind, onClick, onShownChanged)
  local atlas = PadButtons.ATLAS[kind]
  if not atlas then
    error("PadButtons: unknown kind " .. tostring(kind))
  end
  local button = factory.CreateFrame("Button", nil, parent)
  button:SetSize(PadButtons.SIZE, PadButtons.SIZE)
  local glyph = button:CreateTexture(nil, "ARTWORK")
  glyph:SetAllPoints(button)
  glyph:SetAtlas(atlas)
  button:SetScript("OnClick", function()
    onClick()
  end)
  button._wmPadButton = true
  local entry = { onShownChanged = onShownChanged }
  created[button] = entry
  applyShown(button, entry)

  return button
end

function PadButtons.Refresh()
  for button, entry in pairs(created) do
    applyShown(button, entry)
  end
end

ns.SettingsControlsPadButtons = PadButtons

return PadButtons
