local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local trace = ns.trace or require("WhisperMessenger.Core.Trace")

local DataBroker = {}

--- Build the display text for the LDB launcher.
-- Bazooka reads obj.text as a string value — functions are NOT called,
-- they're passed directly to SetFormattedText which blows up.
-- Always returns a plain string.
-- @param unread number|nil — current unread whisper count
-- @return string
function DataBroker.FormatText(unread)
  local count = unread or 0
  if count > 0 then
    return tostring(count) .. " unread"
  end
  return "Whisper Messenger"
end

--- Register the launcher data object with LibDataBroker.
-- Reports the object exclusively through options.onRegistered — the callback
-- fires on both the immediate path and the deferred PLAYER_LOGIN retry, so
-- callers only wire one path. The refresh loop keeps `obj.text` and
-- `obj.unread` up to date; the tooltip reads the cached `unread` attribute
-- instead of rebuilding the contacts list on every hover.
function DataBroker.Register(options)
  options = options or {}

  local function tryRegister()
    if type(_G.LibStub) ~= "table" then
      return false
    end
    local ldb = _G.LibStub("LibDataBroker-1.1", true)
    if ldb == nil then
      return false
    end

    -- text is a plain string — Bazooka requires it. Dynamic updates
    -- happen by assigning ldb.text directly from refreshContacts.
    local dataobj = ldb:NewDataObject("WhisperMessenger", {
      type = "launcher",
      icon = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png",
      label = "Whisper Messenger",
      text = "Whisper Messenger",
      OnClick = function(_)
        if options.onToggle then
          options.onToggle()
        end
      end,
      OnTooltipShow = nil, -- assigned below so it can read the data object
    })

    if dataobj == nil then
      return false
    end

    dataobj.OnTooltipShow = function(tt)
      if not tt or not tt.AddLine then
        return
      end
      tt:AddLine("Whisper Messenger")
      local count = tonumber(dataobj.unread) or 0
      if count > 0 then
        tt:AddLine(DataBroker.FormatText(count))
      end
    end

    if options.onRegistered then
      options.onRegistered(dataobj)
    end

    trace("LDB data object registered: WhisperMessenger")
    return true
  end

  if not tryRegister() and type(_G.CreateFrame) == "function" then
    trace("LDB not available; deferring registration to PLAYER_LOGIN")
    local loginFrame = _G.CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
      tryRegister()
      loginFrame:UnregisterEvent("PLAYER_LOGIN")
    end)
  end
end

ns.MinimapIconDataBroker = DataBroker
return DataBroker
