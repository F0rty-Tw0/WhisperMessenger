-- Fake WoW: Forever gamepad UI: FrameControlsManager, SmartNavigation, the
-- combat check, next-frame timers and an event frame for PLAYER_REGEN_ENABLED.
-- Mirrors Blizzard's SmartNavigation.lua: FrameShown creates the panel info
-- and fires the frame's panel-info-added callback (#L826-L845, #L839);
-- the callback setter only stores it on the frame (#L1982-L1984).
-- env.press mirrors how SmartNav runs a jump override (#L1503-L1520,
-- Utility.lua#L513-L524).
local FakeGamepad = {}

local GLOBALS = {
  "GamepadMode",
  "SmartNavigation",
  "SmartNavigation_MarkFrameIgnored",
  "SmartNavigation_MarkFrameFocusable",
  "SmartNavigation_AddJumpNavigationOverride",
  "SMART_NAV_INPUT_DIRECTION",
  "InCombatLockdown",
  "C_RestrictedActions",
}

function FakeGamepad.New()
  local env = { calls = {}, shownResults = {}, panelInfo = {}, combat = false }
  local listed = {}
  local queue = {}
  local eventFrames = {}
  local scrollFrames = {}
  local saved = nil

  local function log(name, ...)
    table.insert(env.calls, { name = name, args = { ... } })
  end

  function env.count(name)
    local n = 0
    for _, call in ipairs(env.calls) do
      if call.name == name then
        n = n + 1
      end
    end
    return n
  end

  local fcm = {}
  function fcm:FrameShown(frame)
    log("FrameShown", frame)
    ---@type boolean|string|nil
    local result = true
    if #env.shownResults > 0 then
      result = table.remove(env.shownResults, 1)
      if result == "nil" then
        result = nil
      end
    end
    if result == true then
      local info = {}
      env.panelInfo[frame] = info
      if frame.smartNavPanelInfoAddedCallback then
        frame.smartNavPanelInfoAddedCallback(info)
      end
    end
    return result
  end
  function fcm:FrameHidden(frame)
    log("FrameHidden", frame)
    env.panelInfo[frame] = nil
    listed[frame] = nil
  end
  -- FrameControlsManager.lua#L563-L581: lists the popup, returns nothing.
  function fcm:HandlePopupShown(popup)
    log("HandlePopupShown", popup)
    listed[popup] = true
  end
  -- True while FCM holds the popup: shown with HandlePopupShown, not yet hidden.
  function env.isListed(frame)
    return listed[frame] == true
  end
  env.gamepadMode = { FrameControlsManager = fcm }

  local smartNav = {}
  function smartNav:RefreshButtonGroups(frame)
    log("RefreshButtonGroups", frame)
  end
  function smartNav:SetScrollFrameForFrame(frame, scrollFrame)
    log("SetScrollFrameForFrame", frame, scrollFrame)
    scrollFrames[frame] = scrollFrame
  end
  function smartNav:SetSmartNavPanelInfoAddedCallback(frame, callback)
    frame.smartNavPanelInfoAddedCallback = callback
  end
  function smartNav:GetPanelInfo(frame, _dontCreate)
    return env.panelInfo[frame]
  end
  env.smartNavigation = smartNav

  function env.markIgnored(widget, dontPropagate)
    log("MarkFrameIgnored", widget, dontPropagate)
  end

  function env.markFocusable(widget)
    log("MarkFrameFocusable", widget)
  end

  -- As Utility.lua#L6-L12.
  env.directions = {
    UP = { x = 0, y = 1, dirKey = "up" },
    DOWN = { x = 0, y = -1, dirKey = "down" },
    LEFT = { x = -1, y = 0, dirKey = "left" },
    RIGHT = { x = 1, y = 0, dirKey = "right" },
  }

  local overrides = setmetatable({}, { __mode = "k" })
  function env.addJumpOverride(button, direction, override)
    log("AddJumpNavigationOverride", button, direction, override)
    overrides[button] = overrides[button] or {}
    overrides[button][direction.dirKey] = override
  end

  -- A D-pad press on widget: "stay" when focus stays on it, else "move".
  -- A function override runs first; then any override in combat is blocked.
  function env.press(widget, dirName)
    local stored = overrides[widget] and overrides[widget][env.directions[dirName].dirKey]
    local result = stored
    if type(stored) == "function" then
      result = stored()
    end
    if stored ~= nil and env.combat then
      log("ActionBlocked", widget)
      return "stay"
    end
    return result == true and "stay" or "move"
  end

  function env.inCombat()
    return env.combat
  end

  function env.after(_delay, fn)
    table.insert(queue, fn)
  end

  -- Runs the callbacks queued before this flush; ones queued meanwhile wait.
  function env.flush()
    local batch = queue
    queue = {}
    for _, fn in ipairs(batch) do
      fn()
    end
  end

  function env.createFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event)
      self.events[event] = true
    end
    function frame:UnregisterEvent(event)
      self.events[event] = nil
    end
    function frame:SetScript(name, fn)
      self.scripts[name] = fn
    end
    table.insert(eventFrames, frame)
    return frame
  end

  -- Fires PLAYER_REGEN_ENABLED; leaves env.combat as the test set it.
  function env.regen()
    local fired = false
    for _, frame in ipairs(eventFrames) do
      if frame.events.PLAYER_REGEN_ENABLED and frame.scripts.OnEvent then
        fired = true
        frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
      end
    end
    assert(fired, "no frame registered PLAYER_REGEN_ENABLED")
  end

  function env.scrollFrameFor(frame)
    return scrollFrames[frame]
  end

  function env.deps(overrides)
    local deps = {
      isForever = true,
      gamepadMode = env.gamepadMode,
      smartNavigation = env.smartNavigation,
      markIgnored = env.markIgnored,
      markFocusable = env.markFocusable,
      addJumpOverride = env.addJumpOverride,
      directions = env.directions,
      inCombat = env.inCombat,
      after = env.after,
      createFrame = env.createFrame,
    }
    for key, value in pairs(overrides or {}) do
      deps[key] = value
    end
    return deps
  end

  function env.install()
    saved = {}
    for _, name in ipairs(GLOBALS) do
      saved[name] = rawget(_G, name)
    end
    rawset(_G, "GamepadMode", env.gamepadMode)
    rawset(_G, "SmartNavigation", env.smartNavigation)
    rawset(_G, "SmartNavigation_MarkFrameIgnored", env.markIgnored)
    rawset(_G, "SmartNavigation_MarkFrameFocusable", env.markFocusable)
    rawset(_G, "SmartNavigation_AddJumpNavigationOverride", env.addJumpOverride)
    rawset(_G, "SMART_NAV_INPUT_DIRECTION", env.directions)
    rawset(_G, "InCombatLockdown", env.inCombat)
    rawset(_G, "C_RestrictedActions", nil)
  end

  function env.uninstall()
    if not saved then
      return
    end
    for _, name in ipairs(GLOBALS) do
      rawset(_G, name, saved[name])
    end
    saved = nil
  end

  return env
end

return FakeGamepad
