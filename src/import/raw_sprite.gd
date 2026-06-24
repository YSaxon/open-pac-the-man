class_name RawSprite
extends RefCounted

const HEADER_SIZE := 12
const MAX_DIMENSION := 8192


func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE:
		return {"error": "Raw sprite is shorter than its header"}
	var width := _u32_be(bytes, 0)
	var height := _u32_be(bytes, 4)
	var bits_per_pixel := _u32_be(bytes, 8)
	if width <= 0 or height <= 0 or width > MAX_DIMENSION or height > MAX_DIMENSION:
		return {"error": "Invalid raw sprite dimensions %dx%d" % [width, height]}
	if bits_per_pixel != 24 and bits_per_pixel != 32:
		return {"error": "Unsupported raw sprite depth %d" % bits_per_pixel}
	var bytes_per_pixel := bits_per_pixel / 8
	var expected_size := HEADER_SIZE + width * height * bytes_per_pixel
	if bytes.size() != expected_size:
		return {"error": "Raw sprite has %d bytes; expected %d" % [bytes.size(), expected_size]}
	var pixels := bytes.slice(HEADER_SIZE)
	var format := Image.FORMAT_RGB8 if bits_per_pixel == 24 else Image.FORMAT_RGBA8
	var image := Image.create_from_data(width, height, false, format, pixels)
	if image == null or image.is_empty():
		return {"error": "Godot could not create an image from raw sprite data"}
	return {
		"image": image,
		"width": width,
		"height": height,
		"bits_per_pixel": bits_per_pixel,
	}


func _u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)
