math.randomseed(5)
-- math.randomseed(os.time())

Point = {}
function Point:new (x1, y1)
	local p = {x = x1, y = y1}
	setmetatable(p, self)
	self.__index = self
	return p
end

function Point:display (prefix)
	print(prefix, string.format("point: (%d,%d)", self.x, self.y))
end

Graph = {}
function Graph:new (rows, cols)
	local g = {xmax = rows, ymax = cols, map = {}}
	setmetatable(g, self)
	self.__index = self
	-- pct = math.random()
	local pct = .85

	-- for i = 1, (g.xmax * g.ymax) do
	--	local x = math.random()
	--	if x < pct then
	--		g.map[i] = 32
	--	else
	--		g.map[i] = 35
	--	end
	-- end
	return g
end

function Graph:display ()
	print(string.format("rows: %d\ncols: %d", self.xmax, self.ymax))
	for i = 1, self.ymax+2 do io.write("*") end
	io.write("\n")
	for i = 1, self.xmax do
		for j = 1, self.ymax do
			if j == 1 then io.write("*") end
			io.write(string.format("%c", self.map[((i-1)*self.ymax) + j]))
			if j == self.ymax then io.write("*") end
		end
		io.write("\n")
	end
	for i = 1,self.ymax+2 do io.write("*") end
	io.write("\n")
	io.flush()
end


function Graph:map_point (p)
	assert(p ~= nil)
	return (self.ymax * (p.x-1)) + p.y
end

function Graph:is_valid_point (p)
	return p.x >= 1 and p.x <= self.xmax and p.y >= 1 and p.y <= self.ymax and
		self.map[self:map_point(p)] ~= 35
end

function Graph:neighbors(p)
	local l = {
		Point:new(p.x+1, p.y),
		Point:new(p.x-1, p.y),
		Point:new(p.x, p.y+1),
		Point:new(p.x, p.y-1)
	}
	local r = {}
	for _,p in pairs(l) do
		if self:is_valid_point(p) then
			table.insert(r, p)
		end
	end
	return r
end

Queue = {}
function Queue:new ()
	local r = {front = 0, back = -1}
	setmetatable(r, self)
	self.__index = self
	return r
end

function Queue:length ()
	return self.back - self.front + 1
end

function Queue:empty ()
	return self:length() == 0
end

function Queue:enqueue (x)
	assert(x ~= nil)
	self.back = self.back + 1
	self[self.back] = x
end

function Queue:dequeue ()
	if self:empty() then return nil end
	local x = self[self.front]
	self.front = self.front + 1
	return x
end

g = Graph:new(1000,1000)
--g.map[9] = 35
start = Point:new(1,2)
-- goal = Point:new(4,7)
-- goal = Point:new(3,2)
goal = Point:new(900,700)

-- goal:display("goal")
-- print(string.format("g:map_point(goal) type: %s", tostring(type(g:map_point(goal)))))
-- print("goal mapped: ", tostring(g:map_point(goal)))
-- print(string.format("g.map type: %s", tostring(type(g.map))))
-- print(string.format("#g.map: %s", tostring(#g.map)))

-- print(require 'json'.encode(g))

g.map[g:map_point(start)] = 83
g.map[g:map_point(goal)] = 71
-- g:display()

-- print(require 'json'.encode(g))

frontier = Queue:new()
frontier:enqueue(start)
came_from = {}
came_from[g:map_point(start)] = false
rounds = 0
found = false

while not frontier:empty() do
	rounds = rounds + 1
	current = frontier:dequeue()
	-- print("came_from: ", require 'json'.encode(came_from))
	-- print("frontier: ", require 'json'.encode(frontier))
	if current.x == goal.x and current.y == goal.y then
		print("early exit")
		found = true
		break
	end
	-- print("neighbors: ", require 'json'.encode(g:neighbors(current)))
	for _,n in pairs(g:neighbors(current)) do
		-- print("came_from: ", require 'json'.encode(came_from))
		-- print("n: ", require 'json'.encode(n))
		if came_from[g:map_point(n)] == nil then
			-- print("  n: ", require 'json'.encode(n))
			came_from[g:map_point(n)] = current
			frontier:enqueue(n)
		end
	end
	-- print("rounds: ", rounds)
end

cnt = 0
for _,i in pairs(came_from) do
	cnt = cnt + 1
end
print("rounds: ", rounds)
print("len(came_from):", cnt)
-- print("came_from: ", require 'json'.encode(came_from))

if found == false then
	print("no solution")
	os.exit(1)
end

current = goal
path = {}
table.insert(path, current)
path_len = 0
while current ~= start do
	current = came_from[g:map_point(current)]
	table.insert(path, current)
	path_len = path_len + 1
end
table.insert(path, start)
print("path length: ", path_len + 1)
print("path min: ", ((start.x - goal.x)^2 + (start.y - goal.x)^2)^(.5))

for _,p in pairs(path) do
	if p ~= start and p ~= goal then
		g.map[g:map_point(p)] = 43
	end
end

-- g:display()
