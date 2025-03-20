# 显示 正在使用gpu的进程的更详细的信息

Usage
# Clone the repository
git clone https://github.com/yourusername/showmegpu.git

# Navigate to the directory
cd showmegpu

# Make the script executable
chmod +x ./showmegpu.sh

# Run the script
./showmegpu.sh
Example Output
The script will display information about each GPU process in a box format with color-coded indicators:

🚀 RUNNING - Indicates an active process
❗ EXITED - Indicates a process that has terminated
Each box contains the process ID, GPU index, memory usage, process name, start time (in Beijing time), and executable path.

Use Cases
Monitoring machine learning training jobs
Tracking GPU resource utilization
Identifying orphaned GPU processes
Debugging GPU application issues
  
