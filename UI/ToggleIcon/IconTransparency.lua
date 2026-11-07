local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
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

ns.ToggleIconIconTransparency = IconTransparency
return IconTransparency
