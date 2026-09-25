extends AudioStreamPlayer
## The looping jungle bed — wind, insects and the odd bird.
##
## The loop is switched on HERE, at runtime, not in the import settings.
## audio/ambient.wav.import has edit/loop_mode=1 and Godot still loads the
## resource with loop_mode = 0 (verified with tools/audit.tscn), so the import
## setting cannot be relied on.
##
## The file is imported UNCOMPRESSED (compress/mode=0) for two reasons: the
## loop point is a hand-made crossfade between the tail and the head and a
## lossy codec can drop a click right on it, and the frame maths below is only
## valid for plain 16-bit PCM.


func _ready() -> void:
	var source: AudioStreamWAV = preload("res://audio/ambient.wav")
	# duplicate() so we never mutate the shared imported resource.
	var looped: AudioStreamWAV = source.duplicate()
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	# 16-bit mono = 2 bytes per frame. This would be WRONG for a QOA or
	# ADPCM import, which is the other reason the file is uncompressed.
	looped.loop_end = looped.data.size() / 2
	stream = looped
	volume_db = -19.0
	play()
