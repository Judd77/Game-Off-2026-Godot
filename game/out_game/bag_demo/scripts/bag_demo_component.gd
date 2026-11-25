class_name BagDemoComponent
extends Node
## 获取背包的退出按钮，将点击交给所属 View。

var view: BagDemoView

@onready var _exit_button: Button = $Panel/ExitButton


func _ready() -> void:
	_exit_button.pressed.connect(func() -> void:
		if view != null:
			view.on_click_exit()
	)
