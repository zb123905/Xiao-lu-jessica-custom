#!/system/bin/sh
# 杰西卡的私人订制 · 档位反应器 v1.8
# 跟随 uperf 档位：
#  - GPU：性能档自适应（≤85°C→550MHz 满血，≥90°C→470MHz 平滑防急刹），极速档全速 690
#  - 温控：极速档自动切换 Eclipse[丧心病狂 danger]，退出极速自动恢复[深度定制 pro]
#  - 保险丝：极速档下 SOC ≥96°C 自动降回 pro，≤90°C 自动放回
BASEDIR="$(dirname "$(readlink -f "$0")")"
. "$BASEDIR/pathinfo.sh"

GPU_CLK=/sys/class/kgsl/kgsl-3d0/max_gpuclk
GPU_DF=/sys/class/kgsl/kgsl-3d0/devfreq/max_freq
CAP_HIGH=550000000
CAP_LOW=470000000
FULL=690000000
ECO=/data/adb/modules/Eclipse
TCFG=/data/vendor/thermal/config
CHATTR=/system/bin/chattr
LAST=""
THERM="pro"
SAFE=1
GCAP=550000000

set_gpu() {
    for f in "$GPU_CLK" "$GPU_DF"; do
        if [ -f "$f" ]; then
            chmod 644 "$f" 2>/dev/null
            echo "$1" > "$f" 2>/dev/null
        fi
    done
}

apply_thermal() {  # $1 = cool/pro/extreme/danger
    [ "$1" = "$THERM" ] && return 0
    if [ -d "$ECO/vermeer/$1" ] && [ -d "$TCFG" ]; then
        for f in "$ECO/vermeer/$1"/*; do
            n="$(basename "$f")"
            [ -f "$TCFG/$n" ] || continue
            "$CHATTR" -i "$TCFG/$n" 2>/dev/null
            cp -f "$f" "$TCFG/$n" 2>/dev/null
            chown root:system "$TCFG/$n" 2>/dev/null
            chmod 664 "$TCFG/$n" 2>/dev/null
            "$CHATTR" +i "$TCFG/$n" 2>/dev/null
        done
        killall mi_thermald 2>/dev/null
        THERM="$1"
        log "温控配置切换 → $1（mi_thermald 已重启读取）"
    fi
}

soc_temp() {
    T=0
    for z in /sys/class/thermal/thermal_zone*; do
        ty=$(cat "$z/type" 2>/dev/null)
        case "$ty" in
            cpu*) v=$(cat "$z/temp" 2>/dev/null)
                  [ -n "$v" ] && [ "$v" -gt "$T" ] 2>/dev/null && T=$v ;;
        esac
    done
    echo "$T"
}

log() { echo "$(date '+%m-%d %H:%M:%S') [reactor] $1" >> "$USER_PATH/watchdog.log" 2>/dev/null; }

log "反应器启动 v1.8（GPU自适应 / 温控随极速档 / 96°C保险丝）"
while true; do
    M=$(tail -c 2048 "$USER_PATH/uperf_log.txt" 2>/dev/null | grep "Preset inode" | tail -1 | sed "s/.*-> '//;s/'.*//")
    if [ -z "$M" ]; then sleep 5; continue; fi
    if [ "$M" != "$LAST" ]; then
        case "$M" in
            performance) GCAP=$CAP_HIGH; set_gpu "$GCAP" ;;
            *)           GCAP=$FULL; set_gpu "$FULL" ;;
        esac
        if [ "$M" = "fast" ]; then
            apply_thermal danger
            SAFE=1
        elif [ "$M" = "performance" ]; then
            apply_thermal extreme
        else
            apply_thermal cool
        fi
        LAST="$M"
    elif [ "$M" = "performance" ]; then
        # —— 自适应 GPU：热了降档平滑，凉了回升满血（extreme 温控下阈值上调）——
        T=$(soc_temp)
        if [ "$T" -ge 92000 ] 2>/dev/null && [ "$GCAP" != "$CAP_LOW" ]; then
            GCAP=$CAP_LOW
            set_gpu "$GCAP"
            log "性能档 SOC=${T}mC ≥92°C → GPU 降至 470MHz 平滑输出"
        elif [ "$T" -le 87000 ] 2>/dev/null && [ "$GCAP" != "$CAP_HIGH" ]; then
            GCAP=$CAP_HIGH
            set_gpu "$GCAP"
            log "性能档 SOC=${T}mC ≤87°C → GPU 回升 550MHz"
        fi
        set_gpu "$GCAP"
    elif [ "$M" = "fast" ]; then
        T=$(soc_temp)
        if [ "$T" -ge 96000 ] 2>/dev/null; then
            SAFE=0
        elif [ "$T" -le 90000 ] 2>/dev/null; then
            SAFE=1
        fi
        if [ "$SAFE" = "0" ] && [ "$THERM" != "pro" ]; then
            set_gpu "$CAP_LOW"
            apply_thermal pro
            log "⚠ 保险丝触发：极速档 SOC=${T}mC ≥96°C → 自动降回 pro（散热器掉了吗？）"
        elif [ "$SAFE" = "1" ] && [ "$THERM" != "danger" ]; then
            set_gpu "$FULL"
            apply_thermal danger
            log "温度回落 SOC=${T}mC ≤90°C → 恢复 danger 全速"
        fi
    fi
    sleep 5
done
