class_name AudioService
## 按业务目录缓存音频，分别管理背景音乐和可叠加的音效。


const SETTINGS_PATH := "user://audio.cfg"


class ClipLoad:
	signal completed(success: bool)
	var is_complete := false


## 背景音乐音量，范围为 0 到 1。修改后立即应用并保存。
var music_volume: float = 1.0:
	set(value):
		var volume := clampf(value, 0.0, 1.0)
		if music_volume == volume:
			return
		music_volume = volume
		if _music_player != null:
			_music_player.volume_db = linear_to_db(music_volume)
		if _host != null:
			_save_volumes()

## 音效音量，范围为 0 到 1。修改后也会更新正在播放的音效并保存。
var sound_volume: float = 1.0:
	set(value):
		var volume := clampf(value, 0.0, 1.0)
		if sound_volume == volume:
			return
		sound_volume = volume
		var volume_db := linear_to_db(sound_volume)
		for player in _sound_players:
			player.volume_db = volume_db
		if _host != null:
			_save_volumes()

var _assets: AssetService
var _host: Node
var _music_player: AudioStreamPlayer
var _sound_players: Array[AudioStreamPlayer] = []
var _settings := ConfigFile.new()
var _clips: Dictionary[String, AudioStream] = {}
var _clip_loads: Dictionary[String, ClipLoad] = {}
var _music_clip: AudioStream
var _loop_enabled := true


func _init(assets: AssetService, host: Node) -> void:
	_assets = assets
	if _settings.load(SETTINGS_PATH) == OK:
		music_volume = float(_settings.get_value("Audio", "music_volume", music_volume))
		sound_volume = float(_settings.get_value("Audio", "sound_volume", sound_volume))
	_host = host


## 异步加载业务目录下的 audios。同一目录共享加载结果，失败返回 false，可重试。
## 播放键使用不含扩展名的文件名，所有已加载音频的播放键必须唯一。
func load_clips_async(directory: String) -> bool:
	directory = directory.simplify_path()
	var clip_load: ClipLoad = _clip_loads.get(directory)
	if clip_load != null:
		if clip_load.is_complete:
			return true
		return await clip_load.completed

	clip_load = ClipLoad.new()
	_clip_loads[directory] = clip_load
	var resources: Variant = await _assets.load_audio_clips_async(directory)
	clip_load.is_complete = resources != null and _register_clips(resources)
	if not clip_load.is_complete:
		_clip_loads.erase(directory)
	clip_load.completed.emit(clip_load.is_complete)
	return clip_load.is_complete


func _register_clips(resources: Array[Resource]) -> bool:
	var loaded: Dictionary[String, AudioStream] = {}
	for stream: AudioStream in resources:
		var clip_name := stream.resource_path.get_file().get_basename()
		if _clips.has(clip_name) or loaded.has(clip_name):
			push_warning("音频名称重复：%s" % clip_name)
			return false
		loaded[clip_name] = stream
	_clips.merge(loaded)
	return true


## 使用预加载的播放键播放音乐，默认循环。按需创建并复用一个播放器。
## 播放键不存在或同一音乐正在播放时返回 false。
func play_music(clip_name: String, loop: bool = true) -> bool:
	var stream: AudioStream = _clips.get(clip_name)
	if stream == null or (_music_clip == stream and _music_player.playing):
		return false

	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "Music"
		_music_player.volume_db = linear_to_db(music_volume)
		_music_player.finished.connect(_on_music_finished)
		_host.add_child(_music_player, false, Node.INTERNAL_MODE_BACK)

	_music_clip = stream
	_loop_enabled = loop
	_music_player.stream = stream if loop else _one_shot_stream(stream)
	_music_player.play()
	return true


## 停止当前背景音乐，保留已加载的音频和播放器供下次使用。
func stop_music() -> void:
	if _music_player == null:
		return

	_music_player.stop()
	_music_player.stream = null
	_music_clip = null


## 使用预加载的播放键播放一次音效，优先复用空闲播放器，支持叠加播放。
func play_sound(clip_name: String) -> void:
	var stream: AudioStream = _clips.get(clip_name)
	if stream == null:
		return

	var player := _get_sound_player()
	player.stream = _one_shot_stream(stream)
	player.play()


func _get_sound_player() -> AudioStreamPlayer:
	# 播放结束后才清空 stream，因此暂停中的播放器也不会被抢占。
	for player in _sound_players:
		if player.stream == null:
			return player

	var player := AudioStreamPlayer.new()
	player.name = "Sound"
	player.volume_db = linear_to_db(sound_volume)
	player.finished.connect(_on_sound_finished.bind(player))
	_sound_players.append(player)
	_host.add_child(player, false, Node.INTERNAL_MODE_BACK)
	return player


# 只复制设置了循环的内建音频，避免更改其他使用者持有的资源。
func _one_shot_stream(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		var wave := stream.duplicate() as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return wave
	if (stream is AudioStreamMP3 or stream is AudioStreamOggVorbis) and stream.get("loop"):
		var one_shot := stream.duplicate() as AudioStream
		one_shot.set("loop", false)
		return one_shot
	return stream


func _on_music_finished() -> void:
	if _loop_enabled:
		_music_player.play()
	else:
		stop_music()


func _on_sound_finished(player: AudioStreamPlayer) -> void:
	player.stream = null


func _save_volumes() -> void:
	_settings.set_value("Audio", "music_volume", music_volume)
	_settings.set_value("Audio", "sound_volume", sound_volume)
	var save_error := _settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("音量设置保存失败（错误 %s）" % save_error)
