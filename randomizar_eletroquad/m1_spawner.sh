#!/bin/bash
set -e

# =========================
# VARIABLES
# =========================

declare -i -r structure_count=10
declare -i -r decimal_places_precision=1000
declare -i -r min_distance_padding=2
declare -i -r max_distance_padding=63
declare -i -r arena_width=7
declare -i -r arena_length=13
declare -i max_iters=$((2*structure_count))

declare -a -r aruco_shapes=("hexagon" "star" "triangle")
declare -a -r platform_lines=("<!--line 024-->" "<!--line 042-->" "<!--line 058-->" "<!--line 074-->" "<!--line 090-->" "<!--line 106-->" "<!--line 122-->" "<!--line 138-->" "<!--line 154-->" "<!--line 170-->")
declare -a -r shape_lines=("<!--line 029-->" "<!--line 047-->" "<!--line 063-->" "<!--line 079-->" "<!--line 095-->" "<!--line 111-->" "<!--line 127-->" "<!--line 143-->" "<!--line 159-->" "<!--line 175-->")
declare -a -r num_lines=("<!--line 034-->" "<!--line 052-->" "<!--line 068-->" "<!--line 084-->" "<!--line 100-->" "<!--line 116-->" "<!--line 132-->" "<!--line 148-->" "<!--line 164-->" "<!--line 180-->")
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

iter=0

while [ $iter -lt $max_iters ]; do

  x=$(RNG_within_range 0 $((arena_width * decimal_places_precision)))
  y=$(RNG_within_range 0 $((arena_length * decimal_places_precision)))

  # evita proximidade com origem
  if [ $((x*x + y*y)) -lt $((min_distance_padding * decimal_places_precision)) ]; then
    continue
  fi

  # valida distância com pontos anteriores
  valid=1
  index=0
  while [ $index -lt ${#result_array[@]} ]; do
    dx=$((x - result_array[index]))
    dy=$((y - result_array[index+1]))
    dist=$((dx*dx + dy*dy))

    if [ $dist -lt $((min_distance_padding * decimal_places_precision)) ] && [ $dist -ge $((max_distance_padding * decimal_places_precision)) ]; then
      valid=0
      break
    fi
    index=$((index+4))
  done

  if [ $valid -eq 0 ]; then
    continue
  fi

  # salva posição (centralizada)
  result_array+=($((x - (arena_width * decimal_places_precision / 2))))
  result_array+=($((y - (arena_length * decimal_places_precision / 2))))
  
  # uncomment to see results
  # echo "${result_array[$((iter))]} x coord"
  # echo -e "${result_array[$((iter+1))]} y coord\n"

  iter=$((iter+2))
done

# =========================
# NORMALIZA VALORES
# =========================
declare -i iter=0

until [ $iter -ge ${#result_array[@]} ]; do

  # uncomment to see results
  # echo "${result_array[$((iter))]} index $iter before normalization"
  result_array[$iter]=$(mawk "BEGIN {printf \"%.4f\", ${result_array[$iter]} / $decimal_places_precision}")
  # echo -e "${result_array[$((iter))]} index $iter after normalization\n"

  iter=$((iter+1))
done

# =========================
# EDIT SDF
# =========================

cd /root/PX4-Autopilot/Tools/simulation/gz/worlds

iter=0
line=39
index_struct=0

while [ $index_struct -lt $structure_count ]; do

  platform_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}"
  shape_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}"
  num_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}"

  sed -i -n -e "${line}s|.*|${platform_edit}|" -e "$((line+5))s|.*|${shape_edit}|" -e "$((line+10))s|.*|${num_edit}|" eletroquad26_m1.sdf

  iter=$((iter+2))
  line=$((line+18))
  index_struct=$((index_struct+1))

done

# changes the aruco platform
declare -i line=24
platform_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.02 0 0 -90</pose> ${platform_lines[index]}"
shape_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.021 0 0 -90</pose> ${shape_lines[index]}"
aruco_edit="<include merge='true'><uri>models/bouncing/shapes/${result_array[0]}</uri></include> <!--line 033-->"
num_edit="<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.022 0 0 -90</pose> ${num_lines[index]}"

sed -i -n -e "${line}s|.*|${platform_edit}|" -e "$((line+5))s|.*|${shape_edit}|" -e "$((line+9))s|.*|${aruco_edit}|" -e "$((line+10))s|.*|${num_edit}|" eletroquad26_m1.sdf

# creates the actual aruco marker
python3 << 'EOF'
import random
import cv2
import os
abs_path = "/root/PX4-Autopilot/Tools/simulation/gz/worlds/models/bouncing/ArUco_marker/materials/textures"
try:
  os.makedirs(abs_path, exist_ok=True)
  cv2.imwrite(os.path.join(abs_path, f"aruco_sample.png"), cv2.aruco.generateImageMarker(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_5X5_1000), random.randint(3,5), 250))
except Exception as e:
  print(f"Erro ao gerar ArUco: {e}")
EOF

echo "The randomizing script took $SECONDS seconds to run."
