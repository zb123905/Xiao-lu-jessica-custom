#!/system/bin/sh
# 杰西卡的私人订制 · 防猝死看门狗
# 每60秒检查 uperf 心跳；死亡自动拉起；连续3次失败则恢复默认调度并停止（重启后随模块重新开始）
BASEDIR="$(dirname "$(readlink -f "$0")")"
. "$BASEDIR/pathinfo.sh"
. "$BASEDIR/libuperf.sh"

FAIL=0
while true; do
    sleep 60
    # 杰西卡：全家桶守护（v1.7）——反应器与 AsoulOpt 掉线自动拉起
    pgrep -f "jessica_perf/script/mode_reactor.sh" >/dev/null 2>&1 || \
        setsid sh "$SCRIPT_PATH/mode_reactor.sh" >/dev/null 2>&1 </dev/null &
    pgrep -x AsoulOpt >/dev/null 2>&1 || \
        [ -x /data/adb/modules/asoul_affinity_opt/AsoulOpt ] && \
        setsid /data/adb/modules/asoul_affinity_opt/AsoulOpt >/dev/null 2>&1 </dev/null &
    if pgrep uperf >/dev/null 2>&1; then
        FAIL=0
        continue
    fi
    FAIL=$((FAIL + 1))
    echo "$(date '+%m-%d %H:%M:%S') 未发现 uperf（第 $FAIL 次）" >> "$USER_PATH/watchdog.log" 2>/dev/null
    if [ "$FAIL" -ge 3 ]; then
        echo "$(date '+%m-%d %H:%M:%S') 连续3次拉起失败 → 恢复默认调度，看门狗停止（重启后随模块重新开始）" >> "$USER_PATH/watchdog.log" 2>/dev/null
        sh "$SCRIPT_PATH/restore_defaults.sh"
        break
    fi
    echo "$(date '+%m-%d %H:%M:%S') 正在拉起 uperf…" >> "$USER_PATH/watchdog.log" 2>/dev/null
    (uperf_start) >/dev/null 2>&1 &
done
