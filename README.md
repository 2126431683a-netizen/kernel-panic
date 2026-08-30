# KERNEL PANIC — 终端割草生存（二次元北京篇）

一款 Godot 4 制作的动漫风割草生存游戏。你是一名系统管理员 `@`，
被扔进失控的北京生产节点，无数敌对进程（glitch / runner / 石狮 / 神龙）向你涌来——
用自动火力清除它们，捡经验数据包，升级补丁，活得更久。

## 📚 文档（学习这个项目从这里开始）

| 文档 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 产品需求文档：背景/用户/需求清单/指标/路线图 |
| [docs/GDD.md](docs/GDD.md) | 游戏设计文档：核心循环/数值表/敌系/成长/UI/动效设计 |
| [docs/CODE_GUIDE.md](docs/CODE_GUIDE.md) | **源码讲解**：架构/逐文件说明/一帧生命周期/修改指南 |

## 🔧 改数值只动一个文件

**[scripts/game_config.gd](scripts/game_config.gd)** — 全部可调参数集中在这一处
（玩家属性/刷怪曲线/难度成长/经验公式/反馈强度），带中文注释。

## 启动方式

```bash
# 方式一：命令行直接跑（winget 安装的 godot 别名）
godot --path kernel-panic

# 方式二：完整路径（当前安装位置）
"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path kernel-panic

# 方式三：打开编辑器调试
godot --path kernel-panic -e
```

## 操作

| 按键 | 功能 |
|---|---|
| WASD / 方向键 | 移动 |
| （自动） | 锁定最近敌对进程开火 |
| 1 / 2 / 3 或点击 | 升级时选择补丁 |
| ESC | 撤离回标题 |
| R | 死亡后重新引导系统 |

## 玩法系统

- **刷怪导演**：随时间提升刷怪密度与敌人血量；每 30s 一波 TRAFFIC SPIKE；每 75s 刷一个 ELITE
- **8 种升级补丁**：超频射击 / 提权攻击 / 进程分叉（多弹道）/ 穿透补丁 / 低延迟移动 / 内存扩容 / 抓包范围 / 高带宽链路
- **4 种敌人**：▓ glitch（杂兵）◆ runner（快速）█ tank（重甲）★ elite（精英）
- **击杀日志**：每次击杀在左下角打印 `> kill -9 PID xxxx`

## 视觉 / 听觉（AI 生成贴图 + 代码生成特效）

- **AI 贴图**：8 张贴图由 `gpt-image-2` 异步并发生成（见 `../gen_textures.js`），
  纯黑背景 → Godot 无头脚本洪泛抠图 + 发光边缘羽化 → 256px RGBA（`assets/sprites/`）：
  player / enemy_glitch / enemy_runner / enemy_tank / enemy_elite / bullet / gem / title_bg
- **DOOM 火焰**：经典逐元胞传播算法 + 37 阶调色板（标题屏与死亡屏）
- **CRT 后期**：扫描线 + 暗角 + 闪烁 shader
- **粒子涌现敌群**：敌人带正弦游走 + 群体分离力
- **合成音效**：运行时生成方波/噪声 WAV，无音频文件
- **击杀特效**：字符碎片飞溅 + PID 漂浮字 + 屏幕震动

## 灵感致谢（来自 GitHub 100 个好玩项目精选）

| 项目 | 借鉴点 |
|---|---|
| id-Software/DOOM | 竞技场射击 DNA + 火焰特效算法 |
| storax/kubedoom | "杀进程" 梗文化 |
| CleverRaven/Cataclysm-DDA | 生存成长节奏 |
| Anuken/Mindustry | 波次压力设计 |
| hunar4321/particle-life | 敌群涌现行为 |
| GitSquared/edex-ui | 科幻终端 UI |
| ChrisBuilds/terminaltexteffects | 击杀文字特效 |
| ppy/osu | 打击反馈（震屏/闪烁） |
| kitao/pyxel | 复古像素审美 |
| gabrielecirulli/2048 | 小而完整的开局 |

## 自动化测试

```bash
# 无头冒烟测试：跑完整流程（开局→刷怪→升级→死亡→重启）
KP_AUTOTEST=1 godot --path kernel-panic --headless --quit-after 900
```

## 项目结构

```
kernel-panic/
├── project.godot          # 引擎配置（GL Compatibility / 1280x720 / nearest 采样）
├── scenes/Main.tscn       # 唯一场景入口
├── assets/sprites/        # AI 生成贴图（gpt-image-2 → 黑底抠图 → 256px RGBA）
├── scripts/
│   ├── main.gd            # 状态机 / 刷怪导演 / 碰撞 / 升级
│   ├── player.gd          # 玩家：移动 + 自动开火（AI 贴图 + 字符兜底）
│   ├── enemy.gd           # 4 类敌人 + 群体行为（AI 贴图 + 字符兜底）
│   ├── bullet.gd          # 子弹（旋转贴图/拖尾）
│   ├── gem.gd             # 经验数据包（磁吸）
│   ├── fx.gd              # 漂浮字 / 碎片 / 圆环特效
│   ├── hud.gd             # HUD / 标题(AI 背景图) / 升级面板 / 结算
│   ├── doom_fire.gd       # DOOM 火焰算法
│   ├── sfx.gd             # 运行时合成音效（autoload）
│   └── kp.gd              # 配色 / 字体 / 贴图缓存 / figlet 工具
├── tools/process_textures.gd  # 无头贴图后处理（抠图+羽化+缩放）
└── shaders/crt.gdshader   # CRT 扫描线后期
```

## 重新生成贴图

```bash
# 全部缺失贴图（并发 2，避开网关并发上限）
node ../gen_textures.js

# 只生成指定项
node ../gen_textures.js tank gem title

# 之后跑 Godot 无头后处理（抠图/缩放）
godot --headless --path . --script res://tools/process_textures.gd
```
