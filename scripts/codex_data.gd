extends RefCounted
## 旅行手记·居民名册的数据层：按章节组织敌人介绍，Boss 排在最后。
## 只放数据，不含玩法逻辑；改文案/补章节改这里即可。

const ICON_DIR := "res://assets/ui/codex/"

## 章节：id -> 显示名
const CHAPTERS := [
    {"id": "snow", "name": "雪原边境"},
    {"id": "second", "name": "火山洞窟"},
    {"id": "third", "name": "终宴大厅"},
]

## 敌人：id / 名字 / 分类 / 肖像 / 描述 / 攻击方式
const ENEMIES := {
    "snow": [
        {
            "id": "slime",
            "name": "焦饭碗史莱姆",
            "icon": ICON_DIR + "slime_焦饭碗史莱姆.png",
            "kind": "普通 · 贴身近战",
            "desc": "一只坐在青花瓷碗里的米饭团子。顶上的焦壳裂开橙红的缝，两根烧焦的触角还冒着热气。它没长腿，只能靠圆碗底一路蹭过来——别看它慢，糊到你脸上时可一点不温柔。",
            "attack": "不紧不慢地贴上来，进入 1.35 米就一头撞过来。没有前摇、不会冲刺，纯粹的近身消耗。间隔 1 秒，每次 9 点伤害。",
        },
        {
            "id": "swelling_dough",
            "name": "膨胀面团",
            "icon": ICON_DIR + "swelling_dough_膨胀面团.png",
            "kind": "普通 · 蓄力冲刺",
            "desc": "面团发得太快，昨天它自己爬出了烤盘。软塌塌的外表下憋着一股劲，冲起来像一颗失控的面团炮弹。",
            "attack": "在 11 米内会先蹲下蓄力（有预警圈），再以近五倍速度直线撞来。冲刺冷却 4.4 秒，撞中 11 点伤害。",
        },
        {
            "id": "cargo_loader",
            "name": "失控搬运机",
            "icon": ICON_DIR + "cargo_loader_失控搬运机.png",
            "kind": "普通 · 蓄力冲刺",
            "desc": "雪原运输站里报废的搬运机，不知被什么唤醒了。铁皮外壳撞上雪地咚咚作响，老远就能听见它冲过来的声音。",
            "attack": "锁定目标后蓄力冲刺，体型大、撞得也狠。每次 13 点伤害，第 2 波开始出现。",
        },
        {
            "id": "fork_imp",
            "name": "餐叉小鬼",
            "icon": ICON_DIR + "fork_imp_餐叉小鬼.png",
            "kind": "普通 · 高速冲刺",
            "desc": "从餐具堆里钻出来的小家伙，举着餐叉当长矛。它跑得最快，也最沉不住气——总是第一个冲进你的攻击范围。",
            "attack": "冲刺冷却短（3.2 秒）、速度还要再快两成，是贴脸威胁最大的杂兵。撞中 13 点伤害。",
        },
        {
            "id": "toast",
            "name": "焦糊面包怪",
            "icon": ICON_DIR + "toast_焦糊面包怪.png",
            "kind": "普通 · 远程投射",
            "desc": "一片烤过头的面包，边缘焦黑，偏偏还有精神。它很懂得保持距离：你靠近它就退，你退远它又跟上来。",
            "attack": "永远和你保持 5.5~8.5 米，每 1.8 秒吐一枚橙色火弹。命中 10 点伤害，别站桩跟它对射。",
        },
        {
            "id": "mushroom",
            "name": "腐坏蘑菇",
            "icon": ICON_DIR + "mushroom_腐坏蘑菇.png",
            "kind": "普通 · 范围脉冲",
            "desc": "长在阴湿角落的紫蘑菇，菌盖一鼓一鼓地喷着孢子。它走得慢，却最耐打，逼着你尽快做决定。",
            "attack": "每 2.8 秒原地炸开一圈 4.4 米的紫色冲击波，站在圈里就会吃到 8 点伤害。血量是杂兵里最高的。",
        },
        {
            "id": "elite_cooker",
            "name": "高压锅守卫",
            "icon": ICON_DIR + "elite_cooker_高压锅守卫.png",
            "kind": "精英 · 蓄力冲刺",
            "desc": "整套厨房里最沉的家伙。锅盖拧得死紧，表盘上的指针已经红到了头——它每次冲锋都带着一身的蒸汽与怒气。",
            "attack": "13 米外就开始蓄力冲刺，近身挥击更快。伤害 19 点，血量是普通杂兵的三倍多。第 2 波起每 42 秒出现一只。",
        },
        {
            "id": "boss_furnace",
            "name": "暴食烤炉 · 山口之主",
            "icon": ICON_DIR + "boss_furnace_暴食烤炉.png",
            "kind": "首领 · 固定招式循环",
            "desc": "守在山口的巨大烤炉，炉膛里烧着不知多少没能出去的人的晚饭。它不追你，只守着那条路——想过去，就得先让它熄火。",
            "attack": "开炉吸入把你往炉口拉；张嘴喷出焦面包，地面会出现橙色落点；炉温失控时爆发红圈或直接赤热冲刺。最关键的，是它过热停顿、炉芯暴露的那几秒——那时造成的伤害翻倍，是唯一稳的机会。",
        },
    ],
    "second": [],
    "third": [],
}


static func chapter_name(id: String) -> String:
    for c in CHAPTERS:
        if String(c["id"]) == id:
            return String(c["name"])
    return id


static func enemies_of(chapter_id: String) -> Array:
    return ENEMIES.get(chapter_id, [])
