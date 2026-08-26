-- Stub ManualCopy before requiring Hyperlinks. Hyperlinks.HandleClick on a
-- url-typed link calls require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy")
-- to copy the URL to clipboard. The real module pulls live UI deps; the stub
-- lets us assert the copy invocation without dragging in a fake UI.
local capturedCopies = {}
local copyReturn = true
-- The harness's wrapped require strips the "WhisperMessenger." prefix before
-- delegating to the real require, so package.loaded is keyed on the stripped
-- form. Stub under that key.
local manualCopyStub = {
  CopyText = function(text)
    capturedCopies[#capturedCopies + 1] = text
    return copyReturn
  end,
}
package.loaded["UI.ChatBubble.ContextMenu.ManualCopy"] = manualCopyStub
package.loaded["WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy"] = manualCopyStub

local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

local URL_PREFIX = "|cff71d5ff|Hurl:"
local URL_DISPLAY_SEP = "|h"
local URL_END = "|h|r"

local function wrapUrl(target, display)
  return URL_PREFIX .. target .. URL_DISPLAY_SEP .. display .. URL_END
end

return function()
  ----------------------------------------------------------------------------
  -- FormatTextForDisplay: identity / empty inputs
  ----------------------------------------------------------------------------
  do
    assert(Hyperlinks.FormatTextForDisplay(nil) == "", "nil input should produce empty string")
    assert(Hyperlinks.FormatTextForDisplay("") == "", "empty input should produce empty string")
    assert(Hyperlinks.FormatTextForDisplay("plain text no urls") == "plain text no urls", "plain text passes through unchanged")
  end

  ----------------------------------------------------------------------------
  -- Emoji tokens become inline sprites only in plain display segments.
  ----------------------------------------------------------------------------
  do
    local expectedRegions = {
      { key = "heart", left = 28, right = 100, top = 28, bottom = 100 },
      { key = "thumbsup", left = 140, right = 212, top = 28, bottom = 100 },
      { key = "laugh", left = 252, right = 324, top = 28, bottom = 100 },
      { key = "smile", left = 364, right = 436, top = 28, bottom = 100 },
      { key = "wink", left = 476, right = 548, top = 28, bottom = 100 },
      { key = "clap", left = 588, right = 660, top = 28, bottom = 100 },
      { key = "party", left = 700, right = 772, top = 28, bottom = 100 },
      { key = "fire", left = 812, right = 884, top = 28, bottom = 100 },
      { key = "gg", left = 924, right = 996, top = 28, bottom = 100 },
      { key = "wow", left = 28, right = 100, top = 156, bottom = 228 },
      { key = "sad", left = 140, right = 212, top = 156, bottom = 228 },
      { key = "cry", left = 252, right = 324, top = 156, bottom = 228 },
      { key = "angry", left = 364, right = 436, top = 156, bottom = 228 },
      { key = "thinking", left = 476, right = 548, top = 156, bottom = 228 },
      { key = "eyes", left = 588, right = 660, top = 156, bottom = 228 },
      { key = "question", left = 700, right = 772, top = 156, bottom = 228 },
      { key = "pray", left = 812, right = 884, top = 156, bottom = 228 },
      { key = "skull", left = 924, right = 996, top = 156, bottom = 228 },
    }
    local atlas, openError = io.open("Media/reactions.png", "rb")
    local ihdr = atlas and atlas:read(26)
    local closeOk = atlas and atlas:close()
    assert(atlas ~= nil, "reaction atlas should be readable: " .. tostring(openError))
    assert(closeOk, "reaction atlas should close after reading IHDR")
    assert(ihdr and #ihdr == 26, "reaction atlas should contain a complete IHDR")
    assert(string.sub(ihdr, 1, 8) == "\137PNG\r\n\26\n", "reaction atlas should have a PNG signature")
    assert(string.sub(ihdr, 9, 16) == "\0\0\0\rIHDR", "reaction atlas should begin with an IHDR chunk")
    local width = string.byte(ihdr, 17) * 0x1000000 + string.byte(ihdr, 18) * 0x10000 + string.byte(ihdr, 19) * 0x100 + string.byte(ihdr, 20)
    local height = string.byte(ihdr, 21) * 0x1000000 + string.byte(ihdr, 22) * 0x10000 + string.byte(ihdr, 23) * 0x100 + string.byte(ihdr, 24)
    assert(width == 1024 and height == 256, "reaction atlas IHDR should be 1024x256")
    assert(string.byte(ihdr, 25) == 8 and string.byte(ihdr, 26) == 6, "reaction atlas should be 8-bit RGBA")

    for _, region in ipairs(expectedRegions) do
      local coords = ReactionAssets.GetTexCoords(region.key)
      assert(coords ~= nil, "reaction key should have texture coordinates: " .. region.key)
      assert(
        math.floor(coords[1] * 1024 + 0.5) == region.left
          and math.floor(coords[2] * 1024 + 0.5) == region.right
          and math.floor(coords[3] * 256 + 0.5) == region.top
          and math.floor(coords[4] * 256 + 0.5) == region.bottom,
        "reaction key should use its exact atlas region: " .. region.key
      )
      assert(
        Hyperlinks.FormatTextForDisplay(":" .. region.key .. ":")
          == string.format(
            "|TInterface\\AddOns\\WhisperMessenger\\Media\\reactions.png:12:12:0:0:1024:256:%d:%d:%d:%d|t",
            region.left,
            region.right,
            region.top,
            region.bottom
          ),
        "reaction key should render complete inline atlas markup: " .. region.key
      )
    end

    local heartSprite = "|TInterface\\AddOns\\WhisperMessenger\\Media\\reactions.png:12:12:0:0:1024:256:28:100:28:100|t"
    assert(Hyperlinks.FormatTextForDisplay("nice :heart:") == "nice " .. heartSprite, "known emoji token should render as a heart sprite")
    assert(Hyperlinks.FormatTextForDisplay("keep :rocket: literal") == "keep :rocket: literal", "unknown emoji token should remain literal")

    local existing = "|Hitem:6948|h[item :heart:]|h"
    assert(
      Hyperlinks.FormatTextForDisplay("before " .. existing .. " after :heart:") == "before " .. existing .. " after " .. heartSprite,
      "existing hyperlink markup must remain untouched while plain tokens render"
    )

    ----------------------------------------------------------------------------
    -- Emoji formatting must not rewrite either target or display of URLs that
    -- are generated from plain text.
    ----------------------------------------------------------------------------
    do
      local url = "https://example.com/:heart:"
      assert(
        Hyperlinks.FormatTextForDisplay(url .. " :heart:") == wrapUrl(url, url) .. " " .. heartSprite,
        "URL emoji tokens must remain literal while tokens outside the URL render"
      )
    end
  end

  ----------------------------------------------------------------------------
  -- http / https URLs get wrapped in WoW hyperlink syntax
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("http://example.com")
    assert(out == wrapUrl("http://example.com", "http://example.com"), "http URL must be wrapped, got " .. out)

    out = Hyperlinks.FormatTextForDisplay("https://secure.example.com/path?q=1")
    assert(
      out == wrapUrl("https://secure.example.com/path?q=1", "https://secure.example.com/path?q=1"),
      "https URL with query string must be wrapped, got " .. out
    )
  end

  ----------------------------------------------------------------------------
  -- bare www.* URL gets https:// in the link target but display stays as typed
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("www.example.com")
    assert(out == wrapUrl("https://www.example.com", "www.example.com"), "www. URL needs scheme prefix in link target only, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Word-boundary guard: a URL preceded by a word character must NOT be wrapped.
  -- Otherwise "axhttp://x" would gobble up the "http://x" portion as a link.
  ----------------------------------------------------------------------------
  do
    local input = "axhttp://example.com"
    local out = Hyperlinks.FormatTextForDisplay(input)
    assert(out == input, "URL with word-char before must NOT be wrapped, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Trailing punctuation trim: "Visit http://x.com." should keep the period
  -- outside the link so the URL is clickable cleanly.
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("Visit http://example.com.")
    local expected = "Visit " .. wrapUrl("http://example.com", "http://example.com") .. "."
    assert(out == expected, "trailing period should be trimmed and appended after the link, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Balanced delimiter: "(http://x.com/test(a))" — outer ) is unbalanced, trim
  -- it; inner (a) stays inside the URL.
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("(http://example.com/path(a))")
    local expected = "(" .. wrapUrl("http://example.com/path(a)", "http://example.com/path(a)") .. ")"
    assert(out == expected, "unbalanced trailing paren should be trimmed, balanced inner ones kept, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Multiple URLs in a single string each get wrapped independently.
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("see http://a.com and https://b.com today")
    local expected = "see " .. wrapUrl("http://a.com", "http://a.com") .. " and " .. wrapUrl("https://b.com", "https://b.com") .. " today"
    assert(out == expected, "multiple URLs must each be wrapped, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Existing |H...|h...|h hyperlinks (e.g. item links from chat) must pass
  -- through untouched. Plain segments around them still get URL formatting.
  ----------------------------------------------------------------------------
  do
    local existing = "|Hitem:6948|h[Hearthstone]|h"
    local out = Hyperlinks.FormatTextForDisplay("got " .. existing .. " from http://example.com")
    local expected = "got " .. existing .. " from " .. wrapUrl("http://example.com", "http://example.com")
    assert(out == expected, "existing hyperlink must survive, surrounding plain text gets URL-formatted, got " .. out)
  end

  ----------------------------------------------------------------------------
  -- Classic quest-log shift-click format `[Name (questID)]` is plain text in
  -- vanilla Classic. Convert to a real quest hyperlink so the bubble is
  -- clickable and tooltips work.
  ----------------------------------------------------------------------------
  do
    local out = Hyperlinks.FormatTextForDisplay("look at [Apprentice's Duties (471)] please")
    local expected = "look at |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r please"
    assert(out == expected, "classic quest format must be rewritten, got: " .. out)
  end

  ----------------------------------------------------------------------------
  -- HandleClick on a Blizzard (non-url) link delegates to _G.SetItemRef.
  ----------------------------------------------------------------------------
  do
    local savedSetItemRef = _G.SetItemRef
    local sawLink, sawText, sawButton, sawFrame
    _G.SetItemRef = function(link, text, button, frame)
      sawLink, sawText, sawButton, sawFrame = link, text, button, frame
    end

    local handled = Hyperlinks.HandleClick("item:6948", "[Hearthstone]", "LeftButton", { id = "owner" })
    assert(handled == true, "HandleClick should return true when SetItemRef handled the link")
    assert(sawLink == "item:6948", "SetItemRef should receive the original link, got " .. tostring(sawLink))
    assert(sawText == "[Hearthstone]", "SetItemRef should receive the display text, got " .. tostring(sawText))
    assert(sawButton == "LeftButton", "SetItemRef should receive the button arg, got " .. tostring(sawButton))
    assert(type(sawFrame) == "table" and sawFrame.id == "owner", "SetItemRef should receive the source frame, got " .. tostring(sawFrame))

    _G.SetItemRef = savedSetItemRef
  end

  ----------------------------------------------------------------------------
  -- HandleClick with no SetItemRef and a non-url link returns false.
  ----------------------------------------------------------------------------
  do
    local savedSetItemRef = _G.SetItemRef
    _G.SetItemRef = nil

    local handled = Hyperlinks.HandleClick("item:6948", "[Hearthstone]", "LeftButton", nil)
    assert(handled == false, "HandleClick should return false when SetItemRef is missing for a Blizzard link")

    _G.SetItemRef = savedSetItemRef
  end

  ----------------------------------------------------------------------------
  -- HandleClick on a url-typed link routes the URL to the manual-copy fallback.
  -- (LaunchURL is protected in addon context; clipboard copy is the fallback.)
  ----------------------------------------------------------------------------
  do
    capturedCopies = {}
    copyReturn = true
    local handled = Hyperlinks.HandleClick("url:https://example.com/path", "https://example.com/path", "LeftButton", nil)
    assert(handled == true, "HandleClick on url should return true when copy succeeded")
    assert(#capturedCopies == 1, "exactly one copy invocation expected, got " .. tostring(#capturedCopies))
    assert(capturedCopies[1] == "https://example.com/path", "copied URL must match the link payload, got " .. tostring(capturedCopies[1]))
  end

  ----------------------------------------------------------------------------
  -- HandleClick on a url link returns false when the copy fallback fails.
  ----------------------------------------------------------------------------
  do
    capturedCopies = {}
    copyReturn = false
    local handled = Hyperlinks.HandleClick("url:https://fail.example.com", "x", "LeftButton", nil)
    assert(handled == false, "HandleClick on url should return false when copy failed")
    copyReturn = true
  end

  ----------------------------------------------------------------------------
  -- HandleEnter on an external URL anchors the tooltip to the owner and shows
  -- the URL as plain text (we cannot use SetHyperlink for "url:" links).
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local owner, anchor, lastText, hidden, sawHyperlink
    _G.GameTooltip = {
      SetOwner = function(_, o, a)
        owner, anchor = o, a
      end,
      SetText = function(_, t)
        lastText = t
      end,
      SetHyperlink = function(_, link)
        sawHyperlink = link
      end,
      Show = function()
        hidden = false
      end,
      Hide = function()
        hidden = true
      end,
    }

    local ownerStub = { id = "bubble" }
    Hyperlinks.HandleEnter(ownerStub, "url:https://example.com")
    assert(owner == ownerStub, "tooltip should be anchored to the owner frame")
    assert(anchor == "ANCHOR_CURSOR", "tooltip should use ANCHOR_CURSOR, got " .. tostring(anchor))
    assert(lastText == "https://example.com", "tooltip text should be the URL, got " .. tostring(lastText))
    assert(sawHyperlink == nil, "external url tooltip must not call SetHyperlink")
    assert(hidden == false, "tooltip should be Shown after setting text")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- HandleEnter on a Blizzard link uses tooltip:SetHyperlink (so item/spell
  -- tooltips render natively).
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local sawHyperlink, sawText, hidden
    _G.GameTooltip = {
      SetOwner = function() end,
      SetHyperlink = function(_, link)
        sawHyperlink = link
      end,
      SetText = function(_, t)
        sawText = t
      end,
      Show = function()
        hidden = false
      end,
      Hide = function()
        hidden = true
      end,
    }

    Hyperlinks.HandleEnter({}, "item:6948")
    assert(sawHyperlink == "item:6948", "Blizzard link should be passed to SetHyperlink, got " .. tostring(sawHyperlink))
    assert(sawText == nil, "SetText fallback must not run when SetHyperlink succeeded")
    assert(hidden == false, "tooltip must be shown")

    _G.GameTooltip = savedTooltip
  end

  ----------------------------------------------------------------------------
  -- HandleLeave hides GameTooltip when present, no-ops when absent.
  ----------------------------------------------------------------------------
  do
    local savedTooltip = _G.GameTooltip
    local hidden = false
    _G.GameTooltip = {
      Hide = function()
        hidden = true
      end,
    }
    Hyperlinks.HandleLeave()
    assert(hidden == true, "HandleLeave should call GameTooltip:Hide()")

    _G.GameTooltip = nil
    -- Must not error when there is no tooltip global at all.
    Hyperlinks.HandleLeave()

    _G.GameTooltip = savedTooltip
  end
end
