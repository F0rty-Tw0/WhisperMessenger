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

function DataBroker.Register(options)
  options = options or {}

  local dataobj = nil

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
    dataobj = ldb:NewDataObject("WhisperMessenger", {
      type = "launcher",
      icon = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png",
      label = "Whisper Messenger",
      text = "Whisper Messenger",
      OnClick = function(_)
        if options.onToggle then
          options.onToggle()
        end
      end,
      OnTooltipShow = function(tt)
        if not tt or not tt.AddLine then
          return
        end
        tt:AddLine("Whisper Messenger")
        if options.getUnreadCount then
          local count = options.getUnreadCount()
          if count and count > 0 then
            tt:AddLine(tostring(count) .. " unread")
          end
        end
      end,
    })

    if dataobj and options.onRegistered then
      options.onRegistered(dataobj)
    end

    trace("LDB data object registered: WhisperMessenger")
    return dataobj ~= nil
  end

  if not tryRegister() then
    local loginFrame = _G.CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
      tryRegister()
      loginFrame:UnregisterEvent("PLAYER_LOGIN")
    end)
  end

  return dataobj
end

ns.MinimapIconDataBroker = DataBroker
return DataBroker
