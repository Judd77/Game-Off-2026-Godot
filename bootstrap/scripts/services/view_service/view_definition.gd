class_name ViewDefinition
## 登记一个 View 的场景资源、业务脚本和加载策略。

## 场景资源路径，也是 ViewService 查询与加载时使用的键。
var path: String
## 用于创建纯脚本 View 实例的脚本路径。
var view_script_path: String
## 场景根节点应使用的 Component 脚本路径。
var component_script_path: String
## 空层名表示切换当前场景。有层名时，将界面挂到 Facade 下的同名容器。
var layer: StringName
## 卸载后保留 View 实例，重新打开时加载新的组件。
var cache: bool


## 场景 View 使用空层名，公共 UI View 指定挂载层。
func _init(
	scene_path: String, view_script: String, component_script: String, ui_layer: StringName = &"", cache_view: bool = true,
) -> void:
	path = scene_path.simplify_path()
	view_script_path = view_script
	component_script_path = component_script
	layer = ui_layer
	cache = cache_view
