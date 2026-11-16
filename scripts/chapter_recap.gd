extends Control
const Book := preload("res://scripts/book_ui.gd")
const PAGES := [
    ["愿望的味道", "在魔法料理的世界，厨师能把愿望加入食物。\n一碗汤寄托健康，一块蛋糕分享快乐。\n起初，一顿温暖的饭，就足以让人满足。"],
    ["黄金食谱", "后来，人们追求更强的料理，编写了能满足一切愿望的黄金食谱。\n可一个愿望实现，新的愿望又随之而来。\n失败的料理、浪费的食材与未尽的渴望，汇入裂隙，成为饥饿异界。"],
]
var page := 0
var busy := true
var heading: Label
var body: Label
var count: Label
var next: Button
var stage: Control

func _ready() -> void:
    Book.install(self)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var bg := TextureRect.new()
    bg.texture = load("res://assets/cinematics/opening_town_last.png")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0.025, 0.045, 0.05, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    stage = Control.new()
    stage.size = Vector2(1280,720)
    add_child(stage)
    var tag := Book.label("黄金食谱  /  前情",18,Book.GOLD)
    tag.position = Vector2(110,100)
    stage.add_child(tag)
    heading = Book.label("",42,Book.CREAM)
    heading.position = Vector2(110,165)
    stage.add_child(heading)
    body = Book.paragraph("",25,Book.CREAM)
    body.position = Vector2(110,270)
    body.size = Vector2(1060,240)
    body.add_theme_constant_override("line_spacing",14)
    stage.add_child(body)
    count = Book.label("",17,Book.GOLD)
    count.position = Vector2(110,605)
    stage.add_child(count)
    next = Book.button("继续  →")
    next.position = Vector2(940,580)
    next.size = Vector2(230,52)
    next.pressed.connect(advance)
    stage.add_child(next)
    resized.connect(_layout)
    _layout()
    _show_page()
    await CinematicFlow.reveal(0.8)
    busy = false

func _layout() -> void:
    var factor := minf(size.x/1280.0,size.y/720.0)
    stage.scale = Vector2.ONE*factor
    stage.position = (size-stage.size*factor)*0.5

func _show_page() -> void:
    heading.text = PAGES[page][0]
    body.text = PAGES[page][1]
    count.text = "%02d / 02    ·    空格 / Enter 继续" % (page+1)
    next.text = "我们的主角呢？  →" if page == PAGES.size() - 1 else "继续  →"
    stage.modulate.a = 0.0
    create_tween().tween_property(stage,"modulate:a",1.0,0.4)

func advance() -> void:
    if busy:
        return
    if page + 1 < PAGES.size():
        page += 1
        _show_page()
    else:
        busy = true
        await CinematicFlow.cover(0.65)
        CinematicFlow.from_film = true
        get_tree().change_scene_to_file("res://scenes/hero_film.tscn")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
        get_viewport().set_input_as_handled()
        advance()
