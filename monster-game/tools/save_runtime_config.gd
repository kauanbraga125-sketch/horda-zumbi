extends SceneTree
# Export only the native binary project settings; Android templates are not needed.
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=1: push_error("Pass an absolute project.binary output path after --");quit(1);return
	var error=ProjectSettings.save_custom(args[0])
	if error!=OK: push_error("Project settings export failed: "+str(error));quit(1);return
	print("HORDA_PROJECT_BINARY ",args[0]);quit()
