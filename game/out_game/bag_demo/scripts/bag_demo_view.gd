class_name BagDemoView
extends BaseView
## 管理挂在常驻 Popup 层的背包弹窗。


## 关闭当前背包实例。
func on_click_exit() -> void:
	services.view_service.unload(ViewKeys.BAG_DEMO)
