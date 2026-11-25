class_name ConfigService
## 读取 JSON 配置，由业务提供的工厂创建配置表。

## 整批配置加载成功后可用，加载成功前为 null。
var tables: RefCounted


## 为工厂提供按表名读取 JSON 行数组的函数。成功后缓存结果，失败返回 false，可重试。
func load_config(directory: String, create_tables: Callable) -> bool:
	if tables != null:
		return true

	var errors: Array[String] = []
	# 先收集整批读取错误，成功后再将表对象交给调用方。
	var loaded_tables := create_tables.call(
		func(table_name: String) -> Array: return _load_rows(directory, table_name, errors)
	) as RefCounted
	if loaded_tables == null and errors.is_empty():
		errors.append("配表工厂未返回表对象")
	if not errors.is_empty():
		push_error("配置表加载失败\n" + "\n".join(errors))
		return false

	tables = loaded_tables
	return true


static func _load_rows(directory: String, table_name: String, errors: Array[String]) -> Array:
	var path := directory.path_join(table_name + ".json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s 无法读取（%s）" % [path, error_string(FileAccess.get_open_error())])
		return []

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		errors.append("%s 第 %d 行：%s" % [path, json.get_error_line(), json.get_error_message()])
		return []
	if not json.data is Array:
		errors.append("%s 应包含数据行数组" % path)
		return []
	return json.data
