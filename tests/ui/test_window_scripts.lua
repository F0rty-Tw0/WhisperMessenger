local FakeUI = require("tests.helpers.fake_ui")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  assert(WindowScripts ~= nil, "expected WindowScripts module to load")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Shared stubs
  local function noop() end

  -- -----------------------------------------------------------------------
  -- test_wire_buttons_sets_close_click
  -- -----------------------------------------------------------------------
  do
    local closeButton = factory.CreateFrame("Frame", nil, parent)
    local optionsButton = factory.CreateFrame("Frame", nil, parent)
    local resetWindowButton = factory.CreateFrame("Frame", nil, parent)
    local resetIconButton = factory.CreateFrame("Frame", nil, parent)
    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = closeButton,
      optionsButton = optionsButton,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = optionsPanel,
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function(_target)
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(closeButton.scripts) == "table" and type(closeButton.scripts.OnClick) == "function",
      "test_wire_buttons_sets_close_click: expected closeButton to have OnClick script"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_wire_buttons_sets_options_click
  -- -----------------------------------------------------------------------
  do
    local closeButton = factory.CreateFrame("Frame", nil, parent)
    local optionsButton = factory.CreateFrame("Frame", nil, parent)
    local resetWindowButton = factory.CreateFrame("Frame", nil, parent)
    local resetIconButton = factory.CreateFrame("Frame", nil, parent)
    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = closeButton,
      optionsButton = optionsButton,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = optionsPanel,
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function(_target)
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(optionsButton.scripts) == "table" and type(optionsButton.scripts.OnClick) == "function",
      "test_wire_buttons_sets_options_click: expected optionsButton to have OnClick script"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_wire_frame_sets_on_show
  -- -----------------------------------------------------------------------
  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnShow) == "function",
      "test_wire_frame_sets_on_show: expected frame to have OnShow script"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_wire_frame_sets_on_size_changed
  -- -----------------------------------------------------------------------
  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnSizeChanged) == "function",
      "test_wire_frame_sets_on_size_changed: expected frame to have OnSizeChanged script"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_wire_frame_sets_drag_scripts
  -- -----------------------------------------------------------------------
  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnDragStart) == "function",
      "test_wire_frame_sets_drag_scripts: expected frame to have OnDragStart script"
    )
    assert(
      type(frame.scripts.OnDragStop) == "function",
      "test_wire_frame_sets_drag_scripts: expected frame to have OnDragStop script"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_wire_frame_sets_resize_grip_scripts
  -- -----------------------------------------------------------------------
  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(resizeGrip.scripts) == "table" and type(resizeGrip.scripts.OnMouseDown) == "function",
      "test_wire_frame_sets_resize_grip_scripts: expected resizeGrip to have OnMouseDown script"
    )
    assert(
      type(resizeGrip.scripts.OnMouseUp) == "function",
      "test_wire_frame_sets_resize_grip_scripts: expected resizeGrip to have OnMouseUp script"
    )
  end
end
