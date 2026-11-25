class_name AssetService
## 统一加载项目资源和远程图片。调用方通过持有引用保留已加载的资源。


class PendingLoad:
	signal completed(resource: Resource)


var _host: Node
var _pending: Dictionary[String, PendingLoad] = {}
var _idle_http_requests: Array[HTTPRequest] = []


func _init(host: Node) -> void:
	_host = host


## 异步加载 res:// 路径下的资源。相同路径的并发请求共用一次加载，失败返回 null。
func load_async(path: String) -> Resource:
	if not path.begins_with("res://"):
		push_warning("资源路径需要以 res:// 开头：%s" % path)
		return null

	path = path.simplify_path()
	var pending: PendingLoad = _pending.get(path)
	if pending != null:
		return await pending.completed

	if not ResourceLoader.exists(path):
		push_warning("找不到资源：%s" % path)
		return null

	pending = PendingLoad.new()
	_pending[path] = pending
	var resource: Resource
	var request_error := ResourceLoader.load_threaded_request(path)
	if request_error == OK:
		var status := ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await _host.get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path)

		# 也取出失败请求的结果，让同一路径可重试。
		if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			resource = ResourceLoader.load_threaded_get(path)
	else:
		push_warning("无法开始加载资源 %s（错误 %s）" % [path, request_error])

	_pending.erase(path)
	pending.completed.emit(resource)
	return resource


## 递归加载项目目录中的资源。type_hint 为空时加载所有类型。
## 目录不存在时返回空数组，任一资源加载失败时返回 null。
func load_directory_async(directory: String, type_hint: String = "") -> Variant:
	if not directory.begins_with("res://"):
		push_warning("资源目录需要以 res:// 开头：%s" % directory)
		return null

	var resources: Array[Resource] = []
	directory = directory.simplify_path()
	if not DirAccess.dir_exists_absolute(directory):
		return resources

	for path in _list_resource_paths(directory, type_hint):
		var resource := await load_async(path)
		if resource == null:
			return null
		if type_hint.is_empty() or resource.is_class(type_hint):
			resources.append(resource)
	return resources


## 加载业务目录下 audios 中的全部 AudioStream。
func load_audio_clips_async(directory: String) -> Variant:
	return await load_directory_async(directory.path_join("audios"), "AudioStream")


## 下载 PNG 或 JPEG 并创建纹理，下载或解码失败时返回 null。
## 优先复用空闲的 HTTPRequest 节点，每个进行中的下载独占一个节点。
func load_remote_texture_async(url: String) -> Texture2D:
	var request := _take_http_request()
	var request_error := request.request(url)
	# ERR_CANT_CONNECT 也会收到引擎延迟发出的完成信号。
	if request_error != OK and request_error != ERR_CANT_CONNECT:
		request.cancel_request()
		_idle_http_requests.append(request)
		push_warning("无法开始下载远程图片（错误 %s）" % request_error)
		return null

	var response: Array = await request.request_completed
	# 等本帧可能已排队的超时通知处理完，再把节点交给下一个请求。
	await _host.get_tree().process_frame
	_idle_http_requests.append(request)
	var status_code: int = response[1]
	if response[0] != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300:
		push_warning("远程图片下载失败（结果 %s，HTTP %s）" % [response[0], status_code])
		return null

	var body: PackedByteArray = response[3]
	var image := Image.new()
	var decode_error := ERR_FILE_UNRECOGNIZED
	if body.size() >= 8 and body[0] == 0x89 and body.slice(1, 4).get_string_from_ascii() == "PNG":
		decode_error = image.load_png_from_buffer(body)
	elif body.size() >= 3 and body[0] == 0xff and body[1] == 0xd8 and body[2] == 0xff:
		decode_error = image.load_jpg_from_buffer(body)

	if decode_error != OK:
		push_warning("远程图片无法按 PNG 或 JPEG 解码（错误 %s）" % decode_error)
		return null

	return ImageTexture.create_from_image(image)


func _take_http_request() -> HTTPRequest:
	if not _idle_http_requests.is_empty():
		return _idle_http_requests.pop_back()

	var request := HTTPRequest.new()
	request.timeout = 20.0
	_host.add_child(request, false, Node.INTERNAL_MODE_BACK)
	return request


func _list_resource_paths(directory: String, type_hint: String) -> Array[String]:
	var paths: Array[String] = []
	for entry in ResourceLoader.list_directory(directory):
		var path := directory.path_join(entry)
		if entry.ends_with("/"):
			paths.append_array(_list_resource_paths(path, type_hint))
		elif ResourceLoader.exists(path, type_hint):
			paths.append(path)
	return paths
