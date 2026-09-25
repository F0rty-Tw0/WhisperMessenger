local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Message-request strip above the composer, in the AFK/DND banner slot:
-- a one-line notice plus Accept and Delete. Modern skin uses ghost buttons
-- (Delete in the danger red); Native WoW HUD uses Blizzard's red buttons.
local RequestBanner = {}

local NOTICE_KEY = "Not a friend, guildmate or group member."
local BUTTON_HEIGHT = 20
local BUTTON_WIDTH = 72
local BUTTON_GAP = 6

local function createButton(factory, parent, key, nativeChrome, danger)
  local native = nativeChrome and UIHelpers.createTemplatedFrame(factory, "Button", nil, parent, "UIPanelButtonTemplate")
  if native then
    native:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT + 2)
    native:SetText(Localization.Text(key))
    return native
  end
  local colors = { bg = Theme.COLORS.option_button_bg, text = Theme.COLORS.option_button_text }
  local button = UIHelpers.createOptionButton(factory, parent, Localization.Text(key), colors, {
    height = BUTTON_HEIGHT,
    width = BUTTON_WIDTH,
    ghost = true,
    danger = danger,
  })
  return button
end

local function setButtonText(button, key)
  if button.label then
    button.label:SetText(Localization.Text(key))
  else
    button:SetText(Localization.Text(key))
  end
end

-- options: nativeChrome, onAccept(), onDelete()
function RequestBanner.Create(factory, pane, options)
  options = options or {}
  local frame = factory.CreateFrame("Frame", nil, pane)
  frame:SetHeight(BUTTON_HEIGHT + 4)
  frame:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 2)
  frame:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 2)

  local deleteButton = createButton(factory, frame, "Delete", options.nativeChrome, true)
  deleteButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  local acceptButton = createButton(factory, frame, "Accept", options.nativeChrome, false)
  acceptButton:SetPoint("RIGHT", deleteButton, "LEFT", -BUTTON_GAP, 0)

  local notice = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  notice:SetPoint("LEFT", frame, "LEFT", 0, 0)
  notice:SetPoint("RIGHT", acceptButton, "LEFT", -BUTTON_GAP, 0)
  notice:SetJustifyH("LEFT")
  notice:SetText(Localization.Text(NOTICE_KEY))
  UIHelpers.applyColor(notice, Theme.COLORS.text_system)

  acceptButton:SetScript("OnClick", function()
    if options.onAccept then
      options.onAccept()
    end
  end)
  deleteButton:SetScript("OnClick", function()
    if options.onDelete then
      options.onDelete()
    end
  end)
  frame:Hide()

  local banner = { frame = frame }

  function banner.setShown(shown)
    frame:SetShown(shown == true)
  end

  function banner.setLanguage()
    notice:SetText(Localization.Text(NOTICE_KEY))
    setButtonText(acceptButton, "Accept")
    setButtonText(deleteButton, "Delete")
  end

  function banner.refreshTheme()
    UIHelpers.applyColor(notice, Theme.COLORS.text_system)
    for _, button in ipairs({ acceptButton, deleteButton }) do
      if button.applyThemeColors then
        button.applyThemeColors()
      end
    end
  end

  return banner
end

ns.ConversationPaneRequestBanner = RequestBanner
return RequestBanner
