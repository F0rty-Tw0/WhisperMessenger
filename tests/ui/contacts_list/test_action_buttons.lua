local ActionButtons = require("WhisperMessenger.UI.ContactsList.ActionButtons")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local item = {
    conversationKey = "me::WOW::alice",
    displayName = "Alice",
    lastPreview = "hello",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    classTag = nil,
    pinned = false,
  }

  local function makeRow()
    local row = factory.CreateFrame("Button", nil, parent)
    row.item = item
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    return row
  end

  local function makeOptions(callbacks)
    return {
      onRemove = callbacks.onRemove or function() end,
      onPin = callbacks.onPin or function() end,
    }
  end

  -- test_show_actions_shows_button_frames
  do
    local row = makeRow()
    local options = makeOptions({})
    local parentWidth = 260
    row.removeButton = ActionButtons.createRemoveButton(factory, row, parentWidth, options)
    row.pinButton = ActionButtons.createPinButton(factory, row, item, parentWidth, options)
    row.removeButton:Hide()
    row.pinButton:Hide()
    ActionButtons.showActions(row)
    assert(row.removeButton:IsShown() == true, "showActions should show removeButton")
    assert(row.pinButton:IsShown() == true, "showActions should show pinButton")
  end

  -- test_hide_actions_hides_button_frames
  do
    local row = makeRow()
    local options = makeOptions({})
    local parentWidth = 260
    row.removeButton = ActionButtons.createRemoveButton(factory, row, parentWidth, options)
    row.pinButton = ActionButtons.createPinButton(factory, row, item, parentWidth, options)
    row.removeButton:Show()
    row.pinButton:Show()
    ActionButtons.hideActions(row)
    assert(row.removeButton:IsShown() == false, "hideActions should hide removeButton")
    assert(row.pinButton:IsShown() == false, "hideActions should hide pinButton")
  end

  -- test_create_remove_button_returns_frame
  do
    local row = makeRow()
    local options = makeOptions({})
    local btn = ActionButtons.createRemoveButton(factory, row, 260, options)
    assert(btn ~= nil, "createRemoveButton should return a frame")
    assert(btn.icon ~= nil, "remove button should have icon texture")
  end

  -- test_create_pin_button_returns_frame
  do
    local row = makeRow()
    local options = makeOptions({})
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, options)
    local btn = ActionButtons.createPinButton(factory, row, item, 260, options)
    assert(btn ~= nil, "createPinButton should return a frame")
    assert(btn.icon ~= nil, "pin button should have icon texture")
  end

  -- test_remove_button_click_calls_on_remove
  do
    local called = nil
    local row = makeRow()
    local options = makeOptions({
      onRemove = function(it)
        called = it.conversationKey
      end,
    })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, options)
    local onClick = row.removeButton.scripts and row.removeButton.scripts.OnClick
    assert(onClick ~= nil, "removeButton should have OnClick")
    onClick(row.removeButton)
    assert(called == "me::WOW::alice", "onRemove should be called with item, got: " .. tostring(called))
  end

  -- test_pin_button_click_calls_on_pin
  do
    local called = nil
    local row = makeRow()
    local options = makeOptions({
      onPin = function(it)
        called = it.conversationKey
      end,
    })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, options)
    row.pinButton = ActionButtons.createPinButton(factory, row, item, 260, options)
    local onClick = row.pinButton.scripts and row.pinButton.scripts.OnClick
    assert(onClick ~= nil, "pinButton should have OnClick")
    onClick(row.pinButton)
    assert(called == "me::WOW::alice", "onPin should be called with item, got: " .. tostring(called))
  end

  print("PASS: test_action_buttons")
end
