#!/vendor/bin/sh
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
. $BASEDIR/libcommon.sh
. $BASEDIR/libuperf.sh

# 杰西卡：确保隐藏状态目录存在
mkdir -p "$USER_PATH"

# create busybox symlinks
$BIN_PATH/busybox/busybox --install -s $BIN_PATH/busybox

# support vtools
cp -af $SCRIPT_PATH/vtools_powercfg.sh /data/powercfg.sh
cp -af $SCRIPT_PATH/vtools_powercfg.sh /data/powercfg-base.sh
cp -af $SCRIPT_PATH/powercfg.json /data/powercfg.json
chmod 755 /data/powercfg.sh
chmod 755 /data/powercfg-base.sh
echo "sh $SCRIPT_PATH/powercfg_main.sh \"\$1\"" >>/data/powercfg.sh

wait_until_login

sh $SCRIPT_PATH/powercfg_once.sh
sh $SCRIPT_PATH/platform_special.sh
sh $SCRIPT_PATH/miui_migt.sh
uperf_start

# 杰西卡：启动防猝死看门狗（开机3分钟后开始巡检）
(sleep 180; sh $SCRIPT_PATH/watchdog.sh) &

# 杰西卡：AsoulOpt 兜底启动（部分管理器不执行子模块 service.sh）
(
    sleep 45
    if [ -x /data/adb/modules/asoul_affinity_opt/AsoulOpt ] && ! pgrep -f asoul_affinity_opt >/dev/null 2>&1; then
        nohup /data/adb/modules/asoul_affinity_opt/AsoulOpt >/dev/null 2>&1 &
    fi
) &

# 杰西卡：档位反应器（性能档 GPU 限频防热崩帧，v1.3）
(sleep 60; sh $SCRIPT_PATH/mode_reactor.sh) &
