#!/system/bin/sh
# 杰西卡的私人订制 · 卸载还原脚本
USER_PATH="/data/local/tmp/jessica_perf"

wait_until_login() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
}

w() {
    if [ -f "$2" ]; then
        chmod 644 "$2" 2>/dev/null
        echo "$1" > "$2" 2>/dev/null
    fi
}

on_remove() {
    wait_until_login

    # 优先调用模块内还原脚本
    sh "$(dirname "$(readlink -f "$0")")/script/restore_defaults.sh" 2>/dev/null

    # 兜底还原（即使模块文件已被清理也能还原关键项）
    w 556800 /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    w 499200 /sys/devices/system/cpu/cpufreq/policy3/scaling_min_freq
    w 595200 /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
    w 0-7 /dev/cpuset/top-app/cpus
    w 0-6 /dev/cpuset/foreground/cpus
    w 0-2 /dev/cpuset/background/cpus

    rm -f /data/powercfg.sh /data/powercfg-base.sh /data/powercfg.json
    rm -rf "$USER_PATH"
    # 清除旧版 Uperf Game Turbo 在共享存储的残留指纹
    rm -rf /sdcard/Android/yc

    killall uperf 2>/dev/null
    pkill -f watchdog.sh 2>/dev/null
}

# do not block boot
(on_remove &)
