extends CanvasLayer
signal completed
const Recipes := preload("res://scripts/recipe_system.gd")
const Book := preload("res://scripts/book_ui.gd")
var recipe_ids: Array[String] = []
var video: VideoStreamPlayer
var still: TextureRect
var caption: Label
var continue_button: Button
var root: Control
var band: ColorRect
var band_height := 164.0
var card := false
var ending := false
var clock := 0.0

func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    Book.install(root)
    var bg := ColorRect.new()
    bg.color = Color.BLACK
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)
    video = VideoStreamPlayer.new()
    video.expand = true
    video.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(video)
    still = TextureRect.new()
    still.texture = load("res://assets/cinematics/recipe_arrival_last.png")
    still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    still.hide()
    root.add_child(still)
    band = ColorRect.new()
    band.color = Color(0.025,0.04,0.045,0.9)
    band.anchor_top = 1.0
    band.anchor_right = 1.0
    band.anchor_bottom = 1.0
    band.offset_top = -164
    root.add_child(band)
    caption = Book.paragraph("天降食谱\n一道金光穿过风雪，落在奶龙的掌心。",24,Book.CREAM)
    caption.position = Vector2(42,14)
    caption.anchor_right = 1.0
    caption.offset_right = -240
    caption.offset_bottom = 152
    band.add_child(caption)
    continue_button = Book.button("跳过动画  →")
    continue_button.custom_minimum_size = Vector2(190,48)
    continue_button.anchor_left = 1.0
    continue_button.anchor_top = 1.0
    continue_button.anchor_right = 1.0
    continue_button.anchor_bottom = 1.0
    continue_button.offset_left = -218
    continue_button.offset_right = -28
    continue_button.offset_top = -72
    continue_button.offset_bottom = -24
    continue_button.pressed.connect(_advance)
    root.add_child(continue_button)
    root.resized.connect(_layout)
    _layout()
    video.finished.connect(_show_card)
    video.stream = load("res://assets/cinematics/recipe_arrival.ogv") as VideoStream
    if video.stream == null:
        _show_card()
    else:
        video.play()

func _layout() -> void:
    var available := Vector2(root.size.x,maxf(1.0,root.size.y-band_height))
    var width := minf(available.x,available.y*16.0/9.0)
    video.size = Vector2(width,width*9.0/16.0)
    video.position = (available-video.size)*0.5
    still.size = video.size
    still.position = video.position

func _process(delta: float) -> void:
    if card:
        return
    clock += delta
    var t := video.stream_position
    if t >= 9.0:
        caption.text = "愿望化作料理\n食材之间的联系，唤醒了沉睡的配方。"
    elif t >= 4.0:
        caption.text = "黄金食谱 · 新的一页\n书页在光芒中翻开，记下了这一次料理的灵感。"
    if clock > 20.0 or (clock > 3.0 and t < 0.01):
        _show_card()

func _show_card() -> void:
    if card:
        return
    card = true
    video.paused = true
    video.hide()
    still.show()
    if recipe_ids.size() > 1:
        band_height = 280.0
        band.offset_top = -band_height
        caption.offset_bottom = 268
        caption.add_theme_font_size_override("font_size",21)
        _layout()
    var entries: Array[String] = []
    for id in recipe_ids:
        var detail: Dictionary = Recipes.RECIPE_DETAILS[id]
        entries.append("%s  ·  %s\n%s" % [Recipes.RECIPE_NAMES[id],detail["formula"],detail["usage"]])
    caption.text = "料理已解锁\n" + "\n".join(entries)
    continue_button.text = "收下食谱  →"

func _advance() -> void:
    if ending:
        return
    if not card:
        _show_card()
    else:
        ending = true
        video.stop()
        completed.emit()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_ESCAPE,KEY_SPACE,KEY_ENTER,KEY_TAB]:
            get_viewport().set_input_as_handled()
            if event.keycode != KEY_TAB:
                _advance()
