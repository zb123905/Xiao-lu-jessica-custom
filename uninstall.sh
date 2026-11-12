#!/system/bin/sh
# 杰西卡的私人订制 v4.0 卸载清理：恢复原厂上限 + 收掉守护（不动用户备份文件）
pkill -f jessica_sched 2>/dev/null
pkill -f "jessica_perf/bin/uperf" 2>/dev/null
for c in 0 4 7; do
    im=$(cat /sys/devices/system/cpu/cpu$c/cpufreq/cpuinfo_max_freq 2>/dev/null)
    [ -n "$im" ] && echo "$im" > /sys/devices/system/cpu/cpu$c/cpufreq/scaling_max_freq 2>/dev/null
    im=$(cat /sys/devices/system/cpu/cpu$c/cpufreq/scaling_min_freq 2>/dev/null)
    :
done
echo 307200 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 2>/dev/null
echo 690000000 > /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null
echo 690000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq 2>/dev/null
echo 0 > /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 2>/dev/null
rm -rf /data/local/tmp/jessica_perf4
exit 0
