local FakeUI = require("tests.helpers.fake_ui")
local WindowVisibility = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")

-- Visibility with a stub host that shows any key; `events` logs every
-- onPanelVisibilityChanged(visible, key) call.
local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  local events = {}
  local visibility = WindowVisibility.Create({
    optionsPanel = factory.CreateFrame("Frame", nil, frame),
    contactsPane = factory.CreateFrame("Frame", nil, frame),
    contentPane = factory.CreateFrame("Frame", nil, frame),
    frame = frame,
    panelHost = {
      show = function()
        return true
      end,
      hide = function() end,
    },
    onPanelVisibilityChanged = function(visible, key)
      events[#events + 1] = { visible, key }
    end,
  })
  return visibility, events
end

local function assertEvent(event, visible, key, label)
  assert(
    event ~= nil and event[1] == visible and event[2] == key,
    label .. ": got " .. tostring(event and event[1]) .. ", " .. tostring(event and event[2])
  )
end

return function()
  -- test_open_passes_the_key
  do
    local visibility, events = build()
    visibility.setPanelVisible("a")
    assert(#events == 1, "one event on open")
    assertEvent(events[1], true, "a", "open a")
  end

  -- test_swap_closes_without_a_key_then_opens_with_the_new_key
  do
    local visibility, events = build()
    visibility.setPanelVisible("a")
    visibility.setPanelVisible("b")
    assert(#events == 3, "open, close, open")
    assertEvent(events[2], false, nil, "close a")
    assertEvent(events[3], true, "b", "open b")
  end

  -- test_close_passes_no_key
  do
    local visibility, events = build()
    visibility.setPanelVisible("a")
    visibility.setPanelVisible(nil)
    assertEvent(events[2], false, nil, "close")
  end
end
