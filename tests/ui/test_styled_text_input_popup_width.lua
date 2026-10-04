local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

-- Classic clients' StaticPopup widens the dialog from its current width when
-- editBoxWidth is over 260, so a reused popup grows on every open and the
-- stretched input runs past its edges. Retail sizes from a fixed minimum.
return function()
  local wasRetail = FlavorCompat.isRetail

  -- test_classic_popup_input_stays_within_blizzards_fixed_width
  FlavorCompat.isRetail = false
  assert(StyledTextInputPopup.NewDialog().editBoxWidth <= 260, "Classic: no edit box width that makes the dialog grow")

  -- test_retail_popup_keeps_the_wide_input
  FlavorCompat.isRetail = true
  assert(StyledTextInputPopup.NewDialog().editBoxWidth == 340, "Retail: wide input kept")

  FlavorCompat.isRetail = wasRetail
end
