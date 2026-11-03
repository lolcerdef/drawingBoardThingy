local sprites = {}

sprites.ui = {
	boxCorner = love.graphics.newImage('assets/sprites/ui/boxCorner.png'),
	boxMid = love.graphics.newImage('assets/sprites/ui/boxMid.png'),
	boxEdge = love.graphics.newImage('assets/sprites/ui/boxEdge.png'),
	buttonEmpty = love.graphics.newImage('assets/sprites/ui/buttonEmpty.png'),
	slider = love.graphics.newImage('assets/sprites/ui/slider.png'),
}
sprites.tools = {
	brush = love.graphics.newImage('assets/sprites/icons/brush.png'),
	eraser = love.graphics.newImage('assets/sprites/icons/eraser.png'),
}
sprites.icons = {
	left = love.graphics.newImage('assets/sprites/icons/left.png'),
	right = love.graphics.newImage('assets/sprites/icons/right.png'),
	multiplayer = love.graphics.newImage('assets/sprites/icons/multiplayer.png'),
	host = love.graphics.newImage('assets/sprites/icons/host.png'),
	join = love.graphics.newImage('assets/sprites/icons/join.png'),
	copy = love.graphics.newImage('assets/sprites/icons/copy.png'),
	paste = love.graphics.newImage('assets/sprites/icons/paste.png'),
}
sprites.random = {}
for i = 0, 4 do
	table.insert(sprites.random, love.graphics.newImage('assets/sprites/random/'..i..'.png'))
end

return sprites