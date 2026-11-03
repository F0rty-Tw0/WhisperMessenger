-- Fake LibSharedMedia-3.0 holding only sounds. `sounds` is an ordered list
-- of { name, path }; nil leaves LibStub unset (no SharedMedia addon loaded).
-- with(sounds, fn) runs fn with the fake installed and restores LibStub.

local FakeSharedSounds = {}

local function newLibrary(sounds)
  return {
    List = function(_, mediaType)
      local names = {}
      if mediaType == "sound" then
        for _, sound in ipairs(sounds) do
          names[#names + 1] = sound[1]
        end
      end
      return names
    end,
    Fetch = function(_, mediaType, name, noDefault)
      assert(noDefault == true, "SharedMedia sounds must be fetched without LSM's default")
      if mediaType ~= "sound" then
        return nil
      end
      for _, sound in ipairs(sounds) do
        if sound[1] == name then
          return sound[2]
        end
      end
      return nil
    end,
  }
end

function FakeSharedSounds.with(sounds, fn)
  local saved = rawget(_G, "LibStub")
  local stub = nil
  if sounds then
    local library = newLibrary(sounds)
    stub = setmetatable({}, {
      __call = function(_, name)
        if name == "LibSharedMedia-3.0" then
          return library
        end
      end,
    })
  end
  rawset(_G, "LibStub", stub)
  local ok, err = pcall(fn)
  rawset(_G, "LibStub", saved)
  if not ok then
    error(err, 0)
  end
end

return FakeSharedSounds
