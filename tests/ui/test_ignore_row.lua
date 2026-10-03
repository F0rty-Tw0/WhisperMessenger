local FakeUI = require("tests.helpers.fake_ui")
local IgnoreRow = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreRow")

local function pointTo(region, relativeTo)
  for _, point in ipairs(region.points or {}) do
    if point[2] == relativeTo then
      return point
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local list = factory.CreateFrame("Frame", nil, nil)
  local row = IgnoreRow.Create(factory, list, function() end)

  -- test_remove_button_sits_on_the_top_line
  -- Centred on the two-line row it hung below the name and count.
  do
    local point = row.removeButton.points[#row.removeButton.points]
    assert(point[1] == "TOPRIGHT" and point[2] == row and point[3] == "TOPRIGHT", "remove button anchors to the row's top right")
  end

  -- test_blocked_count_is_centred_on_the_remove_button
  do
    local point = pointTo(row.blockedText, row.removeButton)
    assert(point and point[1] == "RIGHT" and point[3] == "LEFT", "blocked count sits left of the button, same centre line")
  end

  -- test_name_shares_the_top_line_centre
  do
    local point = pointTo(row.nameText, row)
    local buttonCentre = -(require("WhisperMessenger.UI.Shared.RemoveButton").SIZE / 2)
    assert(point and point[1] == "LEFT" and point[3] == "TOPLEFT" and point[5] == buttonCentre, "name centred on the button's line")
  end
end
