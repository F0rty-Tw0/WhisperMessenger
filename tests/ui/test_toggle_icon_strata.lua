local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

return function()
  -- The toggle icon and its incoming-message preview must float above
  -- action bars, bags, and other MEDIUM-strata frames. Without an explicit
  -- HIGH strata, both inherit MEDIUM and can render behind those frames.
  local factory = FakeUI.NewFactory()
  local icon = ToggleIcon.Create(factory, {})

  assert(
    icon.frame.frameStrata == "HIGH",
    "expected toggle icon frame to use HIGH strata so it stays above action bars/bags; got " .. tostring(icon.frame.frameStrata)
  )
  assert(
    icon.previewFrame.frameStrata == "HIGH",
    "expected incoming preview frame to use HIGH strata so it stays above action bars/bags; got " .. tostring(icon.previewFrame.frameStrata)
  )

  -- test_widget_strata_setting_applies_at_create
  local lowIcon = ToggleIcon.Create(FakeUI.NewFactory(), {
    getWidgetStrata = function()
      return "LOW"
    end,
  })
  assert(lowIcon.frame.frameStrata == "LOW", "expected the Widget layer setting to set the frame strata; got " .. tostring(lowIcon.frame.frameStrata))
  assert(lowIcon.previewFrame.frameStrata == "HIGH", "expected the preview card to stay HIGH; got " .. tostring(lowIcon.previewFrame.frameStrata))

  -- test_unknown_widget_strata_falls_back_to_high
  local junkIcon = ToggleIcon.Create(FakeUI.NewFactory(), {
    getWidgetStrata = function()
      return "TOOLTIP"
    end,
  })
  assert(junkIcon.frame.frameStrata == "HIGH", "expected an unknown strata to fall back to HIGH; got " .. tostring(junkIcon.frame.frameStrata))

  -- test_apply_strata_changes_the_frame_strata_now
  lowIcon.applyStrata("MEDIUM")
  assert(lowIcon.frame.frameStrata == "MEDIUM", "expected applyStrata to set the frame strata; got " .. tostring(lowIcon.frame.frameStrata))

  print("  All toggle icon strata tests passed")
end
