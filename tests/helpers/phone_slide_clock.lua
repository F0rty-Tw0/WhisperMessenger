local Theme = require("WhisperMessenger.UI.Theme")

-- Plays a phone slide out frame by frame, as the client does.
local PhoneSlideClock = {}

local FPS = 60

local function ticking(viewport)
  return viewport.scripts ~= nil and viewport.scripts.OnUpdate ~= nil
end

-- The slide clamps one tick to 1/30 s, so a slow frame cannot skip it. Two
-- spare frames cover rounding; a slide still running after that is a bug.
function PhoneSlideClock.Finish(viewport)
  local frames = math.ceil(Theme.LAYOUT.PHONE_SLIDE_SECONDS * FPS) + 2
  for _ = 1, frames do
    if not ticking(viewport) then
      return
    end
    viewport.scripts.OnUpdate(viewport, 1 / FPS)
  end
  assert(not ticking(viewport), "the slide did not end within " .. frames .. " frames")
end

return PhoneSlideClock
