local Base = require("WhisperMessenger.UI.Helpers.Base")

-- Fake label: width is 7 per byte; counts how often the width is measured.
local function makeLabel()
  local label = { text = "", measures = 0 }
  function label:SetText(text)
    self.text = text
  end
  function label:GetStringWidth()
    self.measures = self.measures + 1
    return #self.text * 7
  end
  return label
end

return function()
  -- test_long_text_is_measured_a_logarithmic_number_of_times
  -- Every measure is a SetText + GetStringWidth round trip in game; trying
  -- each length from the end cost one per character.
  do
    local label = makeLabel()
    local text = string.rep("abcdefgh", 8) -- 64 characters
    local fitted = Base.fitTextWithEllipsis(label, text, 70)
    assert(fitted == "abcdefg...", "expected the 7-character cut, got " .. fitted)
    assert(label.measures <= 10, "expected at most 10 measures, got " .. label.measures)
  end

  -- test_search_picks_the_longest_fitting_prefix_for_every_width
  -- Same answers as trying every length from the end.
  do
    local text = "Thrall-Draenor  -  |cffffff00Level 80|r Shaman  -  Horde"
    for width = 1, #text * 7 do
      local fitted = Base.fitTextWithEllipsis(makeLabel(), text, width)
      local label = makeLabel()
      label:SetText(fitted)
      assert(label:GetStringWidth() <= width or fitted == "...", "width " .. width .. " overflowed: " .. fitted)
      if fitted ~= text and fitted ~= "..." then
        -- One more visible character must not fit.
        local longer = Base.fitTextWithEllipsis(makeLabel(), text, width + 7)
        assert(#longer >= #fitted, "width " .. width .. " is not the longest cut")
      end
    end
  end
end
