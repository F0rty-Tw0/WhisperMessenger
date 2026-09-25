rawset(_G, "time", os.time)
_G.date = os.date

local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- Contact rows: nickname replaces the name, muted rows show a bell-slash
-- marker and a dim unread badge, unread group mentions show "@".

local function item(overrides)
  local it = {
    conversationKey = "me::WOW::arthas",
    displayName = "Arthas-Area52",
    lastPreview = "hi",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
  }
  for key, value in pairs(overrides or {}) do
    it[key] = value
  end
  return it
end

local function sameRgb(a, b)
  return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local function bind(it, row)
    return RowView.bindRow(factory, parent, row, 1, it, {})
  end

  -- test_nickname_replaces_the_row_name
  local row = bind(item({ nickname = "Big Boss" }))
  assert(row.title.text == "Big Boss", "nickname shown, got " .. tostring(row.title.text))

  -- test_no_nickname_keeps_display_name
  row = bind(item())
  assert(row.title.text == "Arthas-Area52", "display name shown, got " .. tostring(row.title.text))

  -- test_muted_row_shows_bell_slash_marker
  row = bind(item({ muted = true }))
  assert(row.mutedMarker ~= nil and row.mutedMarker:IsShown(), "muted marker shown")
  assert(row.mutedMarker.texturePath == Theme.TEXTURES.muted_icon, "marker uses the bell-slash glyph")

  -- test_unmuting_a_pooled_row_hides_the_marker
  row = bind(item(), row)
  assert(not row.mutedMarker:IsShown(), "marker hidden once unmuted")

  -- test_muted_unread_badge_is_dim
  row = bind(item({ muted = true, unreadCount = 3 }), row)
  local accentBadge = Theme.BadgeColors()
  assert(row.unreadBadge.frame:IsShown(), "muted rows still show their count")
  assert(not sameRgb(row.unreadBadge.background.vertexColor, accentBadge), "muted badge is not the accent colour")

  -- test_unmuted_badge_returns_to_accent
  row = bind(item({ unreadCount = 3 }), row)
  assert(sameRgb(row.unreadBadge.background.vertexColor, accentBadge), "unmuted badge back to accent")
  assert(row.unreadBadge.label.text == "3", "count shown")

  -- test_unread_mention_shows_at_sign_in_badge
  row = bind(item({ channel = "GUILD", unreadCount = 2, hasUnreadMention = true }), row)
  assert(row.unreadBadge.label.text == "@", "mention badge shows @, got " .. tostring(row.unreadBadge.label.text))

  -- test_muted_mention_badge_stays_accent
  row = bind(item({ channel = "GUILD", unreadCount = 2, hasUnreadMention = true, muted = true }), row)
  assert(sameRgb(row.unreadBadge.background.vertexColor, accentBadge), "a mention badge is never dimmed")
end
