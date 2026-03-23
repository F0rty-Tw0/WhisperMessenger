local FakeUI = require("tests.helpers.fake_ui")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local function noop() end

  -- -----------------------------------------------------------------------
  -- test_general_toggle_shows_content_pane_on_click
  -- -----------------------------------------------------------------------
  do
    local generalToggle = factory.CreateFrame("Frame", nil, parent)
    local optionsContentPane = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
      generalToggle = generalToggle,
      optionsContentPane = optionsContentPane,
    }

    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    _G.StaticPopup_Show = function() end

    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(generalToggle.scripts) == "table" and type(generalToggle.scripts.OnClick) == "function",
      "test_general_toggle: expected generalToggle to have OnClick script"
    )

    -- Content pane starts shown (General settings open by default)
    assert(optionsContentPane.shown == true, "test_general_toggle: optionsContentPane should start shown")

    -- First click hides it
    generalToggle.scripts.OnClick(generalToggle)
    assert(
      optionsContentPane.shown == false,
      "test_general_toggle: optionsContentPane should be hidden after first click"
    )

    -- Second click shows it again
    generalToggle.scripts.OnClick(generalToggle)
    assert(
      optionsContentPane.shown == true,
      "test_general_toggle: optionsContentPane should be hidden after second click"
    )

    _G.StaticPopupDialogs = nil
    _G.StaticPopup_Show = nil
  end
end
