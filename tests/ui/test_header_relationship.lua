local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local Theme = require("WhisperMessenger.UI.Theme")

local GAP, SIZE, RIGHT_INSET = 6, 16, 8
local MARK = { primary = "guild", ties = { "guild", "bnet" }, guildName = "Stormguard" }

local function contact(overrides)
  local item = { displayName = "Arthas", classTag = "HUNTER", channel = "WOW", peerHasAddon = false }
  for key, value in pairs(overrides or {}) do
    item[key] = value
  end
  return item
end

local function newView(factory, pane, first)
  local view = HeaderView.Create(factory, pane, first)
  -- Invites off: the badge shows only for a peer that has the addon.
  view.canInviteContact = function()
    return false
  end
  return view
end

-- Where `region` is anchored: the relative frame, with the 6 px gap check.
local function anchoredTo(region)
  local point, relativeTo, relativePoint, x = region:GetPoint()
  assert(point == "LEFT" and relativePoint == "RIGHT" and x == GAP, "LEFT to RIGHT with a 6 px gap")
  return relativeTo
end

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)
  local savedTooltip = _G.GameTooltip

  -- test_mark_shows_for_a_tie_and_hides_without_one
  do
    local view = newView(factory, pane, nil)
    assert(view.headerRelationshipIcon.width == SIZE and view.headerRelationshipIcon.shown == false, "16 px, hidden at first")
    HeaderView.Refresh(view, contact({ relationship = MARK }), nil, nil)
    assert(view.headerRelationshipIcon.shown == true and view.headerRelationshipHover.shown == true, "shown for a guildmate")
    assert(view.headerRelationshipIcon.texturePath == Theme.TEXTURES.relationship_guild, "guild art")
    HeaderView.Refresh(view, contact(), nil, nil)
    assert(view.headerRelationshipIcon.shown == false and view.headerRelationshipHover.shown == false, "hidden when the tie goes")
    HeaderView.Refresh(view, contact({ relationship = MARK }), nil, nil)
    HeaderView.Refresh(view, nil, nil, nil)
    assert(view.headerRelationshipIcon.shown == false, "hidden with no contact")
  end

  -- test_group_header_never_shows_the_mark
  do
    local group = { displayName = "Guild", channel = "GUILD", conversationKey = "me::GUILD::guild", relationship = MARK }
    local view = newView(factory, pane, group)
    HeaderView.Refresh(view, group, { messages = {} }, nil)
    assert(view.headerRelationshipIcon.shown == false, "no mark on a group header")
  end

  -- test_anchor_chain_for_every_mark_faction_badge_combination
  for _, withMark in ipairs({ false, true }) do
    for _, withFaction in ipairs({ false, true }) do
      for _, withBadge in ipairs({ false, true }) do
        local label = string.format("mark=%s faction=%s badge=%s", tostring(withMark), tostring(withFaction), tostring(withBadge))
        local c = contact({
          relationship = withMark and MARK or nil,
          factionName = withFaction and "Horde" or nil,
          peerHasAddon = withBadge,
        })
        local view = newView(factory, pane, c)
        HeaderView.Refresh(view, c, nil, nil)
        assert(view.headerRelationshipIcon:IsShown() == withMark and view.headerFactionIcon:IsShown() == withFaction, label .. ": shown states")
        assert(view.headerAddonBadgeButton:IsShown() == withBadge, label .. ": badge state")
        if withMark then
          assert(anchoredTo(view.headerRelationshipIcon) == view.headerName, label .. ": mark after the name")
        end
        if withFaction then
          local expected = withMark and view.headerRelationshipIcon or view.headerName
          assert(anchoredTo(view.headerFactionIcon) == expected, label .. ": faction anchor")
        end
        if withBadge then
          local expected = (withFaction and view.headerFactionIcon) or (withMark and view.headerRelationshipIcon) or view.headerName
          assert(anchoredTo(view.headerAddonBadgeButton) == expected, label .. ": badge anchor")
        end
      end
    end
  end

  -- test_mark_removed_on_refresh_puts_faction_and_badge_back_on_the_name
  do
    local c = contact({ relationship = MARK, peerHasAddon = true, factionName = "Horde" })
    local view = newView(factory, pane, c)
    HeaderView.Refresh(view, c, nil, nil)
    c.relationship, c.factionName = nil, nil
    HeaderView.Refresh(view, c, nil, nil)
    assert(anchoredTo(view.headerAddonBadgeButton) == view.headerName, "badge back on the name")
    c.factionName = "Horde"
    HeaderView.Refresh(view, c, nil, nil)
    assert(anchoredTo(view.headerFactionIcon) == view.headerName, "faction back on the name")
  end

  -- test_name_fit_reserves_room_for_the_mark (HeaderFit.reservedAfterName)
  do
    local function nameWidth(withMark)
      local c =
        contact({ displayName = "Chaoskekwthelongestname", factionName = "Horde", peerHasAddon = true, relationship = withMark and MARK or nil })
      local view = newView(factory, pane, c)
      HeaderView.Refresh(view, c, nil, nil)
      HeaderView.Relayout(view, 300)
      return view.headerName:GetWidth(), view
    end
    local without = nameWidth(false)
    local with, view = nameWidth(true)
    assert(with == without - (GAP + SIZE), "name gives up mark + gap, got " .. with .. " vs " .. without)
    local right = Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + Theme.LAYOUT.HEADER_ICON_SIZE + Theme.LAYOUT.HEADER_NAME_GAP + with
    for _, region in ipairs({ view.headerRelationshipIcon, view.headerFactionIcon, view.headerAddonBadgeButton }) do
      right = right + GAP + region:GetWidth()
    end
    assert(right == 300 - RIGHT_INSET, "name row ends inside the header, got " .. right)
  end

  -- test_note_room_accounts_for_the_mark (HeaderContactExtras.nameRowRight)
  do
    local function noteWidth(withMark)
      local c = contact({ displayName = "Aliwalker", peerHasAddon = true, note = string.rep("x", 60), relationship = withMark and MARK or nil })
      local view = newView(factory, pane, c)
      HeaderView.Relayout(view, 320)
      HeaderView.Refresh(view, c, nil, nil)
      return view.headerNote:GetWidth()
    end
    local without, with = noteWidth(false), noteWidth(true)
    assert(without < math.floor(320 * 0.4), "room left, not the 40% cap, limits the note here: " .. without)
    assert(with == without - (GAP + SIZE), "note gives up mark + gap, got " .. with .. " vs " .. without)
  end

  -- test_hover_tooltip_lists_every_tie
  do
    local lines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_, text)
        lines = { text }
      end,
      AddLine = function(_, text)
        lines[#lines + 1] = text
      end,
      Show = function() end,
      Hide = function() end,
    }
    local c = contact({ relationship = MARK })
    local view = newView(factory, pane, c)
    HeaderView.Refresh(view, c, nil, nil)
    view.headerRelationshipHover.scripts.OnEnter(view.headerRelationshipHover)
    assert(table.concat(lines, "|") == "Guild: Stormguard|Battle.net friend", "same lines as the row, got " .. table.concat(lines, "|"))
    _G.GameTooltip = savedTooltip
  end

  -- test_conversation_pane_view_carries_the_mark_fields
  do
    local parent = factory.CreateFrame("Frame", "Parent", nil)
    parent:SetSize(600, 420)
    local view = ConversationPane.Create(factory, parent, contact(), { messages = {} })
    assert(view.headerRelationshipIcon ~= nil and view.headerRelationshipHover ~= nil, "pane view copies the header's mark fields")
    ConversationPane.Refresh(view, contact({ relationship = MARK }), { messages = {} }, nil)
    assert(view.headerRelationshipIcon:IsShown() == true, "pane refresh draws the mark")
  end
end
