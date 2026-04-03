#!/bin/bash

# start-variables

declare -r ball_line="<!--line 24-->"

declare -i -r ball_and_hoses_height arena_radius
ball_and_hoses_height=1.6
arena_radius=7

declare -a pole_lines hose_lines hose_length_lines
pole_lines=("<!--line 32-->" "<!--line 37-->" "<!--line 48-->" "<!--line 53-->")
hose_lines=("<!--line 42-->" "<!--line 58-->")
hose_length_string=("<length>?</length>")

# end-variables
# ======================================================================
# start-functions

RNG_within_range() {
  local -i min max
  min=$1
  max=$2

  if [ min -eq max ]; then
    return 
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










cd /root/PX4-Autopilot/Tools/simulation/gz/worlds






cd /root/PX4-Autopilot/Tools/simulation/gz/worlds/models/hang_the_right_wire/hose

# comprimento do cabo = np.sin((points[i]-points[i-1])/2)*2*4.5





echo "This script took $SECONDS to run."
