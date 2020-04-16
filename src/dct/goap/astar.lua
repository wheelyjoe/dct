local PriorityQueue = require "pqueue"

local function astar(graph, start, goal, heuristic)
	local frontier = PriorityQueue()
	local came_from = {}
	local cost_so_far = {}

	frontier:push(0, start)

	while not frontier:empty() do
		local current = frontier:pop()

		if current == goal then
			break
		end

		for _, n in pairs(graph:neighbors(current)) do
			local new_cost = cost_so_far[current] + graph:cost(current, n)
			-- NOTE: not sure how inserting an object as a key will
			-- work in lua tables
			if cost_so_far[n] == nil or new_cost < cost_so_far[n] then
				cost_so_far[n] = new_cost
				local p = new_cost + heuristic(goal, n)
				frontier.push(p, n)
				came_from[n] = current
			end
		end
	end

	return came_from, cost_so_far
end

return {
	astar = astar
}
