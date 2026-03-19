local Fixtures = {}

function Fixtures.clone(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, entry in pairs(value) do
    copy[key] = Fixtures.clone(entry)
  end

  return copy
end

return Fixtures
