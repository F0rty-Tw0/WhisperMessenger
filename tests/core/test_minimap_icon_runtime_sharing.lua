local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")

-- Oracle: the "Same position on every character" spec. With sharing on the
-- minimap button lives at the account angle; a drag writes only that spot.

local function captureMinimapOptions(accountState, characterState)
  local createOptions
  MinimapIconRuntime.Create({
    accountState = accountState,
    characterState = characterState,
    minimapIcon = {
      Create = function(_, options)
        createOptions = options
        return {}
      end,
    },
    dataBroker = { Register = function() end },
  })
  return createOptions
end

local function test_minimap_drag_while_sharing_writes_the_account_angle()
  local accountState = { settings = { shareWidgetPosition = true }, sharedMinimapIcon = { degrees = 200 } }
  local characterState = { minimapIcon = { degrees = 45 } }
  local options = captureMinimapOptions(accountState, characterState)

  options.onPositionChanged({ degrees = 90 })

  assert(accountState.sharedMinimapIcon.degrees == 90, "the drag lands on the account angle")
  assert(characterState.minimapIcon.degrees == 45, "this character's angle stays put")
end

local function test_minimap_drag_without_sharing_writes_this_characters_angle()
  local accountState = { settings = { shareWidgetPosition = false }, sharedMinimapIcon = { degrees = 200 } }
  local characterState = { minimapIcon = { degrees = 45 } }
  local options = captureMinimapOptions(accountState, characterState)

  options.onPositionChanged({ degrees = 90 })

  assert(characterState.minimapIcon.degrees == 90, "the drag lands on this character's angle")
  assert(accountState.sharedMinimapIcon.degrees == 200, "the account angle stays put")
end

local function test_minimap_startup_while_sharing_uses_the_account_angle()
  local accountState = { settings = { shareWidgetPosition = true }, sharedMinimapIcon = { degrees = 200 } }
  local characterState = { minimapIcon = { degrees = 45 } }

  local options = captureMinimapOptions(accountState, characterState)

  assert(options.state.degrees == 200, "the button is created at the account angle")
end

return function()
  test_minimap_drag_while_sharing_writes_the_account_angle()
  test_minimap_drag_without_sharing_writes_this_characters_angle()
  test_minimap_startup_while_sharing_uses_the_account_angle()
end
