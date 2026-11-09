local FakeUI = require("tests.helpers.fake_ui")
local DetachedPreviewRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

local function fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "frame has a " .. script .. " handler")
  handler(frame, ...)
end

local function build(opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:Show()
  uiParent.GetCenter = function()
    return 500, 400
  end
  uiParent.GetTop = function()
    return 800
  end
  local env = {
    uiParent = uiParent,
    accountState = { settings = opts.settings or {} },
    characterState = opts.characterState or {},
    clock = { now = 10 },
    opened = 0,
    log = {},
  }
  env.startHolder = function()
    env.surface.holder.GetCenter = function()
      return 500, 0
    end
    env.surface.holder.GetTop = function()
      return 650
    end
  end
  env.surface = DetachedPreviewRuntime.Create({
    uiFactory = factory,
    uiParent = uiParent,
    accountState = env.accountState,
    characterState = env.characterState,
    buildContacts = function()
      return { "contacts" }
    end,
    acknowledgeLatestWidgetPreview = function(contacts)
      env.log[#env.log + 1] = "ack:" .. tostring(contacts[1])
    end,
    refreshWindow = function()
      env.log[#env.log + 1] = "refresh"
    end,
    onOpenPreview = function()
      env.opened = env.opened + 1
      return true
    end,
    getWidgetIcon = function()
      return env.widget
    end,
    now = function()
      return env.clock.now
    end,
  })
  env.startHolder()
  return env
end

local function moveHolder(env, centerX, top)
  env.surface.holder.GetCenter = function()
    return centerX, 0
  end
  env.surface.holder.GetTop = function()
    return top
  end
end

local function showWhisper(env)
  env.surface.setIncomingPreview("Bob", "hello", "WARRIOR", nil)
end

local function assertPoint(holder, parent, x, y)
  local point, relativeTo, relativePoint, px, py = holder:GetPoint()
  assert(point == "TOP" and relativePoint == "TOP", "holder anchors TOP to TOP")
  assert(relativeTo == parent, "holder anchors to uiParent")
  assert(px == x and py == y, "holder at " .. x .. "," .. y .. " got " .. tostring(px) .. "," .. tostring(py))
end

return function()
  -- test_default_spot_is_top_center
  do
    local env = build()
    assertPoint(env.surface.holder, env.uiParent, 0, -150)
  end

  -- test_drag_saves_top_relative_spot
  do
    local env = build()
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    fire(env.surface.previewFrame, "OnDragStop")
    local saved = env.characterState.detachedPreview
    assert(saved and saved.x == 120 and saved.y == -100, "drag saves the TOP-relative offset")
    assert(env.surface.holder.startedMoving == true, "drag starts moving the holder")
    assertPoint(env.surface.holder, env.uiParent, 120, -100)
  end

  -- test_saved_spot_survives_recreate
  do
    local env = build({ characterState = { detachedPreview = { x = 40, y = -60 } } })
    assertPoint(env.surface.holder, env.uiParent, 40, -60)
  end

  -- test_release_after_drag_does_not_open
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    fire(env.surface.previewFrame, "OnDragStop")
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 0, "the release after a drag does not open the chat")
  end

  -- test_release_during_drag_does_not_open
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    fire(env.surface.previewFrame, "OnDragStop")
    assert(env.opened == 0, "the release before the drag stop does not open the chat")
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 1, "a real click right after a consumed release opens")
  end

  -- test_click_after_window_opens_again
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    fire(env.surface.previewFrame, "OnDragStop")
    env.clock.now = 11
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 1, "a click after the drag window opens the chat")
  end

  -- test_lock_blocks_drag_and_click_opens
  do
    local env = build({ settings = { lockToggleIcon = true } })
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    fire(env.surface.previewFrame, "OnDragStop")
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.surface.holder.startedMoving ~= true, "a locked icon does not drag")
    assert(env.opened == 1, "a locked card still opens on click")
  end

  -- test_shared_spot_used_when_sharing
  do
    local env = build({ settings = { shareWidgetPosition = true }, characterState = { detachedPreview = { x = 5, y = -5 } } })
    local shared = env.accountState.sharedDetachedPreview
    assert(shared and shared.x == 5 and shared.y == -5, "shared spot is seeded from the character spot")
    assertPoint(env.surface.holder, env.uiParent, 5, -5)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    fire(env.surface.previewFrame, "OnDragStop")
    assert(env.accountState.sharedDetachedPreview.x == 120, "drag saves into the shared spot")
    assert(env.characterState.detachedPreview.x == 5, "drag leaves the character spot alone")
  end

  -- test_dismiss_acknowledges_and_refreshes
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnMouseUp", "RightButton")
    assert(env.log[1] == "ack:contacts" and env.log[2] == "refresh", "dismiss acknowledges then refreshes")
  end

  -- test_active_surface_picks_detached_only_when_detached
  do
    local detached = { name = "D" }
    local widget = { name = "W" }
    local function getDetached()
      return detached
    end
    local function getWidget()
      return widget
    end
    local function getNone()
      return nil
    end
    local pick = DetachedPreviewRuntime.ActiveSurface
    assert(pick({ widgetPreviewPosition = "detached" }, getDetached, getWidget) == detached, "detached setting picks the detached surface")
    assert(pick({ widgetPreviewPosition = "right" }, getDetached, getWidget) == widget, "other positions pick the widget")
    assert(pick({ widgetPreviewPosition = "detached" }, getNone, getWidget) == nil, "detached but not created gives nil")
    assert(DetachedPreviewRuntime.IsDetached(nil) == false, "nil settings are not detached")
  end

  -- test_external_preview_refreshes_widget_pulse_found_at_call_time
  do
    local env = build()
    local pulses = 0
    env.widget = {
      refreshPulse = function()
        pulses = pulses + 1
      end,
    }
    env.surface.setExternalPreview({
      sender = "Crafter",
      text = "hi",
      classTag = "WARRIOR",
      onClick = function() end,
      onDismiss = function() end,
      onShown = function() end,
    })
    assert(pulses == 1, "an external preview refreshes the widget pulse")
    assert(env.surface.isExternalPreviewShown() == true, "the external preview shows on the card")
  end

  -- test_hiding_the_card_mid_drag_ends_the_drag
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    env.surface.previewFrame:Hide()
    assert(env.surface.holder.stoppedMoving == true, "hiding the card stops moving the holder")
    local saved = env.characterState.detachedPreview
    assert(saved and saved.x == 120 and saved.y == -100, "hiding mid-drag saves the spot")
    env.surface.previewFrame:Show()
    env.clock.now = 20
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 1, "a click after the hidden drag is not swallowed")
  end

  -- test_hiding_the_card_mid_drag_does_not_swallow_the_next_click
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 620, 700)
    env.surface.previewFrame:Hide()
    env.surface.previewFrame:Show()
    env.clock.now = 10.2
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 1, "a click right after a hidden drag is not swallowed")
  end

  -- test_tiny_drag_release_still_opens
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    fire(env.surface.previewFrame, "OnDragStop")
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 1, "a click that jittered the card opens the chat")
    assert(env.characterState.detachedPreview == nil, "a jitter does not save a spot")
    assertPoint(env.surface.holder, env.uiParent, 0, -150)
  end

  -- test_tiny_drag_release_before_drag_stop_opens_once
  do
    local env = build()
    showWhisper(env)
    fire(env.surface.previewFrame, "OnDragStart")
    moveHolder(env, 502, 649)
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    fire(env.surface.previewFrame, "OnDragStop")
    assert(env.opened == 1, "a jittered click opens once when the release comes first")
    assert(env.characterState.detachedPreview == nil, "a jitter does not save a spot")
    fire(env.surface.previewFrame, "OnMouseUp", "LeftButton")
    assert(env.opened == 2, "the next real click is not swallowed")
  end
end
