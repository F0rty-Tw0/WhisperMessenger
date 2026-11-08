local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IntegrationRow = ns.MessengerWindowBehaviorIntegrationRow or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.IntegrationRow")

-- "Addons using Whisper Messenger" section of the Behavior page: one row per
-- addon the registry lists (it already filters and sorts), or one line when
-- none has connected. Built only when addon integration was on at load.
local IntegrationList = {}

local GAP = 8
local HEADING = "Addons using Whisper Messenger"
local EMPTY = "No addons have connected yet."

local function text(key)
  return Localization.Text(key)
end

local function rowLabels()
  return {
    shared = text("Other addons"),
    tooltip = text("Addons that use Whisper Messenger without naming themselves."),
    notLoaded = text("Not loaded"),
    forget = text("Forget"),
  }
end

-- Rendered height of a section label: the Retail banner has a fixed height,
-- a plain label is as tall as its text.
local function headingHeight(heading)
  local height = heading.region:GetHeight() or 0
  if height <= 0 and heading.label.GetStringHeight then
    height = heading.label:GetStringHeight()
  end
  return math.ceil(height)
end

local function createEmptyLine(factory, frame)
  local holder = factory.CreateFrame("Frame", nil, frame)
  local line = holder:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  line:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  line:SetJustifyH("LEFT")
  line:SetText(text(EMPTY))
  return holder, line
end

local function createDisabled(factory, parent, anchor)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
  frame:SetSize(1, 1)
  frame:Hide()
  local function noop() end
  return { frame = frame, bottom = frame, refresh = noop, refreshLayout = noop, refreshTheme = noop, setLanguage = noop }
end

-- options = { integrations = { registry, enabled }, onLayoutChanged }.
-- Returns { frame, bottom, refresh, refreshLayout, refreshTheme, setLanguage };
-- the next control anchors below `bottom`.
function IntegrationList.Create(factory, parent, anchor, options)
  local integrations = options.integrations or {}
  if integrations.enabled ~= true or integrations.registry == nil then
    return createDisabled(factory, parent, anchor)
  end
  local registry = integrations.registry
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local section = { rows = {} }

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  section.frame = frame
  section.bottom = frame

  local heading = SettingsControls.CreateSectionLabel(frame, text(HEADING))
  heading.region:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  local emptyHolder, emptyLine = createEmptyLine(factory, frame)
  emptyLine:SetWidth(width)

  local handlers = {
    onToggle = function(name, on)
      registry.setAllowed(name, on)
    end,
    onForget = function(name)
      registry.forget(name)
      section.refresh()
    end,
  }

  -- Binds one pooled row per entry, top to bottom; returns the content height.
  local function bindRows(entries, top)
    local labels = rowLabels()
    local y = top
    for index, entry in ipairs(entries) do
      local row = section.rows[index] or IntegrationRow.Create(factory, frame, handlers)
      section.rows[index] = row
      row.width = width
      IntegrationRow.Bind(row, entry, labels)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
      y = y + row:GetHeight() + GAP
    end
    for index = #entries + 1, #section.rows do
      section.rows[index]:Hide()
    end
    return y - GAP
  end

  local function showEmpty(top)
    emptyHolder:ClearAllPoints()
    emptyHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
    local height = math.ceil(emptyLine:GetStringHeight())
    emptyHolder:SetSize(width, height)
    emptyHolder:Show()
    return top + height
  end

  function section.refresh()
    local entries = registry.rows()
    local top = headingHeight(heading) + GAP
    local bottom = bindRows(entries, top)
    if #entries == 0 then
      bottom = showEmpty(top)
    else
      emptyHolder:Hide()
    end
    frame:SetSize(width, math.max(1, bottom))
    if options.onLayoutChanged then
      options.onLayoutChanged()
    end
  end

  function section.refreshLayout(nextWidth)
    if type(nextWidth) ~= "number" or nextWidth <= 0 then
      return
    end
    width = nextWidth
    heading.refreshLayout(nextWidth)
    emptyLine:SetWidth(nextWidth)
    section.refresh()
  end

  function section.refreshTheme()
    heading.refreshTheme(Theme)
    UIHelpers.setTextColor(emptyLine, Theme.COLORS.text_secondary)
    for _, row in ipairs(section.rows) do
      IntegrationRow.RefreshTheme(row)
    end
  end

  function section.setLanguage()
    heading.label:SetText(text(HEADING))
    emptyLine:SetText(text(EMPTY))
    section.refresh()
  end

  registry.onChange(function()
    if frame:IsShown() then
      section.refresh()
    end
  end)
  frame:SetScript("OnShow", section.refresh)
  section.refreshTheme()
  frame:Show()
  section.refresh()
  return section
end

ns.MessengerWindowBehaviorIntegrationList = IntegrationList
return IntegrationList
