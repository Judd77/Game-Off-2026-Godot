class_name LobbyDemoComponent
extends Node
## 获取大厅的文字和按钮节点，将点击交给所属 View。

var view: LobbyDemoView

@onready var message: Label = $Message
@onready var _start_button: Button = $StartButton
@onready var _bag_button: Button = $BagButton


func _ready() -> void:
	_start_button.pressed.connect(func() -> void:
		if view != null:
			view.on_click_start_game()
	)
	_bag_button.pressed.connect(func() -> void:
		if view != null:
			view.on_click_bag()
	)
