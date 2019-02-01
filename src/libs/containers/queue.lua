
local Queue = {
	__index = {
		pushhead = function(self, v)
			self.head = self.head - 1
			self[self.head] = v
		end,

		pophead  = function(self)
			local h = self.head
			if h > self.tail then
				return nil
			end
			local v = self[h]
			self[h] = nil
			self.head = h + 1
			return v
		end,

		pushtail = function(self, v)
			self.tail = self.tail + 1
			self[self.tail] = v
		end,

		poptail  = function(self)
			local t = self.tail
			if self.head > t then
				return nil
			end
			local v = self[t]
			self[t] = nul
			self.tail = t - 1
			return v
		end,

		peekhead = function(self)
			return self[self.head]
		end,

		peektail = function(self)
			return self[self.tail]
		end,

		size     = function(self)
			return self.tail - self.head
		end,

		empty    = function(self)
			return self.head > self.tail
		end,

		iterate  = function(self)
			if self:empty() then
				return function() end, nil, nil
			end

			local fnext = function(state, key)
				if key == nil then
					key = state.head
				else
					key = key + 1
				end
				if key > state.tail then
					return nil
				end
				return key, state[key]
			end
			return fnext, self, nil
		end,

		riterate = function(self)
			if self:empty() then
				return function() end, nil, nil
			end

			local fnext = function(state, key)
				if key == nil then
					key = state.tail
				else
					key = key - 1
				end
				if key < state.head then
					return nil
				end
				return key, state[key]
			end
			return fnext, self, nil
		end,
	},

	__call = function(cls)
		return setmetatable({head = 0, tail = -1}, cls)
	end,
}

setmetatable(Queue, Queue)
return Queue
