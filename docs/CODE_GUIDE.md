# 源码讲解 — CODE_GUIDE
# KERNEL PANIC · Godot 4 源码学习手册

> 面向想读懂、想改这个项目的你。先读 §1 架构，再按需跳读。
> 配套：[PRD](PRD.md) · [GDD](GDD.md)（数值设计）· [README](../README.md)

---

## 1. 架构总览

```
Main.tscn (唯一场景，根节点 Node2D + main.gd)
│
├── main.gd           游戏编排器：状态机 / 刷怪导演 / 碰撞 / 升级 / 背景绘制
│   ├── player.gd     玩家（代码创建）
│   ├── enemies_node ── enemy.gd × N（代码创建）
│   ├── bullets_node ── bullet.gd × N
│   ├── gems_node   ── gem.gd × N
│   ├── fx_node     ── fx.gd × N（漂浮字/碎片/光环/尘土）
│   ├── camera         Camera2D（跟随+震屏）
│   └── hud.gd         CanvasLayer：菜单/HUD/升级/暂停/结算（代码构建 UI）
│
├── kp.gd             class_name KP 全局工具：配色/字体/贴图缓存/居中绘制
└── sfx.gd            autoload：运行时合成音效
```

**核心设计决策：一个场景，万物代码造。** 本项目只有 1 个 .tscn 文件，
所有节点都在 `_ready()` 里用代码创建。这不是偷懒，是三个权衡：

1. 割草游戏实体大量动态生灭，场景文件里摆节点没有意义
2. 代码即文档——每个节点谁创建、挂在哪、为什么存在，grep 一下就知道
3. 避免手写 .tscn 的 uid/ext_resource 脆弱性

代价：**不能在 Godot 编辑器里拖节点调 UI**。所以所有可调数值集中在
`game_config.gd`（见 §6），改参数改那一个文件即可。

## 2. 用到的 Godot 核心概念（学习者重点）

| 概念 | 在本项目中的用法 |
|---|---|
| `Node2D._draw()` / `queue_redraw()` | 玩家/敌人/子弹全是 `_draw()` 画的（贴图或字形），逻辑变化时手动请求重绘 |
| `draw_set_transform(pos, rot, scale)` | 动画系统核心：颠步/挤压拉伸/翻转/倾斜全靠它，一帧一次矩阵 |
| `_process` vs `_physics_process` | 视觉/计时用 `_process`；移动/碰撞/导演用 `_physics_process`（固定步长，判定稳定） |
| `CanvasLayer` | UI 与世界分层：HUD=10，火焰层=8，CRT=100；layer 值大者在上 |
| `process_mode = PROCESS_MODE_ALWAYS` | 暂停树时 UI 仍可交互的关键（升级面板/暂停菜单都靠它） |
| `get_tree().paused` | 升级选卡、暂停、死亡结算时冻结世界 |
| autoload | `sfx.gd` 注册为全局单例，任何脚本直接 `Sfx.play("shoot")` |
| `class_name` | `kp.gd` 声明 `class_name KP`，全项目免 preload 直接用 `KP.GREEN` |
| `SystemFont` | 运行时按名字解析系统字体（Cascadia Mono/雅黑），不打包字体文件 |
| `Image/ImageTexture` | DOOM 火焰逐像素写 `PackedByteArray` → `img.set_data()` → `tex.update()` |
| `ResourceLoader.exists()` | 贴图可选加载：存在就用贴图，不存在退回字形渲染（资产管线安全性） |
| `Tween` | 横幅淡入淡出、受伤红屏、菜单按钮呼吸、吉祥物浮动 |

## 3. 逐文件讲解

### 3.1 main.gd（约 370 行，大脑）

- **状态机** `enum State { TITLE, PLAYING, PAUSED, LEVELUP, GAMEOVER }`
  每个状态的进入函数负责切换 UI 可见性和 `paused`：
  `_start_game` / `_pause_game` / `_resume_game` / `game_over` / `_to_title`
- **`_ready()`**：创建四个实体容器（z_index 1~5 决定绘制层级）、相机、HUD，
  连接 HUD 的 7 个信号（菜单开始/暂停/继续/升级选择……）
- **`_director(delta)`** 刷怪导演：
  - 常规刷怪间隔 `max(0.24, 1.15 − t×0.0021)`
  - 30s 波次爆发 `5 + 2×波次`；75s 精英
  - 类型权重按 `elapsed` 分段（见 GDD §6）
  - 血量成长 `(1 + t/80) × (1 + wave×0.05)`
- **`_collisions()`** 中央碰撞：子弹×敌人、敌人×玩家、经验包拾取——
  **不用物理引擎**，全部距离平方判定。为什么？200 敌人 + 50 子弹的量级下
  距离判定（内层 break + pierce 递减）比 Area2D 信号风暴更快更可控
- **`kill_enemy(e)`**：杀怪会计（kills/日志/掉落/特效/震屏）都在这一个函数
- **`_draw()`**：北京地图背景（arena_bg 铺满 arena）+ 网格 + 金框 + 装饰字形

### 3.2 player.gd（约 120 行）

- `_physics_process`：读物理按键（`Input.is_physical_key_pressed`，免配 InputMap）
  → 归一化移动 → 钳制地图 → 走 `_try_fire()`
- `_try_fire()`：560² 内最近敌人 → `multishot` 发扇形弹（每发 ±0.15rad）→
  枪口光环 + 音效
- **动画状态**：`walk_phase`（步频相位）/`move_amt`（移动量插值，保证起停平滑）/
  `facing`（朝向）/`lean`（倾斜角）——全部在 `_draw` 里经
  `draw_set_transform` 合成。受击有 0.7s 无敌帧 + 闪烁
- 血量归零 → `main.game_over()`

### 3.3 enemy.gd（约 110 行）

- `TYPES` 字典 = 四类敌人的全部数值（含 `hop` 跳高），加新敌人就在这里加一行
- `setup(main, type, hp_mult)`：出生时按导演给的时间系数缩放 HP
- `_physics_process`：追踪 + 正弦游走 + **群体分离**（每敌人分 3 帧轮询、
  最多采样 8 个邻居，O(n²/3) 均摊）+ 朝向玩家翻转
- `_draw`：蹦跳变换（`hopv = |sin(phase)|` → 高度与压扁）+ 血条 + 受击白闪

### 3.4 bullet.gd / gem.gd / fx.gd

- **bullet**：`setup(main, pos, vel, dmg, pierce)` 纯数据注入；越界/超时自毁；
  脉动缩放 + 按速度方向旋转贴图
- **gem**：进入磁吸半径后被"拉走"（`move_toward` 加速），贴身结算 `add_xp`
- **fx**：三种特效共用一个脚本——`text`（PID 漂浮字）/`shard`（字符碎片+尘土）/
  `ring`（扩散环），age/ttl 驱动透明度

### 3.5 hud.gd（约 430 行，UI 全家桶）

- 7 个信号是 UI → 游戏逻辑的**唯一通道**（菜单开始/退出应用/暂停/继续/
  回主菜单/重开/升级选择）；main.gd 通过 `show_xxx/hide_xxx/set_xxx` 反向控制
- `_build_menu/_build_help/_build_pause/_build_gameover/_build_levelup`：
  全部代码构建，控件工厂是 `_mk_label`（雅黑+黑描边）和 `_menu_button`
  （焦点金框样式，`call_deferred("grab_focus")` 实现菜单键盘导航）
- **升级面板**：`show_levelup(三选一, 等级)` 暂停世界；`_input` 拦数字键 1/2/3
- HUD 文本全是 ASCII 拼的：`HP [▓▓▓░░░] 74/100`——零贴图、缩放不糊

### 3.6 kp.gd / sfx.gd / doom_fire.gd / shaders/crt.gdshader

- **kp.gd**：`font()`（Cascadia Mono 等宽）、`ui_font()`（微软雅黑）、
  `tex(name)`（贴图缓存，`res://assets/sprites/<name>.png` 不存在返回 null →
  调用方退回字形渲染）、`figlet()`（ASCII 大字）、`draw_center()`
- **sfx.gd**（autoload）：`_tone(f0,f1,dur,vol)` 方波扫频 + `_noise()` 白噪声
  → 手拼 16bit WAV 字节流 → `AudioStreamWAV`；10 个 player 轮播 + 按音色节流
- **doom_fire.gd**：经典 1993 DOOM 火焰——底行点燃 36 号色，每帧向上传播
  `dst = src − W − rand(0..2)`，色值递减；132×74 元胞写 `PackedByteArray` 一次
  `set_data`（v2.1 动漫化后已从 UI 流程移除，脚本保留可复用）
- **crt.gdshader**：扫描线+暗角 shader（v2.1 已从主场景移除，同样保留）

### 3.7 v2.2 新增模块速览

- **多武器**：状态全部挂在 `player.gd`（`upgrade_levels` 等级表 / `orbit_*` 回旋 /
  `thunder_*` 引雷），伤害结算集中在 `main._collisions`（回旋按敌冷却 0.45s），
  引雷在 `main.cast_thunder()`（随机索敌 → 最近邻链式 → fx_line 折线闪电）
- **升级池**：`main.UPGRADES` 12 项带 `kind/max`；`_roll_upgrades` 做上限过滤、
  武器槽位检查、稀有度抽卡（×2/×3 效果次数）；`_apply_upgrade(id)` 单级应用，
  卡牌稀有度只放大次数不改公式
- **掉落物**：`gem.gd` 重构为四种 kind（xp/heal/magnet/chest），拾取统一进
  `main.collect_pickup` 分发；磁铁 = 全体 gem `force_magnet()`
- **可破坏物**：`breakable.gd`（灯笼/机柜两种绘制），子弹命中走
  `_collisions` 独立循环，破坏奖励见 `break_breakable`
- **事件**：`_director` 尾部 `_spawn_events()` —— 包围圈（按 SWARM_TIMES 时间戳）
  与 5 分钟 Boss（elite 放大版 + `is_boss` 标记）；精英/Boss 引用存
  `elite_ref/boss_ref`，受击经 `enemy.hit → main.update_boss_bar` 刷新顶部血条
- **Build 面板**：`main.build_summary()` 把 `upgrade_levels` 翻译成人话，
  喂给暂停菜单与死亡结算

## 4. 一帧的生命周期（PLAYING 状态）


```
物理帧开始
 ├─ main._physics_process
 │   ├─ _director: elapsed 累加 → 按间隔生成敌人（enemies_node.add_child）
 │   ├─ _collisions: 子弹×敌人（命中→enemy.hit→hp≤0→main.kill_enemy）
 │   │                敌人×玩家（无敌帧检查→player.take_damage）
 │   └─ wave 秒变化 → hud.set_wave
 ├─ player._physics_process: 输入→移动→动画相位→自动开火
 ├─ 每个敌人: 追踪+分离+蹦跳相位 → queue_redraw
 ├─ 每个子弹/宝石/fx: 位移/磁吸/老化
渲染帧
 └─ 依 z_index 绘制: 地图(主) → 宝石1 → 子弹2 → 敌人3 → 玩家4 → 特效5 → HUD(CanvasLayer)
```

## 5. 资产管线（AI 美术是怎么进游戏的）

```
gen_anime_assets.js ──► assets_gen_anime/*.jpg   （nano-banana-pro 生成，黑/白底）
gen_strips.js       ──► sprite_runs/player/raw/  （sprite-gen 行条：品红色度键）
        │
        ▼
kernel-panic/tools/process_textures.gd（无头跑）
        ├─ 角色贴图: 缩放256 → 背景明暗自适应 → 洪泛抠底(保留内部暗部) → 发光边缘羽化
        └─ 背景大图: LANCZOS 缩放
        ▼
kernel-panic/assets/sprites/*.png ──► godot --import ──► KP.tex("player") 运行时加载
```

游戏侧的**优雅降级**是管线安全的钥匙：`KP.tex()` 返回 null 时，
玩家/敌人自动退回 ASCII 字形渲染——任何一张图生成失败游戏都不会坏。

sprite-gen 逐帧行走图集接入方式：`raw/<state>.png` → `extract` 抠底切帧 →
`compose-atlas` 出图集+manifest → 玩家 `_draw` 按 `walk_phase` 换算帧索引
`draw_texture_rect_region` 取区域，与现有挤压拉伸/倾斜动效**叠加**而非替换。

## 6. 修改指南（常见需求速查）

**调难度**：`main.gd` `_director` 的 `1.15 − t×0.0021`（刷怪曲线）、
`elapsed/80`（血量成长）、`wave_cd = 30.0`（波次节奏）

**加一种敌人**：`enemy.gd` 的 `TYPES` 加一行（glyph/hp/speed/dmg/radius/size/xp/hop）
→ `main.gd` `_pick_type` 权重表加分支 → 完成（动画/分离/碰撞自动生效）

**加一种升级补丁**：`main.gd` `UPGRADES` 数组加一项 `{id,name,desc}`
→ `_on_upgrade_chosen` 的 `match` 加应用逻辑 → 完成

**换角色/敌人立绘**：把同名 PNG 放进 `assets/sprites/` → `godot --import` → 完
（256px 带透明通道即可，大小不用精确一致）

**调动画幅度**：`player.gd` `sin(walk_phase)×3.5`（颠步高度）、`×0.055`（挤压强度）、
`-dir.x×0.09`（倾斜角）；`enemy.gd` `hop_height`（TYPES 里）

**改字体/配色**：`kp.gd` 顶部色值常量 + `font()/ui_font()`

**重出某张 AI 贴图**：`node gen_anime_assets.js <关键词>` → 重跑 `process_textures.gd` → `--import`

## 7. 已知取舍（学习价值所在）

1. **中央碰撞 vs 信号驱动**：选了前者，因为实体数量大且规则简单；
   若做复杂弹幕/AABB 精细碰撞，再换 Area2D 分层
2. **代码 UI vs .tscn UI**：见 §1；想要编辑器可视化，可把 HUD 逐步搬进场景，
   信号连接方式不变
3. **空间哈希碰撞**：敌人分离/子弹命中/玩家受击全部走 `spatial_grid`（100px 网格，
   每物理帧初重建），O(n²) → 邻域查询；实体破千依然稳
4. **物理插值**：`project.godot` 开启 `common/physics_interpolation`，
   所有生成点调用 `reset_physics_interpolation()` 防出生拉丝——
   高刷屏（144Hz+）下移动依然顺滑（渲染帧率不再被物理 60Hz 卡住）
5. **`_draw` 手绘 vs Sprite2D 节点**：选 `_draw` 是为了动画矩阵和字形兜底
   统一在一个函数里；做复杂角色骨骼动画才需要 AnimatedSprite2D/骨架
6. **贴图缓存**：实体把 `KP.tex()` 结果缓存为成员变量（生成时取一次），
   `_draw` 热路径零字典查询
7. **英文 prompt 出图**：图像模型对英文 spec 遵从度更高；游戏内文案保持中文
