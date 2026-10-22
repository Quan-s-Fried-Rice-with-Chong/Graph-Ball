# 数维弹球：合并版接口说明

更新：2026-10-22。保留本文件名方便原 A/B 协作引用；内容已替换为最终接口。

## 1. 启动与边界

启动场景为 `scenes/main.tscn`，根节点是 UI Control，脚本为 `scripts/ui/main.gd`，不是 LevelController。UI 通过子节点 `$RunAdapter`（`scripts/adapters/physics_run_adapter.gd`）调用核心。

适配器实例化隐藏的 `scenes/core_world.tscn`，其根才是 LevelController。界面使用共享世界线段绘图，不读取核心轨道节点、不自行模拟匀速运动。界面负责选关解锁、弹层、工具栏、参数输入和视图；核心负责校验、真实物理、触发、计时和存档。

## 2. UI → 适配器

| 方法 | 返回 | 行为 |
| --- | --- | --- |
| configure_formulas(data: Dictionary, sources: Array) | void | 传入仓库已转换的关卡与 UI 公式，配置核心，清空旧结果 |
| update_formulas(sources: Array) | bool | 编辑时整体替换；成功重建曲线，失败发校验信号；运行/暂停拒绝 |
| start() | bool | 仅 editing 可启动；执行核心校验 |
| retry() | void | 保留公式和定义域，回编辑态，清空球、计时与检查点 |
| pause_or_resume() | void | 运行/暂停互换；其他状态不启动 |

重置为初始公式由 UI 重新加载关卡，并调用 configure_formulas。UI 切关前检查解锁，不依赖物理层控制菜单权限。运行前 commit_input、适配全图；running 和 paused 均锁定参数与相机。

## 3. 适配器 → UI

| 信号 | 参数含义 |
| --- | --- |
| curve_changed(segments: Array) | 共享裁剪世界线段，每项含 a、b、材质与公式信息 |
| ball_moved(point: Vector2, elapsed_time: float) | 数学坐标中的球心与已用秒数 |
| checkpoints_changed(reached: Array) | 按关卡数组索引对应的布尔状态；不表示触发顺序 |
| state_changed(state: String) | editing / running / paused / success / failed |
| run_finished(result: Dictionary) | 本局结算，见下表 |
| validation_failed(message: String) | 可展示的错误文本，可能含换行 |

适配器公开只读用途的状态：level、formulas、state、elapsed、reached、ball_position、last_result。调用方不要直接写入。run_finished 延迟到物理查询结束发送，运行代次过期则丢弃，避免切关后出现旧弹层。

| result 字段 | 类型 / 含义 |
| --- | --- |
| success | bool，本局成功与否 |
| reason | String，结果原因 |
| elapsed | float，本局秒数 |
| reached / total | int，完成数 / 总数 |
| formula_count | int，本局公式数量 |
| saved | bool，核心最近一次保存状态；成功局用于“未保存”提示 |
| record | Dictionary，该关已保存的历史记录；可能为空 |

record 中 best_time 与 best_formula_count 独立取最优，不保证来自同一局。失败局不据 saved 字段宣称写入了失败记录。

## 4. 数据格式与坐标

正式关卡从 `LevelRepository.load_levels()` 读取 `data/levels.json`，验证后转换 bounds 为 Rect2、点/定义域为 Vector2。不要把未经仓库处理的原始 JSON 直接交给适配器。

UI 公式：

```gdscript
{
    "template": "quadratic",
    "parameters": {"a": 0.04, "h": 4.0, "k": -1.0},
    "domain": Vector2(-8.5, 10.0)
}
```

模板为 linear、quadratic、sine，参数范围由 `scripts/core/formula_catalog.gd` 的 TEMPLATES 集中提供。每关 1～3 条，按关卡白名单限制类型；域在 bounds 横向范围内，宽度至少 0.05。

核心公式经 Catalog.to_core_list 转换：

```gdscript
{
    "id": "formula_0",
    "type": "quadratic",
    "parameters": {"a": 0.04, "b": -0.32, "c": -0.36},
    "x_range": Vector2(-8.5, 10.0),
    "ui_source": { # 原始 UI 公式完整保留
        "template": "quadratic",
        "parameters": {"a": 0.04, "h": 4.0, "k": -1.0},
        "domain": Vector2(-8.5, 10.0)
    }
}
```

linear 在核心映射为 line；二次转换 b = −2ah、c = ah² + k。保留源参数，a = 0 时不反算 h。数学坐标 x 向右、y 向上；核心以 48px/单位反转 y；画布独立投影同一组线段，缩放不改变物理。

多条轨道均存在，不按公式顺序覆盖。球半径 0.28、轨道厚度 0.15 世界单位；显示随相机缩放，光晕不参加碰撞。

## 5. 核心内部 / 旧接口兼容

LevelController 保留 configure_level、set_formulas、start_run、reset_run、toggle_pause 等内部调用。旧参数助手 update_formula_parameter 修改核心 a/b/c 或正弦参数，会清空 ui_source，避免遗留源参数不一致；update_formula_x_range 同步已有 ui_source.domain。新增函数拒绝未知模块。正式 UI 应整体提交源公式，不混用旧系数助手与顶点参数编辑。

核心状态为 EDITING、RUNNING、PAUSED、SUCCESS、FAILED。旧 simulation_updated(..., checkpoint_index) 的 checkpoint_index 现表示已完成数，不再表示下一检查点序号。UI 采用适配器布尔数组。

## 6. 存档与迭代

SaveManager 保存 `user://progress.json`，Windows 默认 `%APPDATA%/ShuweiPinball/progress.json`。version = 2、content_id = shuwei-pinball，completed_levels 以稳定关卡 ID 为键，记录 completed、best_time、best_formula_count。

只迁移同产品 v1，兼容旧字段 min_formulas；不读演示存档，不覆盖更高版本。临时文件写入后重命名；写入失败通过结果反馈，本次会话解锁保留。

增加关卡优先改 JSON，保持旧 ID 稳定。增加函数须同时扩展注册信息、核心模型/求值/校验/材质及测试。完整规则见素材包 TECHNICAL-DESIGN-v1.0.md；接口变更同步 CHANGELOG。

## 7. 验证

核心 633 项检查通过，完整场景 54 项检查通过、四个参考解实际通关。脚本位于 tests，日志位于 artifacts。参考解来自 JSON reference_formulas，仅供开发测试。
