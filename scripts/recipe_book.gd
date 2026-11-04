extends CanvasLayer
## Shared recipe journal: browsing never grants ingredients or changes saves.
signal closed
const Book = preload("res://scripts/book_ui.gd")
const Recipes = preload("res://scripts/recipe_system.gd")
const Illustration = preload("res://scripts/recipe_illustration.gd")
const Surface = preload("res://scripts/recipe_book_surface.gd")
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
 content=Control.new();content.size=DESIGN;content.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(content)
 heading=text(content,"料理手记",Vector2(143,65),Vector2(185,26),17,MUTED)
 text(content,"食材与搭配",Vector2(143,95),Vector2(420,40),30)
 all_button=button(content,"全部料理",Vector2(330,62),Vector2(100,32));all_button.name="AllRecipesButton";all_button.pressed.connect(func():_set_filter(false))
 owned_button=button(content,"本局已激活",Vector2(439,62),Vector2(125,32));owned_button.name="OwnedRecipesButton";owned_button.pressed.connect(func():_set_filter(true))
 for i in 2:
  var x=143+i*238
  var card=Panel.new();card.position=Vector2(x,173);card.size=Vector2(182,171);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;var card_style=Book.style(Color("f6eaca"),Color("c5ad7f"),0);card_style.shadow_size=2;card.add_theme_stylebox_override("panel",card_style);content.add_child(card)
  var icon=Illustration.new();icon.position=Vector2(12,6);icon.size=Vector2(158,123);card.add_child(icon);ingredient_icons.append(icon)
  var name_=text(card,"",Vector2(8,134),Vector2(166,29),22);name_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ingredient_names.append(name_)
  ingredient_notes.append(text(content,"",Vector2(x,360),Vector2(182,65),18,MUTED))
  ingredient_status.append(text(content,"",Vector2(x,420),Vector2(182,25),17,Color("536b50")))
 text(content,"+",Vector2(335,235),Vector2(35,50),36)
 summary=text(content,"",Vector2(143,463),Vector2(416,48),17,MUTED)
 kind_label=text(content,"",Vector2(632,65),Vector2(390,25),17,MUTED)
 title_label=text(content,"",Vector2(632,95),Vector2(416,42),34)
 hero=Illustration.new();hero.position=Vector2(711,150);hero.size=Vector2(280,182);content.add_child(hero)
 status_label=text(content,"",Vector2(630,329),Vector2(440,24),17,Color("657a55"));status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var scroll=ScrollContainer.new();scroll.name="RecipeDetailsScroll";scroll.position=Vector2(634,366);scroll.size=Vector2(428,137);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
 var detail_col=VBoxContainer.new();detail_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_theme_constant_override("separation",9);scroll.add_child(detail_col)
 effect_label=Book.paragraph("",20,INK);effect_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_child(effect_label)
 usage_label=Book.paragraph("",18,MUTED);usage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_col.add_child(usage_label)
 text(stage,"食材笔记",Vector2(300,518),Vector2(170,24),16,MUTED)
 page_number=text(stage,"",Vector2(779,519),Vector2(140,26),17,MUTED);page_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 previous_button=button(stage,"‹",Vector2(959,513),Vector2(43,34));previous_button.name="PreviousRecipePage";previous_button.pressed.connect(func():_move_page(-1))
 next_button=button(stage,"›",Vector2(1012,513),Vector2(43,34));next_button.name="NextRecipePage";next_button.pressed.connect(func():_move_page(1))
 close_button=button(stage,"×",Vector2(1070,47),Vector2(32,32));close_button.name="CloseRecipeBookButton";close_button.pressed.connect(close_book)
 var footer=text(stage,"选择左侧书签，或用 ← → 翻页     Tab / Esc 合上手记",Vector2(186,602),Vector2(845,25),16,Color("d7c8a3"));footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 tabs_root=Control.new();tabs_root.name="RecipeBookmarks";tabs_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(tabs_root)
 get_viewport().size_changed.connect(_layout)
 _layout();overlay.hide()
func _layout():
 if stage==null:return
 var viewport_size=get_viewport().get_visible_rect().size
 var factor=minf((viewport_size.x-36)/DESIGN.x,(viewport_size.y-28)/DESIGN.y)
 factor=clampf(factor,0.25,1.4)
 stage.scale=Vector2.ONE*factor;stage.position=(viewport_size-DESIGN*factor)*0.5
func is_open():return is_instance_valid(overlay) and overlay.visible
func open_book(recipe_source: Node=null):
 if is_open():return
 previous_focus=get_viewport().gui_get_focus_owner();source=recipe_source;owned_only=is_instance_valid(source)
 owned_button.visible=is_instance_valid(source)
 heading.text="本局料理手记" if is_instance_valid(source) else "旅途中的料理手记"
 overlay.show();_refresh();_layout();close_button.grab_focus()
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 content.modulate.a=1;surface.turn_amount=0
 stage.modulate.a=0
 turn_tween=create_tween();turn_tween.tween_property(stage,"modulate:a",1.0,0.18)
func close_book():
 if not is_open():return
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 content.modulate.a=1;surface.turn_amount=0;overlay.hide();close_button.release_focus()
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
 visible_ids=[]
 var active=[]
 if is_instance_valid(source):active=source.get_active_recipes()
 for id in Recipes.RECIPE_NAMES:
  if not owned_only or active.has(id):visible_ids.append(id)
 if not visible_ids.has(selected_id):selected_id=visible_ids[0] if not visible_ids.is_empty() else ""
 all_button.disabled=not owned_only;owned_button.disabled=owned_only
 _bookmarks();_show_page()
func _bookmarks():
 for child in tabs_root.get_children():tabs_root.remove_child(child);child.queue_free()
 bookmark_buttons=[]
 for i in visible_ids.size():
  var id=visible_ids[i]
  var selected=id==selected_id
  var tab=button(tabs_root,Recipes.RECIPE_NAMES[id],Vector2(16 if selected else 26,159+i*70),Vector2(123 if selected else 113,54))
  tab.name="Bookmark_"+id;tab.add_theme_font_size_override("font_size",19)
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
 selected_id=id;_bookmarks()
 if turn_tween and turn_tween.is_running():turn_tween.kill()
 content.modulate.a=1;surface.turn_amount=0
 turn_tween=create_tween();turn_tween.set_parallel(true)
 turn_tween.tween_property(content,"modulate:a",0.0,0.09)
 turn_tween.tween_property(surface,"turn_amount",0.5,0.09)
 turn_tween.chain().tween_callback(_show_page)
 turn_tween.chain().set_parallel(true)
 turn_tween.tween_property(content,"modulate:a",1.0,0.14)
 turn_tween.tween_property(surface,"turn_amount",1.0,0.14)
func _move_page(direction):
 if visible_ids.is_empty():return
 var index=visible_ids.find(selected_id)
 var next=clampi(index+direction,0,visible_ids.size()-1)
 _select_recipe(visible_ids[next])
func _show_page():
 var empty=selected_id.is_empty()
 hero.visible=not empty
 for node in ingredient_icons+ingredient_names+ingredient_notes+ingredient_status:node.visible=not empty
 if empty:
  kind_label.text="先从一种食材开始";title_label.text="这一页，等你来写"
  status_label.text="本局尚未激活料理"
  effect_label.text="击败敌人获得散逸魔力，升级时在锅里凝成食材。集齐两种搭配，即可激活料理。"
  usage_label.text="切换左上角“全部料理”，查看已有配方。"
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
