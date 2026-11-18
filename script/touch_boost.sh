#!/system/bin/sh
# 杰西卡的私人订制 · 触摸加速（吸收 Uperf input 模块精华）
# 事件驱动：getevent 阻塞读触摸屏，零待机开销
# 只服务省电/均衡档（性能/极速/game 档已钉满血，跳过）
# 中核 policy3 下限引擎不托管，与引擎的缓存写入无冲突

P4=/sys/devices/system/cpu/cpufreq/policy3/scaling_min_freq
TSF=/data/local/tmp/jessica_perf4/tb.ts
PRF=/data/local/tmp/jessica_perf4/prof.txt
CHMOD_OK=0

chmod 644 "$P4" 2>/dev/null && CHMOD_OK=1

boost() {
    p=$(cat "$PRF" 2>/dev/null)
    case "$p" in
        balance) b=1420800 ;;
        powersave) b=1228800 ;;
        *) return 0 ;;
    esac
    cur=$(cat "$P4" 2>/dev/null)
    [ "$cur" = "$b" ] && return 0
    chmod 644 "$P4" 2>/dev/null
    echo "$b" > "$P4" 2>/dev/null
}

restore_if_stale() {
    ts=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
    old=$(cat "$TSF" 2>/dev/null)
    [ "$ts" = "$old" ] || return 0
    sleep 0.6
    now=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
    [ "$now" = "$(cat "$TSF" 2>/dev/null)" ] || exit 0
    cur=$(cat "$P4" 2>/dev/null)
    [ "$cur" = "0" ] || echo 0 > "$P4" 2>/dev/null
    exit 0
}

TOUCHING=0
getevent -ql /dev/input/event7 2>/dev/null | while read -r dev type code val; do
    [ "$code" = "ABS_MT_TRACKING_ID" ] || continue
    if [ "$val" != "ffffffff" ] && [ "$val" != "-1" ]; then
        [ "$TOUCHING" = "1" ] && continue
        TOUCHING=1
        boost
        cut -d' ' -f1 /proc/uptime > "$TSF" 2>/dev/null
        restore_if_stale &
    else
        TOUCHING=0
    fi
done
