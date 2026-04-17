local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local BlizzardChrome = ns.MessengerWindowChromeBuilderBlizzard
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.BlizzardChrome")
local ModernChrome = ns.MessengerWindowChromeBuilderModern
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")
local Buttons = ns.MessengerWindowChromeBuilderButtons
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor
local ChromeBuilder = {}

-- ChromeBuilder builds the messenger window with one of two chrome paths
-- depending on the active skin (resolved from the active theme preset):
--
--   * BLIZZARD skin (Azeroth preset): frame uses BasicFrameTemplateWithInset.
--     Gold border, red close X, dark inset, and centered title come from
--     the Blizzard template — we don't paint them ourselves.
--
--   * MODERN skin (any other preset): frame uses BackdropTemplate. We paint
--     a custom flat-color background, our own title bar with header bg +
--     borders, edge highlights, and a custom close button. This is the
--     pre-Azeroth chrome, restored as an explicit branch so non-native
--     presets keep their modern minimal look.
--
-- Returns: { frame, background, title, newConversationButton, closeButton,
--   optionsButton, resizeGrip, applyTheme } in both cases. Non-chrome
-- layout (rows, composer margins, content positioning) is shared and
-- applied universally by callers regardless of which chrome was built.
function ChromeBuilder.Build(factory, parent, initialState, options)
  options = options or {}

  -- Chrome choice is now controlled by an explicit setting passed in
  -- `options.useNativeChrome` (independent of the color preset). Falls
  -- back to false (modern chrome) if the caller didn't pass it.
  local useBlizzardChrome = options.useNativeChrome == true

  local frame
  if useBlizzardChrome then
    frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BasicFrameTemplateWithInset")
  else
    -- BackdropTemplate mixin makes :SetBackdrop available on Retail 9.0+
    -- (the modern path doesn't use SetBackdrop today, but keeping the mixin
    -- lets us paint a backdrop later without recreating the frame).
    frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BackdropTemplate")
  end

  frame:SetSize(initialState.width or Theme.WINDOW_WIDTH, initialState.height or Theme.WINDOW_HEIGHT)
  frame:SetPoint(
    initialState.anchorPoint or "CENTER",
    parent,
    initialState.relativePoint or initialState.anchorPoint or "CENTER",
    initialState.x or 0,
    initialState.y or 0
  )
  if frame.SetFrameStrata then
    frame:SetFrameStrata("MEDIUM")
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetResizable(true)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, Theme)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  else
    frame:SetMinResize(minWidth, minHeight)
    if frame.SetMaxResize and maxWidth and maxHeight then
      frame:SetMaxResize(maxWidth, maxHeight)
    end
  end
  frame:SetClampedToScreen(true)

  local frameName = frame.GetName and frame:GetName() or frame.name
  if type(_G.UISpecialFrames) == "table" and frameName ~= nil then
    local alreadyRegistered = false
    for _, specialFrameName in ipairs(_G.UISpecialFrames) do
      if specialFrameName == frameName then
        alreadyRegistered = true
        break
      end
    end
    if not alreadyRegistered then
      table.insert(_G.UISpecialFrames, frameName)
    end
  end

  if frame.SetAlpha then
    frame:SetAlpha(Theme.WINDOW_IDLE_ALPHA)
  else
    frame.alpha = Theme.WINDOW_IDLE_ALPHA
  end

  -- Chrome differs by skin (Blizzard template vs custom modern chrome).
  local chromeBranch = useBlizzardChrome and BlizzardChrome or ModernChrome
  local chrome = chromeBranch.Build(factory, frame, options, Theme)
  local title, closeButton = chrome.title, chrome.closeButton
  local applyChromePaint = chrome.applyChromePaint

  local newConv = Buttons.CreateNewConversation(factory, frame, title, useBlizzardChrome, Theme)
  local options_ = Buttons.CreateOptions(factory, frame, closeButton, Theme)
  local resize = Buttons.CreateResizeGrip(factory, frame, Theme)

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    applyChromePaint(activeTheme)
    applyVertexColor(options_.icon, activeTheme.COLORS.text_secondary)
    applyVertexColor(newConv.icon, activeTheme.COLORS.text_primary)
    local hover = activeTheme.COLORS.bg_contact_hover
    applyColorTexture(newConv.bg, { hover[1], hover[2], hover[3], 0.35 })
    local secondary = activeTheme.COLORS.text_secondary
    local gripColor = { secondary[1], secondary[2], secondary[3], 0.4 }
    for _, line in ipairs(resize.lines) do
      applyColorTexture(line, gripColor)
    end
  end

  applyTheme(Theme)

  return {
    frame = frame,
    background = chrome.background,
    title = title,
    newConversationButton = newConv.button,
    closeButton = closeButton,
    optionsButton = options_.button,
    resizeGrip = resize.grip,
    applyTheme = applyTheme,
    titleBarBorder = chrome.titleBarBorder,
    titleBarTopBorder = chrome.titleBarBorder and chrome.titleBarBorder.top or nil,
  }
end

ns.MessengerWindowChromeBuilder = ChromeBuilder

return ChromeBuilder
