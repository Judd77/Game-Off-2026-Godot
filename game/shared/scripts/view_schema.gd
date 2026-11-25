class_name ViewSchema
## 提供框架启动所需的共享目录、入口场景、预加载清单和视图注册。

const ENTRY_SCENE := ViewKeys.LOBBY_DEMO
const SHARED_DIRECTORY := "res://game/shared"
const CONFIG_DIRECTORY := SHARED_DIRECTORY + "/configs"
const PRELOAD_VIEWS: Array[String] = []


## 注册视图对应的场景、纯脚本 View 和场景根节点组件。
static func create_views() -> Array[ViewDefinition]:
	return [
		ViewDefinition.new(
			ViewKeys.LOBBY_DEMO,
			"res://game/out_game/lobby_demo/scripts/lobby_demo_view.gd",
			"res://game/out_game/lobby_demo/scripts/lobby_demo_component.gd",
		),
		ViewDefinition.new(
			ViewKeys.BAG_DEMO,
			"res://game/out_game/bag_demo/scripts/bag_demo_view.gd",
			"res://game/out_game/bag_demo/scripts/bag_demo_component.gd",
			&"Popup",
		),
		ViewDefinition.new(
			ViewKeys.GAME_DEMO,
			"res://game/in_game/game_demo/scripts/game_demo_view.gd",
			"res://game/in_game/game_demo/scripts/game_demo_component.gd",
		),
	]


## 接收按表名读取 JSON 行的回调，创建 Luban 生成的表对象。
static func create_tables(load_rows: Callable) -> Schema.Tables:
	return Schema.Tables.new(load_rows)
