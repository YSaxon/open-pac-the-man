class_name PlistXml
extends RefCounted


func parse(bytes: PackedByteArray) -> Dictionary:
	var parser := XMLParser.new()
	var open_error := parser.open_buffer(bytes)
	if open_error != OK:
		return {"error": "Could not open XML property list (error %d)" % open_error}

	var stack: Array[Dictionary] = []
	var root := {"is_set": false, "value": null}
	var scalar_tag := ""
	var scalar_text := ""

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				if tag == "dict" or tag == "array":
					var frame := {
						"kind": tag,
						"value": {} if tag == "dict" else [],
						"pending_key": "",
					}
					if parser.is_empty():
						_append_value(stack, root, frame["value"])
					else:
						stack.append(frame)
				elif tag in ["key", "string", "integer", "real", "data", "date"]:
					scalar_tag = tag
					scalar_text = ""
					if parser.is_empty():
						_finish_scalar(stack, root, scalar_tag, scalar_text)
						scalar_tag = ""
				elif tag == "true" or tag == "false":
					_append_value(stack, root, tag == "true")
			XMLParser.NODE_TEXT:
				if not scalar_tag.is_empty():
					scalar_text += parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				var tag := parser.get_node_name()
				if tag == scalar_tag:
					_finish_scalar(stack, root, scalar_tag, scalar_text)
					scalar_tag = ""
					scalar_text = ""
				elif tag == "dict" or tag == "array":
					if stack.is_empty() or stack[-1]["kind"] != tag:
						return {"error": "Malformed property-list container"}
					var completed: Dictionary = stack.pop_back()
					_append_value(stack, root, completed["value"])

	if not root["is_set"]:
		return {"error": "Property list has no root value"}
	if not stack.is_empty():
		return {"error": "Property list has unclosed containers"}
	return {"value": root["value"]}


func _finish_scalar(stack: Array[Dictionary], root: Dictionary, tag: String, text: String) -> void:
	if tag == "key":
		if not stack.is_empty() and stack[-1]["kind"] == "dict":
			stack[-1]["pending_key"] = text
		return
	var value: Variant = text
	match tag:
		"integer":
			value = int(text.strip_edges())
		"real":
			value = float(text.strip_edges())
		"data":
			value = Marshalls.base64_to_raw(text.strip_edges())
	_append_value(stack, root, value)


func _append_value(stack: Array[Dictionary], root: Dictionary, value: Variant) -> void:
	if stack.is_empty():
		root["value"] = value
		root["is_set"] = true
		return
	var parent: Dictionary = stack[-1]
	if parent["kind"] == "array":
		parent["value"].append(value)
	else:
		var key: String = parent["pending_key"]
		if key.is_empty():
			return
		parent["value"][key] = value
		parent["pending_key"] = ""

