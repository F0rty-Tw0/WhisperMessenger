local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local Grouping = require("WhisperMessenger.UI.ChatBubble.Grouping")
local Localization = require("WhisperMessenger.Locale.Localization")
local DeliveryMenu = require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")

-- Outgoing bubbles that did not go out show "(Queued)" / "(Not sent)" next
-- to the timestamp. Clicking it opens a small menu (Send now / Retry /
-- Discard). Normal sends show nothing extra.

local function outgoing(text, sentAt, delivery)
  return { direction = "out", kind = "user", text = text, sentAt = sentAt, delivery = delivery, playerName = "Thrall", senderName = "Me" }
end

local function visible(region)
  return region ~= nil and region.shown ~= false
end

local function findVisibleText(root, text)
  for _, child in ipairs(root.children or {}) do
    -- Pooled label frames are never shown explicitly (fake frames start
    -- hidden); a button owner must be shown though.
    if child.text == text and visible(child) and (root.frameType ~= "Button" or visible(root)) then
      return child, root
    end
    local found, owner = findVisibleText(child, text)
    if found then
      return found, owner
    end
  end
  return nil
end

local function findBubble(root, text)
  for _, child in ipairs(root.children or {}) do
    if child._textFS and child._textFS.text == text then
      return child
    end
  end
  return nil
end

-- Visible menu button labelled `text`. Checks the button, not its label:
-- fake font strings start hidden, real ones start shown.
local function menuButton(menu, text)
  for _, button in ipairs(menu._buttons or {}) do
    if button.shown ~= false and button._label.text == text then
      return button
    end
  end
  return nil
end

-- Clicks the header status and returns the open menu frame.
local function openStatusMenu(content, statusText)
  local _, statusButton = findVisibleText(content, statusText)
  assert(statusButton ~= nil and statusButton.frameType == "Button", "status is clickable")
  statusButton.scripts.OnClick(statusButton)
  local menu = DeliveryMenu.GetFrame()
  assert(menu ~= nil and menu.shown == true, "status click opens the menu")
  return menu
end

local function layout(messages, options)
  local factory = FakeUI.NewFactory()
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(400, 600)
  Layout.LayoutMessages(factory, content, messages, 400, options or {})
  return content
end

return function()
  Localization.Configure({ language = "enUS" })
  local savedUIParent = _G.UIParent
  _G.UIParent = FakeUI.NewFactory().CreateFrame("Frame", "UIParent", nil)

  -- test_unsent_messages_never_group
  do
    assert(Grouping.ShouldGroup(outgoing("a", 0), outgoing("b", 1)) == true, "normal sends still group")
    assert(Grouping.ShouldGroup(outgoing("a", 0), outgoing("b", 1, "queued")) == false, "a queued message gets its own label")
    assert(Grouping.ShouldGroup(outgoing("a", 0, "failed"), outgoing("b", 1)) == false, "a message after a failed one starts a group")
  end

  -- test_normal_send_shows_no_status
  do
    local content = layout({ outgoing("hi", 0) })
    assert(findVisibleText(content, "(Queued)") == nil and findVisibleText(content, "(Not sent)") == nil, "no status on a normal send")
  end

  -- test_status_sits_in_the_header_with_no_buttons_around_it
  do
    local content = layout({ outgoing("oops", 0, "failed") }, { onMessageAction = function() end })
    local _, statusButton = findVisibleText(content, "(Not sent)")
    local _, header = findVisibleText(content, "You")
    assert(header ~= nil and statusButton ~= nil and statusButton:GetParent() == header, "status sits in the sender header")
    assert(findVisibleText(content, "Retry") == nil and findVisibleText(content, "Discard") == nil, "actions stay in the menu")
  end

  -- test_failed_message_menu_offers_retry_then_discard
  do
    local actions = {}
    local content = layout({ outgoing("oops", 0, "failed") }, {
      onMessageAction = function(message, action)
        actions[#actions + 1] = { message = message, action = action }
      end,
    })
    local menu = openStatusMenu(content, "(Not sent)")
    local retryButton = menuButton(menu, "Retry")
    assert(retryButton ~= nil and menuButton(menu, "Discard") ~= nil, "Retry and Discard offered")
    retryButton.scripts.OnClick(retryButton)
    assert(#actions == 1 and actions[1].action == "retry" and actions[1].message.text == "oops", "Retry reports the message")
    assert(menu.shown == false, "picking an action closes the menu")
  end

  -- test_locked_queued_message_menu_offers_discard_only
  do
    local actions = {}
    local content = layout({ outgoing("later", 0, "queued") }, {
      chatLocked = true,
      onMessageAction = function(_message, action)
        actions[#actions + 1] = action
      end,
    })
    local menu = openStatusMenu(content, "(Queued)")
    assert(menuButton(menu, "Send now") == nil, "no Send now while locked")
    local discardButton = menuButton(menu, "Discard")
    assert(discardButton ~= nil, "Discard offered")
    discardButton.scripts.OnClick(discardButton)
    assert(actions[1] == "discard", "Discard reports its action")
  end

  -- test_unlocked_queued_message_menu_offers_send_now
  do
    local actions = {}
    local content = layout({ outgoing("later", 0, "queued") }, {
      chatLocked = false,
      onMessageAction = function(_message, action)
        actions[#actions + 1] = action
      end,
    })
    local menu = openStatusMenu(content, "(Queued)")
    local sendButton = menuButton(menu, "Send now")
    assert(sendButton ~= nil, "Send now once the lock lifted")
    sendButton.scripts.OnClick(sendButton)
    assert(actions[1] == "send_now", "Send now reports its action")
  end

  -- test_old_blocked_message_menu_offers_discard_only
  do
    local content = layout({ outgoing("old", 0, "blocked") }, { onMessageAction = function() end })
    local menu = openStatusMenu(content, "(Not sent)")
    assert(menuButton(menu, "Discard") ~= nil and menuButton(menu, "Retry") == nil, "Discard only")
  end

  -- test_unsent_message_adds_no_extra_line
  do
    local normal = Layout.EstimateRowHeight(nil, outgoing("hi", 0), 400, true)
    local failed = Layout.EstimateRowHeight(nil, outgoing("hi", 0, "failed"), 400, true)
    assert(failed == normal, "same height as a normal send")
  end

  -- test_unsent_bubble_is_dimmed
  do
    local sent = findBubble(layout({ outgoing("hi", 0) }), "hi")
    local failed = findBubble(layout({ outgoing("hi", 0, "failed") }), "hi")
    assert(sent ~= nil and failed ~= nil, "both bubbles rendered")
    assert(failed._bgFills[1].color[4] < sent._bgFills[1].color[4], "unsent bubble fades")
  end

  -- test_recycled_label_drops_the_status
  do
    local factory = FakeUI.NewFactory()
    local content = factory.CreateFrame("Frame", nil, nil)
    content:SetSize(400, 600)
    Layout.LayoutMessages(factory, content, { outgoing("x", 0, "queued") }, 400, { onMessageAction = function() end })
    Layout.LayoutMessages(factory, content, { outgoing("y", 0) }, 400, { onMessageAction = function() end })
    assert(findVisibleText(content, "(Queued)") == nil, "pooled label cleared")
  end

  DeliveryMenu.Close()
  _G.UIParent = savedUIParent
end
