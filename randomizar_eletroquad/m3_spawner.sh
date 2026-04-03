#!/bin/bash
set -e

# =========================
# VARIABLES
# =========================

declare -i -r structure_count=3
declare -i -r decimal_places_precision=1000
declare -i -r min_distance_padding=5
declare -i -r max_distance_padding=60
declare -i -r arena_width=7
declare -i -r arena_length=13
declare -i max_iters=$((4*structure_count))

declare -a -r min_valid_angle_array=("0" "297" "231" "176" "114")
declare -a -r max_valid_angle_array=("327" "266" "210" "145" "91")
declare -a -r manometer_value_cap=("20" "40" "60" "80" "100")
declare -a -r manometer_lines=("<!--line 24-->" "<!--line 35-->" "<!--line 46-->")
declare -a -r pointer_lines=("<!--line 29-->" "<!--line 40-->" "<!--line 51-->")
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
  valid=0
  index=0
  while [ $index -lt ${#result_array[@]} ]; do
    dx=$((x - result_array[index]))
    dy=$((y - result_array[index+1]))
    dist=$((dx*dx + dy*dy))

    if [ $dist -gt $((min_distance_padding * decimal_places_precision)) ] && [ $dist -le $((max_distance_padding * decimal_places_precision)) ]; then
      valid=1
      break
    fi
    index=$((index+4))
  done

  if [ $valid -eq 1 ]; then
    continue
  fi

  result_array+=($x $y)

  # ângulo
  interval_chosen=$(RNG_within_range 1 4)
  angle=$(RNG_within_range ${min_valid_angle_array[$interval_chosen]} ${max_valid_angle_array[$interval_chosen]})
  result_array+=($((angle % 360)))

  # value cap
  result_array+=(${manometer_value_cap[$interval_chosen]})
  # result_array+=(${manometer_value_cap[$(RNG_within_range 0 4)]})
  
  # uncomment to check results
  echo "${result_array[$((iter))]} x coord"
  echo "${result_array[$((iter+1))]} y coord"
  echo "${result_array[$((iter+2))]} pointer angle"
  echo -e "${result_array[$((iter+3))]} manometer value cap\n"

  iter=$((iter+4))
done

# =========================
# NORMALIZA VALORES
# =========================
declare -i iter=0

until [ $iter -ge ${#result_array[@]} ]; do

  # uncomment to check results
  echo "${result_array[$((iter))]} index $iter before normalization"
  echo "${result_array[$((iter+1))]} index $((iter+1)) before normalization"

  result_array[$iter]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$iter]} / $decimal_places_precision) - ($arena_width/2)}")
  result_array[$((iter+1))]=$(mawk "BEGIN {printf \"%.4f\", (${result_array[$((iter+1))]} / $decimal_places_precision) - ($arena_length/2)}")
  
  # uncomment to check results
  echo "${result_array[$((iter))]} index $iter after normalization"
  echo -e "${result_array[$((iter+1))]} index $((iter+1)) after normalization\n"

  iter=$((iter+4))
done

# =========================
# EDIT SDF
# =========================

cd /root/PX4-Autopilot/Tools/simulation/gz/worlds

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

  sed -i -e "${line}s|.*|${manometer_edit}|" -e "$((line+5))s|.*|${pointer_edit}|" eletroquad26_m3.sdf

  iter=$((iter+4))
  line=$((line+11))
  index_struct=$((index_struct+1))

done

# =========================
# YAML OUTPUT
# =========================

cat << EOF > /root/harpia_ws/src/eletroquad_m3/config/params.yaml
state_machine:
  ros__parameters:
    manometer_1_position: [${result_array[0]}, ${result_array[1]}, -1.7]
    manometer_1_valuecap: ${result_array[3]}
    manometer_2_position: [${result_array[4]}, ${result_array[5]}, -1.7]
    manometer_2_valuecap: ${result_array[7]}
    manometer_3_position: [${result_array[8]}, ${result_array[9]}, -1.7]
    manometer_3_valuecap: ${result_array[11]}
    read_wait_sec: 5.0
    image_detection_input_topic: '/manometer/processed_image'
    detection_input_topic: '/manometer/detections'
    classification_input_topic: '/manometer/classification'
    alarm_output_topic: '/ring_alarm'

vision:
  ros__parameters:
    model_detection: 'manometerDetector(last).onnx'
    model_value_classification: 'manometerClass(last).onnx'
    model_readability_classification: 'manometerLegivel(best).onnx'
    confidence_threshold: 0.90
    color_img_input_topic: 'camera/down/color/image_raw'
    processed_img_output_topic: '/manometer/processed_image'
    detection_output_topic: '/manometer/detections'
    classification_output_topic: '/manometer/classification'

detector:
  ros__parameters:
    model_detection: 'manometerDetector(last).onnx'
    confidence_threshold: 0.90
    color_img_input_topic: 'camera/down/color/image_raw'
    processed_img_output_topic: '/manometer/processed_image'
    detection_output_topic: '/manometer/detections'
    detection_cropped_output_topic: '/manometer/detection_cropped'

classifier:
  ros__parameters:
    model_value_classification: 'manometerClass(last).onnx'
    model_readability_classification: 'manometerLegivel(best).onnx'
    confidence_threshold: 0.90
    detection_cropped_input_topic: '/manometer/detection_cropped'
    classification_output_topic: '/manometer/classification'
EOF

# =========================
# BUILD
# =========================

cd /root/harpia_ws
colcon build --packages-up-to eletroquad_m3
source /root/.bashrc

echo "The randomizing script took $SECONDS seconds to run."
