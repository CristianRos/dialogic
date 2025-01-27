@tool
class_name DialogicConditionEvent
extends DialogicEvent

## Event that allows branching a timeline based on a condition.

enum ConditionTypes {IF, ELIF, ELSE}

### Settings
## condition type (see [ConditionTypes]). Defaults to if.
var condition_type := ConditionTypes.IF
## The condition as a string. Will be executed as an Expression.
var condition: String = ""


################################################################################
## 						EXECUTE
################################################################################

func _execute() -> void:
	if condition_type == ConditionTypes.ELSE:
		finish()
		return
	
	if condition.is_empty(): condition = "true"
	
	var result :bool= dialogic.Expression.execute_condition(condition)
	if not result:
		var idx :int= dialogic.current_event_idx
		var ignore := 1
		while true:
			idx += 1
			if not dialogic.current_timeline.get_event(idx) or ignore == 0:
				break
			elif dialogic.current_timeline.get_event(idx).can_contain_events:
				ignore += 1
			elif dialogic.current_timeline.get_event(idx) is DialogicEndBranchEvent:
				ignore -= 1
		
		dialogic.current_event_idx = idx-1
	finish()


## only called if the previous event was an end-branch event
## return true if this event should be executed if the previous event was an end-branch event
func should_execute_this_branch() -> bool:
	return condition_type == ConditionTypes.IF


################################################################################
## 						INITIALIZE
################################################################################

func _init() -> void:
	event_name = "Condition"
	set_default_color('Color3')
	event_category = "Flow"
	event_sorting_index = 1
	can_contain_events = true
	continue_at_end = true


# return a control node that should show on the END BRANCH node
func get_end_branch_control() -> Control:
	return load(get_script().resource_path.get_base_dir().path_join('ui_condition_end.tscn')).instantiate()

################################################################################
## 						SAVING/LOADING
################################################################################

func to_text() -> String:
	var result_string := ""
	
	match condition_type:
		ConditionTypes.IF:
			result_string = 'if '+condition+':'
		ConditionTypes.ELIF:
			result_string = 'elif '+condition+':'
		ConditionTypes.ELSE:
			result_string = 'else:'
	
	return result_string


func from_text(string:String) -> void:
	if string.strip_edges().begins_with('if'):
		condition = string.strip_edges().trim_prefix('if ').trim_suffix(':').strip_edges()
		condition_type = ConditionTypes.IF
	elif string.strip_edges().begins_with('elif'):
		condition = string.strip_edges().trim_prefix('elif ').trim_suffix(':').strip_edges()
		condition_type = ConditionTypes.ELIF
	elif string.strip_edges().begins_with('else'):
		condition = ""
		condition_type = ConditionTypes.ELSE


func is_valid_event(string:String) -> bool:
	if (string.strip_edges().begins_with('if ') or string.strip_edges().begins_with('elif ') or string.strip_edges().begins_with('else')) and string.strip_edges().ends_with(':'):
		return true
	return false


################################################################################
## 						EDITOR REPRESENTATION
################################################################################

func build_event_editor():
	add_header_edit('condition_type', ValueType.FIXED_OPTION_SELECTOR, '', '', {
		'selector_options': [
			{
				'label': 'IF',
				'value': ConditionTypes.IF,
			},
			{
				'label': 'ELIF',
				'value': ConditionTypes.ELIF,
			},
			{
				'label': 'ELSE',
				'value': ConditionTypes.ELSE,
			}
		], 'disabled':true})
	add_header_edit('condition', ValueType.CONDITION, '', '', {}, 'condition_type != %s'%ConditionTypes.ELSE)
