local PositionSlots = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")
local TableUtils = require("WhisperMessenger.Util.TableUtils")

-- Oracle: the State x event table of the "Same position on every character"
-- spec. Window slots share 7 geometry fields; the collapsed rail, minimized
-- and compact layout flags stay per character.

local function makeSlots(shared, accountState, characterState)
  accountState.settings = { shareWidgetPosition = shared }
  return PositionSlots.Create({
    accountState = accountState,
    characterState = characterState,
    tableUtils = TableUtils,
  })
end

local function windowState(x, extra)
  local state = {
    anchorPoint = "CENTER",
    relativePoint = "CENTER",
    x = x,
    y = 0,
    width = 900,
    height = 560,
    contactsWidth = 300,
  }
  for key, value in pairs(extra or {}) do
    state[key] = value
  end
  return state
end

local function assertSameSpot(actual, expected, message)
  assert(type(actual) == "table", message .. " (expected a table)")
  for key, value in pairs(expected) do
    assert(actual[key] == value, message .. " (" .. key .. ")")
  end
  for key in pairs(actual) do
    assert(expected[key] ~= nil, message .. " (unexpected " .. key .. ")")
  end
end

local function test_window_share_keeps_collapsed_rail_and_minimized_per_character()
  local account = { sharedWindow = windowState(300) }
  local character = { window = windowState(40, { contactsCollapsed = true, minimized = true }) }
  local slots = makeSlots(true, account, character)

  local shown = slots.read("window")

  assert(shown.contactsCollapsed == true, "the rail stays collapsed for this character")
  assert(shown.minimized == true, "minimized stays per character")
  assert(shown.x == 300, "geometry comes from the account spot")
end

local function test_window_read_while_sharing_never_uses_this_characters_geometry()
  local account = { sharedWindow = windowState(300) }
  local character = { window = windowState(40, { contactsCollapsed = false }) }
  character.window.width = 500
  local slots = makeSlots(true, account, character)

  assertSameSpot(slots.read("window"), windowState(300, { contactsCollapsed = false }), "shared read")
end

local function test_window_drag_while_sharing_leaves_this_characters_geometry()
  local account = { sharedWindow = windowState(300) }
  local character = { window = windowState(40, { contactsCollapsed = false, minimized = false }) }
  local slots = makeSlots(true, account, character)

  slots.write("window", windowState(55, { contactsCollapsed = true, minimized = false }))

  assertSameSpot(account.sharedWindow, windowState(55), "the account spot takes the 7 fields only")
  assertSameSpot(
    character.window,
    windowState(40, { contactsCollapsed = true, minimized = false }),
    "this character keeps its geometry and saves the rail"
  )
end

local function test_window_reset_while_sharing_resets_the_account_spot_and_expands_the_rail()
  local account = { sharedWindow = windowState(300) }
  local character = { window = windowState(40, { contactsCollapsed = true, minimized = false }) }
  local slots = makeSlots(true, account, character)
  local default = windowState(0, { contactsCollapsed = false, minimized = false })

  local shown = slots.reset("window", default)

  assertSameSpot(account.sharedWindow, windowState(0), "the account spot takes the default geometry")
  assertSameSpot(character.window, windowState(40, { contactsCollapsed = false, minimized = false }), "the rail expands, geometry stays")
  assertSameSpot(shown, default, "reset returns the merged state")
end

local function test_window_drag_without_sharing_writes_only_this_characters_spot()
  local account = { sharedWindow = windowState(300) }
  local character = { window = windowState(40, { contactsCollapsed = false }) }
  local slots = makeSlots(false, account, character)
  local nextState = windowState(55, { contactsCollapsed = true })

  slots.write("window", nextState)

  assertSameSpot(character.window, nextState, "this character's spot takes the whole state")
  assert(character.window ~= nextState, "the stored spot is a copy")
  assertSameSpot(account.sharedWindow, windowState(300), "the account spot must not change")
end

local function test_toggle_on_without_a_compact_spot_stores_the_default_marker()
  local account = { sharedCompactWindow = windowState(9) }
  local character = { window = windowState(40, { contactsCollapsed = true }) }
  local slots = makeSlots(true, account, character)

  slots.onToggle(true)

  assertSameSpot(account.sharedCompactWindow, {}, "a missing compact spot must store the marker")
  assertSameSpot(account.sharedWindow, windowState(40), "the window spot takes the 7 fields only")
end

local function test_compact_reset_while_sharing_stops_reseeding_from_this_character()
  local account = { sharedCompactWindow = windowState(9) }
  local character = { compactWindow = windowState(40, { compactLayout = true }) }
  local slots = makeSlots(true, account, character)

  local shown = slots.reset("compactWindow", nil)
  slots.seedAll()

  assert(shown == nil, "compact reset returns nil so the window sizes and centers itself")
  assert(slots.read("compactWindow").anchorPoint == nil, "a shared read never carries this character's geometry")
  assertSameSpot(account.sharedCompactWindow, {}, "the account spot stays the default marker")
  assertSameSpot(character.compactWindow, windowState(40, { compactLayout = true }), "this character's own spot is untouched")
end

local function test_compact_reset_without_sharing_clears_this_characters_spot()
  local account = { sharedCompactWindow = windowState(9) }
  local character = { compactWindow = windowState(40, { compactLayout = true }) }
  local slots = makeSlots(false, account, character)

  local shown = slots.reset("compactWindow", nil)

  assert(shown == nil, "compact reset returns nil")
  assert(character.compactWindow == nil, "this character's compact spot must be cleared")
  assertSameSpot(account.sharedCompactWindow, windowState(9), "the account spot must not change")
end

local function test_compact_read_without_a_spot_is_the_default_marker()
  local slots = makeSlots(false, {}, {})

  assertSameSpot(slots.read("compactWindow"), {}, "no compact spot reads as the marker")
  assert(slots.read("window") == nil, "a missing window spot is not invented")
end

local function makeSurfaces(compactLayoutActive)
  local calls = { icon = {}, window = {}, minimap = {}, detached = 0 }
  local uiParent = { name = "UIParent" }
  local surfaces = {
    uiParent = uiParent,
    compactLayoutActive = compactLayoutActive,
    icon = {
      frame = {
        ClearAllPoints = function() end,
        SetPoint = function(_self, ...)
          calls.icon[#calls.icon + 1] = { ... }
        end,
      },
    },
    window = {
      applySavedState = function(state)
        calls.window[#calls.window + 1] = state
      end,
    },
    minimap = {
      applyRadialPosition = function(state)
        calls.minimap[#calls.minimap + 1] = state
      end,
    },
    detached = {
      applySavedSpot = function()
        calls.detached = calls.detached + 1
      end,
    },
  }
  return surfaces, calls, uiParent
end

local function test_reapply_moves_every_created_surface_and_skips_missing_ones()
  local character = {
    icon = { anchorPoint = "TOP", relativePoint = "BOTTOM", x = 3, y = 4 },
    minimapIcon = { degrees = 77 },
    window = windowState(40),
    compactWindow = windowState(12, { compactLayout = true }),
  }
  local slots = makeSlots(false, {}, character)

  local surfaces, calls, uiParent = makeSurfaces(false)
  PositionSlots.Reapply(slots, surfaces)

  assert(#calls.icon == 1, "the icon moves once")
  local setPoint = calls.icon[1]
  assert(setPoint[1] == "TOP" and setPoint[2] == uiParent and setPoint[3] == "BOTTOM", "the icon anchors to the read spot")
  assert(setPoint[4] == 3 and setPoint[5] == 4, "the icon offsets come from the read spot")
  assert(#calls.window == 1 and calls.window[1] == character.window, "the window gets the window spot")
  assert(#calls.minimap == 1 and calls.minimap[1] == character.minimapIcon, "the minimap gets the minimap spot")
  assert(calls.detached == 1, "the preview re-reads its own spot once")

  local compactSurfaces, compactCalls = makeSurfaces(true)
  PositionSlots.Reapply(slots, compactSurfaces)
  assert(compactCalls.window[1] == character.compactWindow, "the compact flag picks the compact spot")

  PositionSlots.Reapply(slots, { uiParent = uiParent })
end

return function()
  test_reapply_moves_every_created_surface_and_skips_missing_ones()
  test_window_share_keeps_collapsed_rail_and_minimized_per_character()
  test_window_read_while_sharing_never_uses_this_characters_geometry()
  test_window_drag_while_sharing_leaves_this_characters_geometry()
  test_window_reset_while_sharing_resets_the_account_spot_and_expands_the_rail()
  test_window_drag_without_sharing_writes_only_this_characters_spot()
  test_toggle_on_without_a_compact_spot_stores_the_default_marker()
  test_compact_reset_while_sharing_stops_reseeding_from_this_character()
  test_compact_reset_without_sharing_clears_this_characters_spot()
  test_compact_read_without_a_spot_is_the_default_marker()
end
