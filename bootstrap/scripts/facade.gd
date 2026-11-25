class_name Facade
extends CanvasLayer
## Bootstrap 的公共 UI 层，负责初始化服务并加载业务入口。
## 切场景前移到 /root，让服务和下属 UI 容器跨场景保留。

## 此次游戏运行共用的服务入口。
var services: ServiceLocator


func _ready() -> void:
	services = ServiceLocator.new(self, ViewSchema.create_views())
	if services.view_registry.get_view(ViewSchema.ENTRY_SCENE) == null:
		push_error("入口视图未登记：%s" % ViewSchema.ENTRY_SCENE)
		return

	# 等 Bootstrap 入树完成，再启动可能触发换场的加载流程。
	await get_tree().process_frame
	# 配表、共享音频和已登记的预加载全部完成后才能打开业务入口。
	if not services.config_service.load_config(ViewSchema.CONFIG_DIRECTORY, ViewSchema.create_tables):
		return
	if not await services.audio_service.load_clips_async(ViewSchema.SHARED_DIRECTORY):
		push_error("共享音频加载失败")
		return
	for path in ViewSchema.PRELOAD_VIEWS:
		if not await services.view_service.preload_async(path):
			push_error("视图预加载失败：%s" % path)
			return
	# 提前移走 Facade，让场景切换只释放 Bootstrap 和 Poster。
	reparent(get_tree().root)
	await services.view_service.load_async(ViewSchema.ENTRY_SCENE)


func _process(delta: float) -> void:
	services.update(delta)
