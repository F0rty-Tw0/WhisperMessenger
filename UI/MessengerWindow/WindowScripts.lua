local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Buttons = ns.MessengerWindowWindowScriptsButtons
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons")
local Frame = ns.MessengerWindowWindowScriptsFrame or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame")

local WindowScripts = {
  WireButtons = Buttons.WireButtons,
  WireFrame = Frame.WireFrame,
}

ns.MessengerWindowWindowScripts = WindowScripts

return WindowScripts
