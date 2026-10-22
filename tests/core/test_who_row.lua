local WhoRow = require("WhisperMessenger.Core.WhoRow")

local INFO = { fullName = "Ishtarra", area = "Silvermoon City" }

return function()
  -- test_row_ending_in_area_matches
  do
    local text = "[Ishtarra]: Level 90 Dracthyr Mage <Soldiers of Elune> - Silvermoon City"
    assert(WhoRow.Matches(text, INFO) == true, "a row ending in its area should match")
  end

  -- test_area_inside_longer_zone_does_not_match
  do
    local text = "[Ishtarra]: Level 90 Dracthyr Mage - Silvermoon City Outskirts"
    assert(WhoRow.Matches(text, INFO) == false, "the area inside a longer zone must not match")
  end

  -- test_non_string_text_does_not_match
  do
    assert(WhoRow.Matches(nil, INFO) == false, "a missing line must not match")
  end
end
