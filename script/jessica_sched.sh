#!/system/bin/sh
# 杰西卡的私人订制 v4.0 · 自研调度引擎「小鹿当家」（独立版）
# 原则：
#  1. 完全自立：档位、切换、数字全部归我们，不读不翻译任何第三方档位
#  2. 四档：powersave(省电) / balance(均衡·日常默认) / performance(性能) / speed(极速) / game(游戏特化)
#  3. 切换来源优先级：mode.txt 手动 > 分应用规则 perapp.txt > 息屏→省电 > 默认均衡
#  4. 继承验证过的机制：GPU宽迟滞 / tpl_guard / 亮度保底(仅游戏内) / 热保险丝 / 常驻复查

MODDIR="$(dirname "$(readlink -f "$0")")/.."
CFG="$MODDIR/cfg"
P=/data/local/tmp/jessica_perf4
LOG="$P/sched.log"
mkdir -p "$P"

# 单实例锁：mkdir 原子加锁 + 陈旧锁自清理
if mkdir "$P/sched.lockdir" 2>/dev/null; then
    echo $$ > "$P/sched.lockdir/pid"
else
    oldpid=$(cat "$P/sched.lockdir/pid" 2>/dev/null)
    if [ -n "$oldpid" ] && [ -d "/proc/$oldpid" ]; then
        exit 0
    fi
    rm -rf "$P/sched.lockdir"
    mkdir "$P/sched.lockdir" 2>/dev/null || exit 0
    echo $$ > "$P/sched.lockdir/pid"
fi
# 反冻结搬家：脱离宿主 App 的 cgroup，挂到系统根
[ -w /sys/fs/cgroup/cgroup.procs ] && echo $$ > /sys/fs/cgroup/cgroup.procs 2>/dev/null
for f in /dev/memcg/apps/cgroup.procs /dev/memcg/cgroup.procs; do
    [ -w "$f" ] && echo $$ > "$f" 2>/dev/null
done

log(){ echo "$(date '+%m-%d %H:%M:%S') [sched4] $1" >> "$LOG" 2>/dev/null; }

GPU_CLK=/sys/class/kgsl/kgsl-3d0/max_gpuclk
GPU_DF=/sys/class/kgsl/kgsl-3d0/devfreq/max_freq
GPU_TPL=/sys/class/kgsl/kgsl-3d0/thermal_pwrlevel

IM7=$(cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_max_freq 2>/dev/null)
case "$IM7" in ''|*[!0-9]*) IM7=2726400 ;; esac

CAP_FULL=600000000; CAP_MID=550000000; CAP_LOW=470000000
HOT_LOW=92000; HOT_MID=86000; COOL_MID=78000; COOL_FULL=74000
FUSE_ON=97000; FUSE_OFF=88000; FUSE_CNT_NEED=3

# —— Uperf 式触控感知：小核托底 + 触摸提频 ——
BAL_MIN=1017600   # 均衡：亮屏触摸时小核托底 1.0G（参考 Uperf sdm8g2.json）
PERF_MIN=1228800  # 性能/极速：小核常驻 1.2G
MIN0=1017600
LAST_LLCC=""
LAST_MIN="init"
LAST_SMOOTH=""
LAST_SMOOTH4=""

touch_watch() {
    while true; do
        timeout 0.2 getevent -c 1 2>/dev/null >/dev/null && date +%s > "$P/last_touch" 2>/dev/null
    done
}
touch_watch &

# —— Scene 上牌：挂名进程 + 档位接口文件 ——
UPERF_CARD="$MODDIR/bin/uperf"
[ -x "$UPERF_CARD" ] || chmod 755 "$UPERF_CARD" 2>/dev/null
# 真 uperf 二进制挂名（全关配置，只留档位接口），Scene 按进程识别
pgrep -f "jessica_perf/bin/uperf" >/dev/null 2>&1 || "$UPERF_CARD" "$MODDIR/config/uperf_card.json" -o "$P/uperf_card.log" &
CUR_FILE=/storage/emulated/0/Android/yc/uperf/cur_powermode.txt
mkdir -p /storage/emulated/0/Android/yc/uperf 2>/dev/null
[ -f "$CUR_FILE" ] || echo balance > "$CUR_FILE" 2>/dev/null

# —— Scene powercfg 正门接口（/data/powercfg.json，调节卡亮名+切档）——
STATE_TXT="$P/cur_powermode.txt"
cat > /data/powercfg.json <<PCFG
{
    "name": "杰西卡的私人订制",
    "author": "洁西卡🦌 & Eta",
    "version": "v4.0",
    "versionCode": 40002,
    "features": { "strict": true, "pedestal": true },
    "module": "jessica_sched",
    "state": "$STATE_TXT",
    "entry": "/data/powercfg.sh"
}
PCFG
cat > /data/powercfg.sh <<'PCFG'
#!/vendor/bin/sh
STATE=/data/local/tmp/jessica_perf4/cur_powermode.txt
CUR=/storage/emulated/0/Android/yc/uperf/cur_powermode.txt
case "$1" in
"powersave") m="powersave" ;;
"balance"|"auto") m="balance" ;;
"performance") m="performance" ;;
"fast"|"pedestal") m="speed" ;;
"init") m="balance" ;;
*) echo "unknown action '$1'"; exit 0 ;;
esac
echo "$m" >"$STATE"
echo "$m" >"$CUR" 2>/dev/null
PCFG
chmod 755 /data/powercfg.sh 2>/dev/null
cp /data/powercfg.sh /data/powercfg-base.sh 2>/dev/null
[ -f "$STATE_TXT" ] || echo balance > "$STATE_TXT" 2>/dev/null

touch_active() { # $1=亮屏(0/1)
    [ "$1" = "1" ] || return 1
    [ -f "$P/last_touch" ] || return 1
    lt=$(cat "$P/last_touch" 2>/dev/null)
    [ -n "$lt" ] && [ $(( $(date +%s) - lt )) -lt 3 ]
}

bg_app_count() { # 后台应用数（最近任务，排除桌面）
    n=$(timeout 3 dumpsys activity recents 2>/dev/null | grep "Recent #" | grep -cv "type=home")
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    echo $n
}

LAST_GPU=""; GPU_TS=0
BG_TS=0; BG=0; TOP_TS=0; TOP=""
FUSE=0; FUSE_CNT=0
ACTIVE=""

soc_temp() {
    T=0
    for z in /sys/class/thermal/thermal_zone*; do
        ty=$(cat "$z/type" 2>/dev/null)
        case "$ty" in
            cpu-0-0|cpu-1-0|soc-therm|cpu*) v=$(cat "$z/temp" 2>/dev/null)
                [ -n "$v" ] && [ "$v" -gt "$T" ] 2>/dev/null && T=$v ;;
        esac
    done
    echo "$T"
}

set_gpu() {
    [ "$1" = "$LAST_GPU" ] && return 0
    for f in "$GPU_CLK" "$GPU_DF"; do
        [ -f "$f" ] && echo "$1" > "$f" 2>/dev/null
    done
    LAST_GPU="$1"; GPU_TS=$(date +%s)
}

set_cpu() {
    f=/sys/devices/system/cpu/cpu$1/cpufreq/scaling_max_freq
    cur=$(cat "$f" 2>/dev/null)
    [ "$cur" = "$2" ] || echo "$2" > "$f" 2>/dev/null
}

tpl_guard() {
    [ -f "$GPU_TPL" ] || return 0
    tpl=$(cat "$GPU_TPL" 2>/dev/null)
    if [ -n "$tpl" ] && [ "$tpl" != "0" ] && [ "$1" -lt 95000 ]; then
        echo 0 > "$GPU_TPL" 2>/dev/null
        LAST_GPU=""   # 钳制释放会重置 devfreq 上限，强制下一轮按档位重写
        log "thermal_pwrlevel $tpl → 0（钳制解除）"
    fi
}

brightness_guard() {
    [ -f "$P/no_brightness_guard" ] && return 0
    maxb=$(settings get system screen_brightness_max 2>/dev/null)
    case "$maxb" in ''|*[!0-9]*) maxb=4095 ;; esac
    if [ -f "$P/brightness_floor" ]; then
        floor=$(cat "$P/brightness_floor" 2>/dev/null)
        case "$floor" in ''|*[!0-9]*) floor=1200 ;; esac
    else
        floor=$((maxb * 30 / 100))
    fi
    cur=$(settings get system screen_brightness 2>/dev/null)
    case "$cur" in ''|*[!0-9]*) return 0 ;; esac
    if [ "$cur" -lt "$floor" ]; then
        settings put system screen_brightness "$floor" 2>/dev/null
        log "亮度保底：$cur → $floor"
    fi
}

gpu_adaptive() {
    [ "$FUSE" = "1" ] && return 0
    now=$(date +%s)
    case "$LAST_GPU" in
        "$CAP_FULL")
            if   [ "$1" -ge "$HOT_LOW" ]; then want=$CAP_LOW
            elif [ "$1" -ge "$HOT_MID" ]; then want=$CAP_MID
            else want=$CAP_FULL; fi ;;
        "$CAP_MID")
            if   [ "$1" -ge "$HOT_LOW" ]; then want=$CAP_LOW
            elif [ "$1" -le "$COOL_FULL" ]; then want=$CAP_FULL
            else want=$CAP_MID; fi ;;
        "$CAP_LOW")
            if   [ "$1" -le "$COOL_MID" ]; then want=$CAP_MID
            else want=$CAP_LOW; fi ;;
        *) want=$CAP_FULL ;;
    esac
    [ "$want" = "$LAST_GPU" ] && return 0
    [ $((now - GPU_TS)) -lt 30 ] && return 0
    set_gpu "$want"
    log "GPU自适应 → $(($want / 1000000))MHz（SOC=$1）"
}

top_app() {
    timeout 2 dumpsys window 2>/dev/null | sed -n 's/.*mCurrentFocus[^=]*=Window{[^ ]* [^ ]* \([^ /}]*\).*/\1/p' | head -n 1
}

screen_off() {
    timeout 2 dumpsys power 2>/dev/null | grep -q 'mWakefulness=Asleep'
}

VIDEO_APPS="com.bilibili.app com.ss.android.ugc.aweme tv.danmaku.bili"
# 档位决定（完全自研）：手动 > 分应用 > 息屏 > 默认均衡
resolve_mode() {
    m=$(cat "$P/mode.txt" 2>/dev/null)
    case "$m" in
        powersave|balance|performance|speed|game) SRC="手动"; RESP="$m"; return ;;
    esac
    if screen_off; then SRC="息屏"; RESP="powersave"; return; fi
    now=$(date +%s); [ $((now - TOP_TS)) -ge 5 ] && { TOP=$(top_app); TOP_TS=$now; }; pkg=$TOP
    if [ -n "$pkg" ]; then
        m=$(sed -n "s/^$pkg //p" "$MODDIR/perapp.txt" 2>/dev/null | head -n 1)
        case "$m" in
            powersave|balance|performance|speed|game) SRC="分应用"; RESP="$m"; return ;;
        esac
    fi
    # 游戏时后台有视频应用播放 → 自动升性能档（B站/抖音等）
    if [ "$RESP" = "game" ]; then
        for app in $VIDEO_APPS; do
            if pidof "$app" > /dev/null 2>&1; then RESP=performance; SRC="game+video heavy ($app)"; break; fi
        done
    fi
    scene_cur_mode && return
    SRC="默认"; RESP="balance"
}

scene_cur_mode() {
    m=$(cat "$CUR_FILE" 2>/dev/null | tr -d ' \r\n\t')
    case "$m" in
        fast) m="speed" ;;
    esac
    case "$m" in
        powersave|balance|performance|speed|game) SRC="Scene全局"; RESP="$m"; return 0 ;;
    esac
    m=$(cat "$P/cur_powermode.txt" 2>/dev/null | tr -d ' \r\n\t')
    case "$m" in
        fast) m="speed" ;;
    esac
    case "$m" in
        powersave|balance|performance|speed|game) SRC="Scene全局"; RESP="$m"; return 0 ;;
    esac
    return 1
}

cpu_info_max() { cat /sys/devices/system/cpu/cpu$1/cpufreq/cpuinfo_max_freq 2>/dev/null; }

apply_cfg() { # $1=档位 → 输出 GPU 目标；0 = 主动解锁到满血（不清残留上限）
    cfgline=$(grep -v '^#' "$CFG/$1.cfg" 2>/dev/null | grep -v '^[[:space:]]*$' | head -n 1)
    [ -n "$cfgline" ] || return 1
    read c0 c4 c7 g <<EOF
$cfgline
EOF
    case "$g" in ''|*[!0-9]*) g=$CAP_FULL ;; esac
    if [ "$c0" = "0" ]; then c0=$(cpu_info_max 0); else :; fi
    if [ "$c4" = "0" ]; then c4=$(cpu_info_max 4); else :; fi
    if [ "$c7" = "0" ]; then c7=$(cpu_info_max 7); else :; fi
    [ -n "$c0" ] && set_cpu 0 "$c0"
    [ -n "$c4" ] && set_cpu 4 "$c4"
    [ -n "$c7" ] && set_cpu 7 "$c7"
    echo "$g"
}

log "调度引擎 v4.0 独立版「小鹿当家」启动（自研四档 / 分应用 / 息屏联动）"

while true; do
    [ -f "$P/reactor_stop" ] && { log "收到 reactor_stop，退出"; exit 0; }
    # 极速档（散热器场景）2 秒快轮询，更快解除 kgsl thermal_pwrlevel 钳制
    case "$PROF" in speed|powersave) sleep 2 ;; *) sleep 5 ;; esac

    T=$(soc_temp)

    # —— 热保险丝 ——
    if [ "$T" -ge "$FUSE_ON" ]; then
        FUSE_CNT=$((FUSE_CNT + 1))
    else
        FUSE_CNT=0
    fi
    if [ "$FUSE" = "0" ] && [ "$FUSE_CNT" -ge "$FUSE_CNT_NEED" ]; then
        FUSE=1
        for c in 0 4 7; do
            im=$(cat /sys/devices/system/cpu/cpu$c/cpufreq/cpuinfo_max_freq 2>/dev/null)
            [ -n "$im" ] && set_cpu "$c" "$((im * 7 / 10))"
        done
        set_gpu "$CAP_LOW"
        log "⚠ 热保险丝：SOC=${T}mC → CPU 70% + GPU 470MHz"
    elif [ "$FUSE" = "1" ] && [ "$T" -le "$FUSE_OFF" ]; then
        FUSE=0
        for c in 0 4 7; do
            im=$(cat /sys/devices/system/cpu/cpu$c/cpufreq/cpuinfo_max_freq 2>/dev/null)
            [ -n "$im" ] && set_cpu "$c" "$im"
        done
        log "热保险丝解除：SOC=${T}mC"
    fi

    # —— 档位解析与应用（常驻复查）——
    resolve_mode
    PROF=$RESP
    W=1; screen_off && W=0
    # 省电档自适应：后台任务超过 5 个 → 自动切均衡保后台活性
    if [ "$PROF" = "powersave" ]; then
        now=$(date +%s); [ $((now - BG_TS)) -ge 60 ] && { BG=$(bg_app_count); BG_TS=$now; }
        [ "$BG" -ge 2 ] 2>/dev/null && { PROF=balance; SRC="省电→均衡（后台${BG}个）"; }
    fi
    if [ "$PROF" != "$ACTIVE" ]; then
        ACTIVE="$PROF"
        log "档位 → $ACTIVE（来源 $SRC）"
        echo "$ACTIVE" > "$CUR_FILE" 2>/dev/null
        echo "$ACTIVE" > "$P/cur_powermode.txt" 2>/dev/null
    fi
    if [ "$FUSE" = "1" ]; then
        :
    else
        # 省电双档：触摸活跃 = 日用省电（<3.5W），静置 = 深省电（<2W）
        if [ "$PROF" = "powersave" ]; then
            touch_active "$W" && SUB=powersave || SUB=powersave_idle
            if [ "$SUB" != "$LAST_SUB" ]; then
                LAST_SUB=$SUB
                log "省电子档 → $SUB"
            fi
            G=$(apply_cfg "$SUB")
        else
            LAST_SUB=""
            G=$(apply_cfg "$PROF")
        fi
        [ -n "$G" ] && [ "$G" != "$LAST_GPU" ] && set_gpu "$G"
        if [ "$PROF" = "game" ]; then
            brightness_guard
        elif [ "$PROF" != "powersave" ]; then
            gpu_adaptive "$T"
        fi
    fi

    # —— 性能/极速档热平滑（借鉴 Uperf 功率限幅思路）——
    # 不等内核 96°C 硬节流，提前在 88°C 给大核/中核留余量，≤82°C 放满
    if [ "$PROF" = "performance" ] || [ "$PROF" = "speed" ] || [ "$PROF" = "game" ]; then
        im7=$(cpu_info_max 7); [ -n "$im7" ] || im7=3187200
        # 极速档（带散热器场景）：阈值上移，撒开跑；性能档维持 88/92
        if [ "$PROF" = "speed" ]; then TS_MID=92000; TS_HI=88000; TS_FULL=82000
        else TS_MID=92000; TS_HI=88000; TS_FULL=82000; fi
        if   [ "$T" -ge "$TS_HI" ]; then want7=2342400; want4=2188800
        elif [ "$T" -ge "$TS_MID" ]; then want7=2649600; want4=2054400
        elif [ "$T" -le "$TS_FULL" ]; then want7=$im7; want4=$(cpu_info_max 4)
        else want7=$LAST_SMOOTH; want4=$LAST_SMOOTH4; fi
        if [ -n "$want7" ] && [ "$want7" != "$LAST_SMOOTH" ]; then
            set_cpu 7 "$want7"
            log "性能热平滑：cpu7 → $(($want7 / 1000))MHz（SOC=$T）"
            LAST_SMOOTH=$want7
        fi
        if [ -n "$want4" ] && [ "$want4" != "$LAST_SMOOTH4" ]; then
            set_cpu 4 "$want4"
            log "性能热平滑：cpu4 → $(($want4 / 1000))MHz（SOC=$T）"
            LAST_SMOOTH4=$want4
        fi
    else
        LAST_SMOOTH=""
        LAST_SMOOTH4=""
    fi

    # —— Uperf 式小核托底（触控感知）——
    case "$PROF" in
        performance|speed|game) want_min=$PERF_MIN ;;
        balance|powersave) touch_active "$W" && want_min=$BAL_MIN || want_min="" ;;
        *) want_min="" ;;
    esac
    if [ "$want_min" != "$LAST_MIN" ]; then
        mf=/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
        [ -n "$want_min" ] || want_min=307200
        echo "$want_min" > "$mf" 2>/dev/null
        LAST_MIN=$want_min
        [ "$want_min" != "307200" ] && log "小核托底 → $(($want_min / 1000))MHz（$PROF）"
    fi

    # —— 性能/极速：LLCC/L3/DDR 总线解锁 ——
    if [ "$PROF" = "performance" ] || [ "$PROF" = "speed" ] || [ "$PROF" = "game" ]; then
        if [ "$LAST_LLCC" != "1" ]; then
            for b in LLCC L3 DDR; do
                echo 999999999 > /sys/devices/system/cpu/bus_dcvs/$b/hw_max_freq 2>/dev/null
            done
            LAST_LLCC=1
            log "总线解锁：LLCC/L3/DDR 满血"
        fi
    else
        LAST_LLCC=""
    fi

    tpl_guard "$T"
done
