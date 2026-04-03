#!/bin/bash
set -e

# =========================
# VARIABLES
# =========================

declare -i -r structure_count=10
declare -i -r decimal_places_precision=1000
declare -i -r min_distance_padding=60
declare -i -r half_arena_width=3
declare -i -r half_arena_length=6
declare -i iter=0
declare -i max_iters=$((2*structure_count))

declare -a -r aruco_shapes=("hexagon" "star" "triangle")
declare -a -r platform_lines=("<!--line 042-->" "<!--line 058-->" "<!--line 074-->" "<!--line 090-->" "<!--line 106-->" "<!--line 122-->" "<!--line 138-->" "<!--line 154-->" "<!--line 170-->")
declare -a -r shape_lines=("<!--line 047-->" "<!--line 063-->" "<!--line 079-->" "<!--line 095-->" "<!--line 111-->" "<!--line 127-->" "<!--line 143-->" "<!--line 159-->" "<!--line 175-->")
declare -a -r num_lines=("<!--line 052-->" "<!--line 068-->" "<!--line 084-->" "<!--line 100-->" "<!--line 116-->" "<!--line 132-->" "<!--line 148-->" "<!--line 164-->" "<!--line 180-->")
declare -a result_array=()

# =========================
# FUNCTIONS
# =========================

RNG_within_range() {
  local min=$1
  local max=$2

  if [ "$min" -lt "$max" ]; then
    echo $((min + $RANDOM % (max - min + 1)))
  else
    echo $((max + $RANDOM % (min - max + 1)))
  fi
}

# =========================
# GENERATE POINTS
# =========================

declare -i iter=0

while [ $iter -lt $max_iters ]; do

  x=$(RNG_within_range 0 $((half_arena_width * decimal_places_precision * 2)))
  y=$(RNG_within_range 0 $((half_arena_length * decimal_places_precision * 2)))

  # evita proximidade com origem
  if [ $((x*x + y*y)) -lt $((min_distance_padding * decimal_places_precision)) ]; then
    continue
  fi

  # valida distância com pontos anteriores
  valid=1
  index=0
  until [ $index -eq ${#result_array[@]} ]; do
    dx=$((x - result_array[index]))
    dy=$((y - result_array[index+1]))
    dist=$((dx*dx + dy*dy))

    if [ $dist -le $((min_distance_padding * decimal_places_precision)) ]; then
      valid=0
      break
    fi
    index=$((index+2))
  done

  if [ $valid -eq 0 ]; then
    continue
  fi

  result_array+=($x $y)
  
  # uncomment to see results
  # echo "${result_array[$((iter))]} x coord"
  # echo -e "${result_array[$((iter+1))]} y coord\n"

  iter=$((iter+2))
done

# =========================
# NORMALIZA VALORES
# =========================
iter=0

until [ $iter -ge ${#result_array[@]} ]; do

  # uncomment to see results
  # echo "${result_array[$((iter))]} index $iter before normalization"
  # echo "${result_array[$((iter+1))]} index $((iter+1)) before normalization"

  result_array[$iter]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$iter]} / $decimal_places_precision) - $half_arena_width}")
  result_array[$((iter+1))]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$((iter+1))]} / $decimal_places_precision) - $half_arena_length}")
  
  # uncomment to see results
  # echo "${result_array[$((iter))]} index $iter after normalization"
  # echo -e "${result_array[$((iter+1))]} index $((iter+1)) after normalization\n"

  iter=$((iter+2))
done

# =========================
# EDIT SDF
# =========================

cd /root/PX4-Autopilot/Tools/simulation/gz/worlds

iter=0
index_struct=0
lines=42

while [ $index_struct -lt $((structure_count-1)) ]; do

  platform_edit="        <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.011 0 0 -90</pose> ${platform_lines[index_struct]}"
  shape_edit="        <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.012 0 0 -90</pose> ${shape_lines[index_struct]}"
  num_edit="        <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.013 0 0 -90</pose> ${num_lines[index_struct]}"

  sed -i -e "${lines}s|.*|${platform_edit}|" -e "$((lines+5))s|.*|${shape_edit}|" -e "$((lines+10))s|.*|${num_edit}|" eletroquad26_m1.sdf

  iter=$((iter+2))
  lines=$((lines+16))
  index_struct=$((index_struct+1))

done

# changes the aruco platform
declare -i aruco_id=$(RNG_within_range 3 5)
line=24
iter=0
platform_edit="        <pose degrees='true'>${result_array[-2]} ${result_array[-1]} 0.011 0 0 -90</pose> <!--line 024-->"
shape_edit="        <pose degrees='true'>${result_array[-2]} ${result_array[-1]} 0.012 0 0 -90</pose> <!--line 029-->"
aruco_edit="      <include merge='true'><uri>models/bouncing/shapes/${aruco_shapes[$((aruco_id-3))]}</uri></include> <!--line 033-->"
num_edit="        <pose degrees='true'>${result_array[-2]} ${result_array[-1]} 0.013 0 0 -90</pose> <!--line 034-->"

sed -i -e "${line}s|.*|${platform_edit}|" -e "$((line+5))s|.*|${shape_edit}|" -e "$((line+9))s|.*|${aruco_edit}|" -e "$((line+10))s|.*|${num_edit}|" eletroquad26_m1.sdf

# creates the actual aruco marker
python3 << EOF
import random
import cv2
import os
abs_path = "/root/PX4-Autopilot/Tools/simulation/gz/worlds/models/bouncing/ArUco_marker/materials/textures"
try:
  os.makedirs(abs_path, exist_ok=True)
  cv2.imwrite(os.path.join(abs_path, f"aruco_sample.png"), cv2.aruco.generateImageMarker(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_5X5_1000), $aruco_id, 250))
except Exception as e:
  print(f"Erro ao gerar ArUco: {e}")
EOF

echo "The randomizing script took $SECONDS seconds to run."
