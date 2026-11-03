local sprites = {}

sprites.ui = {
	boxCorner = love.graphics.newImage('assets/sprites/ui/boxCorner.png'),
	boxMid = love.graphics.newImage('assets/sprites/ui/boxMid.png'),
	boxEdge = love.graphics.newImage('assets/sprites/ui/boxEdge.png'),
	buttonEmpty = love.graphics.newImage('assets/sprites/ui/buttonEmpty.png'),
	buttonLeft = love.graphics.newImage('assets/sprites/ui/buttonLeft.png'),
	buttonRight = love.graphics.newImage('assets/sprites/ui/buttonRight.png'),
	slider = love.graphics.newImage('assets/sprites/ui/slider.png'),
}
sprites.tools = {
	brush = love.graphics.newImage('assets/sprites/tools/brush.png'),
	eraser = love.graphics.newImage('assets/sprites/tools/eraser.png'),
}

return sprites