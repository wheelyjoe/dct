local RingBuffer = require "ringbuffer"

function test()
	local tests = {
		{
			name = "storage",
			size = 4,
			input = {1, 2, 3, 4},
			verify = {1, 2, 3, 4},
		}, {
			name = "overflow",
			size = 4,
			input = {33, 22, 3, 5, 31, 2, 9, 10, 23, 45},
			verify = {9, 10, 23, 45},
		}, {
			name = "min",
			size = 10,
			input = {1, 2, 3, 4},
			verify = {1, 2, 3, 4},
		},

	}

	local rb = RingBuffer()

	assert(rb:size() == 0, "RingBuffer: size not zero")
	assert(rb:peek() == nil, "RingBuffer: an empty buffer didn't return nil")
	assert(rb:full() == false, "RingBuffer: reports full")
	assert(rb:empty() == true, "RingBuffer: reports not empty")
	rb = nil

	for _, test in ipairs(tests) do
		local rb = RingBuffer(test.size)
		for _, i in ipairs(test.input) do
			rb:push(i)
		end
		assert(rb:empty() == false,
			   string.format("Ringbuffer:%s reports empty", test.name))
		-- print("Test: ", test.name)
		-- for k, v in pairs(rb) do
		--	print(k, ": ", v)
		-- end
		assert(rb:peek() == test.verify[1],
			   string.format("RingBuffer:%s peek failed", test.name))
		for _, i in ipairs(test.verify) do
			assert(rb:peek() == i,
				   string.format("RingBuffer:%s:peek %d != %d",
								 test.name, rb:peek(), i))
			assert(rb:pop() == i,
				   string.format("RingBuffer:%s:pop failed", test.name))
		end
	end

	return true
end

r = "Failed"
if test() then
	r = "Passed"
end
print(string.format("%s - RingBuffer Tests", r))
