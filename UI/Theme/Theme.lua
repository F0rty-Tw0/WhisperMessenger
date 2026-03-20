local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Colors = ns.ThemeColors or require("WhisperMessenger.UI.Theme.Colors")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Layout = ns.ThemeLayout or require("WhisperMessenger.UI.Theme.Layout")
local ThemeTextures = ns.ThemeTextures or require("WhisperMessenger.UI.Theme.Textures")

local Theme = {}

-- Legacy flat constants
Theme.TITLE = "WhisperMessenger"
Theme.WINDOW_IDLE_ALPHA = 1
Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA = 0.72
Theme.WINDOW_ALPHA_FADE_SECONDS = 0.12
Theme.WINDOW_ALPHA_UPDATE_INTERVAL = 0.1

Theme.COLORS = Colors
Theme.FONTS = Fonts
Theme.LAYOUT = Layout
Theme.TEXTURES = ThemeTextures.TEXTURES
Theme.ClassIcon = ThemeTextures.ClassIcon
Theme.FactionIcon = ThemeTextures.FactionIcon

-- Backward-compatible flat aliases
Theme.WINDOW_WIDTH      = Layout.WINDOW_WIDTH
Theme.WINDOW_HEIGHT     = Layout.WINDOW_HEIGHT
Theme.CONTACTS_WIDTH    = Layout.CONTACTS_WIDTH
Theme.TOP_BAR_HEIGHT    = Layout.TOP_BAR_HEIGHT
Theme.CONTENT_PADDING   = Layout.CONTENT_PADDING
Theme.COMPOSER_HEIGHT   = Layout.COMPOSER_HEIGHT
Theme.DIVIDER_THICKNESS = Layout.DIVIDER_THICKNESS

ns.Theme = Theme
return Theme
