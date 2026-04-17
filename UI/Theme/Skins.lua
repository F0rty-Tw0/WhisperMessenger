local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Skins = {}

Skins.MODERN = "modern"
Skins.BLIZZARD = "blizzard"

-- Preset → skin mapping. Adding a new preset that wants Blizzard chrome means
-- adding an entry here; everything else defaults to MODERN.
local presetToSkin = {
  wow_default = Skins.MODERN,
  elvui_dark = Skins.MODERN,
  plumber_warm = Skins.MODERN,
  wow_native = Skins.BLIZZARD,
}

local skinData = {
  [Skins.MODERN] = {
    -- nil entries mean "leave existing flat-surface paint alone".
    window_backdrop = nil,
    close_button_atlas = nil,
    close_button_texture = nil,
    contact_row_highlight_texture = nil,
  },
  [Skins.BLIZZARD] = {
    window_backdrop = {
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      -- UI-Tooltip-Border at edgeSize 16 + insets 4 keeps the edge zone
      -- ~12px thick. Bigger values (DialogBox-Border at edgeSize 32) made
      -- the edge zone fat enough to cover the title text and rendered as
      -- "half-visible" borders against the inset bg. Stay conservative.
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    -- Close button + send button + scrollbar knob intentionally NOT
    -- skinned. `common-iconbutton-close` atlas rendered blank on some
    -- clients; the original UI-StopButton (set as the fallback in
    -- ChromeBuilder.applyTheme) is reliable across all flavors. See
    -- removal of send_button_*/scrollbar_thumb_texture above for the
    -- same "Blizzard texture doesn't fit our layout" reasoning.
    contact_row_highlight_texture = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    -- Same texture as the window backdrop's bgFile so the contacts pane
    -- and conversation area paint with the native Blizzard inset look
    -- (instead of the addon's flat near-black). Painted via
    -- UIHelpers.applyPaneBackground in ChromeBuilder + LayoutBuilder.
    pane_inset_texture = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    -- Conversation-pane contact header (class icon + name + status) uses
    -- Blizzard's FriendsFrame banner texture so the Azeroth skin reads as
    -- a distinct native banner above the thread, instead of blending into
    -- the surrounding dark dialog bg. Modern presets leave this nil and
    -- keep the flat `bg_header` color paint.
    pane_header_texture = "Interface\\FriendsFrame\\UI-FriendsFrame-FriendHeader",
  },
}

local skinOrder = { Skins.MODERN, Skins.BLIZZARD }

function Skins.ListKeys()
  local keys = {}
  for i, key in ipairs(skinOrder) do
    keys[i] = key
  end
  return keys
end

function Skins.Get(key)
  return skinData[key]
end

function Skins.GetActive()
  local Theme = ns.Theme
  if type(Theme) ~= "table" or type(Theme.GetPreset) ~= "function" then
    if type(require) == "function" then
      local ok, mod = pcall(require, "WhisperMessenger.UI.Theme")
      if ok and type(mod) == "table" then
        Theme = mod
      end
    end
  end
  if type(Theme) ~= "table" or type(Theme.GetPreset) ~= "function" then
    return Skins.MODERN
  end
  local preset = Theme.GetPreset()
  return presetToSkin[preset] or Skins.MODERN
end

ns.Skins = Skins
return Skins
