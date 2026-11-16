-- runtime.bnetRepaintPending: a Battle.net friend event arrived since the
-- window was last fully drawn. The status tick redraws an open window while
-- it is set, so a change the friend scan missed stays on screen for one
-- tick at most.

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

-- Returns coordinator, runtime, world. world.paints counts full window
-- draws, world.tick() fires the status ticker, world.setShown(false) hides
-- the frame behind the coordinator's back (the ticker keeps running).
local function makeCoordinator()
  local world = { paints = 0 }
  local shown = false
  local window = {
    frame = {},
    refreshSelection = function()
      world.paints = world.paints + 1
    end,
  }
  function window.frame:IsShown()
    return shown
  end
  function window.frame:Show()
    shown = true
  end
  function window.frame:Hide()
    shown = false
  end
  function world.setShown(nextShown)
    shown = nextShown
  end

  local runtime = { availabilityByGUID = {}, availabilityRequestedAt = {}, chatApi = {}, store = { conversations = {} } }
  local coordinator = WindowCoordinator.Create({
    runtime = runtime,
    getWindow = function()
      return window
    end,
    requestAvailability = function() end,
    cTimer = {
      NewTicker = function(_interval, callback)
        world.tick = callback
        return { Cancel = function() end }
      end,
    },
  })
  return coordinator, runtime, world
end

local function makeOpenCoordinator()
  local coordinator, runtime, world = makeCoordinator()
  coordinator.setWindowVisible(true)
  world.paints = 0
  return coordinator, runtime, world
end

-- An open window with the "selected" chat on screen and an "other" chat in
-- the list. Returns coordinator, runtime, world. world.rowDraws counts
-- draws of the contact rows alone, world.paints full window draws.
local function makeOpenCoordinatorWithSelectedChat()
  local world = { paints = 0, rowDraws = 0 }
  local window = {
    frame = {
      IsShown = function()
        return true
      end,
    },
    refreshContacts = function()
      world.rowDraws = world.rowDraws + 1
    end,
    refreshSelection = function()
      world.paints = world.paints + 1
    end,
  }
  local runtime = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    activeConversationKey = "selected",
    store = { conversations = { selected = { messages = {} }, other = { messages = {} } } },
  }
  local coordinator = WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function()
      return { { conversationKey = "selected", channel = "GUILD" }, { conversationKey = "other", channel = "GUILD" } }
    end,
    getWindow = function()
      return window
    end,
  })
  return coordinator, runtime, world
end

return function()
  -- test_status_tick_repaints_open_window_when_a_friend_event_is_pending
  do
    local _coordinator, runtime, world = makeOpenCoordinator()
    runtime.bnetRepaintPending = true

    world.tick()

    assert(world.paints == 1, "the tick must redraw the window, got " .. world.paints .. " draws")
    assert(runtime.bnetRepaintPending == nil, "the redraw settles the pending friend event")
    world.tick()
    assert(world.paints == 1, "one pending event is one redraw, got " .. world.paints .. " draws")
  end

  -- test_status_tick_does_not_repaint_without_a_pending_friend_event
  do
    local _coordinator, _runtime, world = makeOpenCoordinator()

    world.tick()

    assert(world.paints == 0, "a tick with nothing pending leaves the window alone, got " .. world.paints .. " draws")
  end

  -- test_visible_full_refresh_clears_the_pending_friend_event
  do
    local coordinator, runtime = makeOpenCoordinator()
    runtime.bnetRepaintPending = true

    coordinator.refreshWindow()

    assert(runtime.bnetRepaintPending == nil, "a full draw of the open window settles the pending friend event")
  end

  -- test_visible_partial_refresh_keeps_the_pending_friend_event
  -- A refresh limited to some conversations leaves the other rows as drawn.
  do
    local coordinator, runtime = makeOpenCoordinator()
    runtime.bnetRepaintPending = true

    coordinator.refreshWindow(nil, { ["bnet::friend"] = true })

    assert(runtime.bnetRepaintPending == true, "a partial rebuild does not settle the pending friend event")
  end

  -- test_visible_rows_only_refresh_keeps_the_pending_friend_event
  -- A change in a chat that is not on screen redraws the contact rows and
  -- leaves the header, which shows the selected friend's live state.
  do
    local coordinator, runtime, world = makeOpenCoordinatorWithSelectedChat()
    runtime.bnetRepaintPending = true

    coordinator.refreshWindow("other")

    assert(world.rowDraws == 1 and world.paints == 0, "test precondition: only the contact rows were drawn")
    assert(runtime.bnetRepaintPending == true, "a rows-only draw does not settle the pending friend event")
  end

  -- test_hidden_refresh_keeps_the_pending_friend_event
  do
    local coordinator, runtime, world = makeCoordinator()
    runtime.bnetRepaintPending = true

    coordinator.refreshWindow()

    assert(world.paints == 0, "a hidden window is not drawn")
    assert(runtime.bnetRepaintPending == true, "a hidden refresh draws nothing, so the event stays pending")
  end

  -- test_status_tick_leaves_a_hidden_window_alone
  do
    local _coordinator, runtime, world = makeOpenCoordinator()
    world.setShown(false)
    runtime.bnetRepaintPending = true

    world.tick()

    assert(world.paints == 0, "a hidden window is not drawn by the tick, got " .. world.paints .. " draws")
    assert(runtime.bnetRepaintPending == true, "the event stays pending until the window is drawn")
  end

  -- test_opening_the_window_settles_the_pending_friend_event
  do
    local coordinator, runtime = makeCoordinator()
    runtime.bnetRepaintPending = true

    coordinator.setWindowVisible(true)

    assert(runtime.bnetRepaintPending == nil, "opening draws the whole window")
  end
end
