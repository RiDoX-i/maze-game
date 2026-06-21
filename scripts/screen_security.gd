class_name ScreenSecurity
extends RefCounted

## Toggles Android's window FLAG_SECURE at runtime. When enabled, the OS blocks
## screenshots AND screen recording of the app and shows a blank frame in the
## recent-apps switcher. Used to stop players from capturing the Classic maze
## layout. No-op on every non-Android platform, so it is safe to call anywhere.

const FLAG_SECURE := 0x2000   ## android.view.WindowManager.LayoutParams.FLAG_SECURE


## Enable or disable screenshot/recording blocking for the app window.
static func set_secure(enabled: bool) -> void:
	if OS.get_name() != "Android":
		return
	if not Engine.has_singleton("AndroidRuntime"):
		return
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	var activity = android_runtime.getActivity()
	if activity == null:
		return
	# Window flags must be changed on the Android UI thread.
	var apply := func () -> void:
		var window = activity.getWindow()
		if window == null:
			return
		if enabled:
			window.addFlags(FLAG_SECURE)
		else:
			window.clearFlags(FLAG_SECURE)
	activity.runOnUiThread(android_runtime.createRunnableFromGodotCallable(apply))
