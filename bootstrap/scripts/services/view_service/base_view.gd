class_name BaseView
## 管理业务 View 和 Controller 的生命周期。加载参数可通过 [code]ViewService.load_async()[/code] 的回调设置。

## 当前视图使用的框架服务。
var services: ServiceLocator:
	get:
		return _services.get_ref() as ServiceLocator if _services != null else null
	set(value):
		_services = weakref(value)

## 当前视图的场景、脚本、容器和缓存配置。
var definition: ViewDefinition
## 所有 View 共用的组件引用。ViewService 按登记校验组件脚本，卸载后清空。
var component: Node
## 按列表顺序加载和更新，按完成加载的相反顺序卸载。
var controllers: Array[BaseController] = []
## 组件已交给 View，Controller 和 [method _on_load] 此时可能仍在初始化。
var is_loaded := false
## 此 View 实例曾完整加载成功。缓存实例卸载后保留此标记。
var has_loaded := false
# ServiceLocator 持有 ViewService 及其缓存的 View，回到 Locator 使用弱引用。
var _services: WeakRef
var _loaded_controllers: Array[BaseController] = []
var _on_load_started := false


func _prepare() -> void:
	_on_before_load()


func _load(view_component: Node) -> void:
	component = view_component
	is_loaded = true
	var index := 0
	while index < controllers.size():
		var controller := controllers[index]
		await controller.load_async()
		# 等待期间组件可能已离开场景树，清理刚完成加载的 Controller。
		if component != view_component:
			controller.unload()
			return
		_loaded_controllers.append(controller)
		index += 1
	_on_load_started = true
	await _on_load()
	if component == view_component:
		has_loaded = true


func _update(delta: float) -> void:
	for controller in controllers:
		if not is_loaded:
			return
		controller.update(delta)
	if is_loaded:
		_on_update(delta)


func _unload() -> void:
	if not is_loaded:
		return
	is_loaded = false
	if _on_load_started:
		_on_load_started = false
		_on_unload()
	for index in range(_loaded_controllers.size() - 1, -1, -1):
		_loaded_controllers[index].unload()
	_loaded_controllers.clear()
	if is_instance_valid(component):
		component.set("view", null)
	component = null


## 组件加载前执行，可用于准备 Controller 等不依赖节点的状态。
func _on_before_load() -> void:
	pass


## 组件进入场景树且 Controller 全部加载后执行。业务可以在此等待所需资源。
func _on_load() -> void:
	pass


## 活动 View 的 Controller 完成当帧更新后执行。
func _on_update(_delta: float) -> void:
	pass


## [method _on_load] 已开始时执行，随后逆序卸载 Controller 并清空组件。
func _on_unload() -> void:
	pass
