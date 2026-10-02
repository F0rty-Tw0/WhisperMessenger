local ContactsList = require("WhisperMessenger.UI.ContactsList")
local RowHoverOverlay = require("WhisperMessenger.UI.ContactsList.RowHoverOverlay")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local FakeUI = require("tests.helpers.fake_ui")

local item = {
  conversationKey = "me::WOW::alice",
  displayName = "Alice",
  lastPreview = "hello",
  unreadCount = 0,
  lastActivityAt = 100,
  channel = "WOW",
  pinned = false,
}

local options = {
  onSelect = function() end,
  onPin = function() end,
  onRemove = function() end,
}

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local row = RowView.bindRow(factory, parent, nil, 1, item, options)

  local originalPaint = RowHoverOverlay.paint
  assert(type(originalPaint) == "function", "RowHoverOverlay.paint is the row painter")
  local painted = {}
  rawset(RowHoverOverlay, "paint", function(target)
    painted[#painted + 1] = target
    return originalPaint(target)
  end)

  local function paintedSince(mark)
    for i = mark + 1, #painted do
      if painted[i] == row then
        return true
      end
    end
    return false
  end

  -- test_row_hover_scripts_use_the_painter
  local mark = #painted
  row.mouseOver = true
  row.scripts.OnEnter(row)
  assert(paintedSince(mark), "row OnEnter repaints through RowHoverOverlay.paint")

  -- test_action_button_hover_uses_the_painter
  mark = #painted
  row.removeButton.scripts.OnEnter(row.removeButton)
  assert(paintedSince(mark), "action button hover repaints through RowHoverOverlay.paint")
  row.removeButton.scripts.OnLeave(row.removeButton)
  row.mouseOver = false
  row.scripts.OnLeave(row)

  -- test_set_selected_uses_the_painter
  mark = #painted
  ContactsList.SetSelected({ row }, item.conversationKey)
  assert(paintedSince(mark), "SetSelected repaints through RowHoverOverlay.paint")

  -- test_set_selected_paints_a_row_without_hover_scripts
  local bare = factory.CreateFrame("Button", nil, parent)
  bare.item = item
  bare.bg = bare:CreateTexture(nil, "BACKGROUND")
  mark = #painted
  ContactsList.SetSelected({ bare }, item.conversationKey)
  local found = false
  for i = mark + 1, #painted do
    found = found or painted[i] == bare
  end
  assert(found, "SetSelected paints a bare row through RowHoverOverlay.paint too")

  rawset(RowHoverOverlay, "paint", originalPaint)
  print("PASS: test_row_hover_overlay_paint")
end
