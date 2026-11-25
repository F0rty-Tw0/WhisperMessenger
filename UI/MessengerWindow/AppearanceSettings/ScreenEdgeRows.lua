local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Options = ns.AppearanceSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.Options")
local ColorPicker = ns.AppearanceSettingsColorPicker or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ColorPicker")
local ScreenEdgeGlow = ns.ToggleIconScreenEdgeGlow or require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeGlow")

-- The Screen edge rows on Appearance, slotted into the window style toggles:
-- "Screen edge" under Compact window, "Glow color" under Edge glow. Glow color
-- is Theme (nothing saved: the active preset's accent), a theme preset's accent
-- or a custom colour from the game's picker.
local ScreenEdgeRows = {}

local SCREEN_EDGE_DEFAULT = "off"
local CUSTOM = "custom"
local THEME = "theme"
local SWATCH_SIZE = 10
local SWATCH_INSET = 6

local function createGlowColor(sel, panel, config, onChange)
  local saved = { edgeGlowColor = config.edgeGlowColor, edgeGlowCustom = config.edgeGlowCustom }
  local selector, swatch, before

  local function shownKey()
    local key = saved.edgeGlowColor
    if key == CUSTOM and not ScreenEdgeGlow.CustomColor(saved.edgeGlowCustom) then
      key = nil -- a broken saved colour glows in the active preset's accent
    end
    return key or THEME
  end

  local function paintSwatch()
    local c = ScreenEdgeGlow.CustomColor(saved.edgeGlowCustom)
    if c then
      swatch:SetColorTexture(c[1], c[2], c[3], 1)
      swatch:Show()
    else
      swatch:Hide()
    end
  end

  local function set(color, custom)
    saved.edgeGlowColor, saved.edgeGlowCustom = color, custom
    onChange("edgeGlowColor", color)
    onChange("edgeGlowCustom", custom)
    paintSwatch()
    selector.setSelected(shownKey())
  end

  local function openPicker()
    -- Custom clicked again while the picker is open keeps the choice from before it first opened.
    if not (before and ColorPicker.IsOpen()) then
      before = { edgeGlowColor = saved.edgeGlowColor, edgeGlowCustom = saved.edgeGlowCustom }
    end
    local c = ScreenEdgeGlow.ResolveColor(saved, Theme)
    local opened = ColorPicker.Open(c[1], c[2], c[3], function(r, g, b)
      set(CUSTOM, { r, g, b })
    end, function()
      local restore = before
      if not restore then
        return -- already cancelled
      end
      before = nil
      set(restore.edgeGlowColor, restore.edgeGlowCustom)
    end)
    if not opened then
      selector.setSelected(shownKey())
    end
  end

  selector = sel(Localization.Text("Glow color"), Options.BuildGlowColorOptions(), shownKey(), shownKey(), function(key)
    if key == CUSTOM then
      openPicker()
      return
    end
    if key == THEME then
      key = nil -- the custom colour stays saved for the swatch
    end
    saved.edgeGlowColor = key
    onChange("edgeGlowColor", key)
  end)

  local customButton = selector.buttons[#selector.buttons]
  swatch = customButton:CreateTexture(nil, "OVERLAY")
  swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
  swatch:SetPoint("RIGHT", customButton, "RIGHT", -SWATCH_INSET, 0)
  customButton.swatch = swatch
  paintSwatch()

  function selector.setLanguage()
    selector.label:SetText(Localization.Text("Glow color"))
    selector.setOptionsList(Options.BuildGlowColorOptions())
  end

  return panel:bind(selector, {
    type = "selector",
    reset = function()
      set(nil, nil)
    end,
  })
end

-- Slots a row into the toggle list between two toggles.
local function slotRow(row, above, below, gap)
  row:SetPoint("TOPLEFT", above.row, "BOTTOMLEFT", 0, gap)
  below.row:ClearAllPoints()
  below.row:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, gap)
end

-- sel: AppearanceSettings' ButtonSelector builder; toggles: the window style
-- toggles (Compact window, Edge glow, Window animation, ...). config.compactLayout
-- (nil reads as on, like the toggle) picks whether the rows start shown;
-- onLayoutChanged (optional) remeasures the page after a later show or hide.
function ScreenEdgeRows.Create(sel, panel, config, onChange, toggles, gap, onLayoutChanged)
  local screenEdge = panel:bind(
    sel(Localization.Text("Screen edge"), Options.BuildScreenEdgeOptions(), SCREEN_EDGE_DEFAULT, config.screenEdge or SCREEN_EDGE_DEFAULT, function(v)
      onChange("screenEdge", v)
    end),
    { type = "selector", key = "screenEdge", default = SCREEN_EDGE_DEFAULT }
  )
  slotRow(screenEdge.row, toggles[1], toggles[2], gap)
  local glowColor = createGlowColor(sel, panel, config, onChange)
  slotRow(glowColor.row, toggles[2], toggles[3], gap)
  local rows = { screenEdge.row, toggles[2].row, glowColor.row }

  -- The three rows do nothing without Compact window: hidden, the toggle below
  -- them moves up under Compact window.
  local function place(on)
    for _, row in ipairs(rows) do
      if on then
        row:Show()
      else
        row:Hide()
      end
    end
    local below = toggles[3].row
    below:ClearAllPoints()
    below:SetPoint("TOPLEFT", on and glowColor.row or toggles[1].row, "BOTTOMLEFT", 0, gap)
  end
  place(config.compactLayout ~= false)

  local function setCompact(on)
    place(on)
    if onLayoutChanged then
      onLayoutChanged()
    end
  end

  return {
    setCompact = setCompact,
    setLanguage = function()
      screenEdge.label:SetText(Localization.Text("Screen edge"))
      screenEdge.setOptionsList(Options.BuildScreenEdgeOptions())
      glowColor.setLanguage()
    end,
  }
end

ns.AppearanceSettingsScreenEdgeRows = ScreenEdgeRows
return ScreenEdgeRows
