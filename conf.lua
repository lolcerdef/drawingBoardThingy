function love.conf(t)
	t.console = true
	t.window.width = 1200
	t.window.height = 720
	
	t.window.title = 'Drawing Board Thingy'
	t.window.icon = 'assets/sprites/icons/brush.png'
	
	t.modules.math = false
	t.modules.physics = false
	t.modules.thread = false
	t.modules.video = false
	t.modules.joystick = false
end