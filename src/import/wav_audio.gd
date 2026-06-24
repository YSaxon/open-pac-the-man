class_name WavAudio
extends RefCounted


func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 44 or _text(bytes, 0, 4) != "RIFF" or _text(bytes, 8, 4) != "WAVE":
		return {"error": "Not a RIFF/WAVE stream"}
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var format_tag := 0
	var samples := PackedByteArray()
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_name := _text(bytes, offset, 4)
		var chunk_size := _u32_le(bytes, offset + 4)
		var chunk_start := offset + 8
		if chunk_start + chunk_size > bytes.size():
			return {"error": "Truncated WAV chunk %s" % chunk_name}
		if chunk_name == "fmt " and chunk_size >= 16:
			format_tag = _u16_le(bytes, chunk_start)
			channels = _u16_le(bytes, chunk_start + 2)
			sample_rate = _u32_le(bytes, chunk_start + 4)
			bits_per_sample = _u16_le(bytes, chunk_start + 14)
		elif chunk_name == "data":
			samples = bytes.slice(chunk_start, chunk_start + chunk_size)
		offset = chunk_start + chunk_size + (chunk_size & 1)
	if format_tag != 1:
		return {"error": "Unsupported WAV encoding %d" % format_tag}
	if channels < 1 or channels > 2 or sample_rate <= 0 or bits_per_sample not in [8, 16]:
		return {"error": "Unsupported WAV format"}
	if samples.is_empty():
		return {"error": "WAV has no sample data"}
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS if bits_per_sample == 8 else AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = samples
	return {
		"stream": stream,
		"channels": channels,
		"sample_rate": sample_rate,
		"bits_per_sample": bits_per_sample,
	}


func _text(bytes: PackedByteArray, offset: int, length: int) -> String:
	return bytes.slice(offset, offset + length).get_string_from_ascii()


func _u16_le(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)
