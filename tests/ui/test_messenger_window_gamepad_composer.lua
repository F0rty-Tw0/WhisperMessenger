local FakeUI = require("tests.helpers.fake_ui")
local Flavor = require("tests.helpers.flavor")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Localization = require("WhisperMessenger.Locale.Localization")
local Composer = require("WhisperMessenger.UI.Composer")
local GamepadComposer = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadComposer")
local GamepadWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadWiring")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

local function fakeNav(active)
  ---@type table<string, any>
  local nav = { seen = {} }
  function nav.isActive()
    return active
  end
  for _, name in ipairs({
    "onShow",
    "onHide",
    "refresh",
    "setCloseHandler",
    "setScrollFrame",
    "ignore",
    "markFocusable",
    "setStepper",
    "setEdgeOverride",
    "popupShown",
    "popupHidden",
    "setPopupCloseHandler",
  }) do
    nav[name] = function(...)
      table.insert(nav.seen, { name = name, args = { ... } })
    end
  end
  return nav
end

-- A shown window wired with a fake composer: { box, scroll, input, submit }.
-- opts: inactive (inert nav), noScroll (plain edit box), picker (shown
-- emoji picker), submits (counter table).
local function setup(opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  frame:Show()
  local shell = { frame = frame, chrome = {}, layout = {} }
  local input = factory.CreateFrame("EditBox", nil, frame)
  local submits = { count = 0 }
  local composer = {
    box = opts.noScroll and input or factory.CreateFrame("Frame", nil, frame),
    scroll = not opts.noScroll and factory.CreateFrame("ScrollFrame", nil, frame) or nil,
    input = input,
    submit = function()
      submits.count = submits.count + 1
    end,
  }
  if opts.picker then
    local pickerFrame = factory.CreateFrame("Frame", nil, frame)
    pickerFrame:Show()
    composer.emojiPicker = {
      frame = pickerFrame,
      close = function(self)
        self.frame:Hide()
      end,
    }
  end
  local state = { calls = {} }
  local refs = {
    composer = composer,
    compactMode = {
      onBack = function()
        return false
      end,
    },
    windowVisibility = {
      getVisiblePanel = function()
        return nil
      end,
      isConversationPaneShown = function()
        return true
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
  local nav = fakeNav(not opts.inactive)
  GamepadWiring.Create(shell, nav).attach(refs)
  local closer
  for _, s in ipairs(nav.seen) do
    if s.name == "setCloseHandler" then
      closer = s.args[1]
    end
  end
  return { refs = refs, composer = composer, input = input, state = state, close = closer, submits = submits }
end

local function activeNav()
  return {
    isActive = function()
      return true
    end,
  }
end

-- A real composer; sent records each payload onSend got.
local function realComposer(options)
  Fonts.Initialize("default")
  local factory = FakeUI.NewFactory({ wrap = true })
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local sent = {}
  local composer = Composer.Create(factory, parent, CONTACT, function(payload)
    sent[#sent + 1] = payload
    return true
  end, nil, nil, nil, options)
  local clearComposerFocus = GamepadComposer.Attach(activeNav(), composer)
  return composer, sent, clearComposerFocus
end

local function click(composer)
  composer.scroll.OnSmartNavClick(composer.scroll)
end

local function eachFlavor(check)
  for _, flavor in ipairs(Flavor.ALL) do
    local ok, err = pcall(Flavor.With, flavor[1], flavor[2], check)
    assert(ok, flavor.name .. ": " .. tostring(err))
  end
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_a_puts_the_cursor_in_the_box
  do
    local t = setup()
    click(t.composer)
    assert(t.input:HasFocus() == true, "A puts the cursor in the box")
    assert(t.submits.count == 0, "the first A sends nothing")
  end

  -- test_a_sends_when_the_cursor_is_in_the_box
  do
    local t = setup()
    t.input:SetFocus()
    click(t.composer)
    assert(t.submits.count == 1, "A in the box runs Enter's submit once, got " .. t.submits.count)
  end

  -- test_a_focuses_a_disabled_composer
  do
    local composer = realComposer()
    composer.setEnabled(false)
    click(composer)
    assert(composer.input:HasFocus() == true, "the player can still type in a disabled composer")
  end

  -- test_a_in_a_disabled_composer_sends_nothing
  do
    local composer, sent = realComposer()
    composer.setEnabled(false)
    composer.input:SetText("hi")
    composer.input:SetFocus()
    local ok, err = pcall(click, composer)
    assert(ok, "no error: " .. tostring(err))
    assert(#sent == 0, "a disabled composer sends nothing")
    assert(composer.input:GetText() == "hi", "the text stays in the box")
  end

  -- test_a_on_an_empty_box_sends_nothing
  do
    local composer, sent = realComposer()
    composer.input:SetText("")
    composer.input:SetFocus()
    click(composer)
    assert(#sent == 0, "an empty box sends nothing")
  end

  -- test_a_sends_the_text_in_the_box
  do
    local composer, sent = realComposer()
    composer.input:SetText("hi")
    composer.input:SetFocus()
    click(composer)
    assert(#sent == 1, "A in the box sends once, got " .. #sent)
    assert(sent[1].text == "hi", "the payload carries the typed text, got " .. tostring(sent[1].text))
    assert(sent[1].conversationKey == CONTACT.conversationKey, "the payload names the open conversation")
  end

  -- test_b_takes_the_cursor_out_before_closing
  do
    local t = setup()
    t.input:SetFocus()
    assert(t.close() == true, "the handler claims the press")
    assert(t.input:HasFocus() == false, "B takes the cursor out")
    assert(#t.state.calls == 0, "the window stays open")
  end

  -- test_second_b_closes_as_before
  do
    local t = setup()
    t.input:SetFocus()
    t.close()
    t.close()
    assert(t.state.calls[1] == "close", "the next B closes the window")
  end

  -- test_b_with_a_picker_open_keeps_the_cursor
  do
    local t = setup({ picker = true })
    t.input:SetFocus()
    t.close()
    assert(not t.composer.emojiPicker.frame:IsShown(), "B closes the picker first")
    assert(t.input:HasFocus() == true, "the cursor stays in the box")
  end

  -- test_b_leaves_a_pending_reply_in_place
  do
    local changes = {}
    local composer, _, clearComposerFocus = realComposer({
      onReplyChanged = function(replyTo)
        changes[#changes + 1] = replyTo or false
      end,
    })
    local replyTo = { wireId = "w1", direction = "in", author = "A", snippet = "you coming?" }
    composer.setReply(CONTACT.conversationKey, replyTo)
    composer.input:SetFocus()
    assert(clearComposerFocus() == true, "the cursor was in the box")
    assert(changes[#changes] == replyTo, "the reply is still set")
  end

  -- test_inert_nav_sets_no_handler
  eachFlavor(function()
    local t = setup({ inactive = true })
    assert(t.composer.scroll.OnSmartNavClick == nil, "no A handler without the gamepad UI")
    t.input:SetFocus()
    t.close()
    assert(t.state.calls[1] == "close", "B closes as today")
    assert(t.input:HasFocus() == true, "B leaves the cursor alone")
  end)

  -- test_plain_edit_box_sets_no_handler_and_no_b_step
  eachFlavor(function()
    local t = setup({ noScroll = true })
    t.input:SetFocus()
    t.close()
    assert(t.state.calls[1] == "close", "B closes as today")
    assert(t.input:HasFocus() == true, "B leaves the cursor alone")
  end)

  Fonts.Initialize("default")
  print("PASS: test_messenger_window_gamepad_composer")
end
