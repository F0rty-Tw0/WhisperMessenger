local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local Controls = ns.UIHelpersControls or require("WhisperMessenger.UI.Helpers.Controls")

local UIHelpers = {
  sizeValue = Base.sizeValue,
  applyColor = Base.applyColor,
  applyColorTexture = Base.applyColorTexture,
  applyPaneBackground = Base.applyPaneBackground,
  applyBorderBoxColor = Base.applyBorderBoxColor,
  applyVertexColor = Base.applyVertexColor,
  applyClassColor = Base.applyClassColor,
  captureFramePosition = Base.captureFramePosition,
  setFontObject = Base.setFontObject,
  setTextColor = Base.setTextColor,
  createBorderBox = Shapes.createBorderBox,
  createCircularIcon = Shapes.createCircularIcon,
  createRoundedBackground = Shapes.createRoundedBackground,
  createOptionButton = Controls.createOptionButton,
  createToggleRow = Controls.createToggleRow,
}

ns.UIHelpers = UIHelpers

return UIHelpers
