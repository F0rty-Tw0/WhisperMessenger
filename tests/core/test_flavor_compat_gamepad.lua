local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local Flavor = require("tests.helpers.flavor")

local GLOBALS = { "GamepadMode", "SmartNavigation", "InputUtil" }

-- isRetail, isForever of each flavor stub.
local FLAVORS = {
  { name = "Retail", true, false },
  { name = "Forever", true, true },
  { name = "Classic", false, false },
}

-- Runs check() with the three globals set to values (a missing key → nil),
-- then restores them even when check fails.
local function withGlobals(values, check)
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, values[name])
  end
  local ok, err = pcall(check)
  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

-- Every Blizzard method the gamepad nav calls without a guard of its own.
local REQUIRED = {
  GamepadMode = { "FrameShown", "FrameHidden" },
  SmartNavigation = { "GetPanelInfo", "RefreshButtonGroups", "SetScrollFrameForFrame", "SetSmartNavPanelInfoAddedCallback", "RightClick" },
}

local function withMethods(names)
  local object = {}
  for _, name in ipairs(names) do
    object[name] = function() end
  end
  return object
end

local function api()
  return {
    GamepadMode = { FrameControlsManager = withMethods(REQUIRED.GamepadMode) },
    SmartNavigation = withMethods(REQUIRED.SmartNavigation),
  }
end

-- A client with only part of the API: FrameShown and an empty SmartNavigation.
local function partialApi()
  return {
    GamepadMode = { FrameControlsManager = { FrameShown = function() end } },
    SmartNavigation = {},
  }
end

local function inputUtil(result)
  return {
    IsGamepadUIEnabled = function()
      if result == "throws" then
        error("not ready")
      end
      return result
    end,
  }
end

return function()
  for _, flavor in ipairs(FLAVORS) do
    Flavor.With(flavor[1], flavor[2], function()
      -- test_has_gamepad_ui_true_when_the_api_is_present
      withGlobals(api(), function()
        assert(FlavorCompat.HasGamepadUI() == true, flavor.name .. ": the API alone decides")
      end)

      -- test_has_gamepad_ui_false_without_the_api
      withGlobals({}, function()
        assert(FlavorCompat.HasGamepadUI() == false, flavor.name .. ": no API, no gamepad UI")
      end)

      -- test_has_gamepad_ui_false_with_a_partial_api
      withGlobals(partialApi(), function()
        assert(FlavorCompat.HasGamepadUI() == false, flavor.name .. ": part of the API is not the API")
      end)

      -- test_gamepad_ui_enabled_follows_the_game
      withGlobals({ InputUtil = inputUtil(true) }, function()
        assert(FlavorCompat.IsGamepadUIEnabled() == true, flavor.name .. ": on when the game says so")
      end)

      -- test_gamepad_ui_disabled_without_input_util
      withGlobals({}, function()
        assert(FlavorCompat.IsGamepadUIEnabled() == false, flavor.name .. ": no InputUtil means off")
      end)
    end)
  end

  -- test_has_gamepad_ui_false_without_any_one_required_method
  for _, name in ipairs(REQUIRED.GamepadMode) do
    local missing = api()
    missing.GamepadMode.FrameControlsManager[name] = nil
    withGlobals(missing, function()
      assert(FlavorCompat.HasGamepadUI() == false, "FrameControlsManager without " .. name .. " is not the API")
    end)
  end
  for _, name in ipairs(REQUIRED.SmartNavigation) do
    local missing = api()
    missing.SmartNavigation[name] = nil
    withGlobals(missing, function()
      assert(FlavorCompat.HasGamepadUI() == false, "SmartNavigation without " .. name .. " is not the API")
    end)
  end

  -- test_has_gamepad_ui_checks_the_tables_it_is_given
  local given = api()
  withGlobals({}, function()
    assert(FlavorCompat.HasGamepadUI(given.GamepadMode, given.SmartNavigation) == true, "given tables stand in for the globals")
  end)

  -- test_has_gamepad_ui_given_tables_win_over_the_globals
  local partial = partialApi()
  withGlobals(api(), function()
    assert(FlavorCompat.HasGamepadUI(partial.GamepadMode, partial.SmartNavigation) == false, "the given partial API decides")
  end)

  -- test_has_gamepad_ui_false_argument_means_absent
  withGlobals(api(), function()
    assert(FlavorCompat.HasGamepadUI(false, false) == false, "false is absent: no fallback to the globals")
    assert(FlavorCompat.HasGamepadUI(nil, false) == false, "one absent table is enough")
  end)

  -- test_has_gamepad_ui_false_without_smart_navigation
  local noSmartNav = api()
  noSmartNav.SmartNavigation = nil
  withGlobals(noSmartNav, function()
    assert(FlavorCompat.HasGamepadUI() == false, "SmartNavigation is part of the API")
  end)

  -- test_gamepad_ui_disabled_when_the_game_says_off
  withGlobals({ InputUtil = inputUtil(false) }, function()
    assert(FlavorCompat.IsGamepadUIEnabled() == false, "mouse and keyboard mode")
  end)

  -- test_gamepad_ui_disabled_without_the_check
  withGlobals({ InputUtil = {} }, function()
    assert(FlavorCompat.IsGamepadUIEnabled() == false, "InputUtil without IsGamepadUIEnabled means off")
  end)

  -- test_gamepad_ui_disabled_when_the_check_throws
  withGlobals({ InputUtil = inputUtil("throws") }, function()
    assert(FlavorCompat.IsGamepadUIEnabled() == false, "an error counts as off")
  end)

  -- test_gamepad_ui_enabled_is_read_on_every_call
  local enabled = false
  withGlobals({
    InputUtil = {
      IsGamepadUIEnabled = function()
        return enabled
      end,
    },
  }, function()
    assert(FlavorCompat.IsGamepadUIEnabled() == false, "off first")
    enabled = true
    assert(FlavorCompat.IsGamepadUIEnabled() == true, "the player picked up the pad: on, no reload")
  end)
end
