local PriorityQueue = require "pqueue"

function test()
	local input = {
		{3, "Clear drains"},
		{4, "Feed cat"},
		{5, "Make tea"},
		{1, "Solve RC tasks"},
		{2, "Tax return"},
		{2, "Ford"},
		{2, "Toyota"},
	}

	local verify = {
		{1, "Solve RC tasks"},
		{2, "Tax return"},
		{2, "Ford"},
		{2, "Toyota"},
		{3, "Clear drains"},
		{4, "Feed cat"},
		{5, "Make tea"},
	}

	local pq = PriorityQueue()
	for _, task in ipairs(input) do
		pq:push(unpack(task))
	end

	assert(pq:size() == #verify, string.format("length of pq(%s) != verify(%d)",
		   pq:size(), #verify))

	pq:peek()

	local i = 0
	for p, t in pq.pop, pq do
		i = i+1
		local v = verify[i]
		assert(v[1] == p and v[2] == t, "pq, ordering not as expected")
	end

	assert(pq:empty() == true, "pq, not empty")
	return true
end

r = "Failed"
if test() then
	r = "Passed"
end
print(string.format("%s - PQueue Tests", r))
