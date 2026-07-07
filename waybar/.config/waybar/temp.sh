#!/usr/bin/env bash

cpu_temp=$(cat /sys/class/hwmon/hwmon7/temp1_input)
cpu_temp_c=$((cpu_temp / 1000))
cpu_label=$(cat /sys/class/hwmon/hwmon7/temp1_label)

gpu_temp=$(cat /sys/class/hwmon/hwmon11/temp1_input)
gpu_temp_c=$((gpu_temp / 1000))
gpu_label=$(cat /sys/class/hwmon/hwmon11/temp1_label)

cat << EOF
{"text": "", "tooltip": "CPU ($cpu_label): ${cpu_temp_c}°C\nGPU ($gpu_label): ${gpu_temp_c}°C"}
EOF
