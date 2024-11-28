-- nfifths
-- fifths (from crow) on norns
-- docs go here

engine.name = 'PolyPerc'
music = require 'musicutil'
m = midi.connect()

-- tonics on the circle of fifths starting from Gb all the way to F#,
-- always choosing an octave with a note as close as possible to the key center (0)
circle_of_fifths = { -6, 1, -4, 3, -2, 5, 0, -5, 2, -3, 4, -1, 6 }

tonic = 60

function init()
  scale = major_scale(circle_of_fifths[7] + tonic)
  engine.release(3)
end

m.event = function(data)
  local msg = midi.to_msg(data)
  if (msg.type == 'note_on') then
    local chord = quant_chord(msg.note)
    for i = 1, 3 do
      engine.hz(music.note_num_to_freq(chord[i]))
    end
  end
end

function quant_chord(note)
  local closest_scale_degree = math.floor(util.linlin(0, 11, 0, 6, note % 12) + 0.5)

  local octave_delta = (math.floor(note / 12) * 12) - tonic
  local root = tonic +
      (scale[closest_scale_degree + 1] + (math.floor(closest_scale_degree / 7) * 12) - tonic) + octave_delta

  -- if the note isn't in the key, randomly choose between the next or previous note from the key
  -- guitarists know: a bum note is always only one fret (semitone) away from a good note. Either way will work.
  if note ~= root then
    closest_scale_degree = math.floor(closest_scale_degree + 0.5 + (math.random() * -1))
  end

  local nums = {}

  for i = 1, 3 do
    nums[i] = tonic
        +
        (scale[(closest_scale_degree + (2 * (i - 1))) % 7 + 1] + (math.floor((closest_scale_degree + (2 * (i - 1))) / 7) * 12) - tonic)
        +
        octave_delta
  end
  return nums
end

--build a major scale for any root note (tonic)
function major_scale(tonic)
  local scale = {}
  local whole = 2
  local half = 1
  scale = {
    tonic,
    tonic + whole,
    tonic + whole + whole,
    tonic + whole + whole + half,
    tonic + whole + whole + half + whole,
    tonic + whole + whole + half + whole + whole,
    tonic + whole + whole + half + whole + whole + whole
  }
  return scale
end

----- BELOW HERE FROM CROW VERSION
---
---
---

--[[
-- window boundaries for 13 equal-ish sized windows for -5 to +5V
thirteen_windows = { -4.97, -4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5, 4.97 }
-- choose output values based on input 1 and offsets based on fifths. 0V is assumed to be tuned to C3 (not mandatory!)
input[1].scale = function(x)
  local fifth = 7 / 12
  local relative_to_c3 = x.volts + 2
  output[1].volts = relative_to_c3
  output[2].volts = relative_to_c3 + fifth
  output[3].volts = relative_to_c3 + fifth + fifth
  output[4]() -- pulse output 4 when tuning
end

-- when input 2 hops between windows, choose a new key from the circle of fifths
input[2].window = function(x)
  local new_key = major_scale(circle_of_fifths[x])
  input[1].mode('scale', new_key)
end

--initialize things
function init()

  --input 2 produces value 1 at -5V and value 12 at +5V
  input[2].mode('window',thirteen_windows,0.2)

  --quantize all tuned outputs to the chromatic scale in case our fifths get weird
  for i=1,3 do
      output[i].scale({})
  end

  --start in C major (ie. 0V at input 2)
  input[2].window(7)

  -- set up output 4 pulses
  output[4].action = pulse(0.01, 5)
end
--]]
