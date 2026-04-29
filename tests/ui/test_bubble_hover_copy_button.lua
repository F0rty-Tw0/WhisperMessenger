local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

local function findCopyButton(frame)
  -- The button is now parented to the bubble's parent (sibling of the
  -- bubble), but still tracked on the bubble via _copyButton.
  if frame._copyButton then
    return frame._copyButton
  end
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

  -- test_button_leave_does_not_hide_unrelated_tooltip
  -- Regression: hovering an item link inside a chat bubble shows the WoW
  -- item tooltip via the bubble's OnHyperlinkEnter. While that tooltip is
  -- visible, the cursor can briefly cross over (or end up under) the hover
  -- copy button at the bubble corner — especially under custom fonts
  -- (System / Morpheus) where text wraps differently and links land near
  -- the corner. When the button's OnLeave fires, it must NOT dismiss a
  -- tooltip owned by anything other than the button itself; otherwise the
  -- item tooltip vanishes the moment the cursor moves between the link and
  -- the button.
  do
    local savedTooltip = _G.GameTooltip
    local currentOwner, hidden, anchor
    _G.GameTooltip = {
      SetOwner = function(self, o, a)
        currentOwner, anchor = o, a
        hidden = false
      end,
      GetOwner = function()
        return currentOwner
      end,
      SetText = function() end,
      SetHyperlink = function() end,
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
      text = "|Hitem:6948|h[Hearthstone]|h",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(bubble.frame)
    assert(copyBtn ~= nil, "expected a copy button on the bubble")
    local btnLeave = copyBtn.scripts and copyBtn.scripts.OnLeave
    assert(type(btnLeave) == "function", "expected OnLeave on the copy button")

    -- Simulate the bubble's hyperlink handler claiming the tooltip first.
    _G.GameTooltip:SetOwner(bubble.frame, "ANCHOR_CURSOR")
    _G.GameTooltip:Show()
    assert(hidden == false, "sanity: bubble's hyperlink tooltip must be visible")

    -- Cursor moves to the button area, then leaves it. The button's OnLeave
    -- must not yank the bubble's tooltip out from under the cursor.
    bubble.frame.mouseOver = false
    btnLeave(copyBtn)
    assert(hidden == false, "button OnLeave must not hide a tooltip owned by another frame (the bubble's hyperlink hover)")
    assert(currentOwner == bubble.frame, "tooltip owner should remain the bubble after button OnLeave")
    assert(anchor == "ANCHOR_CURSOR", "tooltip anchor should remain ANCHOR_CURSOR")

    _G.GameTooltip = savedTooltip
  end

  -- test_copy_button_renders_above_sender_name_and_time
  -- Regression: on short bubbles the copy icon sits inside the bubble's top
  -- corner, where the sender-name/timestamp strip above the bubble can pass
  -- through. The button must render on a stratum/level above sibling label
  -- frames so the name and time text never cover it.
  do
    local _, copyText = copySpy()
    local incoming = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "hi",
    }, { paneWidth = 400, copyText = copyText })

    local inBtn = findCopyButton(incoming.frame)
    assert(inBtn ~= nil, "expected a copy button on the incoming bubble")
    -- Inside the bubble's top-right corner.
    local inPoint, _inRel, inRelPoint, inX = inBtn:GetPoint()
    assert(inPoint == "TOPRIGHT", "incoming button should anchor by its TOPRIGHT, got " .. tostring(inPoint))
    assert(inRelPoint == "TOPRIGHT", "incoming button should anchor to the bubble's TOPRIGHT (inside), got " .. tostring(inRelPoint))
    assert((inX or 0) <= 0, "expected non-positive X offset to keep the button inside the bubble")
    assert(
      inBtn.frameStrata == "HIGH",
      "expected the copy button to live on the HIGH strata so it renders above the sender label and time text, got " .. tostring(inBtn.frameStrata)
    )

    local _, copyText2 = copySpy()
    local outgoing = BubbleFrame.CreateBubble(factory, parent, {
      direction = "out",
      kind = "user",
      text = "hi",
    }, { paneWidth = 400, copyText = copyText2 })

    local outBtn = findCopyButton(outgoing.frame)
    assert(outBtn ~= nil, "expected a copy button on the outgoing bubble")
    local outPoint, _outRel, outRelPoint, outX = outBtn:GetPoint()
    assert(outPoint == "TOPLEFT", "outgoing button should anchor by its TOPLEFT, got " .. tostring(outPoint))
    assert(outRelPoint == "TOPLEFT", "outgoing button should anchor to the bubble's TOPLEFT (inside), got " .. tostring(outRelPoint))
    assert((outX or 0) >= 0, "expected non-negative X offset to keep the button inside the bubble")
    assert(outBtn.frameStrata == "HIGH", "expected the outgoing copy button on HIGH strata too")
  end

  -- test_copy_button_z_order_is_reasserted_every_render
  -- Regression: every other message had its copy button drawn behind the
  -- bubble after pool recycling promoted/demoted strata or shuffled levels.
  -- attachHoverCopy must re-assert the button's strata + level + Raise() on
  -- every render so the icon is unconditionally on top.
  do
    local _, copyText = copySpy()
    local first = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "first render",
    }, { paneWidth = 400, copyText = copyText })

    local copyBtn = findCopyButton(first.frame)
    assert(copyBtn ~= nil, "expected a copy button on first render")
    assert(copyBtn.frameStrata == "HIGH", "first render should leave button on HIGH strata")
    local raisedAfterFirst = copyBtn.raisedCount or 0
    assert(raisedAfterFirst >= 1, "expected the button to be raised on first render, got " .. tostring(raisedAfterFirst))

    -- Simulate a pool-reuse render: someone tampers with the strata between
    -- renders (mirrors the messenger window promoting itself to HIGH/MEDIUM
    -- when the user clicks on/off the window).
    copyBtn:SetFrameStrata("MEDIUM")

    -- Re-acquire on the same frame as if the pool returned it. CreateBubble
    -- with the same parent + frame should call attachHoverCopy again, which
    -- must re-assert HIGH and call Raise() again.
    local sameFrameFactory = {
      CreateFrame = function()
        return first.frame
      end,
    }
    BubbleFrame.CreateBubble(sameFrameFactory, parent, {
      direction = "in",
      kind = "user",
      text = "second render",
    }, { paneWidth = 400, copyText = copyText, persistentFactory = factory })

    assert(copyBtn.frameStrata == "HIGH", "expected strata re-asserted to HIGH on every render, got " .. tostring(copyBtn.frameStrata))
    assert((copyBtn.raisedCount or 0) > raisedAfterFirst, "expected Raise() to be called again on re-render, got " .. tostring(copyBtn.raisedCount))
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
