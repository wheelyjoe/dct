#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	dct.init()
	assert(dctcheck.spawngroups == 3, "group spawn broken")
	assert(dctcheck.spawnstatics == 11, "static spawn broken")
	return 0
end

os.exit(main())
