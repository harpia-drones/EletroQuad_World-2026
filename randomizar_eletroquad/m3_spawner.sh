#!/bin/bash

# start-variables

declare -i -r structure_count decimal_places_precision min_distance_padding max_iters arena_width arena_length pointer_alignment_offset
structure_count=3
decimal_places_precision=1000
min_distance_padding=((1*decimal_places_precision))
max_iters=((4*structure_count))
arena_width=7
arena_length=13
pointer_alignment_offset=9 # *1000 para transformar em inteiro

declare -a -r min_valid_angle_array max_valid_angle_array manometer_value_cap manometer_lines pointer_lines
min_valid_angle_array=("0" "297" "231" "176" "114")
max_valid_angle_array=("327" "266" "210" "145" "91")
# (0,20)   = [90,57]   ->(-90°)-> [0,327]   = |33°|
# (20,40)  = [27,356]  ->(-90°)-> [297,266] = |31°|
# (40,60)  = [321,300] ->(-90°)-> [231,210] = |21°|
# (60,80)  = [266,235] ->(-90°)-> [176,145] = |31°|
# (80,100) = [204,181] ->(-90°)-> [114,91]  = |23°|

# (0,20)   = [90,57]   ->(+90°)-> [180,147] = |33°|
# (20,40)  = [27,356]  ->(+90°)-> [117,86]  = |31°|
# (40,60)  = [321,300] ->(+90°)-> [51,30]   = |21°|
# (60,80)  = [266,235] ->(+90°)-> [356,325] = |31°|
# (80,100) = [204,181] ->(+90°)-> [294,271] = |23°|

manometer_value_cap=("20" "40" "60" "80" "100")
manometer_lines=("<!--line 24-->" "<!--line 35-->" "<!--line 46-->")
pointer_lines=("<!--line 29-->" "<!--line 40-->" "<!--line 51-->")

declare -a result_array=()

# end-variables
# ======================================================================
# start-functions

RNG_within_range() {
  local -i min max
  min=$1
  max=$2

  elif [ min -lt max ]; then
    return_val=$(((min + 1) + SRANDOM % max))
  else
    return_val=$(((max + 1) + SRANDOM % min))
  fi
  echo $return_val
}

# end-functions
# ======================================================================
# start-script

declare -i x y interval_chosen iter=0
while :; do
  if [ iter -eq max_iters ]; then
    break
  fi
  x=$(RNG_within_range 0 ((arena_width*min_distance_padding)))
  y=$(RNG_within_range 0 ((arena_length*min_distance_padding)))
  if [ x*x + y*y -lt min_distance_padding ]; then
    continue # if the euclidean distance from the chosen numbers from the coordinates (0,0) is smaller than the parameter, goes all the way to the beggining
  else
    if [ ${#result_array[@]} -eq 0 ]; then # checks if the array is empty
      result_array+=x
      result_array+=y
    else
      until [ (((x-$(result_array[iter]))*(x-$(result_array[iter])) + (y-$(result_array[iter+1]))*(y-$(result_array[iter+1])))) -ge min_distance_padding ]; do
        x=$(RNG_within_range 0 ((arena_width*min_distance_padding)))
        y=$(RNG_within_range 0 ((arena_length*min_distance_padding)))
      done
    fi
  fi
  # chooses the interval where the manometer pointer is pointing and appends it to 'result_array'
  interval_chosen=$(RNG_within_range 0 4)
  result_array+=(($(RNG_within_range $(min_valid_angle_array[interval_chosen]) $(max_valid_angle_array[interval_chosen]))))%360
  result_array+=$(manometer_value_cap[interval_chosen])
  iter=iter+4
done

cd /root/PX4-Autopilot/Tools/simulation/gz/worlds



# TODO: tratar o 'result_array' pra que ele fique nos conformes do gazebo
# (x/decimal_places_precision) - (arena_width/2)
# (y/decimal_places_precision) - (arena_length/2)



while [ iter -le ((structure_count*${#result_array[@]})) ]; do
  # (x, y, YAW, manometer_value_cap)
  local -i iter=0 line=24
 
  # <pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.86 0 0 -90</pose> $(manometer_lines[iter])
  edit='echo "<pose degrees='true'>${result_array[iter]} ${result_array[iter+1]} 0.86 0 0 -90</pose> $(manometer_lines[iter])"'
  sed -i -n ''\"$(line)\"'s/'\"$(edit)\"'' eletroquad26_m3.sdf
  # <pose degrees='true'>${result_array[iter]}+0.009 ${result_array[iter+1]} 0.861 0 0 ${result_array[iter+2]}</pose> $(pointer_lines[iter])
  edit='echo "<pose degrees='true'>${result_array[iter]}+0.009 ${result_array[iter+1]} 0.861 0 0 ${result_array[iter+2]}</pose> $(pointer_lines[iter])"'
  sed -i -n ''\"$(line+5)\"'s/'\"$(edit)\"'' eletroquad26_m3.sdf

  iter=iter+4
  line=line+9
done

cat << EOF > /root/harpia_ws/src/eletroquad_m3/config/params.yaml
state_machine:
  ros__parameters:
    manometer_1_position: [${result_array[iter]}, ${result_array[iter+1]}, -1.7]
    manometer_1_valuecap: ${result_array[iter+3]}
    manometer_2_position: [${result_array[iter+4]}, ${result_array[iter+5]}, -1.7]
    manometer_2_valuecap: ${result_array[iter+7]}
    manometer_3_position: [${result_array[iter+8]}, ${result_array[iter+9]}, -1.7]
    manometer_3_valuecap: ${result_array[iter+11]}
    read_wait_sec: 5.0
    detection_input_topic: '/manometer/processed_image'
    classification_input_topic: '/manometer/classification'
    alarm_output_topic: '/ring_alarm'

detector:
  ros__parameters:
    model_path: '/root/harpia_ws/src/eletroquad_m3/models/manometer_detection.onnx'
    confidence_threshold: 0.90
    color_img_input_topic: 'camera/down/color/image_raw'
    processed_img_output_topic: '/manometer/processed_image'
    detection_output_topic: '/manometer/detections'
    detection_cropped_output_topic: '/manometer/detection_cropped'

classifier:
  ros__parameters:
    model_path_value_classification: '/root/harpia_ws/src/eletroquad_m3/models/manometer_classification.onnx'
    model_path_readability_classification: '/root/harpia_ws/src/eletroquad_m3/models/manometer_readability.onnx'
    confidence_threshold: 0.90
    detection_cropped_input_topic: '/manometer/detection_cropped'
    classification_output_topic: '/manometer/classification'
EOF

cd /root/harpia_ws
colcon build --package-up-to eletroquad_m3
source /root/.bashrc

echo "This script took $SECONDS to run."
