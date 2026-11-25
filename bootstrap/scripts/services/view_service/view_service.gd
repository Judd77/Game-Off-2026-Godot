class_name ViewService
## 管理视图的加载、生命周期、缓存和公共 UI 容器。

## 同一个 CanvasLayer 内按从下到上的绘制顺序创建各容器，System 显示在 Popup 上方。
const LAYER_NAMES := [&"Background", &"Main", &"Popup", &"Guide", &"System"]


# 同一路径的并发调用共用加载结果，卸载请求留到本次加载结束时处理。
class ViewLoad:
	signal completed(view: BaseView)
	var component_ready := false
	var ready_callbacks: Array[Callable] = []
	var unload_requested := false

	func add_ready_callback(callback: Callable) -> void:
		if not callback.is_valid():
			return
		if component_ready:
			callback.call()
		else:
			ready_callbacks.append(callback)

	func notify_component_ready() -> void:
		component_ready = true
		for callback in ready_callbacks:
			if callback.is_valid():
				callback.call()
		ready_callbacks.clear()


var _facade: CanvasLayer
var _registry: ViewRegistry
# ServiceLocator 持有此服务，回到 Locator 使用弱引用。
var _services: WeakRef
var _views: Dictionary[String, BaseView] = {}
var _active_views: Dictionary[String, BaseView] = {}
var _loads: Dictionary[String, ViewLoad] = {}
var _preloaded: Dictionary[String, PackedScene] = {}
var _loading_scene := false


func _init(services: ServiceLocator, registry: ViewRegistry, facade: CanvasLayer) -> void:
	_services = weakref(services)
	_registry = registry
	_facade = facade
	for layer_name in LAYER_NAMES:
		var layer := Control.new()
		layer.name = layer_name
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_facade.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 预加载并持有已登记的 [PackedScene]。实例化组件和执行生命周期留到实际打开时。
func preload_async(path: String) -> bool:
	path = path.simplify_path()
	if _registry.get_view(path) == null:
		push_warning("视图未登记：%s" % path)
		return false
	var scene := await _load_scene_resource(path)
	if scene == null:
		return false
	_preloaded[path] = scene
	return true


## 等待完整加载，失败时返回 [code]null[/code]。同路径的并发调用共用结果。
## [param configure] 仅由首个请求执行，在创建组件前设置 View 参数。
## [param on_component_ready] 在组件进树并绑定所属 View 后、组件赋给 [code]View.component[/code] 前执行。
## 组件就绪后加入的回调立即执行。已活动的 View 直接返回，跳过两个回调。
func load_async(path: String, configure := Callable(), on_component_ready := Callable()) -> BaseView:
	path = path.simplify_path()
	var definition := _registry.get_view(path)
	if definition == null:
		push_warning("视图未登记：%s" % path)
		return null
	if _active_views.has(path):
		return _active_views[path]
	var pending: ViewLoad = _loads.get(path)
	if pending != null:
		pending.add_ready_callback(on_component_ready)
		return await pending.completed

	var is_scene := definition.layer == &""
	if is_scene and _loading_scene:
		push_warning("另一个场景视图正在加载：%s" % path)
		return null
	var operation := ViewLoad.new()
	operation.add_ready_callback(on_component_ready)
	_loads[path] = operation
	if is_scene:
		_loading_scene = true
	var view := await _load_view(definition, configure, operation)
	if is_scene:
		_loading_scene = false
	_loads.erase(path)
	if view == null:
		var failed_view: BaseView = _views.get(path)
		if failed_view != null:
			_release_view(path, failed_view.component)
	elif operation.unload_requested:
		unload(path)
	operation.completed.emit(view)
	return view


## 取得 View 实例，包括加载中或卸载后保留的缓存。通过 [method has] 检查是否活动。
func try_get(path: String) -> BaseView:
	return _views.get(path.simplify_path())


## 判断视图是否已完整加载并加入活动列表。
func has(path: String) -> bool:
	return _active_views.has(path.simplify_path())


## 判断该视图是否最后加入活动列表。画面层级由 [constant LAYER_NAMES] 对应的容器决定。
func is_top(path: String) -> bool:
	return not _active_views.is_empty() and _active_views.keys().back() == path.simplify_path()


## 卸载活动视图。加载中的视图会在完成后卸载。
## 公共 UI 组件会排队销毁，当前场景节点由 [SceneTree] 在切场景时释放。
func unload(path: String) -> void:
	path = path.simplify_path()
	var operation: ViewLoad = _loads.get(path)
	if operation != null:
		operation.unload_requested = true
		return
	var view: BaseView = _active_views.get(path)
	if view == null:
		return
	var component := view.component
	if view.definition.layer != &"" and is_instance_valid(component):
		(component as Control).hide()
		component.queue_free()
	_release_view(path, component)


## 按活动列表顺序更新 View。[param delta] 为上一帧经过的秒数。
func update(delta: float) -> void:
	for view in _active_views.values():
		view._update(delta)


func _load_view(definition: ViewDefinition, configure: Callable, operation: ViewLoad) -> BaseView:
	var path := definition.path
	var view := _create_view(definition)
	if view == null:
		return null
	_views[path] = view
	if configure.is_valid():
		configure.call(view)
	var business_directory := path.get_base_dir().get_base_dir()
	var services := _services.get_ref() as ServiceLocator
	if not await services.audio_service.load_clips_async(business_directory):
		return null
	view._prepare()

	var scene := await _load_scene_resource(path)
	if scene == null:
		return null
	var component := scene.instantiate()
	if component == null:
		return null
	if not _matches_component(definition, component):
		component.free()
		return null

	# 组件脚本通过校验后才进树，避免用不完整的组件替换当前场景。
	if not await _attach_component(component, definition.layer):
		component.free()
		return null
	if not is_instance_valid(component) or component.is_queued_for_deletion():
		return null
	component.set("view", view)
	operation.notify_component_ready()
	if not is_instance_valid(component) or component.is_queued_for_deletion():
		return null
	component.tree_exiting.connect(_release_view.bind(path, component), CONNECT_ONE_SHOT)
	await view._load(component)
	if not view.is_loaded or not is_instance_valid(component) or component.is_queued_for_deletion():
		return null
	_active_views[path] = view
	return view


func _load_scene_resource(path: String) -> PackedScene:
	if _preloaded.has(path):
		return _preloaded[path]
	var services := _services.get_ref() as ServiceLocator
	return await services.asset_service.load_async(path) as PackedScene


func _attach_component(component: Node, layer: StringName) -> bool:
	if layer == &"":
		var tree := _facade.get_tree()
		if tree.change_scene_to_node(component) != OK:
			return false
		await tree.scene_changed
		return true
	var parent := _facade.get_node_or_null(NodePath(layer))
	if parent == null or component is not Control:
		push_error("公共 UI 需要 Control 根节点和有效的层：%s" % component.scene_file_path)
		return false
	parent.add_child(component)
	return true


func _create_view(definition: ViewDefinition) -> BaseView:
	var cached: BaseView = _views.get(definition.path)
	if cached != null and cached.component == null:
		return cached
	var script := load(definition.view_script_path) as Script
	if script == null or not script.can_instantiate():
		push_error("无法创建 View：%s" % definition.path)
		return null
	var instance: Object = script.new()
	var view := instance as BaseView
	if view == null:
		if instance != null and instance is not RefCounted:
			instance.free()
		push_error("View 必须继承 BaseView：%s" % definition.path)
		return null
	view.definition = definition
	view.services = _services.get_ref() as ServiceLocator
	return view


func _matches_component(definition: ViewDefinition, component: Node) -> bool:
	var script := load(definition.component_script_path) as Script
	if script != null and is_instance_of(component, script) and "view" in component:
		return true
	push_error("视图根节点需要使用登记的 Component 脚本并声明 view 属性：%s" % definition.path)
	return false


func _release_view(path: String, component: Node) -> void:
	var view: BaseView = _views.get(path)
	if view == null or view.component != component:
		return
	_active_views.erase(path)
	# 缓存项保留纯脚本 View，组件引用和运行时状态交由 View 清理。
	if not view.definition.cache:
		_views.erase(path)
	view._unload()
