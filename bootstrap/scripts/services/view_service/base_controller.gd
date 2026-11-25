class_name BaseController
## 由所属 View 管理加载、更新和卸载的业务控制器。

## 所属的 View。弱引用避免与持有 Controller 的 View 形成引用环。
var view: BaseView:
	get:
		return _owner.get_ref() as BaseView

var _owner: WeakRef


func _init(owner: BaseView) -> void:
	_owner = weakref(owner)


## 由所属 View 按注册顺序等待加载完成。
func load_async() -> void:
	await _on_load()


## 由所属 View 逆序清理已加载的 Controller。
func unload() -> void:
	_on_unload()


## 在所属 View 的逐帧逻辑前执行。
func update(delta: float) -> void:
	_on_update(delta)


## 子类可在此等待所需资源并初始化运行时状态。
func _on_load() -> void:
	pass


## 子类在此清理运行时状态和信号连接。
func _on_unload() -> void:
	pass


## 子类的逐帧逻辑。[param _delta] 为上一帧经过的秒数。
func _on_update(_delta: float) -> void:
	pass
