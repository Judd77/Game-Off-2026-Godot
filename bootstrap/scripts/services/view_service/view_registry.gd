class_name ViewRegistry
## 保存业务 Schema 提供的视图定义，以场景资源路径索引。

var _views: Dictionary[String, ViewDefinition] = {}


## 完整校验后再发布视图清单，避免启动过程中使用部分登记的定义。
func _init(definitions: Array[ViewDefinition]) -> void:
	var views: Dictionary[String, ViewDefinition] = {}
	for definition in definitions:
		if definition == null or definition.path.is_empty():
			push_error("视图定义缺少场景路径")
			return
		if views.has(definition.path):
			push_error("视图重复登记：%s" % definition.path)
			return
		views[definition.path] = definition
	_views = views


## 按登记路径查询定义。没有匹配项时返回 [code]null[/code]。
func get_view(path: String) -> ViewDefinition:
	return _views.get(path)
