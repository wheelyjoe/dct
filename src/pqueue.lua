-- Priority queue implementation form:
--   https://rosettacode.org/wiki/Priority_queue#Lua

-- API:
--   push(prio, item)
--   pop()
--   empty()
--   size()
--   peek()
--   remove(item)
--   increase(deltaprio, item)
--   decrease(deltaprio, item)
--   __next() -- allows stepping through the queue

local PriorityQueue = {
	__index = {
		push = function(self, p, v)
			local q = self[p]
			if not q then
				q = {first = 1, last = 0}
				self[p] = q
			end
			q.last = q.last + 1
			q[q.last] = v
		end,

		pop = function(self)
			for p, q in pairs(self) do
				if q.first <= q.last then
					local v = q[q.first]
					q[q.first] = nil
					q.first = q.first + 1
					return p, v
				else
					self[p] = nil
				end
			end
		end,

		empty = function(self)
			if next(self) == nil then
				return true
			end
			return false
		end,

		peek = function(self)
			for p, q in pairs(self) do
				if q.first <= q.last then
					local v = q[q.first]
					return p, v
				end
			end
		end,

		size = function(self)
			local l = 0
			for p, q in pairs(self) do
				l = l + (q.last - q.first + 1)
			end
			return l
		end,
	},

	__call = function(cls)
		return setmetatable({}, cls)
	end
}

setmetatable(PriorityQueue, PriorityQueue)
return PriorityQueue
