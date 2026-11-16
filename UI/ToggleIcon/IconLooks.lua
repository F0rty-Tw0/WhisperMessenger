local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconSettingsOptions = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- The small pieces of the toggle icon's look, each a field of one table.
local IconLooks = {}

local DockedLook = {}

-- Getter name on the ToggleIcon options -> key in the Icons panel defaults.
local LOOK_GETTERS = {
  { getter = "getWidgetShape", key = "widgetShape" },
  { getter = "getIconBorder", key = "iconBorder" },
  { getter = "getIconBackground", key = "iconBackground" },
  { getter = "getIconBorderThemed", key = "iconBorderThemed" },
}

local function wrapGetter(options, isDocked, name, defaultKey)
  return function()
    if isDocked() then
      return IconSettingsOptions.DEFAULTS[defaultKey]
    end

    local getter = options[name]
    if getter == nil then
      return nil
    end

    return getter()
  end
end

-- While docked the four look getters answer with the default circle; floating they pass the saved values through.
function DockedLook.Wrap(options, isDocked)
  local wrapped = {}
  for _, look in ipairs(LOOK_GETTERS) do
    wrapped[look.getter] = wrapGetter(options, isDocked, look.getter, look.key)
  end

  return wrapped
end

-- Icon opacity: fades to the chosen widget transparency, but stays opaque while
-- hovered or while whispers are unread.
local IconTransparency = {}

-- Returns { refresh, setHasUnread }.
function IconTransparency.Create(frame, options)
  local hover = options.hover
  local getWidgetTransparency = options.getWidgetTransparency
  -- The real count, not the badge: hiding the badge must not hide the icon.
  local hasUnread = false

  local function resolveWidgetTransparency()
    local value = type(getWidgetTransparency) == "function" and tonumber(getWidgetTransparency()) or nil
    if value == nil or value ~= value then
      return 0
    end

    return math.min(1, math.max(0, value))
  end

  local function refresh()
    if not frame.SetAlpha then
      return
    end

    local opaque = hover.active or hasUnread
    local alpha = opaque and 1 or (1 - resolveWidgetTransparency())
    frame:SetAlpha(alpha)
  end

  local function setHasUnread(value)
    hasUnread = value
    refresh()
  end

  return {
    refresh = refresh,
    setHasUnread = setHasUnread,
  }
end

local CompetitiveIndicator = {}

local INDICATOR_SIZE = 16
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local LOCK_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local LOCK_COLOR = { 1, 0.82, 0, 1 }
local BG_COLOR = { 0.15, 0.15, 0.15, 0.9 }

function CompetitiveIndicator.Create(factory, parentFrame)
  local frame = factory.CreateFrame("Frame", nil, parentFrame)
  frame:SetSize(INDICATOR_SIZE, INDICATOR_SIZE)
  frame:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", -4, -4)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, BG_COLOR)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(INDICATOR_SIZE * 0.7, INDICATOR_SIZE * 0.7)
  icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  icon:SetTexture(LOCK_TEX)
  applyVertexColor(icon, LOCK_COLOR)

  if frame.Hide then
    frame:Hide()
  end

  local function setActive(active)
    if active then
      if frame.Show then
        frame:Show()
      end
    else
      if frame.Hide then
        frame:Hide()
      end
    end
  end

  return {
    frame = frame,
    background = background,
    icon = icon,
    setActive = setActive,
  }
end

-- Lock glyph overlay: small padlock texture pinned to the bottom-right of
-- the icon. Hidden by default; shown only while the icon is locked AND the
-- cursor is hovering it, so the indicator stays out of sight otherwise.
local LockGlyph = {}

local LOCK_GLYPH_RATIO = 0.45 -- lock indicator size vs ICON_SIZE
local LOCK_GLYPH_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"

-- options.isLocked: function returning true while the icon is locked.
-- options.hover: the icon's shared hover state table; `hover.active` is true
-- while the cursor is over the icon.
function LockGlyph.Create(frame, iconSize, options)
  local isLocked = options.isLocked
  local hover = options.hover

  local lockGlyph = frame:CreateTexture(nil, "OVERLAY")
  local function applyLayout(size)
    local s = math.max(8, math.floor((tonumber(size) or iconSize) * LOCK_GLYPH_RATIO))
    lockGlyph:SetSize(s, s)
    if lockGlyph.ClearAllPoints then
      lockGlyph:ClearAllPoints()
    end
    lockGlyph:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  end
  applyLayout(iconSize)
  lockGlyph:SetTexture(LOCK_GLYPH_TEXTURE)
  if lockGlyph.Hide then
    lockGlyph:Hide()
  end

  local function syncVisibility()
    local show = hover.active and isLocked()
    if show then
      if lockGlyph.Show then
        lockGlyph:Show()
      end
    else
      if lockGlyph.Hide then
        lockGlyph:Hide()
      end
    end
  end

  local function refresh()
    if frame.SetMovable then
      frame:SetMovable(not isLocked())
    end
    syncVisibility()
  end

  return {
    texture = lockGlyph,
    applyLayout = applyLayout,
    syncVisibility = syncVisibility,
    refresh = refresh,
  }
end

-- One glow, two reasons for it: unread whispers, and an external preview that
-- asked to pulse. Each call recomputes the whole rule, so stopping one source
-- never stops the other. The external glow obeys the pulse setting only.
local PulseState = {}

function PulseState.New(options)
  local unreadWants = false
  local external = false
  local state = {}

  local function externalWants()
    if not external or (options.getBadgePulse and not options.getBadgePulse()) then
      return false
    end
    return options.isExternalShown() == true
  end

  function state.refresh()
    if unreadWants or externalWants() then
      options.start()
    else
      options.stop()
    end
  end

  function state.setUnreadWants(wants)
    unreadWants = wants and true or false
    state.refresh()
  end

  function state.setExternal(on)
    external = on == true
    state.refresh()
  end

  return state
end

IconLooks.DockedLook = DockedLook
IconLooks.IconTransparency = IconTransparency
IconLooks.CompetitiveIndicator = CompetitiveIndicator
IconLooks.LockGlyph = LockGlyph
IconLooks.PulseState = PulseState

ns.ToggleIconIconLooks = IconLooks
return IconLooks
