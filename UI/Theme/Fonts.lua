local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Fonts = {
  contact_name = "GameFontNormal",
  contact_preview = "GameFontDisableSmall",
  contact_time = "GameFontDisableSmall",
  message_text = "GameFontHighlight",
  message_time = "GameFontDisableSmall",
  header_name = "GameFontHighlightLarge",
  header_status = "GameFontDisableSmall",
  date_separator = "GameFontDisableSmall",
  system_text = "GameFontHighlightSmall",
  unread_badge = "GameFontHighlightSmall",
  composer_input = "ChatFontNormal",
  icon_label = "GameFontHighlight",
  empty_state = "GameFontHighlight",
}

ns.ThemeFonts = Fonts
return Fonts
