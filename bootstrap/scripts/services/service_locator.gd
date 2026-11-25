class_name ServiceLocator
## 创建并持有纯脚本服务，由常驻 Facade 提供引擎节点的宿主。

## 异步加载本地资源和远程纹理。
var asset_service: AssetService
## 缓存并播放音乐和音效。
var audio_service: AudioService
## 读取并保存共享配置表对象。
var config_service := ConfigService.new()
## 按视图键查询业务注册信息。
var view_registry: ViewRegistry
## 管理视图生命周期、实例缓存和公共 UI 容器。
var view_service: ViewService


func _init(facade: CanvasLayer, registrations: Array[ViewDefinition]) -> void:
	asset_service = AssetService.new(facade)
	audio_service = AudioService.new(asset_service, facade)
	view_registry = ViewRegistry.new(registrations)
	view_service = ViewService.new(self, view_registry, facade)


## 由 Facade 逐帧转发，以更新活动视图。
func update(delta: float) -> void:
	view_service.update(delta)
