extends RefCounted

const EngineGD = preload("res://scripts/engine_gd.gd")

static func make() -> Array:
    if ClassDB.class_exists("DominoEngine"):
        return [ClassDB.instantiate("DominoEngine"), "C++"]
    var note := "GDScript - C++ not loaded | gdext=%s | loaded=%s | arch=%s" % [
        str(ResourceLoader.exists("res://domino.gdextension")),
        str(GDExtensionManager.get_loaded_extensions()),
        Engine.get_architecture_name()]
    return [EngineGD.new(), note]

static func add_note(parent: Control, text: String) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 16)
    l.modulate = Color(1, 1, 1, 0.55)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
    l.custom_minimum_size = Vector2(700, 0)
    l.position = Vector2(10, 2)
    parent.add_child(l)
