# A / B 接口约定草案

这是 B 侧预留的接入方式，供双方协商，不代表 A 已经确认。当前主场景的 `RunAdapter` 节点使用 `demo_run_adapter.gd`，A 可通过自己的适配脚本实现以下方法和信号；UI 不需要依赖 A 的内部物理结构。

## 坐标与绘制

- 数据全部使用数学坐标：x 向右，y 向上。像素坐标转换只在 `GraphCanvas` 内进行。
- `bounds` 为数学坐标 `Rect2(xmin, ymin, width, height)`，不是随镜头变化的屏幕范围。
- 曲线点是世界坐标。`curve_changed` 的每一项是独立的 `PackedVector2Array`；不连续点处必须拆段，画布不会跨段连线。
- `ball_moved` 提供的是球心坐标。当前原型的球心沿曲线；A 若实现球滚在轨道上，应提供偏移后的球心，B 直接绘制。
- 起终点、检查点、障碍和球半径都使用同一套世界单位。画布缩放不应改变判定。
- 当前原型用小球半径扩展障碍做连续线段检测，检查点和终点的判定距离包含球半径。正式规则由双方确定。

## B 调用的方法

```gdscript
configure(level: Dictionary, template_id: String, parameters: Dictionary) -> void
update_formula(template_id: String, parameters: Dictionary) -> void
start() -> void
pause_or_resume() -> void
retry() -> void
```

`configure` 切换关卡并回到编辑状态；`update_formula` 在编辑时刷新曲线；`retry` 清空运行状态、时间和检查点，从起点重新开始，保留公式参数。重置由 B 恢复初始模板/参数后重新 `configure`。

当前 UI 读取适配器的 `state` 和 `last_result`。状态值为 `editing`、`running`、`paused`、`success`、`failed`。运行/暂停时应拒绝公式修改。

## A 发出的信号

```gdscript
signal curve_changed(segments: Array)
signal ball_moved(position: Vector2, elapsed: float)
signal checkpoints_changed(reached: Array)
signal state_changed(state: String)
signal run_finished(result: Dictionary)
```

`reached` 是与关卡检查点列表等长的布尔数组。当前四关要求全部通过，不要求顺序；检查点不是复活点。

`result` 字段：

```gdscript
{
    "success": true,
    "reason": "供玩家阅读的成功或失败原因",
    "elapsed": 3.2,
    "reached": 2,
    "total": 2,
    "formula_count": 1,
    "mode": "demo" # 接入正式运动后一起调整界面标记与存档命名
}
```

一次运行只应结算一次。切关、重试或改公式后，前一次延迟结算应作废。B 负责显示、弹窗、选关和演示进度；A 提供正式运动和胜负判定。当前各模板参数范围在 `formula_catalog.gd`，与 A 接入时应统一由同一个来源提供。

## 当前关卡数据

JSON 中坐标为 `[x,y]`，范围与障碍为 `[x,y,width,height]`；`level_repository.gd` 读取后转换为 `Vector2` / `Rect2`。每关包含：ID、标题、目标、提示、允许模板、初始参数、边界、起终点、检查点、容差、球半径、障碍和时间限制。

四关的开发验收解如下，不在游戏界面直接显示：

| 关卡 | 模板 | 参考参数 |
|---|---|---|
| 第一条轨道 | linear | a=-0.4, b=2.2 |
| 绕过那片红色 | quadratic | a=0.07, h=1, k=-1 |
| 跟着波浪走 | sine | a=1.5, b=0.65, h=0, k=1 |
| 选择你的解法 | sine | a=2, b=0.5, h=1, k=1 |

以上只验证几何路径和匀速演示。接入重力后，尤其第三、四关的上坡部分，需要按能量、初速度、摩擦与反弹规则重新设计和验收。

## 接入时共同确定

1. 球是否始终吸附，什么时候允许脱轨和自由落体。
2. 起点连接容差、球心偏移和球半径。
3. 哪些障碍导致失败，哪些物体会反弹。
4. 是否允许多条轨道、怎样限定定义域和处理轨道衔接。
5. COST / 星级的计算规则，以及正式进度的存档方式。

当前原型只开放一条公式；结算显示用时、检查点和公式数。COST、星级、传送门、轨道拼接与排行榜未实现。
