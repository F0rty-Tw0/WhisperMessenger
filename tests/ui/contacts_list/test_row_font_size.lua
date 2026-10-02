rawset(_G, "time", os.time)
_G.date = os.date

local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ContactsList = require("WhisperMessenger.UI.ContactsList.ContactsList")
local DragController = require("WhisperMessenger.UI.MessengerWindow.DragController")
local ContactsController = require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

local BASE_ROW = Theme.LAYOUT.CONTACT_ROW_HEIGHT
local OPTIONS = { onSelect = function() end, onPin = function() end, onRemove = function() end }

local function item(key)
  return {
    conversationKey = "me::WOW::" .. key,
    displayName = key,
    lastPreview = "hi",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    areaName = "Stormwind",
    pinned = true,
    sortOrder = 1,
  }
end

local function pointY(region)
  local point = region.point
  return point[point.n or #point]
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_row_height_stays_base_at_default_and_smaller_fonts
  Fonts.SetFontSize(12)
  assert(Theme.ContactRowHeight() == BASE_ROW, "12px font keeps the base row")
  Fonts.SetFontSize(9)
  assert(Theme.ContactRowHeight() == BASE_ROW, "small fonts never shrink the row")

  -- test_row_height_grows_three_px_per_font_px_above_default
  Fonts.SetFontSize(14)
  assert(Theme.ContactRowHeight() == BASE_ROW + 6, "14px font adds 6px, got " .. Theme.ContactRowHeight())

  -- test_bound_row_uses_grown_height_and_spacing
  local row = RowView.bindRow(factory, parent, nil, 2, item("Alice"), OPTIONS)
  assert(row.height == BASE_ROW + 6, "row is as tall as the grown height, got " .. tostring(row.height))
  assert(pointY(row) == -(BASE_ROW + 6), "second row starts one grown row down, got " .. tostring(pointY(row)))

  -- test_bound_row_spreads_name_and_preview_apart_by_the_extra_height
  local nameY = Theme.LAYOUT.CONTACT_NAME_OFFSET_Y + 3
  local previewY = Theme.LAYOUT.CONTACT_PREVIEW_OFFSET_Y - 3
  assert(pointY(row.title) == nameY, "name moves up by half the extra, got " .. tostring(pointY(row.title)))
  assert(pointY(row.preview) == previewY, "preview moves down by half the extra, got " .. tostring(pointY(row.preview)))

  -- test_rebind_after_font_shrinks_restores_default_spacing
  Fonts.SetFontSize(12)
  RowView.bindRow(factory, parent, row, 2, item("Alice"), OPTIONS)
  assert(pointY(row.title) == Theme.LAYOUT.CONTACT_NAME_OFFSET_Y, "name back on its default offset")
  assert(pointY(row.preview) == Theme.LAYOUT.CONTACT_PREVIEW_OFFSET_Y, "preview back on its default offset")

  -- test_list_content_height_uses_grown_rows
  Fonts.SetFontSize(14)
  local content = factory.CreateFrame("Frame", nil, nil)
  content:SetSize(260, 10)
  local items = {}
  for i = 1, 20 do
    items[i] = item("C" .. i)
  end
  ContactsList.Refresh(factory, content, {}, items, OPTIONS)
  assert(content.height == 20 * (BASE_ROW + 6), "content fits 20 grown rows, got " .. tostring(content.height))

  -- test_drag_hit_test_uses_grown_rows
  local reordered = false
  local contacts = { item("A"), item("B") }
  contacts[2].sortOrder = 2
  local dragContent = factory.CreateFrame("Frame", nil, nil)
  local handlers = DragController.Create(factory, { content = dragContent, scrollFrame = factory.CreateFrame("Frame") }, function()
    return contacts
  end, {
    onReorder = function()
      reordered = true
    end,
  })
  local savedCursor = _G.GetCursorPosition
  -- 50px down: row 2 with 48px rows, still row 1 with 54px rows.
  rawset(_G, "GetCursorPosition", function()
    return 0, -50
  end)
  local sourceRow = factory.CreateFrame("Frame", nil, dragContent)
  sourceRow.item = contacts[1]
  handlers.handleDragStart(sourceRow, 1)
  handlers.handleDragStop(sourceRow, 1)
  rawset(_G, "GetCursorPosition", savedCursor)
  assert(reordered == false, "a drop inside the first grown row is not a reorder")

  -- test_drag_rereads_row_height_after_font_change
  Fonts.SetFontSize(12)
  local lateHandlers = DragController.Create(factory, { content = dragContent, scrollFrame = factory.CreateFrame("Frame") }, function()
    return contacts
  end, {
    onReorder = function()
      reordered = true
    end,
  })
  Fonts.SetFontSize(14)
  rawset(_G, "GetCursorPosition", function()
    return 0, -50
  end)
  lateHandlers.handleDragStart(sourceRow, 1)
  lateHandlers.handleDragStop(sourceRow, 1)
  rawset(_G, "GetCursorPosition", savedCursor)
  assert(reordered == false, "a font change after the drag controller exists still grows the hit rows")

  -- test_contacts_scroll_step_follows_row_height
  local view = ScrollView.Create(factory, parent, { width = 260, height = 400, step = BASE_ROW })
  local controller = ContactsController.Create(factory, view, { item("A") }, {})
  controller.refresh(nil, nil)
  assert(view.step == BASE_ROW + 6, "wheel step is one grown row, got " .. tostring(view.step))
  assert(view.scrollBar.valueStep == BASE_ROW + 6, "scroll bar step is one grown row, got " .. tostring(view.scrollBar.valueStep))

  -- test_contacts_wheel_notch_scrolls_one_grown_row
  local manyContacts = {}
  for i = 1, 40 do
    manyContacts[i] = item("W" .. i)
  end
  controller.refresh(manyContacts, nil)
  view.scrollFrame:GetScript("OnMouseWheel")(view.scrollFrame, -1)
  local offset = ScrollView.GetOffset(view)
  assert(offset == BASE_ROW + 6, "one notch scrolls one grown row, got " .. tostring(offset))

  Fonts.SetFontSize(12)
  print("PASS: test_row_font_size")
end
