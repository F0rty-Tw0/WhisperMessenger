-- Records StaticPopup_Show / StaticPopup_Hide names and ReloadUI calls while
-- fn(popups) runs, then puts the real globals back.
local ReloadPopups = {}

function ReloadPopups.With(fn)
  local saved = {
    dialogs = rawget(_G, "StaticPopupDialogs"),
    show = rawget(_G, "StaticPopup_Show"),
    hide = rawget(_G, "StaticPopup_Hide"),
    reload = rawget(_G, "ReloadUI"),
  }
  local popups = { shown = {}, hidden = {}, reloads = 0 }
  rawset(_G, "StaticPopupDialogs", {})
  rawset(_G, "StaticPopup_Show", function(name)
    popups.shown[#popups.shown + 1] = name
  end)
  rawset(_G, "StaticPopup_Hide", function(name)
    popups.hidden[#popups.hidden + 1] = name
  end)
  rawset(_G, "ReloadUI", function()
    popups.reloads = popups.reloads + 1
  end)
  local ok, err = pcall(fn, popups)
  rawset(_G, "StaticPopupDialogs", saved.dialogs)
  rawset(_G, "StaticPopup_Show", saved.show)
  rawset(_G, "StaticPopup_Hide", saved.hide)
  rawset(_G, "ReloadUI", saved.reload)
  if not ok then
    error(err, 0)
  end
end

return ReloadPopups
