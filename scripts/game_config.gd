class_name GameConfig
## ============================================================
##  游戏调参中心 —— 改数值只需要动这个文件
##  对应设计说明见 docs/GDD.md，源码讲解见 docs/CODE_GUIDE.md
## ============================================================

## ---- 地图 ----
const ARENA_W := 1500.0            ## 地图半宽（总宽 = ×2 = 3000）
const ARENA_H := 950.0             ## 地图半高
const MAX_ENEMIES := 220           ## 同屏敌人上限（性能保护）
const GRID_CELL := 100.0           ## 空间哈希网格边长（碰撞/分离加速）

## ---- 玩家基础属性 ----
const PLAYER_MAX_HP := 100.0       ## 初始最大生命
const PLAYER_SPEED := 270.0        ## 移动速度 px/s
const FIRE_INTERVAL := 0.38        ## 射击间隔秒
const FIRE_RANGE := 560.0          ## 自动索敌范围
const BULLET_SPEED := 540.0        ## 子弹速度
const BULLET_DAMAGE := 10.0        ## 子弹伤害
const BULLET_TTL := 1.2            ## 子弹存活时间秒
const MAGNET_RADIUS := 95.0        ## 经验磁吸半径
const IFRAMES := 0.7               ## 受击无敌帧秒

## ---- 升级上限（防数值爆炸）----
const FIRE_INTERVAL_MIN := 0.07
const MOVE_SPEED_MAX := 520.0
const MULTISHOT_MAX := 6
const PIERCE_MAX := 5
const MAGNET_MAX := 400.0
const BULLET_SPEED_MAX := 1100.0

## ---- 刷怪导演 ----
const SPAWN_INTERVAL_BASE := 1.15  ## 开局刷怪间隔秒
const SPAWN_INTERVAL_DECAY := 0.0021  ## 每存活 1 秒间隔减少量
const SPAWN_INTERVAL_MIN := 0.24   ## 刷怪间隔下限
const RUNNER_UNLOCK_AT := 40.0     ## 疾行者出现时间
const TANK_UNLOCK_AT := 140.0      ## 石狮出现时间
const WAVE_PERIOD := 30.0          ## 波次间隔秒
const WAVE_BURST_BASE := 5         ## 波次爆发基础数量
const WAVE_BURST_PER_WAVE := 2     ## 每波次额外增加数量
const ELITE_PERIOD := 75.0         ## 精英出现间隔秒
const RUNNER_WEIGHT_MID := 0.35    ## 中期疾行者权重
const RUNNER_WEIGHT_LATE := 0.30   ## 后期疾行者权重
const TANK_WEIGHT_LATE := 0.20     ## 后期石狮权重

## ---- 难度成长 ----
const HP_GROWTH_TIME_DIV := 80.0   ## 血量时间成长：HP ×(1 + 秒/此值)
const HP_GROWTH_WAVE := 0.05       ## 血量波次成长：HP ×(1 + 波次×此值)

## ---- 经验与等级 ----
const XP_FIRST_LEVEL := 6          ## 升到 2 级所需经验
const XP_FLAT := 4                 ## 升级公式常数（xp_next = XP_FLAT + level×XP_PER_LEVEL）
const XP_PER_LEVEL := 2            ## 每级增量

## ---- 反馈强度 ----
const SHAKE_ON_HIT := 5.0          ## 玩家受击震屏
const SHAKE_ON_HEAVY_KILL := 6.0   ## 重甲/精英击杀震屏
const CAMERA_SMOOTHING := 6.0      ## 相机跟随插值速度

## ---- 武器系统 ----
const WEAPON_SLOTS := 3            ## 武器槽上限
const ORBIT_RADIUS := 110.0        ## 回旋扳手轨道半径
const ORBIT_SPEED := 3.2           ## 回旋角速度 rad/s
const ORBIT_DMG_BASE := 8.0        ## 回旋伤害基础
const ORBIT_HIT_CD := 0.45         ## 同一敌人回旋命中冷却秒
const THUNDER_INTERVAL := 2.2      ## 引雷基础间隔秒
const THUNDER_DMG := 22.0          ## 引雷基础伤害
const THUNDER_RANGE := 700.0       ## 引雷索敌范围
const THUNDER_CHAIN := 2           ## 链式跳跃次数
const THUNDER_CHAIN_RANGE := 320.0 ## 链式跳跃距离

## ---- 掉落 ----
const HEAL_DROP_CHANCE := 0.045    ## 恢复包掉率
const MAGNET_DROP_CHANCE := 0.012  ## 磁铁掉率
const HEAL_AMOUNT := 30.0          ## 恢复包回血量
const BREAKABLE_COUNT := 14        ## 地图可破坏物数量
const ELITE_CHEST := true          ## 精英掉宝箱（免费升级）

## ---- 事件 ----
const SWARM_TIMES := [150.0, 360.0]  ## 包围圈事件触发时间点
const SWARM_COUNT := 24              ## 包围圈敌人数
const SWARM_RADIUS := 620.0          ## 包围圈半径
const BOSS_AT := 300.0               ## Boss 出现时间（5 分钟）
const BOSS_HP_MULT := 5.0            ## Boss 血量倍率（叠在时间成长上）
const BOSS_SCALE := 1.6              ## Boss 体型倍率
const BOSS_SPEED_MULT := 0.85        ## Boss 速度倍率
const BOSS_DROP_CHEST := 2           ## Boss 掉宝箱数

## ---- 稀有度 ----
const RARE_CHANCE := 0.18            ## 稀有卡概率（效果×2）
const EPIC_CHANCE := 0.07            ## 史诗卡概率（效果×3）
const LOW_HP_THRESHOLD := 0.3        ## 低血量警告阈值
