extends RichTextEffect
var bbcode := "appear"
var progress := 0.0
var interval := 0.065

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var age := progress - float(char_fx.relative_index) * interval
	var opacity := clampf(age / 0.32, 0.0, 1.0)
	char_fx.color = char_fx.color.lerp(Color("deb975"), (1.0-opacity)*0.7)
	char_fx.color.a *= opacity
	char_fx.offset.y += (1.0-opacity) * 9.0
	return true
