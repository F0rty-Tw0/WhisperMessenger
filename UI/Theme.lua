local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = {
  WINDOW_WIDTH = 900,
  WINDOW_HEIGHT = 560,
  CONTACTS_WIDTH = 280,
  TOP_BAR_HEIGHT = 52,
  CONTENT_PADDING = 16,
  COMPOSER_HEIGHT = 56,
  DIVIDER_THICKNESS = 1,
  WINDOW_ACTIVE_ALPHA = 1,
  WINDOW_INACTIVE_ALPHA = 0.72,
  WINDOW_ALPHA_FADE_SECONDS = 0.12,
  WINDOW_ALPHA_UPDATE_INTERVAL = 0.1,
  TITLE = "WhisperMessenger",
}

ns.Theme = Theme

return Theme
