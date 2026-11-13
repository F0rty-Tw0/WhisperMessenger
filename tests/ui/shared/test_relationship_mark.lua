local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local RelationshipMark = require("WhisperMessenger.UI.Shared.RelationshipMark")

local function fakeTooltip()
  local state = { lines = {} }
  state.tooltip = {
    SetOwner = function(_, owner, anchor)
      state.owner, state.anchor = owner, anchor
    end,
    SetText = function(_, text)
      state.lines = { text }
    end,
    AddLine = function(_, text)
      state.lines[#state.lines + 1] = text
    end,
    Show = function()
      state.shown = true
    end,
    Hide = function()
      state.shown = false
    end,
  }
  return state
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  local savedTooltip = _G.GameTooltip

  -- test_create_makes_a_hidden_icon_and_a_motion_only_hover_frame
  do
    local mark = RelationshipMark.Create(parent, 14)
    assert(mark.icon.width == 14 and mark.icon.height == 14, "icon is size x size")
    assert(mark.icon.shown == false and mark.hover.shown == false, "both start hidden")
    assert(mark.hover.parent == parent and mark.hover.allPoints == mark.icon, "hover frame covers the icon")
    assert(mark.hover.mouseEnabled == true and mark.hover.mouseMotionEnabled == true, "hover tracks the pointer")
    assert(mark.hover.mouseClickEnabled == false, "clicks fall through to what is below")
    assert(mark.hover.scripts.OnClick == nil and mark.hover.scripts.OnMouseUp == nil, "no click scripts")
  end

  -- test_bind_picks_the_art_of_the_primary_tie
  for _, tie in ipairs({ "guild", "bnet", "friend", "community" }) do
    local mark = RelationshipMark.Create(parent, 14)
    assert(RelationshipMark.Bind(mark, { primary = tie, ties = { tie } }) == true, tie .. ": Bind reports shown")
    assert(mark.icon.texturePath == Theme.TEXTURES["relationship_" .. tie], tie .. ": its own texture")
    assert(mark.icon.shown == true and mark.hover.shown == true, tie .. ": icon and hover shown")
  end

  -- test_guild_is_desaturated_and_tinted_others_keep_their_art
  do
    local guild = RelationshipMark.Create(parent, 14)
    RelationshipMark.Bind(guild, { primary = "guild", ties = { "guild" } })
    local tint = Theme.RelationshipTint("guild")
    assert(guild.icon.desaturated == true and guild.icon.vertexColor[2] == tint[2], "green shield")
    local bnet = RelationshipMark.Create(parent, 14)
    RelationshipMark.Bind(bnet, { primary = "bnet", ties = { "bnet" } })
    assert(bnet.icon.desaturated ~= true and bnet.icon.vertexColor[1] == 1 and bnet.icon.vertexColor[3] == 1, "bnet untinted")
  end

  -- test_bind_nil_or_unknown_hides_both
  do
    local mark = RelationshipMark.Create(parent, 14)
    RelationshipMark.Bind(mark, { primary = "guild", ties = { "guild" } })
    assert(RelationshipMark.Bind(mark, nil) == false, "nil rel: not shown")
    assert(mark.icon.shown == false and mark.hover.shown == false and mark.rel == nil, "both hidden, rel cleared")
    RelationshipMark.Bind(mark, { primary = "guild", ties = { "guild" } })
    assert(RelationshipMark.Bind(mark, { primary = "enemy", ties = { "enemy" } }) == false, "unknown tie: not shown")
    assert(mark.icon.shown == false, "unknown tie hides the icon")
  end

  -- test_hover_lists_every_tie_in_order
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    local mark = RelationshipMark.Create(parent, 14)
    RelationshipMark.Bind(mark, {
      primary = "guild",
      ties = { "guild", "bnet", "community" },
      guildName = "Stormguard",
      communityName = "Night Raiders",
    })
    mark.hover.scripts.OnEnter(mark.hover)
    local expected = { "Guild: Stormguard", "Battle.net friend", "Community: Night Raiders" }
    assert(table.concat(state.lines, "|") == table.concat(expected, "|"), "tooltip lines, got " .. table.concat(state.lines, "|"))
    assert(state.shown == true and state.owner == mark.hover and state.anchor == "ANCHOR_RIGHT", "opens beside the mark")
    mark.hover.scripts.OnLeave(mark.hover)
    assert(state.shown == false, "hides on leave")
  end

  -- test_hover_is_safe_without_a_tooltip_or_a_tie
  do
    local state = fakeTooltip()
    _G.GameTooltip = state.tooltip
    local mark = RelationshipMark.Create(parent, 14)
    mark.hover.scripts.OnEnter(mark.hover)
    assert(state.shown ~= true, "unbound mark shows no tooltip")
    RelationshipMark.Bind(mark, { primary = "friend", ties = { "friend" } })
    _G.GameTooltip = nil
    mark.hover.scripts.OnEnter(mark.hover)
    mark.hover.scripts.OnLeave(mark.hover)
  end

  _G.GameTooltip = savedTooltip
end
