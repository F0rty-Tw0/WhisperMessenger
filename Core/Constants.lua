local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  ADDON_NAME = addonName or "WhisperMessenger",
  VERSION = "0.1.0",
}

ns.Constants = Constants

return Constants
