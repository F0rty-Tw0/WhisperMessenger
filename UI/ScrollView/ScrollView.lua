local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local Factory = ns.ScrollViewFactory or require("WhisperMessenger.UI.ScrollView.Factory")

local ScrollView = {}
ScrollView.GetRange = Metrics.GetRange
ScrollView.GetOffset = Metrics.GetOffset
ScrollView.RefreshMetrics = Metrics.RefreshMetrics
ScrollView.Sync = Navigation.Sync
ScrollView.SetVerticalScroll = Navigation.SetVerticalScroll
ScrollView.ScrollBy = Navigation.ScrollBy
ScrollView.Create = Factory.Create

ns.ScrollView = ScrollView
return ScrollView
