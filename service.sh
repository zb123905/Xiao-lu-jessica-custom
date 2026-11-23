#!/system/bin/sh
# 杰西卡的私人订制 v4.0 · 自研调度引擎启动入口（带看门狗）
MODDIR=${0%/*}
(
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
    sleep 8
    # 开机先重冻结雹名单（OTA/系统更新会解冻）
    [ -f /data/adb/jessica/refreeze.sh ] && sh /data/adb/jessica/refreeze.sh >/dev/null 2>&1
    # 看门狗：前台跑引擎，意外退出（如被 OOM 杀掉）5 秒内自动拉起
    # 引擎自带单实例锁，重复拉起会被锁挡住，不会多开
    while true; do
        sh "$MODDIR/script/jessica_sched.sh" < /dev/null > /dev/null 2>&1
        sleep 5
    done
) &

# 内存拓展自愈：开机检测无 swap 则补挂 zram 16G
(
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
    sleep 20
    if [ "$(cat /proc/swaps | wc -l)" -le 1 ]; then
        mkswap /dev/block/zram0 > /dev/null 2>&1
        swapon /dev/block/zram0 > /dev/null 2>&1
    fi
) &
