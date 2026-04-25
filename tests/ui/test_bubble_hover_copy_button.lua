local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

local function findCopyButton(frame)
  for _, child in ipairs(frame.children) do
    if child._wmCopyButton == true then
      return child
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)

  local function copySpy()
    local seen = {}
    return seen, function(text)
      seen[#seen + 1] = text
      return true
    end
  end

  -- test_bubble_creates_a_hidden_copy_button
  do
    local seen, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "hello there",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button child on the bubble frame")
    assert(copyBtn.shown == false, "expected the copy button to be hidden by default")
    assert(copyBtn.mouseEnabled == true, "expected the copy button to be mouse-enabled so it receives clicks")
    assert(#seen == 0, "creating the bubble must not trigger a copy")
  end

  -- test_bubble_hover_shows_copy_button_and_leave_hides_it
  do
    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "show me on hover",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button child")

    local onEnter = bubble.frame.scripts and bubble.frame.scripts.OnEnter
    local onLeave = bubble.frame.scripts and bubble.frame.scripts.OnLeave
    assert(type(onEnter) == "function", "expected an OnEnter handler on the bubble frame")
    assert(type(onLeave) == "function", "expected an OnLeave handler on the bubble frame")

    onEnter(bubble.frame)
    assert(copyBtn.shown == true, "OnEnter on the bubble should show the copy button")

    -- Mouse moved off both bubble and button → hide.
    bubble.frame.mouseOver = false
    copyBtn.mouseOver = false
    onLeave(bubble.frame)
    assert(copyBtn.shown == false, "OnLeave on the bubble should hide the copy button")
  end

  -- test_bubble_leave_keeps_copy_button_when_mouse_moved_onto_the_button
  -- WoW fires OnLeave on the parent the moment the mouse enters a mouse-enabled
  -- child. Without this safeguard, the copy button would flicker out the second
  -- the user moved their cursor toward it.
  do
    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "no flicker",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    bubble.frame.scripts.OnEnter(bubble.frame)
    assert(copyBtn.shown == true, "sanity: OnEnter should show the button")

    -- Cursor left the bubble's mouse area but landed on the copy button.
    bubble.frame.mouseOver = false
    copyBtn.mouseOver = true
    bubble.frame.scripts.OnLeave(bubble.frame)
    assert(copyBtn.shown == true, "the copy button must stay visible while the cursor is on it")
  end

  -- test_clicking_the_copy_button_copies_the_bubble_text
  do
    local seen, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "out",
      kind = "user",
      text = "copy me exactly",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button on the outgoing bubble too")
    local onClick = copyBtn.scripts and copyBtn.scripts.OnClick
    assert(type(onClick) == "function", "expected the copy button to wire an OnClick handler")

    onClick(copyBtn, "LeftButton")
    assert(#seen == 1, "expected exactly one copy invocation, got " .. tostring(#seen))
    assert(seen[1] == "copy me exactly", "expected the bubble's text to be copied, got " .. tostring(seen[1]))
  end

  -- test_system_messages_do_not_get_a_copy_button
  -- System notices ("X joined", date dividers, etc.) are not user content; a
  -- copy affordance there is just visual noise.
  do
    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "system",
      text = "Arthas has joined the party.",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn == nil, "system bubbles must not get a copy button")
  end

  -- test_right_click_copy_menu_still_works_alongside_the_hover_button
  -- Regression: adding the hover-copy button must not strip the existing
  -- right-click → "Copy Text" context menu.
  do
    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "right click still works",
    }, { paneWidth = 400, copyText = copyText })

    local mouseUp = bubble.frame.scripts and bubble.frame.scripts.OnMouseUp
    local mouseDown = bubble.frame.scripts and bubble.frame.scripts.OnMouseDown
    assert(type(mouseUp) == "function", "OnMouseUp handler should still be present")
    assert(type(mouseDown) == "function", "OnMouseDown handler should still be present")
  end

  -- test_copy_button_shows_a_copy_text_tooltip_on_hover
  do
    local owner, ownerAnchor, lastText, hidden
    local savedTooltip = _G.GameTooltip
    _G.GameTooltip = {
      SetOwner = function(self, o, a)
        owner, ownerAnchor = o, a
      end,
      SetText = function(self, t)
        lastText = t
      end,
      Show = function()
        hidden = false
      end,
      Hide = function()
        hidden = true
      end,
    }

    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "with tooltip",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button")
    local btnEnter = copyBtn.scripts and copyBtn.scripts.OnEnter
    local btnLeave = copyBtn.scripts and copyBtn.scripts.OnLeave
    assert(type(btnEnter) == "function", "expected OnEnter on the copy button")
    assert(type(btnLeave) == "function", "expected OnLeave on the copy button")

    btnEnter(copyBtn)
    assert(owner == copyBtn, "expected the tooltip to be anchored to the copy button")
    assert(ownerAnchor ~= nil, "expected an anchor argument to SetOwner")
    assert(lastText == "Copy text", "expected the tooltip text 'Copy text', got " .. tostring(lastText))
    assert(hidden == false, "expected the tooltip to be shown on hover")

    bubble.frame.mouseOver = false
    btnLeave(copyBtn)
    assert(hidden == true, "expected the tooltip to be hidden when leaving the copy button")

    _G.GameTooltip = savedTooltip
  end

  -- test_copy_button_uses_persistent_factory_not_the_pooled_factory
  -- Regression: in production, `factory` is the FramePool wrapper that pops
  -- arbitrary frames off `_freeFrames` ignoring frameType and parent. Using
  -- it for the copy button hijacks a pooled avatar/label frame — the user
  -- saw the class icon disappear and no copy icon appear. The button must
  -- come from a non-pooled "persistent" factory instead.
  do
    local pooledFactory = FakeUI.NewFactory()
    local persistentFactory = FakeUI.NewFactory()
    local pooledCalls = 0
    local persistentCalls = 0

    local pooledWrapper = {
      CreateFrame = function(frameType, name, p)
        pooledCalls = pooledCalls + 1
        return pooledFactory.CreateFrame(frameType, name, p)
      end,
    }
    local persistentWrapper = {
      CreateFrame = function(frameType, name, p)
        persistentCalls = persistentCalls + 1
        return persistentFactory.CreateFrame(frameType, name, p)
      end,
    }

    local _, copyText = copySpy()
    local bubble = BubbleFrame.CreateBubble(pooledWrapper, parent, {
      direction = "in",
      kind = "user",
      text = "the right factory please",
    }, {
      paneWidth = 400,
      copyText = copyText,
      persistentFactory = persistentWrapper,
    })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button child")
    assert(persistentCalls > 0, "expected the persistent factory to create the copy button — got 0 calls")
  end
end
