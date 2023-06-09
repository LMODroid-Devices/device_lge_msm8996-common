#!/vendor/bin/sh

################################################################################
# local definitions

soc_revision=`cat /sys/devices/soc0/revision`

################################################################################

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}

################################################################################

# disable thermal hotplug to switch governor
write /sys/module/msm_thermal/core_control/enabled 0

# bring back main cores CPU 0,2
write /sys/devices/system/cpu/cpu0/online 1
write /sys/devices/system/cpu/cpu2/online 1

# Tweak interactive governor before trying to switch to schedutil if EAS is available
write /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor interactive
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load 1
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif 1
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay 19000
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load 90
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate 20000
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq 960000
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy 1
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads 80
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time 19000
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/max_freq_hysteresis 79000
write /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 300000
write /sys/devices/system/cpu/cpu0/cpufreq/interactive/ignore_hispeed_on_notif 0

write /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor interactive
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/use_sched_load 1
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/use_migration_notif 1
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/above_hispeed_delay "19000 1400000:39000 1700000:19000 2100000:79000"

write /sys/devices/system/cpu/cpu2/cpufreq/interactive/go_hispeed_load 90
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/timer_rate 20000
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/hispeed_freq 1248000
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/io_is_busy 1
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/target_loads "85 1500000:90 1800000:70 2100000:95"

write /sys/devices/system/cpu/cpu2/cpufreq/interactive/min_sample_time 19000
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/max_freq_hysteresis 39000
write /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq 300000
write /sys/devices/system/cpu/cpu2/cpufreq/interactive/ignore_hispeed_on_notif 0

# if EAS is present, switch to schedutil governor (no effect if not EAS)
write /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor "schedutil"
write /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor "schedutil"

# set schedutil adjustments, based on the "Balanced" Spectrum profile for LGE_8996
# CPU0 (little core cluster) will boost slightly more than CPU2 (big core cluster)
# since the LITTLE 1.2GHz cap from the Balanced profile is where they start
# losing efficiency.
write /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us 1000
write /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us 1750
write /sys/devices/system/cpu/cpu2/cpufreq/schedutil/down_rate_limit_us 1000
write /sys/devices/system/cpu/cpu2/cpufreq/schedutil/up_rate_limit_us 2250

# re-enable thermal hotplug
write /sys/module/msm_thermal/core_control/enabled 1

# input boost configuration
write /sys/module/cpu_boost/parameters/input_boost_freq "0:1324800 2:1324800"
write /sys/module/cpu_boost/parameters/input_boost_ms 40

# Setting b.L scheduler parameters
write /proc/sys/kernel/sched_migration_fixup 1
write /proc/sys/kernel/sched_upmigrate 95
write /proc/sys/kernel/sched_downmigrate 90
write /proc/sys/kernel/sched_freq_inc_notify 400000
write /proc/sys/kernel/sched_freq_dec_notify 400000
write /proc/sys/kernel/sched_spill_nr_run 3
write /proc/sys/kernel/sched_init_task_load 100

# Update DVR cpusets to boot-time values.
write /dev/cpuset/kernel/cpus 0-3
write /dev/cpuset/system/cpus 0-3
write /dev/cpuset/system/performance/cpus 0-3
write /dev/cpuset/system/background/cpus 0-3
write /dev/cpuset/system/cpus 0-3
write /dev/cpuset/application/cpus 0-3
write /dev/cpuset/application/performance/cpus 0-3
write /dev/cpuset/application/background/cpus 0-3
write /dev/cpuset/application/cpus 0-3

# Enable bus-dcvs
for cpubw in /sys/class/devfreq/*qcom,cpubw* ; do
    write $cpubw/governor "bw_hwmon"
    write $cpubw/polling_interval 50
    write $cpubw/min_freq 1525
    write $cpubw/bw_hwmon/mbps_zones "1525 5195 11863 13763"
    write $cpubw/bw_hwmon/sample_ms 4
    write $cpubw/bw_hwmon/io_percent 34
    write $cpubw/bw_hwmon/hist_memory 20
    write $cpubw/bw_hwmon/hyst_length 10
    write $cpubw/bw_hwmon/low_power_ceil_mbps 0
    write $cpubw/bw_hwmon/low_power_io_percent 34
    write $cpubw/bw_hwmon/low_power_delay 20
    write $cpubw/bw_hwmon/guard_band_mbps 0
    write $cpubw/bw_hwmon/up_scale 250
    write $cpubw/bw_hwmon/idle_mbps 1600
done

for memlat in /sys/class/devfreq/*qcom,memlat-cpu* ; do
    write $memlat/governor "mem_latency"
    write $memlat/polling_interval 10
done

# This doesn't affect msm8996pro since it's revisions only go to 1.1
if [ "$soc_revision" == "2.0" ]; then
  #Disable suspend for v2.0
  write /sys/power/wake_lock pwr_dbg
elif [ "$soc_revision" == "2.1" ]; then
  # Enable C4.D4.E4.M3 LPM modes
  # Disable D3 state
  write /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled 0
  write /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled 0
  # Disable DEF-FPC mode
  write /sys/module/lpm_levels/system/pwr/cpu0/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/pwr/cpu1/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/perf/cpu2/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/perf/cpu3/fpc-def/idle_enabled N
fi

# Enable all LPMs by default
# This will enable C4, D4, D3, E4 and M3 LPMs
write /sys/module/lpm_levels/parameters/sleep_disabled N

# Signal perfd that boot has completed
setprop sys.post_boot.parsed 1
