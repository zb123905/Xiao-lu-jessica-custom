#!/system/bin/sh
# 杰西卡的私人订制 · 恢复 HyperOS 默认调度状态
# 用途：看门狗崩溃保护 / 手动急救（sh restore_defaults.sh 后建议重启一次彻底复原）
BASEDIR="$(dirname "$(readlink -f "$0")")"
. "$BASEDIR/pathinfo.sh"

w() {
    if [ -f "$2" ]; then
        chmod 644 "$2" 2>/dev/null
        echo "$1" > "$2" 2>/dev/null
    fi
}

log() { echo "$(date '+%m-%d %H:%M:%S') $1" >> "$USER_PATH/watchdog.log" 2>/dev/null; }

# 1) CPU 最低频（红米K70 HyperOS 3 默认，2026-11-02 实测值）
w 556800 /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
w 499200 /sys/devices/system/cpu/cpufreq/policy3/scaling_min_freq
w 595200 /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq

# 2) cpuset 分组
w 0-7 /dev/cpuset/top-app/cpus
w 0-6 /dev/cpuset/foreground/cpus
w 0-2 /dev/cpuset/background/cpus
w 0-2 /dev/cpuset/system-background/cpus

# 3) 总线 DCVS 解除锁定（恢复 hw_max = 不限制）
for f in /sys/devices/system/cpu/bus_dcvs/*/*/max_freq; do
    hw="$(cat "$(dirname "$f")/hw_max_freq" 2>/dev/null)"
    [ -n "$hw" ] && w "$hw" "$f"
done

# 4) stune / uclamp 归零（彻底还原请重启一次）
for d in /dev/stune/*/; do w 0 "${d}schedtune.boost"; w 0 "${d}schedtune.prefer_idle"; done 2>/dev/null
for d in /dev/cpuctl/*/; do w 0 "${d}cpu.uclamp.min"; w 0 "${d}cpu.uclamp.latency_sensitive"; done 2>/dev/null

# 5) migt 权限还原（hide_value 的 bind-mount 需重启才能彻底解除）
chmod 644 /sys/module/migt/parameters/* 2>/dev/null
chmod 755 /sys/module/migt /sys/class/misc/migt 2>/dev/null

# 6) 温控接口权限还原
chmod 644 /sys/devices/virtual/thermal/thermal_message/cpu_limits 2>/dev/null

log "已恢复 HyperOS 默认调度（bind-mount 类改动重启后彻底消失）"
echo "杰西卡：已恢复默认调度状态，建议重启一次哦~"
