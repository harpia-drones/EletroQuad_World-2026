#!/bin/bash

# start-variables

declare -i -r structure_count decimal_places_precision min_distance_padding max_iters arena_width arena_length
structure_count=10
decimal_places_precision=1000
min_distance_padding=1
max_iters=((2*structure_count+1))
arena_width=7
arena_length=13

declare -a -r aruco_shapes platform_lines shape_lines num_lines
aruco_shapes=("hexagon" "star" "triangle")
platform_lines=("<!--line 024-->" "<!--line 042-->" "<!--line 058-->" "<!--line 074-->" "<!--line 090-->" "<!--line 106-->" "<!--line 122-->" "<!--line 138-->" "<!--line 154-->" "<!--line 170-->")
shape_lines=("<!--line 029-->" "<!--line 047-->" "<!--line 063-->" "<!--line 079-->" "<!--line 095-->" "<!--line 111-->" "<!--line 127-->" "<!--line 143-->" "<!--line 159-->" "<!--line 175-->")
num_lines=("<!--line 034-->" "<!--line 052-->" "<!--line 068-->" "<!--line 084-->" "<!--line 100-->" "<!--line 116-->" "<!--line 132-->" "<!--line 148-->" "<!--line 164-->" "<!--line 180-->")

# end-variables
# ======================================================================
# start-functions

RNG_within_range() {
  local -i min max
  min=$1
  max=$2

  if [ min -lt max ]; then
    return_val=$(((min + 1) + $RANDOM % max))
  else
    return_val=$(((max + 1) + $RANDOM % min))
  fi
  echo $return_val
}

# end-functions
# ======================================================================
# start-script

# chooses the shape for the ArUco marker
result_array+=$(aruco_shapes[$(RNG_within_range 0 2)])

# positions all of the platforms everywhere
declare -i x y iter=1
while :; do
  if [ iter -eq max_iters ]; then
    break
  fi
  x=$(RNG_within_range 0 $((arena_width*min_distance_padding*decimal_places_precision)))
  y=$(RNG_within_range 0 $((arena_length*min_distance_padding*decimal_places_precision)))
  if [ x*x + y*y -lt min_distance_padding*decimal_places_precision ]; then
    continue # if the euclidean distance from the chosen numbers from the coordinates (0,0) is smaller than the parameter, goes all the way to the beggining
  else
    if [ ${#result_array[@]} -eq 1 ]; then # checks if the array has platforms already
      result_array+=$((x-arena_width*decimal_places_precision))
      result_array+=$((y-arena_length*decimal_places_precision))
    else
      until [ $(((x-$(result_array[iter]))*(x-$(result_array[iter])) + (y-$(result_array[iter+1]))*(y-$(result_array[iter+1])))) -ge min_distance_padding*decimal_places_precision ]; do

        x=$(RNG_within_range 0 ((arena_width*min_distance_padding*decimal_places_precision)))
        y=$(RNG_within_range 0 ((arena_length*min_distance_padding*decimal_places_precision)))
      done
      result_array+=((x-arena_width*decimal_places_precision))
      result_array+=((y-arena_length*decimal_places_precision))
    fi
  fi
  iter=iter+2
done

while [ iter -le ${#result_array[@]} ]
  result_array[iter]=$(mawk "BEGIN {printf \".4f\", $result_array[iter] / $decimal_places_precision}")
  # new_result=$(mawk "BEGIN {printf \".4f\", $result_array[iter] / $decimal_places_precision}")
  # result_array[iter]=new_result
done

cd /root/PX4-Autopilot/Tools/simulation/gz/worlds

declare -i iter=3 index=0 line=39
while [ iter -le ((structure_count*${#result_array[@]})) ]; do

  # <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}
  platform_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}"
  # <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}
  shape_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}"
  # <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}
  num_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}"

  sed -i -n "$(line)s|.*|$(platform_edit)" "$(line+5)s|.*|$(shape_edit)" "$(line+10)s|.*|$(num_edit)" eletroquad26_m1.sdf

  iter=iter+2
  index=index+1
  line=line+13
done

# changes the aruco platform
declare -i line=24
# <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}
platform_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}"
# <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}
shape_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}"
# <include merge='true'><uri>models/bouncing/shapes/${result_array[0]}</uri></include> <!--line 033-->
edit="<include merge='true'><uri>models/bouncing/shapes/${result_array[0]}</uri></include> <!--line 033-->"
# <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}
num_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}"

sed -i -n "$(line)s|.*|$(platform_edit)" "$(line+5)s|.*|$(shape_edit)" "33s|.*|$(edit)" "$(line+10)s|.*|$(num_edit)" eletroquad26_m1.sdf


# cd /root/PX4-Autopilot/Tools/simulation/gz/worlds/models/bouncing/ArUco_marker/materials/textures


echo "This script took $SECONDS to run."
