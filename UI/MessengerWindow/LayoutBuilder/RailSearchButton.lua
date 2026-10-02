local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Magnifier that stands in for the search field while the contacts pane is
-- the collapsed rail. The caller sets its OnClick (expand and focus search).
local RailSearchButton = {}

-- Same glyph as the search field's own magnifier.
local SEARCH_ICON_TEXTURE = "Interface\\Common\\UI-Searchbox-Icon"
local ICON_SIZE = 14
local FIELD_RADIUS = 8

-- options: theme, searchMargin, searchHeight, nativeChrome
function RailSearchButton.Create(factory, contactsPane, options)
  local theme = options.theme or Theme
  local size = options.searchHeight
  local button = factory.CreateFrame("Button", nil, contactsPane)
  button:SetSize(size, size)
  button:SetPoint("TOP", contactsPane, "TOP", 0, -options.searchMargin)

  -- Modern: the search field's rounded fill, shrunk to a square. The Native
  -- WoW HUD shows the glyph alone over the template art.
  local field = not options.nativeChrome and UIHelpers.createRoundedBackground(button, FIELD_RADIUS) or nil
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetTexture(SEARCH_ICON_TEXTURE)
  button.icon = icon

  local hovered = false
  local activeTheme = theme
  local function paint()
    if field then
      field.setColor(activeTheme.COLORS.bg_search_input or activeTheme.COLORS.bg_input)
    end
    UIHelpers.applyVertexColor(icon, hovered and activeTheme.COLORS.text_primary or activeTheme.COLORS.text_secondary)
  end

  button:SetScript("OnEnter", function(self)
    hovered = true
    paint()
    local tooltip = _G.GameTooltip
    if tooltip and tooltip.SetOwner then
      tooltip:SetOwner(self, "ANCHOR_RIGHT")
      tooltip:SetText(Localization.Text("Search chats"))
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    hovered = false
    paint()
    local tooltip = _G.GameTooltip
    if tooltip and tooltip.Hide then
      tooltip:Hide()
    end
  end)

  -- Repaint for the active theme (called on build and every theme refresh).
  button.applySkin = function(nextTheme)
    activeTheme = nextTheme or activeTheme
    paint()
  end
  paint()
  button:Hide()
  return button
end

ns.MessengerWindowLayoutRailSearchButton = RailSearchButton

return RailSearchButton
