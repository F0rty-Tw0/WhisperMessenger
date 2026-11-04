local PreviewMetrics = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local Card = require("tests.helpers.preview_reply_card")

local function showWithoutRow(state)
  state.card.setIncomingPreview("Jaina", "Need help?", "MAGE", nil)
end

local function assertPoint(frame, expected, label)
  local point = { frame:GetPoint() }
  for i = 1, 5 do
    assert(point[i] == expected[i], label .. ": point arg " .. i .. " is " .. tostring(expected[i]) .. ", got " .. tostring(point[i]))
  end
end

return function()
  local function test_row_adds_its_height_and_centers_the_icon_on_the_text()
    local state = Card.Build()
    showWithoutRow(state)
    local heightWithoutRow = state.card.frame:GetHeight()
    Card.ShowJaina(state)
    local frame = state.card.frame
    local rowHeight = state.card.replyHold.row.height()
    assert(frame:GetHeight() == heightWithoutRow + rowHeight, "the row adds its height, got " .. tostring(frame:GetHeight()))
    assert(frame:GetWidth() >= PreviewMetrics.REPLY_MIN_WIDTH, "the card is wide enough to type in, got " .. tostring(frame:GetWidth()))
    assertPoint(state.card.classIconFrame, { "LEFT", frame, "TOPLEFT", PreviewMetrics.LEFT_PAD, -heightWithoutRow / 2 }, "row shown")
  end

  local function test_update_without_meta_restores_the_plain_card()
    local state = Card.Build()
    showWithoutRow(state)
    local heightWithoutRow = state.card.frame:GetHeight()
    Card.ShowJaina(state)
    showWithoutRow(state)
    local frame = state.card.frame
    assert(frame:GetHeight() == heightWithoutRow, "the height drops back, got " .. tostring(frame:GetHeight()))
    assertPoint(state.card.classIconFrame, { "LEFT", frame, "LEFT", PreviewMetrics.LEFT_PAD, 0 }, "row hidden")
  end

  local function countClearAllPoints(frame)
    local counter = { calls = 0 }
    local original = frame.ClearAllPoints
    frame.ClearAllPoints = function(...)
      counter.calls = counter.calls + 1
      return original(...)
    end
    return counter
  end

  local function test_same_shape_update_keeps_the_icon_anchor()
    local state = Card.Build()
    showWithoutRow(state)
    local plainCounter = countClearAllPoints(state.card.classIconFrame)
    state.card.setIncomingPreview("Jaina", "Still there?", "MAGE", nil)
    assert(plainCounter.calls == 0, "a plain card update keeps the icon anchor, got " .. plainCounter.calls)
    Card.ShowJaina(state)
    local rowCounter = countClearAllPoints(state.card.classIconFrame)
    Card.ShowJaina(state, Card.Jaina(600))
    assert(rowCounter.calls == 0, "a same-size row update keeps the icon anchor, got " .. rowCounter.calls)
  end

  test_row_adds_its_height_and_centers_the_icon_on_the_text()
  test_update_without_meta_restores_the_plain_card()
  test_same_shape_update_keeps_the_icon_anchor()
end
