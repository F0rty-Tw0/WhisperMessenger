local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local IgnorePrompt = ns.IgnorePrompt or require("WhisperMessenger.UI.Shared.IgnorePrompt")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local ContactsSearchUI = ns.MessengerWindowLayoutContactsSearchUI or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local IgnoreRow = ns.FiltersSettingsIgnoreRow or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreRow")

-- "Ignored players" section of the Filters page: a search field, a scrolling
-- list that only ever builds VISIBLE_ROWS row frames (re-bound on scroll), the
-- "Ignore for" choice and an "Add player…" button.
local IgnoreListSection = {}

IgnoreListSection.VISIBLE_ROWS = 6

local NAME_DIALOG = "WHISPER_MESSENGER_IGNORE_PLAYER"
-- Name-Realm fits in 12 + 1 + realm letters; leave room for long realms.
local NAME_MAX_LETTERS = 64
local DAY_SECONDS = 24 * 60 * 60
local DURATIONS = {
  { key = "day", labelKey = "1 day", seconds = DAY_SECONDS },
  { key = "week", labelKey = "7 days", seconds = 7 * DAY_SECONDS },
  { key = "forever", labelKey = "Forever" },
}
local DEFAULT_DURATION = "forever"
local GAP = 8

local function text(key)
  return Localization.Text(key)
end

local function now()
  return type(_G.time) == "function" and _G.time() or nil
end

local function durationSeconds(key)
  for _, duration in ipairs(DURATIONS) do
    if duration.key == key then
      return duration.seconds
    end
  end
  return nil
end

local function durationOptions()
  local list = {}
  for index, duration in ipairs(DURATIONS) do
    list[index] = { key = duration.key, label = text(duration.labelKey) }
  end
  return list
end

-- Entries whose name contains `query` (lowercased), sorted by name. Each
-- entry's stored key goes in `keys`: removal deletes by that key, since a key
-- saved on another realm is not what Key(name) rebuilds here.
local function matchingEntries(filters, query, keys)
  local entries = {}
  for key, entry in pairs(filters.ignored) do
    local name = string.lower(entry.name or "")
    if query == "" or string.find(name, query, 1, true) then
      entries[#entries + 1] = entry
      keys[entry] = key
    end
  end
  table.sort(entries, function(a, b)
    return string.lower(a.name or "") < string.lower(b.name or "")
  end)
  return entries
end

local function countEntries(filters)
  local count = 0
  for _ in pairs(filters.ignored) do
    count = count + 1
  end
  return count
end

local function createSearch(factory, frame, anchor, width, onQueryChanged)
  local holder = factory.CreateFrame("Frame", nil, frame)
  holder:SetSize(width, Theme.LAYOUT.CONTACT_SEARCH_HEIGHT)
  holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP)
  local search = ContactsSearchUI.Build(factory, holder, {
    contactsWidth = width,
    searchMargin = 0,
    searchHeight = Theme.LAYOUT.CONTACT_SEARCH_HEIGHT,
    searchClearButtonSize = Theme.LAYOUT.CONTACT_SEARCH_CLEAR_BUTTON_SIZE,
    nativeChrome = Hud.IsOn(),
  })
  search.frame:ClearAllPoints()
  search.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  search.frame:SetSize(width, Theme.LAYOUT.CONTACT_SEARCH_HEIGHT)
  search.placeholder:SetText(text("Search"))
  search.applySkin(Theme)

  local input = search.input
  local function sync()
    local query = string.lower(input:GetText() or "")
    if not search.native then
      search.placeholder:SetShown(query == "")
      search.clearButton:SetShown(query ~= "")
    end
    onQueryChanged(query)
  end
  input:SetScript("OnTextChanged", sync)
  input:SetScript("OnEscapePressed", function()
    input:SetText("")
    sync()
    input:ClearFocus()
  end)
  if search.clearButton and not search.native then
    search.clearButton:SetScript("OnClick", function()
      input:SetText("")
      sync()
    end)
  end
  search.holder = holder
  return search
end

-- options = { filters, panel, onLayoutChanged }. Returns the section with
-- `bottom` (the frame the next control anchors below) and `redraw`.
function IgnoreListSection.Create(factory, frame, anchor, options)
  local filters = options.filters
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local section = { rows = {} }
  local query, offset, entries, entryKeys = "", 0, {}, {}
  local selectedDuration = DEFAULT_DURATION

  local titleSection = SettingsControls.CreateSectionLabel(frame, text("Ignored players"))
  titleSection.region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local search = createSearch(factory, frame, titleSection.region, width, function(nextQuery)
    query, offset = nextQuery, 0
    section.redraw()
  end)

  local list = factory.CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", search.holder, "BOTTOMLEFT", 0, -GAP)
  list:EnableMouseWheel(true)

  local function remove(key)
    IgnoreList.RemoveKey(filters, key)
    section.redraw()
  end

  local function bindRows()
    for index = 1, IgnoreListSection.VISIBLE_ROWS do
      local entry = entries[offset + index]
      local row = section.rows[index]
      if entry ~= nil then
        if row == nil then
          row = IgnoreRow.Create(factory, list, remove)
          row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * IgnoreRow.HEIGHT)
          section.rows[index] = row
        end
        row:SetWidth(width)
        IgnoreRow.Bind(row, entry, entryKeys[entry])
        row:Show()
      elseif row ~= nil then
        row:Hide()
      end
    end
  end

  list:SetScript("OnMouseWheel", function(_self, delta)
    local maxOffset = math.max(0, #entries - IgnoreListSection.VISIBLE_ROWS)
    offset = math.min(maxOffset, math.max(0, offset - delta))
    bindRows()
  end)

  local durationSelector = options.panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Ignore for"),
      optionsList = durationOptions(),
      fallbackKey = DEFAULT_DURATION,
      initial = DEFAULT_DURATION,
      onChange = function(value)
        selectedDuration = value
      end,
      rowWidth = width,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    }),
    { type = "selector" }
  )
  durationSelector.row:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -GAP)

  local addButton = options.panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Add player…"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = width, ghost = true }
    ),
    { type = "optionButton" }
  )
  addButton:SetPoint("TOPLEFT", durationSelector.row, "BOTTOMLEFT", 0, -GAP)
  addButton:SetScript("OnClick", function()
    TextInputDialog.Show(NAME_DIALOG, {
      prompt = text("Add player…"),
      accept = text("Add"),
      maxLetters = NAME_MAX_LETTERS,
      onAccept = function(typed)
        local name = string.match(typed or "", "^%s*(.-)%s*$")
        if name == "" then
          return
        end
        IgnorePrompt.AskReason(function(reason)
          IgnoreList.Add(filters, name, { reason = reason, duration = durationSeconds(selectedDuration) })
          section.redraw()
        end)
      end,
    })
  end)
  section.bottom = addButton

  function section.redraw()
    IgnoreList.Sweep(filters, now())
    entryKeys = {}
    entries = matchingEntries(filters, query, entryKeys)
    titleSection.label:SetText(string.format("%s (%d)", text("Ignored players"), countEntries(filters)))
    offset = math.min(offset, math.max(0, #entries - IgnoreListSection.VISIBLE_ROWS))
    bindRows()
    local shown = math.min(#entries, IgnoreListSection.VISIBLE_ROWS)
    list:SetSize(width, math.max(shown * IgnoreRow.HEIGHT, 1))
    if options.onLayoutChanged then
      options.onLayoutChanged()
    end
  end

  function section.refreshTheme()
    titleSection.refreshTheme(Theme)
    search.applySkin(Theme)
    for _, row in ipairs(section.rows) do
      IgnoreRow.RefreshTheme(row)
    end
  end

  function section.refreshLayout(nextWidth)
    width = nextWidth
    titleSection.refreshLayout(nextWidth)
    search.holder:SetWidth(nextWidth)
    search.frame:SetWidth(nextWidth)
    section.redraw()
  end

  function section.setLanguage()
    search.placeholder:SetText(text("Search"))
    durationSelector.label:SetText(text("Ignore for"))
    durationSelector.setOptionsList(durationOptions())
    addButton.label:SetText(text("Add player…"))
    section.redraw()
  end

  section.redraw()
  return section
end

ns.FiltersSettingsIgnoreListSection = IgnoreListSection
return IgnoreListSection
