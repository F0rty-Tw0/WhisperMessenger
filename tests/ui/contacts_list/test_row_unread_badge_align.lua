local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local FakeUI = require("tests.helpers.fake_ui")

-- The row's unread badge shares the timestamp's right edge, so it lines up
-- under the time instead of hugging the pane divider.

local function pointX(region, pointName)
  for _, point in ipairs(region.points or {}) do
    if point[1] == pointName then
      return point[4]
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)

  -- test_unread_badge_right_edge_matches_timestamp
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local label = RowElements.createTimestamp(row, { lastActivityAt = 0 }, {
      TimeFormat = {
        ContactPreview = function()
          return "now"
        end,
      },
    })
    local badge = RowElements.createUnreadBadge(factory, row)
    local timeRight = pointX(label, "TOPRIGHT")
    local badgeRight = pointX(badge.frame, "BOTTOMRIGHT")
    assert(timeRight ~= nil and badgeRight ~= nil, "both anchor to the row's right edge")
    assert(badgeRight == timeRight, "badge right edge " .. tostring(badgeRight) .. " should match timestamp " .. tostring(timeRight))
  end
end
