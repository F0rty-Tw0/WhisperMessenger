local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local Metrics = ns.ScrollViewMetrics or loadModule("WhisperMessenger.UI.ScrollView.Metrics", "ScrollViewMetrics")
local Navigation = ns.ScrollViewNavigation or loadModule("WhisperMessenger.UI.ScrollView.Navigation", "ScrollViewNavigation")
local Factory = ns.ScrollViewFactory or loadModule("WhisperMessenger.UI.ScrollView.Factory", "ScrollViewFactory")

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
