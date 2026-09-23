local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local BlizzardChrome = ns.MessengerWindowChromeBuilderBlizzard or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.BlizzardChrome")
local ModernChrome = ns.MessengerWindowChromeBuilderModern or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")
local Buttons = ns.MessengerWindowChromeBuilderButtons or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")
local ResizeGrip = ns.MessengerWindowChromeBuilderResizeGrip or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ResizeGrip")
local PatchNotesButton = ns.MessengerWindowChromeBuilderPatchNotesButton
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.PatchNotesButton")
local TitleBarLayout = ns.MessengerWindowChromeBuilderTitleBarLayout or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.TitleBarLayout")
local ChromeBuilder = {}

local function applyResizeBounds(frame, parent, theme, windowScale)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, theme, windowScale)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  else
    frame:SetMinResize(minWidth, minHeight)
    if frame.SetMaxResize and maxWidth and maxHeight then
      frame:SetMaxResize(maxWidth, maxHeight)
    end
  end
end

-- ChromeBuilder builds the messenger window with one of two chrome paths,
-- chosen by the Native WoW HUD setting (independent of the color preset):
--
--   * Native WoW HUD: frame uses BasicFrameTemplateWithInset. Gold border,
--     red close X, dark inset, and centered title come from the Blizzard
--     template — we don't paint them ourselves.
--
--   * Custom chrome (default): frame uses BackdropTemplate. We paint a flat
--     background, our own title bar with header bg, a window edge hairline,
--     and a custom close button.
--
-- Returns: { frame, background, title, newConversationButton, patchNotesButton,
--   closeButton, optionsButton, backButton, resizeGrip, applyTheme, refreshScale,
--   setOptionsActive, setPatchNotesGlow } in both cases. Non-chrome
-- layout (rows, composer margins, content positioning) is shared and
-- applied universally by callers regardless of which chrome was built.
function ChromeBuilder.Build(factory, parent, initialState, options)
  options = options or {}
  local normalizedWindowScale = WindowScale.Normalize(options.windowScale)

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
  frame:SetScale(normalizedWindowScale)

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
  applyResizeBounds(frame, parent, Theme, normalizedWindowScale)
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

  -- Chrome differs by setting (Blizzard template vs custom chrome).
  local chromeBranch = useBlizzardChrome and BlizzardChrome or ModernChrome
  local chrome = chromeBranch.Build(factory, frame, options, Theme)
  local title, closeButton = chrome.title, chrome.closeButton
  local applyChromePaint = chrome.applyChromePaint

  local newConv = Buttons.CreateNewConversation(factory, frame, Theme)
  local patchNotes = PatchNotesButton.Create(factory, frame, Theme)
  local options_ = Buttons.CreateOptions(factory, frame, Theme)
  local back = Buttons.CreateBack(factory, frame, Theme)
  local resize = ResizeGrip.Create(factory, frame)
  local titleBarParts = {
    frame = frame,
    titleBar = chrome.titleBar,
    title = title,
    closeButton = closeButton,
    newConversationButton = newConv.button,
    patchNotesButton = patchNotes.button,
    optionsButton = options_.button,
    backButton = back.button,
    blizzardChrome = useBlizzardChrome,
  }

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    TitleBarLayout.Apply(titleBarParts, activeTheme)
    applyChromePaint(activeTheme)
    options_.applyTheme(activeTheme)
    back.applyTheme(activeTheme)
    newConv.applyTheme(activeTheme)
    patchNotes.applyTheme(activeTheme)
    resize.applyTheme(activeTheme)
  end

  local function refreshScale(nextScale)
    local normalizedScale = WindowScale.Normalize(nextScale)
    frame:SetScale(normalizedScale)
    Shapes.refreshHairlines()
    applyResizeBounds(frame, parent, Theme, normalizedScale)
    return normalizedScale
  end

  applyTheme(Theme)
  local function setOptionsActive(active)
    options_.setActive(active)
    if active then
      back.button:Show()
    else
      back.button:Hide()
    end
  end

  return {
    frame = frame,
    background = chrome.background,
    title = title,
    newConversationButton = newConv.button,
    patchNotesButton = patchNotes.button,
    closeButton = closeButton,
    optionsButton = options_.button,
    backButton = back.button,
    resizeGrip = resize.grip,
    applyTheme = applyTheme,
    refreshScale = refreshScale,
    setOptionsActive = setOptionsActive,
    setPatchNotesGlow = patchNotes.setGlowing,
    titleBar = chrome.titleBar,
  }
end

ns.MessengerWindowChromeBuilder = ChromeBuilder

return ChromeBuilder
