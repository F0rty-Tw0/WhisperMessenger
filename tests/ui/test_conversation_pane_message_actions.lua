local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

local DeliveryMenu = require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")

-- The pane passes delivery-menu actions up with the open contact, and
-- redraws the queued bubble when the lock lifts (the message itself did not
-- change), so the menu then offers Send now.
local function openStatusMenu(root)
  local label = FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == "(Queued)" and node.parent.frameType == "Button" and node.parent.shown ~= false
  end)
  assert(label ~= nil, "(Queued) status shown")
  label.parent.scripts.OnClick(label.parent)
  return DeliveryMenu.GetFrame()
end

local function menuButton(menu, text)
  for _, button in ipairs(menu._buttons or {}) do
    if button.shown ~= false and button._label.text == text then
      return button
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local calls = {}
  local pane = ConversationPane.Create(factory, parent, nil, nil, {
    onMessageAction = function(contact, message, action)
      calls[#calls + 1] = { contact = contact, message = message, action = action }
    end,
  })
  local contact = { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" }
  local queued = { direction = "out", kind = "user", text = "gg", sentAt = 10, delivery = "queued" }
  local conversation = { messages = { queued } }

  -- test_locked_pane_hides_send_now
  ConversationPane.Refresh(pane, contact, conversation, nil, "Whispers are paused")
  local menu = openStatusMenu(pane.frame)
  assert(menuButton(menu, "Send now") == nil, "no Send now while the pause notice shows")
  assert(menuButton(menu, "Discard") ~= nil, "Discard while locked")
  DeliveryMenu.Close()

  -- test_lock_lift_redraws_with_send_now
  ConversationPane.Refresh(pane, contact, conversation, nil, nil)
  menu = openStatusMenu(pane.frame)
  local sendButton = menuButton(menu, "Send now")
  assert(sendButton ~= nil, "Send now appears once the notice clears")

  -- test_click_reports_the_open_contact
  sendButton.scripts.OnClick(sendButton)
  assert(#calls == 1 and calls[1].contact == contact and calls[1].message == queued and calls[1].action == "send_now", "action forwarded")

  _G.UIParent = savedUIParent
end
