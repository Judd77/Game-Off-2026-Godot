class_name GameDemoView
extends BaseView
## 管理 3D 演示与大厅之间的切换。


## 退出当前场景并返回大厅。
func on_click_exit() -> void:
	await services.view_service.load_async(ViewKeys.LOBBY_DEMO)
