class_name LobbyDemoView
extends BaseView
## 从配置表显示大厅文案，并打开局内场景或背包。

const DEMO_ROW_ID := 1

## 基类加载的大厅组件，供大厅的业务方法访问。
var lobby_component: LobbyDemoComponent:
	get:
		return component as LobbyDemoComponent


func _on_load() -> void:
	var tables := services.config_service.tables as Schema.Tables
	lobby_component.message.text = tables.tbDemo.get_item(DEMO_ROW_ID).Message


## 进入 3D 演示场景。
func on_click_start_game() -> void:
	await services.view_service.load_async(ViewKeys.GAME_DEMO)


## 在常驻 Popup 层打开背包。
func on_click_bag() -> void:
	await services.view_service.load_async(ViewKeys.BAG_DEMO)
