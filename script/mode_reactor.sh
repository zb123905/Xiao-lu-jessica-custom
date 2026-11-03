#!/system/bin/sh
# 杰西卡的私人订制 · 档位反应器 v1.5
# 跟随 uperf 档位：
#  - GPU：性能档 550MHz 防热崩帧，其他档全速 690
#  - 温控：极速档自动切换 Eclipse[丧心病狂 danger]，退出极速自动恢复[深度定制 pro]
#  - 保险丝：极速档下 SOC(CPU) ≥96°C 自动降回 pro+限GPU，≤90°C 自动放回 danger（防散热器脱落）
BASEDIR="$(dirname "$(readlink -f "$0")")"
. "$BASEDIR/pathinfo.sh"

GPU_CLK=/sys/class/kgsl/kgsl-3d0/max_gpuclk
GPU_DF=/sys/class/kgsl/kgsl-3d0/devfreq/max_freq
CAP=550000000
FULL=690000000
ECO=/data/adb/modules/Eclipse
TCFG=/data/vendor/thermal/config
CHATTR=/system/bin/chattr
LAST=""
THERM="pro"    # 当前生效的温控档
SAFE=1         # 极速档保险丝状态：1=允许 danger，0=过热保护中

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
        killall mi_thermald 2>/dev/null   # init 会自动拉起并读取新配置
        THERM="$1"
        log "温控配置切换 → $1（mi_thermald 已重启读取）"
    fi
}

soc_temp() {  # 取所有 cpu* 温区最大值，单位毫摄式度
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

log "反应器启动 v1.5（GPU随档位 / 温控随极速档 / 96°C保险丝）"
while true; do
    M=$(tail -c 2048 "$USER_PATH/uperf_log.txt" 2>/dev/null | grep "Preset inode" | tail -1 | sed "s/.*-> '//;s/'.*//")
    if [ -z "$M" ]; then sleep 5; continue; fi
    if [ "$M" != "$LAST" ]; then
        case "$M" in
            performance) set_gpu "$CAP" ;;
            *)           set_gpu "$FULL" ;;
        esac
        # 刷新率联动（v1.6）：省电档 90Hz 省电，其余档 120Hz
        if [ "$M" = "powersave" ]; then
            settings put system peak_refresh_rate 90.0 2>/dev/null
        else
            settings put system peak_refresh_rate 120.0 2>/dev/null
        fi
        if [ "$M" = "fast" ]; then
            apply_thermal danger
            SAFE=1
        else
            apply_thermal pro
        fi
        LAST="$M"
    elif [ "$M" = "fast" ]; then
        # —— 极速档保险丝：SOC 过热自动降级，凉了自动放回 ——
        T=$(soc_temp)
        if [ "$T" -ge 96000 ] 2>/dev/null; then
            SAFE=0
        elif [ "$T" -le 90000 ] 2>/dev/null; then
            SAFE=1
        fi
        if [ "$SAFE" = "0" ] && [ "$THERM" != "pro" ]; then
            set_gpu "$CAP"
            apply_thermal pro
            log "⚠ 保险丝触发：极速档 SOC=${T}mC ≥96°C → 自动降回 pro+限GPU（散热器掉了吗？）"
        elif [ "$SAFE" = "1" ] && [ "$THERM" != "danger" ]; then
            set_gpu "$FULL"
            apply_thermal danger
            log "温度回落 SOC=${T}mC ≤90°C → 恢复 danger 全速"
        fi
    elif [ "$M" = "performance" ]; then
        # 周期性重申，防止温控把 GPU 上限抬回去
        CUR=$(cat "$GPU_CLK" 2>/dev/null)
        [ -n "$CUR" ] && [ "$CUR" -gt "$CAP" ] && set_gpu "$CAP"
    fi
    sleep 5
done
