# 小鹿杰西卡的私人订制 1.0 🦌

> 红米 K70（vermeer · 骁龙8 Gen 2 · HyperOS 3）专属 Magisk 调度模块
> 由洁西卡基于 [Uperf Game Turbo 1.51](https://github.com/yinwanxi/Uperf-Game-Turbo)（吟惋兮）/ [uperf 904](https://github.com/yc9559/uperf)（Matt Yang）深度定制

## ✨ 特性

### 四档设计（ Scene 工具箱可直接切档）

| 档位 | 场景 | 说明 |
|---|---|---|
| 省电 powersave | 日常全局默认 / 拉格朗日自动 | 静止时小核降到 0.63GHz 休息，桌面 90Hz |
| 均衡 balance | 王者荣耀（含体验服）/ QQ 微信支付宝等日常应用自动 | 目标 ~4W，120Hz |
| 性能 performance | 三角洲行动自动 | 目标 ≤7.5W 削峰稳帧，GPU 限 550MHz 防热崩帧 |
| 极速 fast | 散热器专用手动档 | 三簇频率钉死 + GPU 全速 + 温控自动放开 |

### 智能联动
- **分应用自动切档**：打开游戏/常用应用自动换挡，回桌面自动省电
- **档位反应器**：跟随档位同步 GPU 上限、Eclipse 温控档（极速档自动"丧心病狂"、退出自动恢复"深度定制"）、屏幕刷新率（省电 90Hz / 其余 120Hz）
- **96°C 保险丝**：极速档 SOC 过热自动降级，凉了自动放回（防散热器脱落）

### 防猝死三件套
- 看门狗（总管家）每 60s 巡检：uperf 掉线自动拉起，反应器/AsoulOpt 掉线自动守护
- 连续 3 次拉起失败 → 自动还原 HyperOS 默认频率，绝不锁死发热
- 卸载自动还原全部默认状态

### 温控共存
与 [Eclipse 定制温控](https://github.com/[your-fork])（K70 专用）和平共存：不杀 mi_thermald、不锁 cpu_limits，温度由 Eclipse 管、调度由本模块管。

### 隐藏加固
状态文件迁移至 `/data/local/tmp/jessica_perf`（普通应用不可见）、无联网更新检查、清理旧版 uperf 存储指纹。

## 📦 安装

1. 关闭 Scene 自带调度功能（Scene 仅作切换器/监控）
2. Magisk → 模块 → 从本地安装 → 选择 zip
3. 提示安装 AsoulOpt（游戏线程绑核）时按 **音量上键** 确认
4. 重启

切换方式：Scene 性能配置 / `sh /data/powercfg.sh balance|powersave|performance|fast|auto`

## 🗂 目录结构

```
├── module.prop            模块信息
├── customize.sh / setup.sh  安装脚本
├── service.sh / post-fs-data.sh  开机入口
├── config/
│   ├── sdm8g2.json        SM8550 四档调度参数（核心定制）
│   └── perapp_powermode.txt  分应用规则
├── script/
│   ├── powercfg_once.sh   开机初始化（已移除杀温控逻辑）
│   ├── miui_migt.sh       MIUI migt 禁用
│   ├── powercfg_main.sh   档位切换入口（含极速档钉频）
│   ├── watchdog.sh        防猝死看门狗（总管家）
│   ├── mode_reactor.sh    档位反应器（GPU/温控/刷新率联动）
│   └── restore_defaults.sh  一键还原
├── bin/uperf              调度核心
└── modules/asoulopt.zip   内置 AsoulOpt 游戏线程优化
```

## 🙏 致谢

- [yc9559](https://github.com/yc9559/uperf) — uperf 原作
- [吟惋兮 yinwanxi](https://github.com/yinwanxi/Uperf-Game-Turbo) — Game Turbo 改版
- [nakixii](https://github.com/nakixii/Magisk_AsoulOpt) — AsoulOpt 线程优化
- 苏疫杆菌 — Eclipse 定制温控（温控联动适配）
- 所有陪洁西卡测试数据的朋友们

## ⚠️ 免责声明

仅供学习交流，刷入产生的任何问题请自行承担。极速档请搭配散热器使用。
