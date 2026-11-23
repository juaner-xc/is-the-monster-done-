extends CanvasLayer
## Shared recipe journal: browsing never grants ingredients or changes saves.
signal closed
const Book = preload("res://scripts/book_ui.gd")
const UiSfx = preload("res://scripts/ui_sfx.gd")
const Recipes = preload("res://scripts/recipe_system.gd")
const Illustration = preload("res://scripts/recipe_illustration.gd")
const Surface = preload("res://scripts/recipe_book_surface.gd")
const Codex = preload("res://scripts/codex_data.gd")
const INK=Color("493a2c")
const MUTED=Color("7d7056")
const DESIGN=Vector2(1160,630)
const NOTES={"chili":"让平底锅与火焰更有威力。","oil":"扩大挥锅范围。","fruit":"提高调味弹伤害。","ice":"让调味弹附加减速。","mushroom":"提高最大生命。","cream":"恢复生命，强化持续恢复。","flour":"减少受到的伤害。","black_salt":"提高伤害，代价是生命上限。","sweet_potato":"减少受到的伤害。","caramel":"强化持续恢复。","any":"任意一种其他食材均可搭配。"}
var overlay: ColorRect
var stage: Control
var surface: Control
var content: Control
var heading: Label
var summary: Label
var owned_button: Button
var all_button: Button
var close_button: Button
var previous_button: Button
var next_button: Button
var source: Node
var owned_only=false
var previous_focus: Control
var selected_id="fire_ring"
var visible_ids=[]
var bookmark_buttons=[]
var page_number: Label
var kind_label: Label
var title_label: Label
var effect_label: Label
var usage_label: Label
var hero: Control
var ingredient_names=[]
var ingredient_notes=[]
var ingredient_icons=[]
var ingredient_status=[]
var status_label: Label
var tabs_root: Control
var turn_tween: Tween
# 旅行手记状态
var current_mode := "residents"       # residents=居民名册 / recipes=料理手册
var current_chapter := "snow"         # snow / second / third
var chapter_buttons := []
var mode_buttons := []
var residents_mode_btn: Button
var recipes_mode_btn: Button
var residents_root: Control           # 居民名册页面
var recipes_root: Control             # 料理手册页面（原 content 的料理内容）
var resident_icon: TextureRect        # 敌人透明立绘
var resident_name: Label
var resident_kind: Label
var resident_desc_hint: Label
var resident_attack_hint: Label
var resident_desc: Label
var resident_attack: Label
var resident_badge: Label             # 右上角章节标签
var resident_index: Label
var footer_label: Label
var resident_selected := 0

func text(parent,value,pos,box,font_size=20,color=INK):
 var n=Book.label(value,font_size,color);n.position=pos;n.size=box;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(n);return n
func button(parent,value,pos,box):
 var n=Button.new();n.text=value;n.position=pos;n.size=box;n.add_theme_font_size_override("font_size",17)
 n.add_theme_color_override("font_color",INK);n.add_theme_color_override("font_hover_color",INK);n.add_theme_color_override("font_pressed_color",INK);n.add_theme_color_override("font_disabled_color",MUTED)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var fill=Color("e8d5aa") if state!="hover" else Color("f8edcf")
  var style=Book.style(fill,Color("bca477"),6);style.shadow_size=2
  n.add_theme_stylebox_override(state,style)
 parent.add_child(n);return n
func _ready():
 layer=20;process_mode=Node.PROCESS_MODE_ALWAYS
 overlay=ColorRect.new();overlay.name="RecipeBookOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.color=Color(0.035,0.055,0.045,0.88);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay)
 var font=SystemFont.new();font.font_names=PackedStringArray(["KaiTi","STKaiti","Microsoft YaHei","SimSun"])
 overlay.theme=Theme.new();overlay.theme.default_font=font
 stage=Control.new();stage.name="OpenCookbook";stage.size=DESIGN;stage.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(stage)
 surface=Surface.new();surface.size=DESIGN;stage.add_child(surface)
 residents_root=Control.new();residents_root.name="ResidentsPage";residents_root.size=DESIGN;residents_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(residents_root)
 recipes_root=Control.new();recipes_root.name="RecipesPage";recipes_root.size=DESIGN;recipes_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(recipes_root)
 content=Control.new();content.name="RecipeContent";content.size=DESIGN;content.mouse_filter=Control.MOUSE_FILTER_IGNORE;recipes_root.add_child(content)
 heading=text(content,"旅行手记",Vector2(143,65),Vector2(185,26),17,MUTED)
 text(content,"食材与搭配",Vector2(143,95),Vector2(420,40),30)
 all_button=button(content,"全部料理",Vector2(872,58),Vector2(86,32));all_button.name="AllRecipesButton";all_button.pressed.connect(func():_set_filter(false))
 owned_button=button(content,"本局已激活",Vector2(966,58),Vector2(100,32));owned_button.name="OwnedRecipesButton";owned_button.pressed.connect(func():_set_filter(true))
 for i in 2:
  var x=143+i*238
  var card=Panel.new();card.position=Vector2(x,173);card.size=Vector2(182,171);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;var card_style=Book.style(Color("f6eaca"),Color("c5ad7f"),0);card_style.shadow_size=2;card.add_theme_stylebox_override("panel",card_style);content.add_child(card)
  var icon=Illustration.new();icon.position=Vector2(12,6);icon.size=Vector2(158,123);card.add_child(icon);ingredient_icons.append(icon)
  var name_=text(card,"",Vector2(8,134),Vector2(166,29),22);name_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ingredient_names.append(name_)
  ingredient_notes.append(text(content,"",Vector2(x,360),Vector2(182,65),18,MUTED))
  ingredient_status.append(text(content,"",Vector2(x,420),Vector2(182,25),17,Color("536b50")))
 text(content,"+",Vector2(335,235),Vector2(35,50),36)
 summary=text(content,"",Vector2(143,463),Vector2(416,48),17,MUTED)
 kind_label=text(content,"",Vector2(632,62),Vector2(230,26),17,MUTED)
 title_label=text(content,"",Vector2(632,95),Vector2(416,42),34)
 hero=Illustration.new();hero.position=Vector2(711,150);hero.size=Vector2(280,182);content.add_child(hero)
 status_label=text(content,"",Vector2(630,329),Vector2(440,24),17,Color("657a55"));status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var scroll=ScrollContainer.new();scroll.name="RecipeDetailsScroll";scroll.position=Vector2(634,366);scroll.size=Vector2(428,137);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
 var detail_col=VBoxContainer.new();detail_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_theme_constant_override("separation",9);scroll.add_child(detail_col)
 effect_label=Book.paragraph("",20,INK);effect_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_child(effect_label)
 usage_label=Book.paragraph("",18,MUTED);usage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_child(usage_label)
 text(content,"食材笔记",Vector2(300,518),Vector2(170,24),16,MUTED)
 page_number=text(stage,"",Vector2(779,519),Vector2(140,26),17,MUTED);page_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 previous_button=button(stage,"‹",Vector2(959,513),Vector2(43,34));previous_button.name="PreviousRecipePage";previous_button.pressed.connect(func():_move_page(-1))
 next_button=button(stage,"›",Vector2(1012,513),Vector2(43,34));next_button.name="NextRecipePage";next_button.pressed.connect(func():_move_page(1))
 close_button=button(stage,"×",Vector2(1070,47),Vector2(32,32));close_button.name="CloseRecipeBookButton";close_button.pressed.connect(close_book)
 footer_label=text(stage,"选择章节与书签，或用 ← → 翻页     Tab / Esc 合上手记",Vector2(186,602),Vector2(845,25),16,Color("d7c8a3"));footer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 tabs_root=Control.new();tabs_root.name="RecipeBookmarks";tabs_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(tabs_root)
 _build_codex_ui()
 get_viewport().size_changed.connect(_layout)
 _layout();overlay.hide()

# ============ 旅行手记：居民名册 / 章节标签 / 模式切换 ============
func _build_codex_ui():
 # 模式按钮（左页上方，居民名册 / 料理手册）
 residents_mode_btn=button(stage,"居民名册",Vector2(335,58),Vector2(108,34));residents_mode_btn.name="ModeResidentsButton";residents_mode_btn.pressed.connect(func():_set_mode("residents"))
 recipes_mode_btn=button(stage,"料理手册",Vector2(450,58),Vector2(108,34));recipes_mode_btn.name="ModeRecipesButton";recipes_mode_btn.pressed.connect(func():_set_mode("recipes"))
 mode_buttons=[residents_mode_btn,recipes_mode_btn]
 # 章节标签（书页左缘向外伸出的三个书签）
 var chapter_tabs:=Control.new();chapter_tabs.name="ChapterTabs";chapter_tabs.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(chapter_tabs)
 for i in Codex.CHAPTERS.size():
  var c:Dictionary=Codex.CHAPTERS[i]
  var b:Button=button(chapter_tabs,String(c["name"]),Vector2(8,150+i*64),Vector2(120,54))
  b.name="ChapterTab_"+String(c["id"])
  b.add_theme_font_size_override("font_size",18)
  b.pressed.connect(_select_chapter.bind(String(c["id"])))
  chapter_buttons.append(b)
 # 居民名册：左页带卡纸边框的透明立绘，右页徽标 / 大标题 / 描述 / 攻击方式
 var portrait_frame:=Panel.new();portrait_frame.position=Vector2(140,150);portrait_frame.size=Vector2(410,350);portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var portrait_style:=Book.style(Color("f6eaca"),Color("c5ad7f"),0);portrait_style.set_corner_radius_all(12);portrait_style.shadow_size=3;portrait_frame.add_theme_stylebox_override("panel",portrait_style);residents_root.add_child(portrait_frame)
 resident_icon=TextureRect.new();resident_icon.name="ResidentPortrait";resident_icon.position=Vector2(150,158);resident_icon.size=Vector2(390,334)
 resident_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;resident_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 resident_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;residents_root.add_child(resident_icon)
 text(residents_root,"居民名册",Vector2(143,95),Vector2(420,40),30)
 resident_index=text(residents_root,"",Vector2(150,508),Vector2(380,26),17,MUTED);resident_index.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 resident_badge=text(residents_root,"",Vector2(632,58),Vector2(230,26),17,Color("8a6f4e"))
 resident_kind=text(residents_root,"",Vector2(878,58),Vector2(190,26),16,MUTED)
 resident_name=text(residents_root,"",Vector2(632,150),Vector2(430,46),34)
 resident_desc_hint=text(residents_root,"它的样子",Vector2(632,205),Vector2(200,24),17,MUTED)
 resident_desc=Book.paragraph("",18,INK);resident_desc.position=Vector2(632,230);resident_desc.custom_minimum_size=Vector2(430,115);residents_root.add_child(resident_desc)
 resident_attack_hint=text(residents_root,"攻击方式",Vector2(632,356),Vector2(200,24),17,MUTED)
 resident_attack=Book.paragraph("",17,MUTED);resident_attack.position=Vector2(632,381);resident_attack.custom_minimum_size=Vector2(430,145);residents_root.add_child(resident_attack)

func _set_mode(mode:String):
 if current_mode==mode:return
 UiSfx.play_page_turn(self)
 current_mode=mode
 _refresh()
 _apply_mode_visual()

func _apply_mode_visual():
 var residents:bool=current_mode=="residents"
 residents_root.visible=residents
 recipes_root.visible=not residents
 if footer_label!=null:footer_label.text="用 ← → 或右下角箭头翻阅居民     Tab / Esc 合上手记" if residents else "点击底部索引切换料理，或用 ← → 翻页     Tab / Esc 合上手记"
 for b in mode_buttons:
  var active:bool=(b==residents_mode_btn)==residents
  var bg:=Color("536752") if active else Color("d7c59e")
  for stt in ["normal","hover","pressed","focus"]:
   var s:=Book.style(bg,Color("8c7a56"),6);s.shadow_size=2
   b.add_theme_stylebox_override(stt,s)
  for stt in ["font_color","font_hover_color","font_pressed_color"]:
   b.add_theme_color_override(stt,Color("fff0ca") if active else INK)
 for b in chapter_buttons:
  var selected:bool=(String(b.name)=="ChapterTab_"+current_chapter)
  var bg:=Color("536752") if selected else Color("d7c59e")
  for stt in ["normal","hover","pressed","focus"]:
   var s:=Book.style(bg,Color("8c7a56"),8);s.border_width_left=6;s.border_color=Color("b89b62");s.shadow_size=2;s.corner_radius_top_left=5;s.corner_radius_bottom_left=5
   b.add_theme_stylebox_override(stt,s)
  for stt in ["font_color","font_hover_color","font_pressed_color"]:
   b.add_theme_color_override(stt,Color("fff0ca") if selected else INK)

func _select_chapter(id:String):
 if current_chapter==id:return
 UiSfx.play_page_turn(self)
 current_chapter=id
 resident_selected=0
 _refresh()
 _apply_mode_visual()

func _layout():
 if stage==null:return
 var viewport_size=get_viewport().get_visible_rect().size
 var factor=minf((viewport_size.x-36)/DESIGN.x,(viewport_size.y-28)/DESIGN.y)
 factor=clampf(factor,0.25,1.4)
 stage.scale=Vector2.ONE*factor;stage.position=(viewport_size-DESIGN*factor)*0.5
func is_open():return is_instance_valid(overlay) and overlay.visible
func open_book(recipe_source: Node=null):
 if is_open():return
 UiSfx.play_page_turn(self)
 previous_focus=get_viewport().gui_get_focus_owner();source=recipe_source;owned_only=is_instance_valid(source)
 owned_button.visible=is_instance_valid(source)
 heading.text="旅行手记 · 本局" if is_instance_valid(source) else "旅行手记"
 overlay.show();_refresh();_layout();close_button.grab_focus()
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 _reset_page_fade();surface.turn_amount=0
 stage.modulate.a=0
 turn_tween=create_tween();turn_tween.tween_property(stage,"modulate:a",1.0,0.18)
func close_book():
 if not is_open():return
 UiSfx.play_page_turn(self)
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 _reset_page_fade();surface.turn_amount=0;overlay.hide();close_button.release_focus()
 if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():previous_focus.grab_focus()
 closed.emit()
func _input(event):
 if not is_open() or not event is InputEventKey:return
 var key=event.physical_keycode if event.physical_keycode else event.keycode
 if key in [KEY_TAB,KEY_ESCAPE,KEY_LEFT,KEY_RIGHT]:
  get_viewport().set_input_as_handled()
  if not event.pressed or event.echo:return
  if key in [KEY_TAB,KEY_ESCAPE]:close_book()
  else:_move_page(-1 if key==KEY_LEFT else 1)
func _set_filter(owned):
 owned_only=owned and is_instance_valid(source);_refresh()
func _refresh():
 _apply_mode_visual()
 if current_mode=="residents":
  _refresh_residents();return
 # ---- 料理手册（按章节）----
 visible_ids=[]
 var active=[]
 if is_instance_valid(source):active=source.get_active_recipes()
 # 第一章为现有料理；第二、三章暂无独立配方
 var chapter_recipes:Array = ["fire_ring","ice_shot","cream_guard","pastry_shield","dark_dish","baked_sweet_potato"] if current_chapter=="snow" else []
 for id in chapter_recipes:
  if not owned_only or active.has(id):visible_ids.append(id)
 if not visible_ids.has(selected_id):selected_id=visible_ids[0] if not visible_ids.is_empty() else ""
 all_button.disabled=not owned_only;owned_button.disabled=owned_only
 _bookmarks();_show_page()
func _bookmarks():
 for child in tabs_root.get_children():tabs_root.remove_child(child);child.queue_free()
 bookmark_buttons=[]
 if current_mode=="residents":
  # 居民页靠左右翻页箭头 / ← → 浏览，不再占用左缘书签区
  return
 var n:=visible_ids.size()
 if n==0:return
 var bw:=120.0;var gap:=8.0
 var total:=n*bw+(n-1)*gap
 var startx:=(DESIGN.x-total)*0.5
 for i in n:
  var id=visible_ids[i]
  var selected=id==selected_id
  var tab=button(tabs_root,Recipes.RECIPE_NAMES[id],Vector2(startx+i*(bw+gap),558),Vector2(bw,34))
  tab.name="Bookmark_"+id;tab.add_theme_font_size_override("font_size",15)
  var accent=Color(Recipes.RECIPE_DETAILS[id].color)
  for state in ["normal","hover","pressed","focus"]:
   var bg=Color("536752") if selected else Color("d7c59e")
   if state=="hover":bg=bg.lightened(0.12)
   var style=Book.style(bg,Color("8c7a56"),8);style.border_width_left=6;style.border_color=accent;style.shadow_size=2;style.corner_radius_top_left=5;style.corner_radius_bottom_left=5
   tab.add_theme_stylebox_override(state,style)
  for state in ["font_color","font_hover_color","font_pressed_color"]:tab.add_theme_color_override(state,Color("fff0ca") if selected else INK)
  tab.pressed.connect(_select_recipe.bind(id));bookmark_buttons.append(tab)
func _select_recipe(id):
 if selected_id==id:return
 UiSfx.play_page_turn(self)
 selected_id=id;_bookmarks()
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 var page:Control=_page_root()
 _reset_page_fade();surface.turn_amount=0
 turn_tween=create_tween();turn_tween.set_parallel(true)
 turn_tween.tween_property(page,"modulate:a",0.0,0.09)
 turn_tween.tween_property(surface,"turn_amount",0.5,0.09)
 turn_tween.chain().tween_callback(_show_page)
 turn_tween.chain().set_parallel(true)
 turn_tween.tween_property(page,"modulate:a",1.0,0.14)
 turn_tween.tween_property(surface,"turn_amount",1.0,0.14)
func _move_page(direction):
 if current_mode=="residents":
  var es:Array=Codex.enemies_of(current_chapter)
  if es.is_empty():return
  var nx:int=clampi(resident_selected+direction,0,es.size()-1)
  _select_resident(nx);return
 if visible_ids.is_empty():return
 var index=visible_ids.find(selected_id)
 var next=clampi(index+direction,0,visible_ids.size()-1)
 _select_recipe(visible_ids[next])
func _show_page():
 if current_mode=="residents":
  _show_resident();return
 var empty=selected_id.is_empty()
 hero.visible=not empty
 for node in ingredient_icons+ingredient_names+ingredient_notes+ingredient_status:node.visible=not empty
 if empty:
  kind_label.text="先从一种食材开始";title_label.text="这一页，等你来写"
  status_label.text="本局尚未激活料理"
  effect_label.text="击败敌人获得散逸魔力，升级时在锅里凝成食材。集齐两种搭配，即可激活料理。"
  usage_label.text="切换右页上方“全部料理”，查看已有配方。"
  summary.text="这本手记记录你的搭配。\n当前只显示本局已激活的料理。"
  page_number.text="— / —";previous_button.disabled=true;next_button.disabled=true;return
 var detail=Recipes.RECIPE_DETAILS[selected_id]
 title_label.text=Recipes.RECIPE_NAMES[selected_id];kind_label.text=detail.kind
 hero.set_kind(selected_id)
 effect_label.text="效果  ·  "+detail.effect
 usage_label.text="用法  ·  "+detail.usage
 var ingredients=detail.ingredients.duplicate()
 if selected_id=="dark_dish":ingredients.append("any")
 for i in 2:
  var id=ingredients[i]
  ingredient_names[i].text="其他食材" if id=="any" else Recipes.UPGRADE_DEFS[id].name
  ingredient_icons[i].set_kind("fruit" if id=="any" else id)
  ingredient_notes[i].text=NOTES[id]
  ingredient_status[i].text=""
  if is_instance_valid(source):
   var level=source.get_level(id) if id!="any" else 0
   if id=="any":
    for other in Recipes.UPGRADE_DEFS:
     if other!="black_salt" and source.get_level(other)>0:level=1
   ingredient_status[i].text="已有 Lv.%d"%level if level>0 else "尚未获得"
 var active=is_instance_valid(source) and source.get_active_recipes().has(selected_id)
 status_label.text=("本局已激活" if active else "本局尚未集齐") if is_instance_valid(source) else "料理图鉴 · 可在冒险中尝试"
 summary.text="升级时选择食材。\n集齐搭配后自动生效，无需手动装配。"
 if is_instance_valid(source):summary.text="本局已激活 %d / 6 道料理。\n查看期间战斗暂停，合上后继续。"%source.get_active_recipes().size()
 var index=visible_ids.find(selected_id)
 page_number.text="%d / %d"%[index+1,visible_ids.size()]
 previous_button.disabled=index==0;next_button.disabled=index==visible_ids.size()-1
 var scroll=effect_label.get_parent().get_parent() as ScrollContainer
 scroll.scroll_vertical=0

# ============ 居民名册 ============
func _refresh_residents():
 var es:Array=Codex.enemies_of(current_chapter)
 resident_selected=clampi(resident_selected,0,maxi(es.size()-1,0))
 _bookmarks();_show_resident()

func _select_resident(index:int):
 if index==resident_selected:return
 UiSfx.play_page_turn(self)
 resident_selected=index
 _bookmarks()
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 var page:Control=_page_root()
 _reset_page_fade();surface.turn_amount=0
 turn_tween=create_tween();turn_tween.set_parallel(true)
 turn_tween.tween_property(page,"modulate:a",0.0,0.09)
 turn_tween.tween_property(surface,"turn_amount",0.5,0.09)
 turn_tween.chain().tween_callback(_show_resident)
 turn_tween.chain().set_parallel(true)
 turn_tween.tween_property(page,"modulate:a",1.0,0.14)
 turn_tween.tween_property(surface,"turn_amount",1.0,0.14)

func _show_resident():
 var es:Array=Codex.enemies_of(current_chapter)
 if es.is_empty():
  resident_icon.texture=null
  resident_desc_hint.visible=false;resident_attack_hint.visible=false
  resident_badge.text=Codex.chapter_name(current_chapter)
  resident_kind.text="—"
  resident_name.text="这一页还空着"
  resident_desc.text="关于" + Codex.chapter_name(current_chapter) + "的记录尚未写进手记。\n等走过这段路，再回来补上吧。"
  resident_attack.text=""
  resident_index.text="0 / 0"
  page_number.text="— / —"
  previous_button.disabled=true;next_button.disabled=true
  return
 resident_desc_hint.visible=true;resident_attack_hint.visible=true
 var e:Dictionary=es[clampi(resident_selected,0,es.size()-1)]
 resident_badge.text=Codex.chapter_name(current_chapter)
 resident_name.text=String(e["name"])
 resident_kind.text=String(e["kind"])
 resident_desc.text=String(e["desc"])
 resident_attack.text=String(e["attack"])
 var tex:Texture2D=load(String(e["icon"])) as Texture2D
 resident_icon.texture=tex
 resident_icon.visible=(tex!=null)
 resident_index.text="%d / %d" % [resident_selected+1,es.size()]
 page_number.text="%d / %d" % [resident_selected+1,es.size()]
 previous_button.disabled=(resident_selected==0)
 next_button.disabled=(resident_selected==es.size()-1)

func _page_root()->Control:
 return residents_root if current_mode=="residents" else recipes_root

func _reset_page_fade()->void:
 residents_root.modulate.a=1
 recipes_root.modulate.a=1
