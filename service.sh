#!/system/bin/sh
# 杰西卡的私人订制 v4.0 · 自研调度引擎启动入口
MODDIR=${0%/*}
(
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
    sleep 8
    setsid sh "$MODDIR/script/jessica_sched.sh" < /dev/null > /dev/null 2>&1 &
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
