#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")

local function main()
	dct.init()
	_G.dct.theater:exec(50)
	assert(dctcheck.spawngroups == 3,
		string.format("group spawn broken; expected(%d), got(%d)",
		3, dctcheck.spawngroups))
	assert(dctcheck.spawnstatics == 11,
		string.format("static spawn broken; expected(%d), got(%d)",
		11, dctcheck.spawnstatics))
	return 0
end

os.exit(main())
