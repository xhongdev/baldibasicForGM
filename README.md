# baldibasicForGM

Baldi's Basics Classic 1.4.3 的 GameMaker LTS 2026 移植项目。当前以 Unity 反编译工程 `BALDI` 为场景和玩法依据；早期 Godot 原型仍保留在历史工具中。

在 GameMaker 中打开 `baldibasicForGM.yyp` 后运行。已导入的资源包含在仓库内，运行游戏不需要安装 Unity 或访问原工程。

## 当前地图修复

- 墙、半墙及门直接使用 Unity 子物体的完整父级变换与网格顶点，保留偏在墙一侧的门洞。
- 23 扇真实门：9 扇教室门、6 扇教职工门、8 扇双开门。出生区教室门、办公室门、食堂入口等已按原场景对齐。
- 绘制和碰撞使用同一份几何数据；寻路经过实际门洞中心。原场景的高墙和食堂高天花板保留真实高度。
- 导入原版墙面材质、海报、暗区颜色和纹理重复比例。保留墙两面的朝向，避免重叠贴图闪烁。
- 682 个地板区域连通，7 个笔记本使用原场景坐标。

用浏览器打开 [地图位置对照图](tools/unity_map_comparison.svg)：红色虚线为修复前的门，蓝色／黄色为原版门的位置，绿色圆点为笔记本。悬停在门上可查看源物体名称与坐标。

## 贴图、界面与玩法修复

- Unity Plane 与 Quad 分别转换纹理坐标，校规和黑板文字按正确方向显示。
- 3D 精灵使用实际纹理页 UV 和裁边数据。物品图标、七种笔记本封面、喷雾和出口牌由原场景资源引用导入。
- 物品栏、答题机、结果标记和数字按钮按 Unity RectTransform 布局；绘制与点击区域共用数据。3D 绘制后恢复原矩阵，避免污染界面。
- BSODA 在 Baldi 移动前处理接触，并检查快速追逐穿过喷雾的情况。持续接触时使用喷雾速度推离，停止追逐移动。
- 修正第一题答错后的拍尺间隔；答题语音按队列播放，提交答案和退出会取消旧语音。门声随距离衰减，拾取与答错不再播放无关的提示音。

## 操作

- WASD／方向键：移动；Shift：跑步。
- 鼠标：转向；左键：打开瞄准的门、拾取道具或笔记本。
- 1／2／3 或滚轮：选择物品；右键或 Q：使用。
- 空格：向后看；跳绳时为空格／左键／E 起跳，需要连续成功 5 次。
- Esc：暂停；暂停时 Q 返回标题；F11：全屏。
- F1：打开／关闭作弊测试菜单；菜单内 Esc 关闭菜单。
- 收集 7 个笔记本并完成答题后，依次寻找 4 个出口。

十种道具及售货机、电话、磁带机已接入。NPC 行为和完整原版流程仍需进一步对齐，详见 [移植审查记录](PORTING.md)。

## 作弊测试菜单（F1）

进入学校后按 **F1**。菜单打开时暂停游戏和音频，释放鼠标；按 F1 或 Esc 关闭。答题时和失败画面也能打开。菜单会保留原来的暂停状态，所有开关在重新开始学校时恢复关闭。

| 页面 | 功能 |
| --- | --- |
| Player | 无敌、穿墙、无限体力、物品不消耗、免违规处罚、暂停 Baldi／其他 NPC 的 AI、忽略门锁、三倍移动速度；恢复体力、解除留堂／跳绳、复活回出生点、重开学校 |
| Items | 选择物品栏位置后，直接放入任意一种道具；支持 1／2／3 选栏及清空物品栏 |
| Teleport | 出生点、校长办公室、7 个笔记本、售货机／电话／磁带机、5 个出口标志和全部 23 扇门；列表可翻页或滚轮浏览 |
| World / Flow | 启动追逐、把 Baldi 放到前方、调整怒气；设置 0／1／2／7 个笔记本、开启出口阶段、开关门、恢复拾取物、打开／完成答题机、接受当前答案、启动跳绳 |

**快速测试 BSODA：**面朝一段空走廊，打开 F1 → `World / Flow` → `Baldi + 3 BSODA test setup`。它会把 Baldi 放到前方、暂停其他 NPC 的 AI，并放入三罐汽水。关闭菜单后右键使用。测试死亡判定时保持 `God mode` 关闭。

传送会选取可站立的位置并面向目标。穿墙关闭时，如果玩家位于墙内，会移回附近的可站立地板。`Pause ... AI` 暂停角色的自主行为，BSODA 等外力仍生效，方便观察推挤。

## 重新导入 Unity 场景

```powershell
python tools/import_unity_map.py --write
python tools/import_unity_gameplay.py
python tools/import_unity_presentation.py
```

默认原工程为 `D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI`。可通过 `--unity "其他路径\BALDI"` 指定。

地图导入器默认只分析，不写入；`--write` 会在检查全部门洞和连通性通过后更新地图、材质资源与项目包含文件。`--check` 可与原场景再次比较，`--verbose` 输出逐门坐标。

`scripts/` 与 `objects/` 是当前运行代码。`tools/gml/` 是早期模板，旧的 `build_from_godot.py`、`apply_*doors.py`、`fix_*doors.py`、`rebuild_*from_unity.py` 不适用于新版地图格式。Godot 生成器需要显式传入 `--legacy-rebuild` 才会覆盖工程。

## 验证

```powershell
python tools/test_unity_map.py
python tools/test_presentation.py
python tools/import_unity_map.py --check
python tools/import_unity_gameplay.py --check
python tools/import_unity_presentation.py --check
python tools/run_gamemaker_checks.py
```

最后一条会调用本机 GameMaker VM 编译器并启动真实 Runner 执行 GML 回归检查，之后自动退出。需要可用的 GameMaker runtime 和本机许可证；可用 `--runtime`、`--license` 指定路径。日志位于 `.gmcache/build-gms2-windows-VM/`。普通运行不启用自检。

当前验证：517 项真实 Runner 检查通过；地图与显示资源此前的 10 个 Python 回归测试通过。Runner 检查包含 3D 精灵与 2D 参考图的像素比较、物品栏完整绘制、13 个答题按钮的绘制和点击、出生点出口牌、30/60/144 FPS 的 BSODA 推离、语音中断和拍尺频率，以及作弊菜单的暂停恢复、道具、无敌、穿墙退出、流程切换和安全传送。

运行检查后还会生成 `.gmcache/build-gms2-windows-VM/bb_school_window.png`、`bb_yctp_window.png` 和独立的 `bb_hud_check.png`、`bb_yctp_check.png`，供画面复核。
作弊菜单预览为 `.gmcache/build-gms2-windows-VM/bb_cheat_menu.png`。
