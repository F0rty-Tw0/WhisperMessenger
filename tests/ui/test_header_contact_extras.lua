local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local Theme = require("WhisperMessenger.UI.Theme")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

-- Conversation header: nickname with the real name dimmed beside it, a
-- muted marker, and the note behind a gold label with the full text on hover.
return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)
  local header = HeaderView.Create(factory, pane, nil)
  HeaderView.Relayout(header, 600)

  local function refresh(contact)
    HeaderView.Refresh(header, contact, {}, nil)
    return header.headerName.text
  end

  local dimRealName = UIHelpers.colorEscape(Theme.COLORS.text_secondary) .. "Arthas-Area52|r"

  -- test_plain_contact_shows_display_name
  assert(refresh({ displayName = "Arthas-Area52", channel = "WOW" }) == "Arthas-Area52", "plain name")

  -- test_nickname_leads_with_dim_real_name_beside_it
  local title = refresh({ displayName = "Arthas-Area52", channel = "WOW", nickname = "Big Boss" })
  assert(title == "Big Boss  " .. dimRealName, "nickname then dim real name, got " .. tostring(title))

  -- test_muted_conversation_shows_marker_in_title
  title = refresh({ displayName = "Arthas-Area52", channel = "WOW", muted = true })
  assert(string.find(title, Theme.TEXTURES.muted_icon, 1, true), "muted marker in the header title")

  local goldLabel = UIHelpers.colorEscape(Theme.TAG_GOLD) .. "Note:|r "
  local primary = UIHelpers.colorEscape(Theme.COLORS.text_primary)

  -- test_note_shows_gold_label_then_primary_text
  refresh({ displayName = "Arthas-Area52", channel = "WOW", note = "Raid leader, Tuesdays" })
  local note = header.headerNote
  assert(note ~= nil and note:IsShown(), "note line shown")
  local expected = goldLabel .. primary .. "Raid leader, Tuesdays|r"
  assert(note.text == expected, "gold label + primary note, got " .. tostring(note.text))

  -- test_long_note_ellipsis_keeps_colour_codes_intact
  -- 600px header -> 240px cap; fake width is 7px per byte.
  refresh({ displayName = "Arthas-Area52", channel = "WOW", note = string.rep("x", 60) })
  local text = note.text
  assert(string.sub(text, 1, #goldLabel + #primary) == goldLabel .. primary, "label and colour kept whole")
  assert(string.sub(text, -5) == ".." .. ".|r", "ellipsis then closing escape, got " .. tostring(text))
  local plain = string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
  assert(#plain * 7 <= 240, "label + fitted note within the cap, got " .. tostring(#plain * 7))

  -- test_note_tooltip_shows_full_text
  local tooltipLines = {}
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text)
      tooltipLines[#tooltipLines + 1] = text
    end,
    AddLine = function(_, text)
      tooltipLines[#tooltipLines + 1] = text
    end,
    Show = function() end,
    Hide = function() end,
  }
  header.headerNoteHitArea.scripts.OnEnter(header.headerNoteHitArea)
  local joined = table.concat(tooltipLines, "\n")
  assert(string.find(joined, string.rep("x", 60), 1, true), "tooltip carries the full note")
  _G.GameTooltip = nil

  -- test_no_note_hides_the_line
  refresh({ displayName = "Arthas-Area52", channel = "WOW" })
  assert(not header.headerNote:IsShown(), "note hidden without a note")
  assert(not header.headerNoteHitArea:IsShown(), "no hover area without a note")

  -- test_note_starts_after_name_and_badge_on_narrow_header
  -- Fake text is 7px per byte; the note is right-aligned to the header.
  local nameLeft = Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + Theme.LAYOUT.HEADER_ICON_SIZE + Theme.LAYOUT.HEADER_NAME_GAP
  local function plainWidth(fontString)
    local plainText = string.gsub(string.gsub(fontString.text or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    return #plainText * 7
  end
  HeaderView.Relayout(header, 380)
  refresh({ displayName = "Aliwalker", channel = "WOW", note = string.rep("x", 60) })
  assert(header.headerAddonBadgeButton:IsShown(), "invite badge shown on the name row")
  local badgeRight = nameLeft + plainWidth(header.headerName) + 6 + header.headerAddonBadgeButton:GetWidth()
  local noteLeft = 380 - 8 - plainWidth(note)
  assert(note:IsShown(), "note still fits at 380px")
  assert(noteLeft > badgeRight, "note starts after the badge: note " .. noteLeft .. " vs badge " .. badgeRight)

  -- test_note_hides_when_name_row_leaves_no_room
  HeaderView.Relayout(header, 260)
  assert(not note:IsShown(), "no room left: note hidden instead of overlapping")
  assert(not header.headerNoteHitArea:IsShown(), "hover area hidden with it")
  HeaderView.Relayout(header, 600)

  -- test_group_header_ignores_nickname_but_shows_mute
  title = refresh({ displayName = "guild::x", channel = "GUILD", nickname = "nope", muted = true, title = "Guild" })
  assert(not string.find(title, "nope", 1, true), "groups never show a nickname")
  assert(string.find(title, Theme.TEXTURES.muted_icon, 1, true), "muted group shows the marker")
end
