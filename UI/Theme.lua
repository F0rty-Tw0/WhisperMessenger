local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = {
  WINDOW_WIDTH = 900,
  WINDOW_HEIGHT = 560,
  CONTACTS_WIDTH = 280,
  TITLE = "WhisperMessenger",
}

ns.Theme = Theme

return Theme
