@tool
extends SyntaxHighlighter

## Syntax highlighter for the dialogic text timeline editor and text events in the visual editor.

enum Modes {TEXT_EVENT_ONLY, FULL_HIGHLIGHTING}
var mode := Modes.FULL_HIGHLIGHTING


## RegEx's
var word_regex := RegEx.new()
var region_regex := RegEx.new()
var text_event_regex := RegEx.new()
var character_event_regex := RegEx.new()
var shortcode_regex := RegEx.new()
var shortcode_param_regex := RegEx.new()
var text_effects_regex := RegEx.new()
var text_random_word_regex := RegEx.new()
var settings_event_regex := RegEx.new()

## Colors
var normal_color : Color 
var comment_color : Color
var text_effect_color : Color
var choice_color : Color
var translation_id_color: Color

var code_flow_color : Color 
var boolean_operator_color : Color
var variable_color : Color
var string_color : Color

var keyword_VAR_color : Color
var keyword_SETTING_color : Color
var keyword_label_color : Color
var keyword_return_color : Color

var character_event_color : Color
var character_name_color : Color
var character_portrait_color : Color

var shortcode_color : Color
var shortcode_param_color : Color
var shortcode_value_color : Color

var shortcode_events := {}

func _init():
	# Load colors from editor settings
	if DialogicUtil.get_dialogic_plugin():
		var editor_settings = DialogicUtil.get_dialogic_plugin().get_editor_interface().get_editor_settings()
		normal_color = editor_settings.get('text_editor/theme/highlighting/text_color')
		comment_color = editor_settings.get('text_editor/theme/highlighting/comment_color')
		text_effect_color = normal_color.darkened(0.2)
		choice_color = DialogicUtil.get_color('Color3').lerp(normal_color, 0.5)
		translation_id_color = editor_settings.get('text_editor/theme/highlighting/comment_color')
		
		code_flow_color = editor_settings.get("text_editor/theme/highlighting/control_flow_keyword_color")
		boolean_operator_color = code_flow_color.lightened(0.5)
		variable_color = editor_settings.get('text_editor/theme/highlighting/engine_type_color')
		string_color = editor_settings.get('text_editor/theme/highlighting/string_color')

		shortcode_color =  editor_settings.get('text_editor/theme/highlighting/gdscript/annotation_color')
		shortcode_param_color = editor_settings.get('text_editor/theme/highlighting/gdscript/node_path_color')
		shortcode_value_color = editor_settings.get('text_editor/theme/highlighting/gdscript/node_reference_color')

		keyword_VAR_color = editor_settings.get('text_editor/theme/highlighting/keyword_color')
		keyword_SETTING_color = editor_settings.get('text_editor/theme/highlighting/member_variable_color')
		keyword_label_color = DialogicUtil.get_color('Color7').lerp(normal_color, 0.2)
		keyword_return_color = DialogicUtil.get_color('Color7').lerp(normal_color, 0.2)
		
		character_event_color = DialogicUtil.get_color('Color2').lerp(normal_color, 0.5)
		character_name_color = DialogicUtil.get_color('Color2').lerp(normal_color, 0.7)
		character_portrait_color = DialogicUtil.get_color('Color2').lerp(normal_color, 0.8)
	
	shortcode_regex.compile("\\W*\\[(?<id>\\w*)(?<args>[^\\]]*)?")
	shortcode_param_regex.compile('((?<parameter>[^\\s=]*)\\s*=\\s*"(?<value>([^=]|\\\\=)*)(?<!\\\\)")')
	text_event_regex.compile("\\W*((\")?(?<name>(?(2)[^\"\\n]*|[^(: \\n]*))(?(2)\"|)(\\W*\\((?<portrait>.*)\\))?\\s*(?<!\\\\):)?(?<text>.*)")
	var text_effects := ""
	for idx in DialogicUtil.get_indexers():
		for effect in idx._get_text_effects():
			text_effects+= effect['command']+'|'
	text_effects += "b|i|u|s|code|p|center|left|right|fill|indent|url|img|font|font_size|opentype_features|color|bg_color|fg_color|outline_size|outline_color|table|cell|ul|ol|lb|rb|br"
	text_effects_regex.compile("(?<!\\\\)\\[\\s*/?(?<command>"+text_effects+")\\s*(=\\s*(?<value>.+?)\\s*)?\\]")
	character_event_regex.compile("(?<type>Join|Update|Leave)\\s*(\")?(?<name>(?(2)[^\"\\n]*|[^(: \\n]*))(?(2)\"|)(\\W*\\((?<portrait>.*)\\))?(\\s*(?<position>\\d))?(\\s*\\[(?<shortcode>.*)\\])?")
	text_random_word_regex.compile("(?<!\\\\)\\<[^\\[\\>]+(\\/[^\\>]*)\\>")


func _get_line_syntax_highlighting(line:int) -> Dictionary:
	var str_line := get_text_edit().get_line(line)
	
	if shortcode_events.is_empty():
		for event in Engine.get_main_loop().get_meta('dialogic_event_cache', []):
			if event.get_shortcode() != 'default_shortcode':
				shortcode_events[event.get_shortcode()] = event
	
	var dict := {}
	dict[0] = {'color':normal_color}

	dict = color_translation_id(dict, str_line)
	
	if mode == Modes.FULL_HIGHLIGHTING:
		if str_line.strip_edges().begins_with('#'):
			dict[0] = {'color':comment_color}
			return fix_dict(dict)
		
		if str_line.strip_edges().begins_with("["):
			if !text_effects_regex.search(str_line.get_slice(' ', 0)):
				var result:= shortcode_regex.search(str_line)
				if result:
					if result.get_string('id') in shortcode_events:
						dict[result.get_start('id')] = {"color":shortcode_events[result.get_string('id')].event_color.lerp(normal_color, 0.2)}
						dict[result.get_end('id')] = {"color":normal_color}
					
					if result.get_string('args'):
						color_shortcode_content(dict, str_line, result.get_start('args'), result.get_end('args'), shortcode_events[result.get_string('id')].event_color)
				return fix_dict(dict)
		
		if str_line.strip_edges().begins_with('-'):
			dict[0] = {'color':choice_color}
			if '[' in str_line:
				dict[str_line.find('[')] = {"color":normal_color}
				dict = color_word(dict, code_flow_color, str_line, 'if', str_line.find('['), str_line.find(']'))
				dict = color_condition(dict, str_line, str_line.find('['), str_line.find(']'))
				dict = color_shortcode_content(dict, str_line, str_line.find(']'))
			return fix_dict(dict)
		
		for word in ['if', 'elif', 'else']:
			if str_line.strip_edges().begins_with(word):
				dict[str_line.find(word)] = {"color":code_flow_color}
				dict[str_line.find(word)+len(word)] = {"color":normal_color}
				dict = color_condition(dict, str_line)
				return fix_dict(dict)
		
		for word in ['Join', 'Update', 'Leave']:
			if str_line.strip_edges().begins_with(word):
				dict[str_line.find(word)] = {"color":character_event_color}
				dict[str_line.find(word)+len(word)] = {"color":normal_color}
				var result := character_event_regex.search(str_line)
				if result.get_string('name'):
					dict[result.get_start('name')] = {"color":character_name_color}
					dict[result.get_end('name')] = {"color":normal_color}
				if result.get_string('portrait'):
					dict[result.get_start('portrait')] = {"color":character_portrait_color}
					dict[result.get_end('portrait')] = {"color":normal_color}
				if result.get_string('shortcode'):
					dict = color_shortcode_content(dict, str_line, result.get_start('shortcode'), result.get_end('shortcode'))
				return fix_dict(dict)
		
		if str_line.strip_edges().begins_with('VAR'):
			dict[str_line.find('VAR')] = {"color":keyword_VAR_color}
			dict[str_line.find('VAR')+3] = {"color":normal_color}
			dict = color_region(dict, string_color, str_line, '"', '"', str_line.find('VAR'))
			dict = color_region(dict, variable_color, str_line, '{', '}', str_line.find('VAR'))
			return fix_dict(dict)
		
		if str_line.strip_edges().begins_with('label'):
			dict[str_line.find('label')] = {"color":keyword_label_color}
			dict[str_line.find('label')+5] = {"color":keyword_label_color.lerp(normal_color, 0.3)}
		
		if str_line.strip_edges().begins_with('return'):
			dict[str_line.find('return')] = {"color":keyword_return_color}
			dict[str_line.find('return')+6] = {"color":keyword_return_color.lerp(normal_color, 0.3)}
		
		
		if str_line.strip_edges().begins_with('jump'):
			dict[str_line.find('jump')] = {"color":keyword_label_color}
			dict[str_line.find('jump')+4] = {"color":keyword_label_color.lerp(normal_color, 0.3)}
		
		
		if str_line.strip_edges().begins_with('Setting'):
			dict[str_line.find('Setting')] = {"color":keyword_SETTING_color}
			dict[str_line.find('Setting')+7] = {"color":normal_color}
			dict = color_word(dict, keyword_SETTING_color, str_line, 'reset')
			dict = color_region(dict, string_color, str_line, '"', '"')
			dict = color_region(dict, variable_color, str_line, '{', '}')
			return fix_dict(dict)
	
	
	var result := text_event_regex.search(str_line)
	if !result:
		return fix_dict(dict)
	if mode == Modes.FULL_HIGHLIGHTING:
		if result.get_string('name'):
			dict[result.get_start('name')] = {"color":character_name_color}
			dict[result.get_end('name')] = {"color":normal_color}
		if result.get_string('portrait'):
			dict[result.get_start('portrait')] = {"color":character_portrait_color}
			dict[result.get_end('portrait')] = {"color":normal_color}
	if result.get_string('text'):
		var effects_result := text_effects_regex.search_all(str_line)
		for eff in effects_result:
			dict[eff.get_start()] = {"color":text_effect_color}
			dict[eff.get_end()] = {"color":normal_color}
		dict = color_region(dict, variable_color, str_line, '{', '}', result.get_start('text'))
		
		for replace_mod_match in text_random_word_regex.search_all(result.get_string('text')):
			var color := string_color
			color = color.lerp(normal_color, 0.4)
			dict[replace_mod_match.get_start()+result.get_start('text')] = {'color':string_color}
			var offset := 1
			for b in replace_mod_match.get_string().trim_suffix('>').trim_prefix('<').split('/'):
				color.h = wrap(color.h+0.2, 0, 1)
				dict[replace_mod_match.get_start()+result.get_start('text')+offset] = {'color':color}
				offset += len(b)
				dict[replace_mod_match.get_start()+result.get_start('text')+offset] = {'color':string_color}
				offset += 1
			dict[replace_mod_match.get_end()+result.get_start('text')] = {'color':normal_color}
	
	
	return fix_dict(dict)


func fix_dict(dict:Dictionary) -> Dictionary:
	var d := {}
	var k := dict.keys()
	k.sort()
	for i in k:
		d[i] = dict[i]
	return d


func color_condition(dict:Dictionary, line:String, from:int = 0, to:int = 0) -> Dictionary:
	dict = color_word(dict, code_flow_color, line, 'or',  from, to)
	dict = color_word(dict, code_flow_color, line, 'and', from, to)
	dict = color_word(dict, code_flow_color, line, '==',  from, to)
	dict = color_word(dict, code_flow_color, line, '!=',  from, to)
	dict = color_word(dict, code_flow_color, line, '>=',  from, to)
	dict = color_word(dict, code_flow_color, line, '<=',  from, to)
	dict = color_word(dict, code_flow_color, line, '> ',   from, to)
	dict = color_word(dict, code_flow_color, line, '< ',   from, to)
	dict = color_region(dict, variable_color, line, '{', '}', from, to)
	dict = color_region(dict, string_color, line, '"', '"', from, to)
	
	
	return dict


func color_translation_id(dict:Dictionary, line:String) -> Dictionary:
	dict = color_region(dict, translation_id_color, line, '#id:', '')
	return dict


func color_word(dict:Dictionary, color:Color, line:String, word:String, from:int= 0, to:int = 0) -> Dictionary:
	word_regex.compile("\\W(?<word>"+word+")\\W")
	if to <= from: 
		to = len(line)-1
	for i in word_regex.search_all(line.substr(from, to-from+2)):
		dict[i.get_start('word')+from] = {'color':color}
		dict[i.get_end('word')+from] = {'color':normal_color}
	return dict


func color_region(dict:Dictionary, color:Color, line:String, start:String, end:String, from:int = 0, to:int = 0) -> Dictionary:
	if end.is_empty():
		region_regex.compile("(?<!\\\\)"+start+".*")
	else:
		region_regex.compile("(?<!\\\\)"+start+"(.(?!"+end+"))*."+end)
	if to <= from: 
		to = len(line)-1
	for region in region_regex.search_all(line.substr(from, to-from+2)):
		dict[region.get_start()+from] = {'color':color}
		dict[region.get_end()+from] = {'color':normal_color}
	return dict


func color_shortcode_content(dict:Dictionary, line:String, from:int = 0, to:int = 0, base_color:=normal_color) -> Dictionary:
	if to <= from: 
		to = len(line)-1
	var args_result:= shortcode_param_regex.search_all(line.substr(from, to-from+2))
	for x in args_result:
		dict[x.get_start()+from] = {"color":base_color.lerp(normal_color, 0.5)}
		dict[x.get_start('value')+from-1] = {"color":base_color.lerp(normal_color, 0.7)}
		dict[x.get_end()+from] = {"color":normal_color}
	return dict
