#!/bin/bash
# Vibrant color palette
COLOR_RESET="\e[0m"
COLOR_GREEN="\e[38;5;82m"    # Bright green
COLOR_YELLOW="\e[38;5;226m"  # Golden yellow
COLOR_CYAN="\e[38;5;39m"     # Sky blue
COLOR_RED="\e[38;5;196m"     # Bright red
COLOR_BLUE="\e[38;5;33m"     # Bright blue
COLOR_MAGENTA="\e[38;5;204m" # Bright magenta
COLOR_GRAY="\e[38;5;245m"    # Soft gray
COLOR_BOLD="\e[1m"
COLOR_ORANGE="\e[38;5;208m"  # Orange for medium-high utilization

# Unicode symbols to keep the rocket emoji
ICON_RUNNING="🚀"  # Running indicator
ICON_EXITED="❗"   # Exited indicator

# Box drawing characters for rounded corners
HORIZONTAL="─"
VERTICAL="│"
TOP_LEFT="╭"
TOP_RIGHT="╮"
BOTTOM_LEFT="╰"
BOTTOM_RIGHT="╯"

# Box width and spacing
BOX_WIDTH=90
BOX_SPACING=0    # Reduced spacing between boxes
LINE_SPACING=0   # No extra spacing within boxes

echo -e "${COLOR_BOLD}${COLOR_CYAN}GPU PROCESS MONITOR${COLOR_RESET}"
echo -e "${COLOR_GRAY}══════════════════════════════════════════════════════════════════════════════════════════${COLOR_RESET}"

# Generate GPU mapping using associative array
declare -A gpu_mapping
while IFS=',' read -r index uuid; do
  gpu_mapping["$uuid"]="$index"
done < <(nvidia-smi --query-gpu=index,uuid --format=csv,noheader)

# Store GPU utilization data with color coding based on utilization level
declare -A gpu_utilization
declare -A gpu_utilization_color
while IFS=',' read -r index util; do
  # Trim whitespace and store the utilization
  util=$(echo $util | xargs)
  gpu_utilization["$index"]="$util"
  
  # Extract numeric value from utilization percentage
  util_value=$(echo $util | sed 's/%//')
  
  # Color code based on utilization percentage
  if (( $(echo "$util_value < 30" | bc -l) )); then
    gpu_utilization_color["$index"]="${COLOR_GREEN}"  # Low utilization: green
  elif (( $(echo "$util_value < 60" | bc -l) )); then
    gpu_utilization_color["$index"]="${COLOR_YELLOW}" # Medium utilization: yellow
  elif (( $(echo "$util_value < 80" | bc -l) )); then
    gpu_utilization_color["$index"]="${COLOR_ORANGE}" # Medium-high utilization: orange
  else
    gpu_utilization_color["$index"]="${COLOR_RED}"    # High utilization: red
  fi
done < <(nvidia-smi --query-gpu=index,utilization.gpu --format=csv,noheader)

# Store GPU memory utilization with color coding
declare -A gpu_memory
declare -A gpu_memory_color
declare -A gpu_memory_used
declare -A gpu_memory_total
while IFS=',' read -r index used total; do
  # Trim whitespace
  used=$(echo $used | xargs)
  total=$(echo $total | xargs)
  
  # Store raw values
  gpu_memory_used["$index"]="$used"
  gpu_memory_total["$index"]="$total"
  
  # Calculate percentage
  used_value=$(echo $used | sed 's/[^0-9]//g')
  total_value=$(echo $total | sed 's/[^0-9]//g')
  
  # Avoid division by zero
  if [ "$total_value" -ne 0 ]; then
    percent=$(echo "scale=2; $used_value * 100 / $total_value" | bc)
  else
    percent=0
  fi
  
  # Format memory usage display
  gpu_memory["$index"]="${used} / ${total} (${percent}%)"
  
  # Color code based on percentage
  if (( $(echo "$percent < 30" | bc -l) )); then
    gpu_memory_color["$index"]="${COLOR_GREEN}"  # Low memory usage: green
  elif (( $(echo "$percent < 60" | bc -l) )); then
    gpu_memory_color["$index"]="${COLOR_YELLOW}" # Medium memory usage: yellow
  elif (( $(echo "$percent < 80" | bc -l) )); then
    gpu_memory_color["$index"]="${COLOR_ORANGE}" # Medium-high memory usage: orange
  else
    gpu_memory_color["$index"]="${COLOR_RED}"    # High memory usage: red
  fi
done < <(nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader)

# Count number of processes to display
process_count=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader | wc -l)
echo -e "${COLOR_YELLOW}Found ${process_count} GPU processes${COLOR_RESET}\n"

# Draw a box around each process with fixed width
draw_box_top() {
  local line="${TOP_LEFT}"
  for ((i=0; i<BOX_WIDTH-2; i++)); do
    line+="${HORIZONTAL}"
  done
  line+="${TOP_RIGHT}"
  echo -e "$line"
}

draw_box_bottom() {
  local line="${BOTTOM_LEFT}"
  for ((i=0; i<BOX_WIDTH-2; i++)); do
    line+="${HORIZONTAL}"
  done
  line+="${BOTTOM_RIGHT}"
  echo -e "$line"
}

draw_box_content() {
  # Calculate padding needed for proper alignment
  local content="$1"
  
  # Remove color codes for length calculation
  local clean_content=$(echo -e "$content" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g")
  local clean_length=${#clean_content}
  
  # Adjust for multi-width characters
  local emoji_count=$(echo -n "$clean_content" | grep -o -i "🚀" | wc -l)
  clean_length=$((clean_length + emoji_count))  # Count the extra width for emojis
  
  # Calculate padding
  local padding=$((BOX_WIDTH - clean_length - 4))  # -4 for the vertical bars and spaces
  
  # Create padding string
  local pad_string=""
  for ((i=0; i<padding; i++)); do
    pad_string+=" "
  done
  
  # Print content with consistent top and bottom spacing
  echo -e "${COLOR_GRAY}${VERTICAL}${COLOR_RESET} $content${pad_string} ${COLOR_GRAY}${VERTICAL}${COLOR_RESET}"
}

# Retrieve compute applications data
nvidia-smi --query-compute-apps=pid,gpu_uuid,used_memory,process_name --format=csv,noheader | while IFS=, read -r pid gpu_uuid used_memory process_name; do
  if [[ -z "$pid" ]]; then
    continue
  fi
  
  gpu_index="${gpu_mapping[$gpu_uuid]}"
  current_gpu_util="${gpu_utilization[$gpu_index]}"
  current_gpu_util_color="${gpu_utilization_color[$gpu_index]}"
  current_gpu_memory="${gpu_memory[$gpu_index]}"
  current_gpu_memory_color="${gpu_memory_color[$gpu_index]}"
  
  # Check if process is still running
  if ! ps -p "$pid" > /dev/null 2>&1; then
    status="${COLOR_RED}${ICON_EXITED} EXITED${COLOR_RESET}"
    start_time="N/A"
    full_path="N/A"
  else
    status="${COLOR_GREEN}${ICON_RUNNING} RUNNING${COLOR_RESET}"
    start_time=$(ps -o lstart= -p "$pid")
    # Convert start time to Beijing time (GMT+8)
    start_time_bj=$(TZ='Asia/Shanghai' date -d "$start_time" +"%Y-%m-%d %H:%M:%S")
    # Get the full path of the process
    full_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || ps -o comm= -p "$pid")
    if [[ -z "$full_path" ]]; then
      full_path="<path not accessible>"
    fi
  fi
  
  # Truncate long paths to fit in box
  if [[ ${#full_path} -gt $((BOX_WIDTH - 15)) ]]; then
    full_path="${full_path:0:$((BOX_WIDTH - 18))}..."
  fi
  
  # Print process block with box drawing
  draw_box_top
  draw_box_content "${COLOR_BOLD}PID:${COLOR_RESET} ${COLOR_GREEN}${pid}${COLOR_RESET}  ${status}"
  draw_box_content "${COLOR_BOLD}GPU:${COLOR_RESET} ${COLOR_CYAN}${gpu_index}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}GPU Utilization:${COLOR_RESET} ${current_gpu_util_color}${current_gpu_util}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}GPU Memory:${COLOR_RESET} ${current_gpu_memory_color}${current_gpu_memory}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}Process Memory:${COLOR_RESET} ${COLOR_YELLOW}${used_memory}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}Process:${COLOR_RESET} ${COLOR_GRAY}${process_name}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}Started:${COLOR_RESET} ${COLOR_BLUE}${start_time_bj}${COLOR_RESET}"
  draw_box_content "${COLOR_BOLD}Path:${COLOR_RESET} ${COLOR_GRAY}${full_path}${COLOR_RESET}"
  draw_box_bottom
done

echo -e ""
echo -e "${COLOR_GRAY}══════════════════════════════════════════════════════════════════════════════════════════${COLOR_RESET}"

# Display GPU utilization and memory summary at the bottom
echo -e "\n${COLOR_BOLD}${COLOR_CYAN}GPU UTILIZATION AND MEMORY SUMMARY${COLOR_RESET}"
for index in "${!gpu_utilization[@]}"; do
  util="${gpu_utilization[$index]}"
  util_color="${gpu_utilization_color[$index]}"
  mem="${gpu_memory[$index]}"
  mem_color="${gpu_memory_color[$index]}"
  
  echo -e "  GPU ${COLOR_BOLD}${COLOR_CYAN}$index${COLOR_RESET}: "
  echo -e "    Compute: ${util_color}${util}${COLOR_RESET}"
  echo -e "    Memory:  ${mem_color}${mem}${COLOR_RESET}"
done

echo -e "\n${COLOR_CYAN}Monitor completed at: $(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S")${COLOR_RESET}"
