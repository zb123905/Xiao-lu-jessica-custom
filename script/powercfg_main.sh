#!/system/bin/sh
#
# Copyright (C) 2021-2022 Matt Yang
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

BASEDIR="$(dirname $(readlink -f "$0"))"
. $BASEDIR/pathinfo.sh

action="$1"
case "$1" in
"powersave" | "balance" | "performance" | "auto")
    echo "$1" >"$USER_PATH/cur_powermode.txt"
    # 杰西卡：非极速档恢复大核/超大核默认下限
    echo 499200 > /sys/devices/system/cpu/cpufreq/policy3/scaling_min_freq 2>/dev/null
    echo 595200 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 2>/dev/null
    ;;
"fast" | "pedestal")
    echo "fast" >"$USER_PATH/cur_powermode.txt"
    # 杰西卡：极速档钉死大核/超大核最低频（散热器专用）
    echo 1420800 > /sys/devices/system/cpu/cpufreq/policy3/scaling_min_freq 2>/dev/null
    echo 1708800 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 2>/dev/null
    ;;
"init") echo "powersave" >"$USER_PATH/cur_powermode.txt" ;;
*) echo "Failed to apply unknown action '$1'." ;;
esac
