# 第三章终宴大厅地图

地图已在 Blender 建模，并安装到 A:/Monste/MonsterDone_Godot。项目中的 scenes/final_banquet_hall.tscn 已更新，原地图和脚本已备份到 backups/chapter3_design_20261103_144142。

双击项目根目录 Preview_FinalBanquet.cmd，或本文件夹中的 打开第三章.cmd，可以进入地图。

WASD 移动，鼠标转动视角，F 交互，M 查看平面图，F6 切换建筑总览与角色视角，Esc 打开菜单。总览模式会暂时隐藏大厅拱顶，方便查看布局。

已制作：旧送餐入口、候宴前厅、宴前准备区、左侧废稿厨房、右侧供给回廊、主宴厅、后方 BOSS 战场与核心区。建筑包含石柱、拱门、拱顶、红帷幕、彩窗；家具包含长宴桌、座椅、餐罩、餐具、烛台、工作台、厨房货架、炉具、管道和运输车。

原有行走、BOSS 模型、黄金食谱、准备检查、阀门、设施补救与结局方案演示均已接回。六条主要通行路线、F6 隐藏拱顶、食谱和两组阀门交互已验证。

当前为可行走、可交互的地图建模版本；正式 BOSS 战和最终剧情演出仍未完成。美术以分色材质和建模细节为主，尚未制作完整手绘纹理与最终烘焙灯光。

## 文件

- chapter3_final_banquet.blend：建筑、陈设与渲染灯光的 Blender 源文件。游戏内 BOSS、可交互食谱和核心晶体由 Godot 场景补入。
- chapter3_final_banquet.glb：游戏地图模型。
- godot_overview.png：游戏中隐藏拱顶的整体截图。
- godot_banquet.png：宴会大厅游戏截图。
- godot_kitchen.png、godot_supply.png、godot_boss_arena.png：侧厅及 BOSS 区截图。
- chapter3_overview.png：Blender 建筑渲染。

模型约 33.5 万三角面，26 个网格分组，97 个基础碰撞体。地图约宽 60 米、纵深 86 米。Blender 源文件另存于项目 tools/chapter3_authoring，带建模脚本和所用开源道具。

## 开源道具来源

锅、碗、碎盘、油瓶来自 Kenney Food Kit；木桶和木箱来自 Kenney Pirate Kit。通过 GitHub 仓库 https://github.com/Hidencod/tge-assets 下载，作者为 Kenney，许可为 CC0 1.0。原始模型和许可证已保存到项目 tools/chapter3_authoring/kenney。主体建筑、长桌、座椅、餐罩、帷幕、管道等为本次制作。

- https://kenney.nl/assets/food-kit
- https://kenney.nl/assets/pirate-kit
- https://github.com/Hidencod/tge-assets/blob/main/LICENSE
