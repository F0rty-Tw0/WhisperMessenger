local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local Controls = ns.UIHelpersControls or require("WhisperMessenger.UI.Helpers.Controls")

local UIHelpers = {
  TRANSPARENT = Base.TRANSPARENT,
  setBorderEdgesShown = Base.setBorderEdgesShown,
  hoverButtonFill = Base.hoverButtonFill,
  applyHorizontalFade = Base.applyHorizontalFade,
  applyHorizontalFadeLeft = Base.applyHorizontalFadeLeft,
  applyVerticalFade = Base.applyVerticalFade,
  applyVerticalFadeDown = Base.applyVerticalFadeDown,
  createSheen = Shapes.createSheen,
  applySheen = Shapes.applySheen,
  sizeValue = Base.sizeValue,
  createTemplatedFrame = Base.createTemplatedFrame,
  applyColor = Base.applyColor,
  applyColorTexture = Base.applyColorTexture,
  applyBorderBoxColor = Base.applyBorderBoxColor,
  applyVertexColor = Base.applyVertexColor,
  colorEscape = Base.colorEscape,
  applyClassColor = Base.applyClassColor,
  captureFramePosition = Base.captureFramePosition,
  setFontObject = Base.setFontObject,
  setTextColor = Base.setTextColor,
  fitTextWithEllipsis = Base.fitTextWithEllipsis,
  createBorderBox = Shapes.createBorderBox,
  hairlineThickness = Shapes.hairlineThickness,
  snapToPixelGrid = Shapes.snapToPixelGrid,
  polishBadge = Shapes.polishBadge,
  createCircularIcon = Shapes.createCircularIcon,
  resizeCircularIcon = Shapes.resizeCircularIcon,
  createRoundedBackground = Shapes.createRoundedBackground,
  createOptionButton = Controls.createOptionButton,
  createToggleRow = Controls.createToggleRow,
}

ns.UIHelpers = UIHelpers

return UIHelpers
