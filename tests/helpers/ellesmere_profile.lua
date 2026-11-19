-- Fakes EllesmereUI Action Bars for one call: a profile table is served as
-- its db.profile, nil means the module is missing, "error" makes GetAddon
-- throw. _G.EllesmereUI is cleared afterwards, even when fn fails.
return function(profile, fn)
  rawset(_G, "EllesmereUI", {
    Lite = {
      GetAddon = function(name)
        assert(name == "EllesmereUIActionBars", "asks for the action bars module")
        if profile == "error" then
          error("boom")
        end
        return profile and { db = { profile = profile } } or nil
      end,
    },
  })
  local ok, err = pcall(fn)
  rawset(_G, "EllesmereUI", nil)
  if not ok then
    error(err, 0)
  end
end
