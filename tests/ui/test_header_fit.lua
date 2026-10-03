local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local Theme = require("WhisperMessenger.UI.Theme")

-- The name row (name, faction icon, addon badge, group chip) must fit inside
-- the header: a long name at a big font truncates so the badge stays fully
-- visible instead of running past the pane edge.

local RIGHT_INSET = 8
local ROW_GAP = 6
local NAME_LEFT = Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + Theme.LAYOUT.HEADER_ICON_SIZE + Theme.LAYOUT.HEADER_NAME_GAP

local function shown(region)
  return region ~= nil and region:IsShown()
end

-- Right edge of the name row as laid out: name box, then each shown
-- follower with its gap.
local function rowRight(view)
  local right = NAME_LEFT + view.headerName:GetWidth()
  for _, region in ipairs({ view.headerFactionIcon, view.headerAddonBadgeButton, view.headerChannelChip }) do
    if shown(region) then
      local width = region.GetStringWidth and region.frameType == "FontString" and region:GetStringWidth() or region:GetWidth()
      right = right + ROW_GAP + width
    end
  end
  return right
end

local function whisperContact(name)
  return { displayName = name, classTag = "HUNTER", factionName = "Horde", channel = "WOW", peerHasAddon = false }
end

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_long_name_truncates_so_badge_fits_inside_header
  do
    local contact = whisperContact("Chaoskekwthelongestname")
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    HeaderView.Relayout(view, 300)
    assert(shown(view.headerAddonBadgeButton), "invite badge shows")
    local natural = view.headerName:GetStringWidth()
    assert(view.headerName:GetWidth() < natural, "long name is narrowed, got " .. tostring(view.headerName:GetWidth()))
    assert(rowRight(view) <= 300 - RIGHT_INSET, "name row ends inside the header, got " .. rowRight(view))
    assert(rowRight(view) == 300 - RIGHT_INSET, "name takes all the room left, got " .. rowRight(view))
  end

  -- test_short_name_keeps_its_natural_width
  do
    local contact = whisperContact("Bob")
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    HeaderView.Relayout(view, 300)
    assert(view.headerName:GetWidth() == view.headerName:GetStringWidth(), "short name keeps its width, got " .. tostring(view.headerName:GetWidth()))
  end

  -- test_widening_the_header_restores_the_full_name
  do
    local contact = whisperContact("Chaoskekwthelongestname")
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, nil, nil)
    HeaderView.Relayout(view, 300)
    HeaderView.Relayout(view, 900)
    assert(
      view.headerName:GetWidth() == view.headerName:GetStringWidth(),
      "wide header shows the whole name, got " .. tostring(view.headerName:GetWidth())
    )
  end

  -- test_refresh_refits_when_the_badge_text_changes
  do
    local contact = whisperContact("Chaoskekwthelongestname")
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Relayout(view, 300)
    HeaderView.Refresh(view, contact, nil, nil)
    assert(rowRight(view) == 300 - RIGHT_INSET, "invite badge fits after refresh, got " .. rowRight(view))
    contact.peerHasAddon = true
    HeaderView.Refresh(view, contact, nil, nil)
    assert(rowRight(view) == 300 - RIGHT_INSET, "shorter badge gives the name more room, got " .. rowRight(view))
  end

  -- test_group_chip_fits_inside_header
  do
    local contact = { displayName = "Guild", channel = "GUILD", conversationKey = "me::GUILD::guild" }
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Relayout(view, 200)
    HeaderView.Refresh(view, contact, { messages = {} }, nil)
    view.headerName:SetText("A very long guild chat title that will not fit")
    view.headerChannelChip:SetText("[Guild]")
    view.headerChannelChip:Show()
    HeaderView.Relayout(view, 200)
    assert(rowRight(view) <= 200 - RIGHT_INSET, "chip ends inside the header, got " .. rowRight(view))
  end
end
