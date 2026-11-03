local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The Behavior page shows the current open/close key and a "Set keybind…"
-- button that opens the game's Key Bindings screen. The button is disabled
-- with a reason in combat and on clients that can't open that screen.

local GLOBALS = { "Settings", "KeyBindingFrame_LoadUI", "ShowUIPanel", "InCombatLockdown", "GetBindingKey", "GetBindingText" }

local function withGlobals(values, fn)
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, values[name])
  end
  local ok, err = pcall(fn)
  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

local function create()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return BehaviorSettings.Create(factory, parent, {}, { onChange = function() end })
end

local function fireEvent(frame, event)
  local onEvent = frame:GetScript("OnEvent")
  assert(onEvent, "row should handle events")
  onEvent(frame, event)
end

return function()
  Localization.Configure({ language = "enUS" })
  local opened = {}
  local inCombat = false
  ---@type string|nil
  local boundKey = "CTRL-O"
  local env = {
    Settings = {
      KEYBINDINGS_CATEGORY_ID = 7,
      OpenToCategory = function(categoryID, scrollTo)
        opened[#opened + 1] = { categoryID, scrollTo }
      end,
    },
    InCombatLockdown = function()
      return inCombat
    end,
    GetBindingKey = function(action)
      if action == "WHISPERMESSENGER_TOGGLE" then
        return boundKey
      end
    end,
    GetBindingText = function(key)
      return "<" .. key .. ">"
    end,
  }

  withGlobals(env, function()
    local result = create()
    local button = FindUI.byLabel(result.frame, "Set keybind…")

    -- test_keybind_row_shows_current_key
    assert(FindUI.text(result.frame, "Open/close: <CTRL-O>"), "current key should be shown next to the button")

    -- test_keybind_button_opens_game_key_bindings
    FindUI.click(button)
    assert(#opened == 1 and opened[1][1] == 7, "click should open the Key Bindings category")

    -- test_keybind_row_follows_binding_changes
    boundKey = nil
    fireEvent(button:GetParent(), "UPDATE_BINDINGS")
    assert(FindUI.text(result.frame, "Open/close: Not bound"), "unbound key should read Not bound")

    -- test_keybind_button_disabled_in_combat
    inCombat = true
    fireEvent(button:GetParent(), "PLAYER_REGEN_DISABLED")
    assert(FindUI.disabledCover(button), "button should be covered in combat")
    FindUI.click(button)
    assert(#opened == 1, "click in combat must not open the game screen")

    -- test_keybind_button_reenabled_after_combat
    inCombat = false
    fireEvent(button:GetParent(), "PLAYER_REGEN_ENABLED")
    assert(FindUI.disabledCover(button) == nil, "button should be enabled after combat")
  end)

  -- test_keybind_button_hides_messenger_before_opening_key_bindings
  local events = {}
  local hideEnv = {
    Settings = {
      KEYBINDINGS_CATEGORY_ID = 7,
      OpenToCategory = function()
        events[#events + 1] = "open"
      end,
    },
    InCombatLockdown = function()
      return false
    end,
  }
  withGlobals(hideEnv, function()
    local ns = {
      Bootstrap = {
        runtime = {
          setWindowVisible = function(visible)
            events[#events + 1] = "visible:" .. tostring(visible)
          end,
        },
      },
    }
    local KeybindRow = assert(loadfile("UI/MessengerWindow/BehaviorSettings/KeybindRow.lua"))("WhisperMessenger", ns)
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local panel = {
      bind = function(_self, control)
        return control
      end,
    }
    local keybind = KeybindRow.Create(factory, frame, frame, { panel = panel })
    FindUI.click(keybind.bottom)
    assert(events[1] == "visible:false" and events[2] == "open", "click should hide the messenger, then open Key Bindings")
  end)

  -- test_keybind_button_disabled_without_key_bindings_screen
  withGlobals({}, function()
    local result = create()
    local button = FindUI.byLabel(result.frame, "Set keybind…")
    assert(FindUI.disabledCover(button), "button should be disabled when the flavor can't open Key Bindings")
  end)
end
