-- nfifths
-- fifths (from crow) on norns
-- docs go here

engine.name = 'MxSynths'
music = require 'musicutil'
midi_in = midi.connect(1)
midi_out = midi.connect(2)

-- tonics on the circle of fifths starting from Gb all the way to F#,
-- always choosing an octave with a note as close as possible to the key center (0)
circle_of_fifths = { 0, -5, 2, -3, 4, -1, 6, -6, 1, -4, 3, -2, 5 }

key_names = {
  "C",
  "G",
  "D",
  "A",
  "E",
  "B",
  "F#",
  "Db",
  "Ab",
  "Eb",
  "Bb",
  "F"
}

-- window boundaries for 13 equal-ish sized windows for -5 to +5V (for crow input)
thirteen_windows = { -4.97, -4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5, 4.97 }

voicing = 1

permutations = {
  { true,  false, false },
  { false, true,  false },
  { false, false, true },
  { true,  true,  false },
  { true,  false, true },
  { false, true,  true },
  { true,  true,  true }
}

tonic = 60
key_index = 1

slew = 0

function init()
  local mxsynths_=include("nfifths/lib/mx.synths")
  mxsynths=mxsynths_:new({save=true,previous=true})

  -- overwrite a couple mxsynths methods for chord purposes
  function mxsynths:note_on(note,amp,duration) fifths_note_on(note,amp, duration) end
  function mxsynths:note_off(note) fifths_note_off(note) end

  mxsynths:setup_midi()

  scale = major_scale(tonic)
  screen.aa(0)

  --crow init steps
  --input 2 produces value 1 at -5V and value 12 at +5V
  crow.input[2].mode('window', thirteen_windows, 0.2)

  --quantize all tuned outputs to the chromatic scale in case our fifths get weird
  for i = 1, 3 do
    crow.output[i].scale({})
  end
  --comment

  --start in C major (ie. 0V at input 2)
  crow.input[2].window(key_index)

  -- set up output 4 pulses
  crow.output[4].action = crow.pulse(0.01, 5)

  redraw()
end

-- midi_in.event = function(data)
--   local msg = midi.to_msg(data)
--   if msg.type == 'note_on' then
--     local chord = quant_chord(msg.note)
--     for i = 1, 3 do
--       if permutations[voicing][i] then
--         engine.mx_note_on(chord[i],msg.vel, nil)
--         midi_out:note_on(chord[i], msg.vel)
--       end
--     end
--   elseif msg.type == 'note_off' then
--     local chord = quant_chord(msg.note)
--     for i = 1, 3 do
--       engine.mx_note_off(chord[i])
--       midi_out:note_off(chord[i])
--     end
--   end
-- end

function fifths_note_on(note,amp,duration)
  print("note on: ", note, " amp: ", amp, " duration: ",duration)
  local chord = quant_chord(note)
  for i = 1, 3 do
    if permutations[voicing][i] then
      engine.mx_note_on(chord[i],amp,duration)
      midi_out:note_on(chord[i], amp,duration)
    end
  end
end

function fifths_note_off(note)
  local chord = quant_chord(note)
    for i = 1, 3 do
      engine.mx_note_off(chord[i])
      midi_out:note_off(chord[i])
    end
end 

function redraw()
  screen.clear()
  draw_fifths()
  draw_dots(permutations[voicing])
  draw_env()
  draw_slew()
  screen.update()
end

function draw_slew()
  screen.move(85,53)
  screen.text("slew: " .. slew .. "%")
end

function draw_env()
  screen.move(87,38)
  screen.line(87,28)
  screen.line(97,28)
  screen.line(97,38)
  screen.stroke()
end

function draw_dots(states)
  local dot_radius = 1
  local x = 80
  local y = 15
  local spacing = 8

  for i = 1, 3 do
    if states[i] then
      screen.move(x + (i * spacing), y)
      screen.circle(x + (i * spacing), y, dot_radius + 1)
    else
      screen.move(x + dot_radius + (i * spacing), y)
      screen.pixel(x + (i * spacing), y)
    end
    screen.fill()
    screen.stroke()
  end
end

function draw_fifths()
  local radians = 0
  local center_x = 32
  local center_y = 34
  local big_radius = 25
  local small_radius = 7
  local x
  local y

  for i = 1, 13 do
    x = center_x + (big_radius * math.sin(radians))
    y = center_y - (big_radius * math.cos(radians))

    if i < 13 then
      radians = radians + (math.pi / 6)
      screen.move(x, y)
      screen.text_center(key_names[i])
    end

    if i == key_index then
      screen.move(x + 1+ small_radius, y-2)
      screen.circle(x+1, y - 2, small_radius)
      screen.stroke()
    end
  end
end

function quant_chord(note)
  
  local closest_scale_degree = math.floor(util.linlin(0, 11, 0, 6, note % 12) + 0.5)
  local octave_delta = (math.floor(note / 12) * 12) - tonic
  local root = tonic +
      (scale[closest_scale_degree + 1] + (math.floor(closest_scale_degree / 7) * 12) - tonic) + octave_delta

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

function rotate_key(delta)
  key_index = key_index + delta
  if key_index < 1 then key_index = 13 end
  if key_index > 13 then key_index = 1 end
  scale = major_scale(circle_of_fifths[key_index] + tonic)
end

function key(n, z)
  if z == 0 then
    if n == 2 then
      rotate_key(-1)
    elseif n == 3 then
      rotate_key(1)
    end
    redraw()
  end
end

function enc(n, d)
  --print("n = ",n,"d = ",d)
  if n == 1 then
    voicing = voicing + d
    if voicing > 7 then
      voicing = 1
    elseif voicing < 1 then
      voicing = 7
    end
  elseif n == 2 then

  elseif n == 3 then
    slew = util.clamp(slew + d, 0, 100)
  end
  redraw()
end

-- choose output values based on input 1 and offsets based on fifths. 0V is assumed to be tuned to C3 (not mandatory!)
crow.input[1].scale = function(x)
  local fifth = 7 / 12
  local relative_to_c3 = x.volts + 2
  crow.output[1].volts = relative_to_c3
  crow.output[2].volts = relative_to_c3 + fifth
  crow.output[3].volts = relative_to_c3 + fifth + fifth
  crow.output[4]() -- pulse output 4 when tuning
end

-- when input 2 hops between windows, choose a new key from the circle of fifths
crow.input[2].window = function(x)
  local new_key = major_scale(circle_of_fifths[x])
  crow.input[1].mode('scale', new_key)
end
