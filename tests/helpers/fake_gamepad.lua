-- Fake WoW: Forever gamepad UI: FrameControlsManager, SmartNavigation, the
-- combat check, next-frame timers and an event frame for PLAYER_REGEN_ENABLED.
-- Mirrors Blizzard's SmartNavigation.lua: FrameShown creates the panel info
-- and fires the frame's panel-info-added callback (#L826-L845, #L839);
-- the callback setter only stores it on the frame (#L1982-L1984).
-- env.overrideFor reads the frame a jump override points at. Prompted bindings (the X button, which the addon
-- must not use) and the game's right-click come from fake_gamepad_bindings.
local FakeGamepadBindings = require("tests.helpers.fake_gamepad_bindings")

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
  "GamepadSharedUtility",
  "GAMEPAD_FACE_LEFT",
  "PromptedBindingMixin",
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
    fcm.isPopupFrame[frame] = nil
    listed[frame] = nil
  end
  -- FrameControlsManager.lua#L563-L581: lists the popup only when its inner
  -- FrameShown adds it (refused while the gamepad UI is off), returns nothing.
  function fcm:HandlePopupShown(popup)
    log("HandlePopupShown", popup)
    if env.refusePopups then
      return
    end
    fcm.isPopupFrame[popup] = true
    listed[popup] = true
  end
  fcm.isPopupFrame = {}
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
  FakeGamepadBindings.Install(env, log, smartNav)

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

  -- WM must hand SmartNav a frame or nil, never a function override.
  local overrides = setmetatable({}, { __mode = "k" })
  function env.addJumpOverride(button, direction, override)
    if type(override) == "function" then
      error("fake SmartNav: jump override must be a frame or nil")
    end
    log("AddJumpNavigationOverride", button, direction, override)
    overrides[button] = overrides[button] or {}
    overrides[button][direction.dirKey] = override
  end

  -- The frame SmartNav jumps to when the D-pad presses dirName on widget.
  function env.overrideFor(widget, dirName)
    return overrides[widget] and overrides[widget][env.directions[dirName].dirKey]
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

  local function fire(event)
    local fired = false
    for _, frame in ipairs(eventFrames) do
      if frame.events[event] and frame.scripts.OnEvent then
        fired = true
        frame.scripts.OnEvent(frame, event)
      end
    end
    assert(fired, "no frame registered " .. event)
  end
  env.fire = fire

  -- Fires PLAYER_REGEN_ENABLED; leaves env.combat as the test set it.
  function env.regen()
    fire("PLAYER_REGEN_ENABLED")
  end

  function env.scrollFrameFor(frame)
    return scrollFrames[frame]
  end

  function env.deps(overrides)
    local deps = {
      gamepadMode = env.gamepadMode,
      smartNavigation = env.smartNavigation,
      markIgnored = env.markIgnored,
      markFocusable = env.markFocusable,
      addJumpOverride = env.addJumpOverride,
      directions = env.directions,
      inCombat = env.inCombat,
      after = env.after,
      createFrame = env.createFrame,
      gamepadSharedUtility = env.sharedUtility,
      rightClickKey = env.FACE_LEFT,
      promptedBindingMixin = env.promptedBindingMixin,
    }
    for key, value in pairs(overrides or {}) do
      deps[key] = value
    end
    return deps
  end

  -- withoutApi: true = a client without the gamepad UI (no GamepadMode);
  -- "partial" = a client with FrameShown alone and an empty SmartNavigation.
  -- The other globals stay, so any gamepad call the addon still makes is
  -- logged.
  function env.install(withoutApi)
    saved = {}
    for _, name in ipairs(GLOBALS) do
      saved[name] = rawget(_G, name)
    end
    local partial = withoutApi == "partial"
    local partialMode = { FrameControlsManager = { FrameShown = fcm.FrameShown } }
    rawset(_G, "GamepadMode", (partial and partialMode) or (not withoutApi and env.gamepadMode) or nil)
    rawset(_G, "SmartNavigation", partial and {} or env.smartNavigation)
    rawset(_G, "SmartNavigation_MarkFrameIgnored", env.markIgnored)
    rawset(_G, "SmartNavigation_MarkFrameFocusable", env.markFocusable)
    rawset(_G, "SmartNavigation_AddJumpNavigationOverride", env.addJumpOverride)
    rawset(_G, "SMART_NAV_INPUT_DIRECTION", env.directions)
    rawset(_G, "InCombatLockdown", env.inCombat)
    rawset(_G, "C_RestrictedActions", nil)
    rawset(_G, "GamepadSharedUtility", env.sharedUtility)
    rawset(_G, "GAMEPAD_FACE_LEFT", env.FACE_LEFT)
    rawset(_G, "PromptedBindingMixin", env.promptedBindingMixin)
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
