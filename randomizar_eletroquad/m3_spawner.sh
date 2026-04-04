#!/bin/bash
set -e


# =========================
# VARIABLES
# =========================

declare -i -r structure_count=3
declare -i -r decimal_places_precision=1000
declare -i -r min_distance_padding=20
declare -i -r arena_width=6
declare -i -r arena_length=12
declare -i -r tuple_size=4
declare -i max_iters=$((tuple_size*structure_count))

declare -a -r min_valid_angle_array=("0" "297" "231" "176" "114")
declare -a -r max_valid_angle_array=("327" "266" "210" "145" "91")
declare -a -r manometer_value_cap=("20" "40" "60" "80" "100")
declare -a -r manometer_lines=("<!--line 24-->" "<!--line 35-->" "<!--line 46-->")
declare -a -r pointer_lines=("<!--line 29-->" "<!--line 40-->" "<!--line 51-->")
declare -a result_array=()


if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  RED='\033[31;1m'
  YELLOW='\033[33;1m'
  YELLOW_BG='\033[33;7m'
  GREEN='\033[92;1m'
  NC='\033[0m'

else
  RED=''
  YELLOW=''
  YELLOW_BG=''
  GREEN=''
  NC=''
fi


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

  x=$(RNG_within_range 0 $((arena_width * decimal_places_precision)))
  y=$(RNG_within_range 0 $((arena_length * decimal_places_precision)))

  # evita proximidade com origem
  if [ $((x*x + y*y)) -lt $((min_distance_padding * decimal_places_precision * decimal_places_precision)) ]; then
    continue
  fi

  # valida distância com pontos anteriores
  valid=1
  index=0
  while [ $index -lt ${#result_array[@]} ]; do
    dx=$((x - result_array[index]))
    dy=$((y - result_array[index+1]))
    dist=$((dx*dx + dy*dy))

    if [ $dist -le $((min_distance_padding * decimal_places_precision * decimal_places_precision)) ]; then
      valid=0
      break
    fi
    index=$((index+tuple_size))
  done

  if [ $valid -eq 0 ]; then
    continue
  fi

  result_array+=($x $y)

  # ângulo
  interval_chosen=$(RNG_within_range 1 4)
  angle=$(RNG_within_range ${min_valid_angle_array[$interval_chosen]} ${max_valid_angle_array[$interval_chosen]})
  result_array+=($((angle % 360)))

  # value cap
  result_array+=(${manometer_value_cap[$(RNG_within_range 0 4)]})

  iter=$((iter+tuple_size))
done

# =========================
# NORMALIZA VALORES
# =========================

iter=0

until [ $iter -ge ${#result_array[@]} ]; do

  result_array[$iter]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$iter]} / $decimal_places_precision) - ($arena_width/2)}")
  result_array[$((iter+1))]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$((iter+1))]} / $decimal_places_precision) - ($arena_length/2)}")

  iter=$((iter+tuple_size))
done

# =========================
# EDIT SDF
# =========================

iter=0
line=24
index_struct=0

while [ $index_struct -lt $structure_count ]; do

  x=${result_array[$iter]}
  y=${result_array[$((iter+1))]}
  yaw=${result_array[$((iter+2))]}

  manometer_edit="        <pose degrees='true'>$x $y 0.86 0 0 -90</pose> ${manometer_lines[$index_struct]}"

  x_offset=$(mawk "BEGIN {printf \"%.4f\", $x + 0.009}")
  pointer_edit="        <pose degrees='true'>$x_offset $y 1.711 0 0 $yaw</pose> ${pointer_lines[$index_struct]}"

  sed -i -e "${line}s|.*|${manometer_edit}|" -e "$((line+5))s|.*|${pointer_edit}|" /root/PX4-Autopilot/Tools/simulation/gz/worlds/eletroquad26_m3.sdf

  iter=$((iter+tuple_size))
  line=$((line+11))
  index_struct=$((index_struct+1))

done

# =========================
# YAML OUTPUT
# =========================

edit1="    manometer_1_position: [${result_array[0]}, ${result_array[1]}, -1.7]"
edit2="    manometer_1_valuecap: ${result_array[3]}"
edit3="    manometer_2_position: [${result_array[4]}, ${result_array[5]}, -1.7]"
edit4="    manometer_2_valuecap: ${result_array[7]}"
edit5="    manometer_3_position: [${result_array[8]}, ${result_array[9]}, -1.7]"
edit6="    manometer_3_valuecap: ${result_array[11]}"

sed -i -e "3s|.*|${edit1}|" -e "4s|.*|${edit2}|" -e "5s|.*|${edit3}|" -e "6s|.*|${edit4}|" -e "7s|.*|${edit5}|" -e "8s|.*|${edit6}|" /root/harpia_ws/src/eletroquad_m3/config/params.yaml

# =========================
# BUILD
# =========================

echo -e "${YELLOW}Calculando novas posições...${NC}"
echo -e "${YELLOW}Modificando arquivos...${NC}"
echo -e "${YELLOW}Construindo pacotes...${NC}"
cd /root/harpia_ws
colcon build --packages-up-to eletroquad_m3
source /root/.bashrc
echo -e "${GREEN}Posições dos manômeros alteradas com sucesso!${NC}"

# echo -e "Este script demorou ${GREEN}$SECONDS segundos${NC} para concluir."
