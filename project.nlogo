extensions [ matrix ]
globals [
  bystanders-strategies-1 bystanders-strategies-2 victims-strategies bullies-strategies
  b nts ts sdb sb idb ]

breed [bullies bully]
bullies-own [ strategy-1 strategy-2 strategies-1 strategies-2 payoff ]
breed [victims victim]
victims-own [ strategy strategies payoff ]
breed [bystanders bystander]
bystanders-own [ strategy-1 strategy-2 strategies-1 strategies-2 payoff ]

to setup
  random-seed 42
  clear-all
  check-population-perc
  setup-patches
  setup-agents
  setup-values
  reset-ticks
end

to go
  if ticks = (max-steps - 1) [ stop ]

  setup-patches
  place-agents

  if game-1 [
    play-game-1
    revise-game-1
  ]

  if game-2 [
    play-game-2
    revise-game-2
  ]

  setup-agents-shape

  tick
end

to check-population-perc
  if (victims-perc + bystanders-perc + bullies-perc) != 100 [ error "Victims, bystanders and bullies percentages must sum up to 100." ]
end

to setup-patches
  ask patches [ set pcolor white - 1 ]
end

; --------------- Setup agents ------------------------------ ;
to setup-agents
  set bullies-strategies (list "bully" "dont")
  set bystanders-strategies-1 (list "defend" "witness")
  set bystanders-strategies-2 (list "defend" "support")
  set victims-strategies (list "victim")

  setup-victims
  setup-bullies
  setup-bystanders
end

to setup-victims
  let num-victims (round (population * (victims-perc / 100)))

  create-victims num-victims [
    set payoff 0
    set strategies victims-strategies
    set strategy one-of strategies
  ]
end

to setup-bullies
  let num-bullies (round (population * (bullies-perc / 100)))

  create-bullies num-bullies [
    set payoff 0
    set strategies-1 bullies-strategies
    set strategies-2 bullies-strategies
    set strategy-1 "dont"
    set strategy-2 "dont"
  ]

  let num-bullying-1 (round (num-bullies * (bullying-dist-1 / 100)))
  ask n-of num-bullying-1 bullies [
    set strategy-1 "bully"
  ]

  let num-bullying-2 (round (num-bullies * (bullying-dist-2 / 100)))
  ask n-of num-bullying-2 bullies [
    set strategy-2 "bully"
  ]

end

to setup-bystanders
  let num-bystanders (round (population * (bystanders-perc / 100)))

  create-bystanders num-bystanders [
    set payoff 0
    set strategies-1 bystanders-strategies-1
    set strategies-2 bystanders-strategies-2

    set strategy-1 "witness"
    set strategy-2 "defend"
  ]

  let num-defenders (round (num-bystanders * (defenders-dist / 100)))
  ask n-of num-defenders bystanders with [ strategy-1 = "witness" ] [ set strategy-1 "defend" ]

  let num-supporters (round (num-bystanders * (supporters-dist / 100)))
  ask n-of num-supporters bystanders with [ strategy-2 = "defend" ] [ set strategy-2 "support" ]
end

to setup-agents-shape
  ask turtles [ set shape "person student" ]
  ask bullies [ set color red ]
  ask victims [ set color black ]
  ask bystanders [ set color gray ]
end


; --------------- Placing ------------------------------ ;
to place-agents
  place-victims
  place-bystanders
  place-bullies
end

to place-victims
  ask victims [ setxy random-xcor random-ycor ]
end

to place-bystanders
  ask bystanders [ setxy random-xcor random-ycor ]
end

to place-bullies
  ask bullies [
    ;; bully needs to be around one victim
    let choosen-victim one-of victims

    ;; set position of bully such that the victim is in its range of action
    let x ([xcor] of choosen-victim + ((random-normal 0 1) * (communication-radius / 2)))
    if x >= max-pxcor [set x (max-pxcor)]
    if x <= min-pxcor [set x (min-pxcor)]

    let y ([ycor] of choosen-victim + ((random-normal 0 1) * (communication-radius / 2)))
    if y >= max-pycor [set y (max-pycor)]
    if y <= min-pycor [set y (min-pycor)]

    setxy x y

    ;; set patch color to light red to highlight the area the bully is active on
    set pcolor red + 3
    ask patches in-radius communication-radius [
      set pcolor red + 3
    ]
  ]
end

; ------------------ Games ------------------------------- ;
to setup-values
  set b baseline-value
  set nts (not-take-stand * b)
  set ts (take-stand * b)
  set sdb (support-but-bully-backs-up * b)
  set sb (support-bully * b)
  set idb (defend-ineffective * b)
end


to-report pmi [agent]
  if is-bully? agent [
    if ([strategy-1] of agent) = "bully" [ report 0 ]
    if ([strategy-1] of agent) = "dont" [ report 1 ]
  ]

  if is-bystander? agent [
    if ([strategy] of agent) = "witness" [ report 2 ]
    if ([strategy] of agent) = "defend" [ report 3 ]
  ]
end

; -- Game 1 -- ;
to-report pmi-g1 [agent]
  if is-bully? agent [
    if ([strategy-1] of agent) = "bully" [ report 0 ]
    if ([strategy-1] of agent) = "dont" [ report 1 ]
  ]

  if is-bystander? agent [
    if ([strategy-1] of agent) = "witness" [ report 2 ]
    if ([strategy-1] of agent) = "defend" [ report 3 ]
  ]
end

to-report pm-g1
  report (matrix:from-row-list (list
    (list 0 0 (2 * b) 0)
    (list 0 0 b b)
    (list nts b 0 0)
    (list ts b 0 0)
  ))
end

to play-game-1
  ;; play bullies
  ask bullies [
    foreach sort bystanders in-radius communication-radius [ the-other ->
      let bully-pmi pmi-g1 turtle who
      let byst-pmi pmi-g1 the-other

      ;; set bully payoff
      set payoff payoff + (matrix:get pm-g1 bully-pmi byst-pmi)
      ;; set bystander payoff
      ask the-other [ set payoff payoff + (matrix:get pm-g1 byst-pmi bully-pmi) ]
    ]
  ]
end

to revise-game-1
  ask bullies [
    ;; randomly choose probability
    ifelse (random-float 1) < prob-revision [ set strategy-1 one-of strategies-1]
    [
      ;; get target of same breed in comunication range
      let target max-one-of other breed in-radius communication-radius [ payoff ]
      if target != nobody and [payoff] of target > payoff [ set strategy-1 [strategy-1] of target ]
    ]
  ]

  ask bystanders [
    ;; randomly choose probability
    ifelse (random-float 1) < prob-revision [ set strategy-1 one-of strategies-1]
    [
      ;; get target of same breed in comunication range
      let target max-one-of other breed in-radius communication-radius [ payoff ]
      if target != nobody and [payoff] of target > payoff [ set strategy-1 [strategy-1] of target ]
    ]
  ]
end


; -- Game 2 -- ;
to-report pmi-g2 [agent]
  if is-bully? agent [
    if ([strategy-2] of agent) = "bully" [ report 0 ]
    if ([strategy-2] of agent) = "dont" [ report 1 ]
  ]

  if is-bystander? agent [
    if ([strategy-2] of agent) = "support" [ report 2 ]
    if ([strategy-2] of agent) = "defend" [ report 3 ]
  ]
end

to-report pm-g2
  report (matrix:from-row-list (list
    (list 0 0 (3 * b) (- b))
    (list 0 0 0 (- 2 * b))
    (list sb sdb 0 0)
    (list idb (2 * b) 0 0)
  ))
end

to play-game-2
  ask bullies [
    ;; game is played only if:
    ;;  1) there is a bully bullying in the nearby
    ;;  2) there is a defender in the nearby of the bully and its decision was to part for the victim
    let cond-1 (is-bully? who and strategy-1 = "bully") or (any? bullies with [ strategy-1 = "bully" ] in-radius communication-radius)
    let cond-2 (any? bystanders with [ strategy-1 = "defend" ] in-radius communication-radius) ;; if current turtle stand out as a defender than its counted by default

    if cond-1 and cond-2 [
      foreach sort bystanders in-radius communication-radius [ the-other ->
        let bully-pmi pmi-g2 turtle who
        let byst-pmi pmi-g2 the-other

        ;; set bully payoff
        set payoff payoff + (matrix:get pm-g2 bully-pmi byst-pmi)
        ;; set bystander payoff
        ask the-other [ set payoff payoff + (matrix:get pm-g2 byst-pmi bully-pmi) ]
      ]
    ]
  ]
end

to revise-game-2
  ask bullies [
    ;; randomly choose probability
    ifelse (random-float 1) < prob-revision [ set strategy-2 one-of strategies-2]
    [
      ;; get target of same breed in comunication range
      let target max-one-of other breed in-radius communication-radius [ payoff ]
      if target != nobody and [payoff] of target > payoff [ set strategy-2 [strategy-2] of target ]
    ]
  ]

  ask bystanders [
    ;; randomly choose probability
    ifelse (random-float 1) < prob-revision [ set strategy-2 one-of strategies-2]
    [
      ;; get target of same breed in comunication range
      let target max-one-of other breed in-radius communication-radius [ payoff ]
      if target != nobody and [payoff] of target > payoff [ set strategy-2 [strategy-2] of target ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
5
325
368
689
-1
-1
9.6
1
10
1
1
1
0
0
0
1
-18
18
-18
18
1
1
1
ticks
30.0

BUTTON
10
10
83
43
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
90
10
180
43
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
190
10
253
43
NIL
go
T
1
T
OBSERVER
NIL
R
NIL
NIL
1

PLOT
765
10
1285
355
Bystanders game-1 strategy distribution
Time
Percentage
0.0
1000.0
0.0
1.0
true
true
"clear-plot\nset-plot-x-range 0 max-steps + 1\n\nset-current-plot-pen \"Defend\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2\n\nset-current-plot-pen \"Witness\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2" "let pop count bystanders\n\nlet def (count bystanders with [strategy-1 = \"defend\"]) / pop\nlet wit (count bystanders with [strategy-1 = \"witness\"]) / pop\n\nset-current-plot-pen \"Defend\"\nforeach (range 0 1 0.2) [ i -> plot (wit + def) ]\n\nset-current-plot-pen \"Witness\"\nforeach (range 0 1 0.2) [ i -> plot (wit) ]"
PENS
"Defend" 1.0 1 -10899396 true "" ""
"Witness" 1.0 1 -7500403 true "" ""

SLIDER
380
55
740
88
communication-radius
communication-radius
2
world-width
3.0
1
1
patches
HORIZONTAL

SLIDER
380
130
740
163
prob-revision
prob-revision
0
0.1
0.0025
0.0001
1
NIL
HORIZONTAL

TEXTBOX
10
115
160
136
Population setup
18
0.0
1

TEXTBOX
380
25
630
50
Communication setup
18
0.0
1

TEXTBOX
380
100
650
130
Strategy variation
18
0.0
1

SLIDER
380
200
740
233
defenders-dist
defenders-dist
0
100
17.0
1
1
NIL
HORIZONTAL

SLIDER
380
270
740
303
witnessers-dist
witnessers-dist
0
100
54.0
1
1
NIL
HORIZONTAL

SLIDER
380
235
740
268
supporters-dist
supporters-dist
0
100
29.0
1
1
NIL
HORIZONTAL

SLIDER
380
340
740
373
bullying-dist-2
bullying-dist-2
0
100
100.0
1
1
NIL
HORIZONTAL

INPUTBOX
260
10
365
80
max-steps
500.0
1
0
Number

INPUTBOX
5
140
365
200
population
300.0
1
0
Number

SLIDER
380
415
740
448
baseline-value
baseline-value
1
10
5.0
0.05
1
NIL
HORIZONTAL

SLIDER
5
205
365
238
victims-perc
victims-perc
0
100
11.0
1
1
NIL
HORIZONTAL

SLIDER
5
245
365
278
bystanders-perc
bystanders-perc
0
100
78.0
1
1
NIL
HORIZONTAL

SLIDER
5
285
365
318
bullies-perc
bullies-perc
0
100
11.0
1
1
NIL
HORIZONTAL

TEXTBOX
380
385
590
410
Payoff matrix values
18
0.0
1

TEXTBOX
380
170
630
200
Strategy distirbution
18
0.0
1

PLOT
1290
10
1825
355
Bullies first game strategy distribution
Timesteps
Percentage
0.0
501.0
0.0
1.0
true
true
"clear-plot\nset-plot-x-range 0 max-steps + 1\n\nset-current-plot-pen \"Bully\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2\n\nset-current-plot-pen \"Don't bully\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2" "let pop count bullies\n\nlet do (count bullies with [strategy-1 = \"bully\"]) / pop\nlet dont (count bullies with [strategy-1 = \"dont\"]) / pop\n\nset-current-plot-pen \"Bully\"\nforeach (range 0 1 0.2) [ i -> plot (dont + do) ]\n\nset-current-plot-pen \"Don't bully\"\nforeach (range 0 1 0.2) [ i -> plot (dont) ]"
PENS
"Bully" 1.0 0 -2674135 true "" ""
"Don't bully" 1.0 0 -11221820 true "" ""

PLOT
1290
360
1825
705
Bullying on first game - second game strategy distribution
Timesteps
Percentage
0.0
10.0
0.0
1.0
true
true
"clear-plot\nset-plot-x-range 0 max-steps + 1\n\nset-current-plot-pen \"Bully\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2\n\nset-current-plot-pen \"Don't bully\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2\n\nset-current-plot-pen \"No bullying\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2" "let pop bullies with [ strategy-1 = \"bully\" ]\n\nifelse any? pop [\n  let do (count pop with [strategy-2 = \"bully\"]) / count pop\n  let dont (count pop with [strategy-2 = \"dont\"]) / count pop\n  set-current-plot-pen \"Bully\"\n  foreach (range 0 1 0.2) [ i -> plot (dont + do) ]\n  set-current-plot-pen \"Don't bully\"\n  foreach (range 0 1 0.2) [ i -> plot (dont) ]\n  set-current-plot-pen \"No bullying\"\n  foreach (range 0 1 0.2) [ i -> plot 0 ]\n] [\n  set-current-plot-pen \"Bully\"\n  foreach (range 0 1 0.2) [ i -> plot 0 ]\n  set-current-plot-pen \"Don't bully\"\n  foreach (range 0 1 0.2) [ i -> plot 0 ]\n  set-current-plot-pen \"No bullying\"\n  foreach (range 0 1 0.2) [ i -> plot 1 ]\n]"
PENS
"Bully" 1.0 0 -2674135 true "" ""
"Don't bully" 1.0 0 -11221820 true "" ""
"No bullying" 1.0 0 -1 true "" ""

PLOT
765
360
1285
705
Bystanders game-2 strategy distribution
Time
Percentage
0.0
1000.0
0.0
1.0
false
true
"clear-plot\nset-plot-x-range 0 max-steps + 1\n\nset-current-plot-pen \"Defend\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2\n\nset-current-plot-pen \"Support\"\nset-plot-pen-mode 1\nset-plot-pen-interval 0.2" "let pop count bystanders\n\nlet def (count bystanders with [strategy-2 = \"defend\"]) / pop\nlet sup (count bystanders with [strategy-2 = \"support\"]) / pop\n\nset-current-plot-pen \"Defend\"\nforeach (range 0 1 0.2) [ i -> plot (sup + def) ]\n\nset-current-plot-pen \"Support\"\nforeach (range 0 1 0.2) [ i -> plot (sup) ]"
PENS
"Defend" 1.0 0 -10899396 true "" ""
"Support" 1.0 0 -955883 true "" ""

SLIDER
380
455
740
488
take-stand
take-stand
-3
3
-0.5
0.05
1
NIL
HORIZONTAL

SLIDER
380
495
740
528
not-take-stand
not-take-stand
-3
3
-0.5
0.05
1
NIL
HORIZONTAL

SLIDER
380
535
740
568
support-but-bully-backs-up
support-but-bully-backs-up
-3
3
-0.5
0.05
1
NIL
HORIZONTAL

SLIDER
380
575
740
608
support-bully
support-bully
-3
3
-0.5
0.05
1
NIL
HORIZONTAL

SLIDER
380
615
740
648
defend-ineffective
defend-ineffective
-3
3
1.0
0.05
1
NIL
HORIZONTAL

SWITCH
10
45
130
78
game-1
game-1
0
1
-1000

SWITCH
137
45
252
78
game-2
game-2
0
1
-1000

SLIDER
380
305
740
338
bullying-dist-1
bullying-dist-1
0
100
100.0
1
1
NIL
HORIZONTAL

TEXTBOX
15
715
580
786
Model developed by Nicolas Lazzari (979086) - nicolas.lazzari2@studio.unibo.it
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
