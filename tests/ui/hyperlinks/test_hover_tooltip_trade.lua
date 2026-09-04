-- trade: links must never reach GameTooltip:SetHyperlink on hover. The client
-- treats SetHyperlink("trade:...") as a request to open the profession
-- window rather than showing a tooltip, so hovering a profession link in a
-- chat bubble popped open the trade-skill UI. Clicking still works via
-- SetItemRef (Hyperlinks.HandleClick), which is untouched by this fix.
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local function newTooltipStub()
  local calls = { setOwner = 0, setHyperlink = nil, setText = nil, show = 0, hide = 0 }
  local tooltip = {
    SetOwner = function()
      calls.setOwner = calls.setOwner + 1
    end,
    SetHyperlink = function(_, link)
      calls.setHyperlink = link
    end,
    SetText = function(_, t)
      calls.setText = t
    end,
    Show = function()
      calls.show = calls.show + 1
    end,
    Hide = function()
      calls.hide = calls.hide + 1
    end,
  }
  return tooltip, calls
end

return function()
  ----------------------------------------------------------------------------
  -- Bare trade: link must not touch the tooltip at all.
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local tooltip, calls = newTooltipStub()
    _G.GameTooltip = tooltip

    Hyperlinks.HandleEnter({}, "trade:Player-1234-ABCDEF:2259:1:1:1:2:0:0:0:0")

    assert(calls.setOwner == 0, "SetOwner must not be called for a trade link")
    assert(calls.setHyperlink == nil, "SetHyperlink must not be called for a trade link")
    assert(calls.setText == nil, "SetText must not be called for a trade link")
    assert(calls.show == 0, "Show must not be called for a trade link")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- Full |Htrade:...|h[Name's Blacksmithing]|h markup must not touch the tooltip.
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local tooltip, calls = newTooltipStub()
    _G.GameTooltip = tooltip

    Hyperlinks.HandleEnter({}, "|Htrade:Player-1234-ABCDEF:2259:1:1:1:2:0:0:0:0|h[Name's Blacksmithing]|h")

    assert(calls.setOwner == 0, "SetOwner must not be called for |H-wrapped trade link")
    assert(calls.setHyperlink == nil, "SetHyperlink must not be called for |H-wrapped trade link")
    assert(calls.setText == nil, "SetText must not be called for |H-wrapped trade link")
    assert(calls.show == 0, "Show must not be called for |H-wrapped trade link")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- Case-insensitive match on the link type.
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local tooltip, calls = newTooltipStub()
    _G.GameTooltip = tooltip

    Hyperlinks.HandleEnter({}, "TRADE:foo")

    assert(calls.setOwner == 0, "SetOwner must not be called for uppercase TRADE link")
    assert(calls.setHyperlink == nil, "SetHyperlink must not be called for uppercase TRADE link")
    assert(calls.show == 0, "Show must not be called for uppercase TRADE link")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- Regression guard: a normal Blizzard link (item:) must still show its
  -- native tooltip via SetHyperlink.
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local tooltip, calls = newTooltipStub()
    _G.GameTooltip = tooltip

    Hyperlinks.HandleEnter({}, "item:6948")

    assert(calls.setHyperlink == "item:6948", "item link should still be passed to SetHyperlink, got " .. tostring(calls.setHyperlink))
    assert(calls.show == 1, "tooltip should still be shown for item link")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- HandleLeave after a skipped trade hover must not error even when
  -- GameTooltip only exposes Hide (keeps the enter/leave pair symmetrical).
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local hidden = false
    _G.GameTooltip = {
      Hide = function()
        hidden = true
      end,
    }

    Hyperlinks.HandleEnter({}, "trade:Player-1234-ABCDEF:2259:1:1:1:2:0:0:0:0")
    Hyperlinks.HandleLeave()
    assert(hidden == true, "HandleLeave should still hide the tooltip after a skipped trade hover")

    _G.GameTooltip = savedTooltip
  end
end
