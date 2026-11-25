class_name GameDemoComponent
extends Node
## 获取 3D 演示的退出按钮，将点击交给所属 View。

var view: GameDemoView

@onready var _exit_button: Button = $HUD/ExitButton


func _ready() -> void:
	_exit_button.pressed.connect(func() -> void:
		if view != null:
			view.on_click_exit()
	)
