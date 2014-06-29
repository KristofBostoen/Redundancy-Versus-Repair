;  For more information see the the Info tab. Do not forget to change the version number and date under the Info tab.

globals [
ref_distance      ; the scale example: 1 patch = 25 meters
Days_running        ; number of days the model is runnig
Time_of_day         ; the current time in hours
new_ticket          ; switch variable to set ticket_counter at the same number as ticket_number witch are variables owned by different turtles
current_number      ; switch variable to check if turn_number has the same value as ticket_number witch are variables owned by different turtles
current_collector   ; switch variable to identify a single turtle to update for
CollectorHLocation  ; switch variable to let home_location be read by other turtles
CollectorCLocation  ; switch variable to let waterpoint locations be read by other turtles
carry_water         ; switch variable to let carry_amount be read by households
To_Carry            ; switch variable to let pump know how much water was taken
;PumpBreakdownVolume ; Amount of water a pump can produce before it breaks down
;NumberOfPumpsBroken ; Number of pumps that are not working at the moment
max_queueP          ; switch variable to let pump know what max_queue is of collector  
collection_timeP    ; switch variable to let pump know wath the collectiontime is of a collector
enough_water?       ; check if they have enough water, true or false
;Random_setup?
;RandomWaterVolume
]

breed [households household]            ; turtle household
breed [waterpoints waterpoint]          ; turtle waterpoint
breed [watercollectors watercolletor]   ; turtle watercollector

Patches-own
[
patch_has_hh?      ; wether there is a household at a patch
patch_has_wp?      ; wether there is a waterpoint at a patch 
HH_density_radius  ; wat the household density radius is
]

households-own
[
household-locationH     ; their location
water_amount            ; the amount of water that is currently at the household
service_level           ; the service level calculated by amount of water and time needed to collect water




number_residents        ; each household has a number of residents
needed_water            ; each household needs a certain amount of water depending on the number of residents
water_service           ; percentage water/needed water
end_collecting_time
start_collecting_time
Total_Collecting_Time_Day
Total_Collections_Day
one_collecting_time

]

waterpoints-own
[
working-rate            ; at what rate a waterpoint is working : 1 = working 0 = not working
Moment_Broken           ; the exact tick when a water point breaks down
waterpoint_locationP    ; their location
ticket_counter          ; ticketcounter shows how many watercollectors there are at a waterpoint
turn_number             ; turnnumber shows witch number can fetch water, when it is their turn
queue_length            ; The lenth (in time) of the queue
Water_Delivered         ; amount of water collected from this water point
]

watercollectors-own
[
home_location           ; the household that is their home                      
walking-speed           ; the speed the watercollectors walk with
watercollection_status  ; the status they have during the day ; outgoing, collecting-water, redirecting, returnhome etc.
waterpoint_locationC    ; This shows the location of the waterpoint they go to to fetch water
;collection_time         ; the time it takes to pump water
end_of_collectiontime   ; this is the time a watercollector finishes pumping water
ticket_number           ; the number they got at the waterpoint to wait in queue and to fetch water
carry_amount            ; the amount of water they carry
max_queueC              ; The maximum time they want to spend queuing
]

to setup
clear-all
reset-ticks 

set ref_distance 25    ; the distance for a patch is 25 meter
set new_ticket 0
set Days_running 0

setup_households
setup_waterpoints
setup_watercollectors
if random_setup? = true                ; setup a random situation with a random number of water amount at households
    [ask households
         [ set water_amount random 120]
     ask waterpoints
         [ set water_delivered random 90000] ; and a random number of water taken from the water points
    ]

end

to go
if count waterpoints with [working-rate = 1] < 2
 [stop] 
determine_time_day               ; Determine what the time of the day is and how many days the model is running
Check_Pump_Repair
outgoing                         ; when the watercollector moves to a waterpoint
arrive                           ; when the watercollector arrives at a waterpoint
re_search                        ; If a queue is to long they will search for a water point with a shorter queue
redirect                         ; when the watercollector is redirected from a waterpoint to another waterpoint (if queue is to long or if waterpoint is broken)
queue                            ; the actual waiting at the pump
collect_water                    ; collecting water
return_home                      ; returning home 
standby                          ; watercollector is standby at home and dropped of his water
tick
  
end

;THIS PROCEDURE SETS UP THE HOUSEHOLD IN A SIMPLE TWO_STAGE SPREAD ALLOWING FOR CLUSTERING
to setup_households  
   ask patches [ set patch_has_hh?  false ]                                
 ask n-of Nbr_of_HH_clusters patches [                               ;Nbr_of_HH_clusters   determines the total number of household CLUSTERS
   Ask n-of Nbr_of_HH_in_cluster patches in-radius Radius_of_cluster ;Nbr_of_HH_in_cluster determines the total number of househodl in each cluster
                                                                     ;Radius_of_cluster    determines the radius of the cluster households
     [set patch_has_hh? true]                                            ;declare patch has household
 ]                                                                   ;close "ask n-of ...
 set-default-shape households "house"                                ;set that households look like a house
 ask patches [if patch_has_hh? = true                                    ;set only one house on each patch with patch_has_hh = 1
               [sprout-households 1                                  ;
                 [set color brown                                    ;colour the house brown                                                
              set size 6                                             ;set the size of the house
              set water_amount 0                                     ; start with 0 water
              set number_residents 4 + random 4                      ; they have between 4 and 8 residents per household
              set needed_water (number_residents * 15)               ; people need 15 liter per person
              set Total_collecting_Time_Day 0
              set Total_Collections_Day 0
              set Service_level 4  
                 ]                                                   ; end set color brown
               ]                                                     ; end sprout households 1
             ]                                                       ; end if patche_has_hh?                     
end


to setup_watercollectors
 set-default-shape watercollectors "person"    ; set watercollectors to look like persons
  ask patches [ if patch_has_hh? = true        ; if a patch has a household there will be one watercollector
    [sprout-watercollectors 1
[set color blue                                ; color of watercollectors
  set size 6                                   ; size of watercollectors
  hide-turtle
  set home_location patch-here                 ; giving their household the sign home_location
  set watercollection_status "standby"           ; start of the day with status outgoing 
  set walking-speed (average_speed + random 2.7) ; set the walking speed
  set ticket_number 1                            ; the first ticketnumber that will be given by a waterpoint is 1
  set carry_amount 0                             ; the amount of water they carry is at the beginning of the day 0
  set max_queueC 10 / 60 
  set Waterpoint_locationC [Waterpoint_locationP] of min-one-of waterpoints [distance myself]
                                               ; sets the waterpoint they have to walk to as the waterpoint closest to their home_location
]                                              ; end set color yellow 
   ]                                           ; end sprout watercollectors 1  
               ]                               ; end if patch_has_hh? = true 
          
                                               
                                               
 end
  
to setup_waterpoints 
 ask patches [set patch_has_wp? false]       ; first ask all the patches to have no waterpoints
 ask n-of Nbr_of_waterpoints patches         ; ask a number of waterpoints (can be changed in interface)
    [set patch_has_wp? true]                 ; to have a waterpoint
                                    
 set-default-shape waterpoints "handpump"    ; set shape of waterpoint is cactus
 ask patches 
   [if patch_has_wp? = true                  ; if we say the patch has a waterpoint we will sprout a turtle waterpoint
      [sprout-waterpoints 1
         [set waterpoint_locationP patch-here; give the location of the waterpoint as waterpoint_locationP
          set color sky                      ; give the color sky
          set label-color white              ; give the label-color white
          set size 8                         ; set the size
         ]                                   ; end set waterpoint_locationP 
      ]                                      ; end spout-waterpoints 1
   ]                                         ; end if patch_has_wp? = true
 ask waterpoints 
 [set working-rate 1                      ; ask all the waterpoints to set their workingrate at 1 (working)
  set turn_number 1                       ; and ask them to set their first turn_number at 1
  set Water_Delivered 0                   ; No water delivered at the start
  set ticket_counter 0                    ; ask them to set their ticket_counter at 0 at the start
  ]                                       ; end set working-rate 1                      
  ask n-of NumberOfPumpsBroken waterpoints; ask a number of waterpoints (number can be changed at interface)
  [set working-rate 0                      ; to set their workingrate at 0 (not-working) and turn orange
   set color orange
   set Moment_Broken Ticks                 ; If a water point breaks down the Moment_Broken is the number of ticks at that time
  ]                                        ; end set working-rate 0 
                                        
end 
            
To determine_time_day                                        ; to determine the current time and day
if floor (ticks / 1080 ) > Days_running                      ; 1080 ticks per day, 60 ticks per hour
[set Days_running Days_running + 1                           ; if 1080 ticks have past the day will go up 
 ask waterpoints
   [set ticket_counter 0                                     ; every day ticket counter starts at 0
    set turn_number 1]                                       ; every day turn number starts at 0
ask households
   [let Average_Collection_time 1
    if Total_Collections_Day > 0
       [set Average_Collection_Time (Total_Collecting_Time_Day * 60 / Total_Collections_Day)]
    ifelse (water_service >= 50)
       [if Average_Collection_time <= 10
           [set Service_level 1
            set color green]
       if (Average_Collection_Time > 10) and (Average_Collection_Time <= 60)
           [set Service_level 2
            set color yellow]
       if Average_Collection_Time > 60
           [set Service_level 3
            set color orange]
        ]                                                    ; end if Average_Collection_time <= 10
        [set Service_level 4
         set color red]                                      ; end of the ifelse (water_service
     set Total_Collections_Day 0                             ; every day the total number of collections starts at 0
     ifelse (water_amount - needed_water) > 0
           [set water_amount (water_amount - needed_water)]
           [set water_amount 0] 
   ] 
 ]                                                           ; end set days_running   
set Time_of_day ( 6 + ((ticks - (1080 * Days_running))/ 60)) ; day starts at 6 and ends at 12 so 18 hours each 60 ticks
end

to Check_Pump_Repair                               ; to check if a pump can be repaired
Ask waterpoints
[if working-rate < 1                               ; check if the pump is broken
  [if (Ticks - Moment_Broken) > (PumpRepairTime * 1080)  ; if the current ticks - the ticks of the moment the pump broke down is bigger then the repair time
       [set working-rate  1                        ; the working-rate becomes 1
        set color blue                             ; the color will be blue
        set Water_Delivered 0]                     ; and the water_delivered will be set to 0 again
   ]                                               ; end if (ticks-moment_broken
 ]                                                 ; end if working-rate < 1
end


to outgoing
ask watercollectors
[if watercollection_status = "outgoing"
  [show-turtle
  face waterpoint_locationC                                                        ; they will face the location they have to go to and step 1 patch further
   let thedistance (distance Waterpoint_locationC)                                  ; we let the distance they need to cover to a waterpoint be thedistance
        ifelse thedistance >= walking-speed                                         ; if this distance is bigger then their walkingspeed they will walk with their walking-speed
        [forward walking-speed]                                                       
        [forward thedistance]                                                       ; if the distance is smaller they will walk only the distance
  if Time_of_Day > 18.5                                                             ; if they are outgoing and the time of the day is later then 18:30 they will go home
    [set watercollection_status "return_home"]
  if ([patch_has_wp?] of patch-here = true) and (Waterpoint_LocationC = patch-here) ; see if the patch they are on has a waterpoint and if it is the location
  [set watercollection_status "arrived"]                                            ; they had to go to (waterpoint_locationC) then they have arrived]                       
   ]                                                                                ; end face waterpoint_locationC
 ]                                                                                  ; end if watercollection_status = outgoing
end

to arrive 
  ask watercollectors
   [Set Current_Collector WHO                                      ; to be able to give the new ticketnumber to a single collector
     if watercollection_status = "arrived"
       [set max_queueP max_queueC                                  ; set max_queue of collector into global variable to read by waterpoints                      
        set collection_timeP (collection_time / 60)                       ; collection time is in minutes on the interface in the model it is number/60 ticks = minutes
        ask waterpoints-here
            [set queue_length (count watercollectors-here * collection_timeP)  ; queue_length is the number of watercollectors here * the collection_time of the collectors
             ifelse working-rate = 1                               ; check if the waterpoint works if so
                [ifelse queue_length > max_queueP                  ; check if queue is to long if so re_search for another pump
                  [ask turtle Current_Collector
                    [set watercollection_status "re_search"
                      set color blue]                              ; end set watercollectionstatus research
                  ]                                                ; end ask turtle current_collector
                  [ask turtle Current_Collector                    ; ask the watercollector at this patch that just arrived (and only that one)
                     [set watercollection_status "queue"    
                      ask waterpoints-here 
                          [set ticket_counter ticket_counter + 1   ; ask the waterpoint here to set his ticket_counter 1 higher since a collector has allready taken a ticket
                           set new_ticket ticket_counter           ; change ticket_counter to global variable
                           if ticket_counter < 60
                              [set color green]
                           if (ticket_counter > 60) and (ticket_counter < 120)
                              [set color yellow]
                           if ticket_counter > 120
                              [set color red]
                            ]                                      ; end set ticket_counter
                   set ticket_number new_ticket                    ; take the global variable new_ticket and set it even with ticket_number
                       ]                                           ; end set watercollection_status queue
                    ]                                              ; end ask turtle currentcollector
                  ]                                                ; end ifelse queue_length
                [ask turtle Current_Collector                      ; if the waterpoint doesn't work
                     [set watercollection_status "redirecting"     ; let (only this) watercollector be redirected
                     ]                                             ; end set watercollection status redirected
                ]                                                  ; end ask turtle current_collector
              ]                                                    ; end set queue_length (count watercoll-here 
           ]                                                       ; end set max_queueP max_queuec
       ]                                                           ; end set current_collector who
    end
  

to redirect                                               ; if a waterpoint is broken a watercollector will be redirected to another working waterpoint
  Ask Watercollectors
   [if watercollection_status = "redirecting"
     [set CollectorCLocation patch-here                   ; shows what the current position is of the watercollectors and sets it to CollectorClocation
      set CollectorHLocation Home_Location                ; makes a global variable the same as Home_location so it can be read by other turtles
      set Waterpoint_LocationC [Waterpoint_locationP] of  ; asks what the minimum distance is (from a working waterpoint to a household + from a working waterpoint to a watercollector)
                     min-one-of  waterpoints with [working-rate = 1]
                     [((Distance CollectorHLocation) + (Distance CollectorCLocation))]  ; CollectorHlocation is the location of the household (home_location) CollectorClocation of the watercollector
      
      set watercollection_status "outgoing"               ; if it is redirected to another waterpoint it will be outgoing again
      ]                                                   ; end set collectorClocation patch-here
    ]                                                     ; end if watercollection_status = redirecting             
                    
end

to re_search                                              ; to search for another water point with a small queue
  ask watercollectors
  [if watercollection_status = "re_search"
    [set CollectorCLocation patch-here                    ; we set the location of the watercollector CollectorClocation
     set CollectorHLocation Home_Location                 ; we set the homelocation of the collector as CollectorHlocation
     set waterpoint_locationC [waterpoint_locationP] of min-one-of 
         waterpoints with [(waterpoint_locationP != CollectorClocation) AND (working-rate = 1)] 
         [((Distance CollectorHLocation) + (Distance CollectorCLocation))]
                                                          ; we calculate the minimum distance of a waterpoint that works with a small queue
                                                          ; and set this waterpoint as Waterpoint_locationC
         set watercollection_status "outgoing"
    ]                                                     ; end set collectorClocation patch-here   
   ]                                                      ; end if watercollection_status = research 
end
 
to queue                                        ; the actual queuing procedure
ask watercollectors
[if watercollection_status = "queue"
  [ask waterpoints-here                         ; only ask the waterpoint here, the one where the watercollector is at
    [set current_number turn_number]            ; set their turnnumber in to a global variable to check              
     if current_number = ticket_number          ; if the turnnumber equals the ticket_number of the waterpoint    
       [set watercollection_status "collect_water"   ; if so they can collect water
        set end_of_collectiontime (Time_of_Day + (collection_time / 60)) ; the time they will be finished is the current time plus the collection time
       ]                                        ; end set watercollection status collect water
   ]                                            ; end ask waterpoints-here
 ]                                              ; end if watercollection status = queue
end

to collect_water
  ask watercollectors
  [if watercollection_status = "collect_water"
      [if Time_of_Day > end_of_collectiontime           ; if the collection time is over (end_of_collectiontime)
         [set watercollection_status "return_home"      ; they will return home
          set To_Carry (15 + random 5)                  ; with a random amount of water between 15 and 20
          set carry_amount To_Carry                     ; set to_carry in a switch variable carry_amount
          ask waterpoints-here
             [set turn_number turn_number + 1           ; if a collector leaves the pump with water the next one can get water so the turn_number goes up
              set Water_Delivered Water_Delivered + To_Carry
              if Water_Delivered > (PumpBreakDownVolume + random RandomWaterVolume)  ; If water delivered is more then the Pumpbreakdownvolum 
                                                                                     ; plus a random number choosen at the interface the pump breaks down
                 [set working-rate 0                    ; if the pump breaks down the working-rate = 0
                  set color orange                      ; the color is orange 
                  set Moment_Broken Ticks]              ; the moment of breakdown is the number of ticks so far
             ]                                          ; end set turn_number turn_n
          ]                                             ; end set watercollection_status "return_home"
       ]                                                ; end if time_of_day > end_of_collectiontime
  ]                                                     ; end if watercollection_status = ´collectwater`       
end
 
  
to return_home                  
ask watercollectors
[if watercollection_status = "return_home"                   ; if they have the status return_home they will return to their home_location
      [ set waterpoint_locationC [waterpoint_locationP] of min-one-of ; if they returnhome their destination for a waterpoint will be the colest waterpoint
         waterpoints with [working-rate = 1] [distance myself]        ; that works
        face home_location                                            ; they will face their home_location 
        let thedistance (distance home_location)                      ; distance to their home is thedistance
        ifelse thedistance >= walking-speed                           ; if this distance is larger then their walking speed
        [forward walking-speed]                                       ; they walk with the walking speed
        [forward thedistance]                                         ; if not they will walk the distance leftover
         if ([patch_has_hh?] of patch-here = true) and (home_location = patch-here)  ; if they arrive, they check if the patch has a household and if it is their household
           [ask watercollectors-here    
                [set watercollection_status "standby"                                ; if they are home they will be standby until they go for water again
                  ask households-here
                  [set end_collecting_time Time_of_Day                               ; if they arrive home this will be the end of their collection time
                    set one_collecting_time (end_collecting_time - start_collecting_time) ; the one-time collection is calculated
                    set Total_Collecting_Time_Day Total_Collecting_Time_Day + (end_collecting_time - start_collecting_time) ; the total collection time of the day is calculated
                    set Total_Collections_Day Total_Collections_Day + 1
                   ]                                                  ; end set end_collecting_time  
                 ]                                                    ; end set watercollection status standby
            ]                                                         ; end ask watercollectors-here
      ]                                                               ; end set waterpoint_location
      ]   
end  

to standby
  ask watercollectors
      [if watercollection_status = "standby"                 ; if the water collectors are standby they will drop of their water
        [ hide-turtle
          set carry_water carry_amount                        ; sets carry water into a global variable so it can be read by household
         ask households-here 
             [set water_amount (water_amount + carry_water)  ; current amount of water of a household will be increased with the water of the watercollector
              set water_service ((water_amount / needed_water) * 100)  ; water service is the percentage of water they have compared to water they need
              set enough_water? (water_amount > needed_water)
             ]
       set carry_amount 0                                    ; the water of the watercollector will be set to 0 again
       if Time_of_Day < 18.5 and ((random-float 1 > 0.96)    ; so people won't directly leave the house again
       and (enough_water? = false))
           [set watercollection_status "outgoing"
            ask households-here
            [set start_collecting_time Time_of_Day]          ; if they go out this will be the start time of their collecting
             ]                                               ; end set watercollection status outgoing
         ]                                                   ; end set carry_water 
       ]                                                     ; end if watercollection status = standby
end
@#$#@#$#@
GRAPHICS-WINDOW
646
10
1466
855
202
203
2.0
1
10
1
1
1
0
1
1
1
-202
202
-203
203
1
1
1
ticks
30.0

INPUTBOX
14
617
169
677
average_speed
4
1
0
Number

INPUTBOX
12
685
167
745
nbr_of_HH_clusters
10
1
0
Number

INPUTBOX
11
751
166
811
nbr_of_HH_in_cluster
1000
1
0
Number

BUTTON
407
517
473
550
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
10
822
165
882
Radius_of_cluster
100
1
0
Number

INPUTBOX
489
301
644
361
nbr_of_waterpoints
16
1
0
Number

BUTTON
478
518
533
553
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
539
519
602
552
step
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

PLOT
246
356
482
506
Number of broken pumps
time
Brokenpumps
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count waterpoints with [working-rate = 0]"

SLIDER
248
320
463
353
PumpRepairTime
PumpRepairTime
0
100
11
1
1
Days
HORIZONTAL

PLOT
8
354
240
504
Service Level
NIL
NIL
0.0
4.0
0.0
10.0
true
false
"set-histogram-num-bars 4" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [service_level] of households"

PLOT
303
10
640
234
Users per waterpoint per day
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "ask waterpoints [plot (ticket_counter / (count waterpoints with [working-rate = 1])) ]"

PLOT
4
10
299
231
Number of Working Pumps
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count waterpoints with [working-rate = 1]"

SLIDER
3
317
232
350
PumpBreakDownVolume
PumpBreakDownVolume
0
1000000
995000
1000
1
NIL
HORIZONTAL

MONITOR
12
512
186
557
houses with service level good
count households with [color = green]
17
1
11

MONITOR
193
512
381
557
houses with service level average
count households with [color = yellow]
17
1
11

MONITOR
13
568
177
613
houses with service level bad
count households with [color = orange]
17
1
11

MONITOR
194
567
357
612
houses with no service-level
count households with [color = red]
17
1
11

MONITOR
486
364
645
409
waterpoints with user-rate 1
count waterpoints with [color = green]
17
1
11

MONITOR
485
411
645
456
waterpoints with user-rate 2
count waterpoints with [color = yellow ]
17
1
11

MONITOR
485
459
647
504
waterpoints with user-rate 3
count waterpoints with [color = red]
17
1
11

MONITOR
399
235
461
280
Days
Days_running
17
1
11

MONITOR
246
237
369
282
NIL
round (Time_of_Day)
17
1
11

SLIDER
4
280
232
313
collection_time
collection_time
0
3
0.5
0.5
1
minutes
HORIZONTAL

SLIDER
248
282
462
315
NumberOfPumpsBroken
NumberOfPumpsBroken
0
nbr_of_waterpoints
0
1
1
NIL
HORIZONTAL

SWITCH
3
244
155
277
random_setup?
random_setup?
0
1
-1000

INPUTBOX
488
239
643
299
RandomWaterVolume
40000
1
0
Number

BUTTON
169
244
232
277
stop
stop
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This is **Version 00.00** (19 June 2014) of **Redundacy Versus Repair** for water service delivery. This model aims at understanding in the relation between redundancy and speed of repair in order to maintain a certain cervice delivery model.
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
The model is rebuild by Sophie Tielens sltielens@gmail.com as part of her studies at the TU Delft. The model is build for IRC [ircwash.org] and the WEL group [welgroup.co.uk]. Co-supervisors are Kristof Bostoen@ircwash.org and Chris Chris.BROWN@WELgroup.co.uk.
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

cactus
false
0
Polygon -7500403 true true 130 300 124 206 110 207 94 201 81 183 75 171 74 95 79 79 88 74 97 79 100 95 101 151 104 169 115 180 126 169 129 31 132 19 145 16 153 20 158 32 162 142 166 149 177 149 185 137 185 119 189 108 199 103 212 108 215 121 215 144 210 165 196 177 176 181 164 182 159 302
Line -16777216 false 142 32 146 143
Line -16777216 false 148 179 143 300
Line -16777216 false 123 191 114 197
Line -16777216 false 113 199 96 188
Line -16777216 false 95 188 84 168
Line -16777216 false 83 168 82 103
Line -16777216 false 201 147 202 123
Line -16777216 false 190 162 199 148
Line -16777216 false 174 164 189 163

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

handpump
false
0
Polygon -7500403 true true 135 15 300 45 300 60 135 30
Rectangle -7500403 true true 45 75 120 300
Polygon -7500403 true true 45 75 75 0 150 0 120 75 45 75
Rectangle -2674135 false false 75 75 150 75
Polygon -7500403 true true 0 105 0 135 15 135 15 120 45 120 45 105 0 105
Line -1 false 45 75 120 75

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
NetLogo 5.0.5
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
0
@#$#@#$#@
