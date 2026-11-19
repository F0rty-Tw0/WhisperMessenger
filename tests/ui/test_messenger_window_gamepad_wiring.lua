local FakeUI = require("tests.helpers.fake_ui")
local GamepadWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadWiring")

local function fakeNav()
  ---@type table<string, any>
  local nav = { seen = {} }
  for _, name in ipairs({ "onShow", "onHide", "refresh", "setCloseHandler", "setScrollFrame", "ignore" }) do
    nav[name] = function(...)
      table.insert(nav.seen, { name = name, args = { ... } })
    end
  end
  function nav.count(name)
    local n = 0
    for _, s in ipairs(nav.seen) do
      n = n + (s.name == name and 1 or 0)
    end
    return n
  end
  return nav
end

local function setup(opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  if opts.shown then
    frame:Show()
  end
  local shell = {
    frame = frame,
    chrome = { resizeGrip = factory.CreateFrame("Button", nil, frame) },
    layout = { contactsResizeHandle = factory.CreateFrame("Button", nil, frame) },
  }
  local input = factory.CreateFrame("EditBox", nil, frame)
  local box = opts.plainBox and input or factory.CreateFrame("Frame", nil, frame)
  local state = { options = false, panel = nil, calls = {} }
  local refs = {
    composer = { box = box, input = input },
    conversation = {
      transcript = { scrollFrame = factory.CreateFrame("ScrollFrame", nil, frame), content = factory.CreateFrame("Frame", nil, frame) },
    },
    compactMode = {
      onBack = function()
        return false
      end,
    },
    windowVisibility = {
      getVisiblePanel = function()
        return state.panel
      end,
      isConversationPaneShown = function()
        return not state.options and state.panel == nil
      end,
      setOptionsVisible = function(v)
        table.insert(state.calls, "options:" .. tostring(v))
      end,
      setPanelVisible = function(k)
        table.insert(state.calls, "panel:" .. tostring(k))
      end,
      closeWindow = function()
        table.insert(state.calls, "close")
      end,
    },
  }
  local nav = fakeNav()
  local wiring = GamepadWiring.Create(shell, nav)
  wiring.attach(refs)
  local closer
  for _, s in ipairs(nav.seen) do
    if s.name == "setCloseHandler" then
      closer = s.args[1]
    end
  end
  return { frame = frame, shell = shell, refs = refs, nav = nav, state = state, close = closer, wiring = wiring }
end

local function ignoredWith(nav, widget)
  for _, s in ipairs(nav.seen) do
    if s.name == "ignore" and s.args[1] == widget then
      return true, s.args[2]
    end
  end
  return false
end

return function()
  -- test_window_show_and_hide_reach_the_nav
  do
    local t = setup()
    t.frame:Show()
    t.frame:Hide()
    assert(t.nav.count("onShow") == 1 and t.nav.count("onHide") == 1, "hooks forward show and hide")
  end

  -- test_attach_registers_a_window_already_shown
  do
    local t = setup({ shown = true })
    assert(t.nav.count("onShow") == 1, "already shown at attach: registered now")
  end

  -- test_b_closes_settings_when_they_are_shown
  do
    local t = setup({ shown = true })
    t.state.options = true
    assert(t.close() == true and t.state.calls[1] == "options:false", "isOptionsVisible = no panel and pane covered")
  end

  -- test_b_reads_the_compact_back_hook_at_press_time
  do
    local t = setup({ shown = true })
    t.state.options = true
    t.refs.compactMode.onBack = function()
      return true
    end
    assert(t.close() == true and #t.state.calls == 0, "replaced onBack hook is the one called")
  end

  -- test_b_closes_the_window_with_nothing_open
  do
    local t = setup({ shown = true })
    assert(t.close() == true and t.state.calls[1] == "close", "window closes")
  end

  -- test_right_stick_targets_the_chat_transcript
  do
    local t = setup()
    local found
    for _, e in ipairs(t.nav.seen) do
      if e.name == "setScrollFrame" then
        found = e.args[1]
      end
    end
    assert(found == t.refs.conversation.transcript.scrollFrame, "chat transcript is the right-stick target")
  end

  -- test_dead_stops_are_ignored
  do
    local t = setup()
    assert(ignoredWith(t.nav, t.shell.chrome.resizeGrip), "window resize grip")
    assert(ignoredWith(t.nav, t.shell.layout.contactsResizeHandle), "contacts resize handle")
    local content, contentNoProp = ignoredWith(t.nav, t.refs.conversation.transcript.content)
    assert(content and not contentNoProp, "transcript content and every bubble under it")
    local holder, holderNoProp = ignoredWith(t.nav, t.refs.composer.box)
    assert(holder and holderNoProp == true, "composer holder alone; the message box under it stays")
  end

  -- test_plain_edit_box_composer_is_not_ignored
  do
    local t = setup({ plainBox = true })
    assert(not ignoredWith(t.nav, t.refs.composer.input), "the message box itself stays reachable")
  end

  -- test_refresh_forwards_to_the_nav
  do
    local t = setup()
    t.wiring.refresh()
    assert(t.nav.count("refresh") == 1, "refresh reaches GamepadNav")
  end
end
