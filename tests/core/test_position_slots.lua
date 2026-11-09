local PositionSlots = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")
local TableUtils = require("WhisperMessenger.Util.TableUtils")

-- Oracle: the State x event table of the "Same position on every character"
-- spec. S = sharing setting, P = this character's spot, A = account spot.

local function makeSlots(shared, accountState, characterState)
  accountState.settings = accountState.settings or {}
  accountState.settings.shareWidgetPosition = shared
  return PositionSlots.Create({
    accountState = accountState,
    characterState = characterState,
    tableUtils = TableUtils,
  })
end

local function spot(x)
  return { anchorPoint = "CENTER", relativePoint = "CENTER", x = x, y = 0 }
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

local function snapshot(state)
  local copy = {}
  for key, value in pairs(state) do
    copy[key] = type(value) == "table" and snapshot(value) or value
  end
  return copy
end

local function assertSnapshotsEqual(before, after, message)
  for key, value in pairs(before) do
    if type(value) == "table" then
      assertSameSpot(after[key], value, message .. " " .. key)
    else
      assert(after[key] == value, message .. " " .. key)
    end
  end
  for key in pairs(after) do
    assert(before[key] ~= nil, message .. " unexpected " .. key)
  end
end

local function test_login_with_sharing_uses_the_account_spot_for_a_new_character()
  local accountSpot = spot(300)
  local account = { sharedWidgetPosition = accountSpot }
  local character = { icon = spot(0) }
  local slots = makeSlots(true, account, character)

  assert(slots.read("icon") == accountSpot, "a new character must show the account spot")
  assertSameSpot(character.icon, spot(0), "the character's own spot must stay untouched")
end

local function test_login_with_sharing_seeds_a_missing_account_spot_from_this_character()
  local account = {}
  local character = { icon = spot(40) }
  local slots = makeSlots(true, account, character)

  local shown = slots.read("icon")

  assertSameSpot(account.sharedWidgetPosition, spot(40), "the account spot must be seeded from this character")
  assert(account.sharedWidgetPosition ~= character.icon, "the seeded account spot must be a copy")
  assert(shown == account.sharedWidgetPosition, "the seeded account spot is what is shown")
end

local function test_login_with_sharing_and_no_preview_spot_seeds_the_default_marker()
  local account = {}
  local character = {}
  local slots = makeSlots(true, account, character)

  local shown = slots.read("detachedPreview")

  assertSameSpot(shown, {}, "no preview spot must read as the default marker")
  assertSameSpot(account.sharedDetachedPreview, {}, "the account preview spot must be the default marker, not nil")
end

local function test_toggle_on_overwrites_the_account_spot_with_this_characters_spot()
  local account = { sharedWidgetPosition = spot(300), sharedMinimapIcon = { degrees = 200 } }
  local character = { icon = spot(40), minimapIcon = { degrees = 10 }, detachedPreview = spot(7) }
  local slots = makeSlots(true, account, character)

  slots.onToggle(true)

  assertSameSpot(account.sharedWidgetPosition, spot(40), "the widget spot must be overwritten")
  assertSameSpot(account.sharedMinimapIcon, { degrees = 10 }, "the minimap spot must be overwritten")
  assertSameSpot(account.sharedDetachedPreview, spot(7), "the preview spot must be overwritten")
  assert(account.sharedWidgetPosition ~= character.icon, "the overwrite must store a copy")
end

local function test_toggle_on_without_a_preview_spot_stores_the_default_marker()
  local account = { sharedDetachedPreview = spot(9) }
  local character = { icon = spot(40) }
  local slots = makeSlots(true, account, character)

  slots.onToggle(true)

  assertSameSpot(account.sharedDetachedPreview, {}, "a character with no preview spot must store the marker")
end

local function test_toggle_off_keeps_the_account_spot_and_reads_this_characters_spot()
  local account = { sharedWidgetPosition = spot(300) }
  local character = { icon = spot(40) }
  local slots = makeSlots(false, account, character)

  slots.onToggle(false)

  assert(slots.read("icon") == character.icon, "off must show this character's own spot")
  assertSameSpot(account.sharedWidgetPosition, spot(300), "the account spot must be kept")
end

local function test_toggle_off_twice_changes_nothing()
  local account = { sharedWidgetPosition = spot(300), sharedDetachedPreview = {} }
  local character = { icon = spot(40), minimapIcon = { degrees = 10 } }
  local slots = makeSlots(false, account, character)
  local accountBefore = snapshot(account)
  local characterBefore = snapshot(character)

  slots.onToggle(false)
  slots.onToggle(false)

  assertSnapshotsEqual(accountBefore, snapshot(account), "account")
  assertSnapshotsEqual(characterBefore, snapshot(character), "character")
end

local function test_drag_while_sharing_writes_only_the_account_spot()
  local account = { sharedWidgetPosition = spot(300) }
  local character = { icon = spot(40) }
  local slots = makeSlots(true, account, character)
  local nextState = spot(55)

  slots.write("icon", nextState)

  assertSameSpot(character.icon, spot(40), "the character's own spot must not change")
  assertSameSpot(account.sharedWidgetPosition, spot(55), "the account spot must take the drag")
  assert(account.sharedWidgetPosition ~= nextState, "the stored spot must be a copy")
end

local function test_drag_without_sharing_writes_only_this_characters_spot()
  local account = { sharedWidgetPosition = spot(300) }
  local character = { icon = spot(40) }
  local slots = makeSlots(false, account, character)
  local nextState = spot(55)

  slots.write("icon", nextState)

  assertSameSpot(account.sharedWidgetPosition, spot(300), "the account spot must not change")
  assertSameSpot(character.icon, spot(55), "this character's spot must take the drag")
  assert(character.icon ~= nextState, "the stored spot must be a copy")
end

local function test_reset_while_sharing_resets_only_the_account_spot()
  local account = { sharedWidgetPosition = spot(300) }
  local character = { icon = spot(40) }
  local slots = makeSlots(true, account, character)
  local default = spot(0)

  local shown = slots.reset("icon", default)

  assertSameSpot(account.sharedWidgetPosition, spot(0), "the account spot must be reset")
  assertSameSpot(character.icon, spot(40), "this character's spot must not change")
  assert(account.sharedWidgetPosition ~= default, "the reset must store a copy")
  assert(shown == account.sharedWidgetPosition, "reset returns what is now shown")
end

local function test_reset_without_sharing_resets_only_this_characters_spot()
  local account = { sharedWidgetPosition = spot(300) }
  local character = { icon = spot(40) }
  local slots = makeSlots(false, account, character)
  local default = spot(0)

  local shown = slots.reset("icon", default)

  assertSameSpot(character.icon, spot(0), "this character's spot must be reset")
  assertSameSpot(account.sharedWidgetPosition, spot(300), "the account spot must not change")
  assert(character.icon ~= default, "the reset must store a copy")
  assert(shown == character.icon, "reset returns what is now shown")
end

local function test_seed_all_fills_only_missing_account_spots()
  local existing = spot(300)
  local account = { sharedWidgetPosition = existing }
  local character = { icon = spot(40), minimapIcon = { degrees = 10 } }
  local slots = makeSlots(true, account, character)

  slots.seedAll()

  assert(account.sharedWidgetPosition == existing, "a present account spot must be kept as is")
  assertSameSpot(account.sharedMinimapIcon, { degrees = 10 }, "a missing minimap spot must be seeded")
  assertSameSpot(account.sharedDetachedPreview, {}, "a missing preview spot must be seeded with the marker")
end

local function test_seed_all_without_sharing_writes_nothing()
  local account = {}
  local character = { icon = spot(40), minimapIcon = { degrees = 10 } }
  local slots = makeSlots(false, account, character)

  slots.seedAll()

  assert(account.sharedWidgetPosition == nil, "no widget spot may be written")
  assert(account.sharedMinimapIcon == nil, "no minimap spot may be written")
  assert(account.sharedDetachedPreview == nil, "no preview spot may be written")
end

local function test_is_shared_reads_a_swapped_settings_table()
  local account = { settings = { shareWidgetPosition = true } }
  local slots = makeSlots(true, account, {})
  assert(slots.isShared() == true, "the setting is on")

  account.settings = { shareWidgetPosition = false }
  assert(slots.isShared() == false, "a swapped settings table must be read")

  account.settings = nil
  assert(slots.isShared() == false, "missing settings mean not shared")
end

return function()
  test_login_with_sharing_uses_the_account_spot_for_a_new_character()
  test_login_with_sharing_seeds_a_missing_account_spot_from_this_character()
  test_login_with_sharing_and_no_preview_spot_seeds_the_default_marker()
  test_toggle_on_overwrites_the_account_spot_with_this_characters_spot()
  test_toggle_on_without_a_preview_spot_stores_the_default_marker()
  test_toggle_off_keeps_the_account_spot_and_reads_this_characters_spot()
  test_toggle_off_twice_changes_nothing()
  test_drag_while_sharing_writes_only_the_account_spot()
  test_drag_without_sharing_writes_only_this_characters_spot()
  test_reset_while_sharing_resets_only_the_account_spot()
  test_reset_without_sharing_resets_only_this_characters_spot()
  test_seed_all_fills_only_missing_account_spots()
  test_seed_all_without_sharing_writes_nothing()
  test_is_shared_reads_a_swapped_settings_table()
end
