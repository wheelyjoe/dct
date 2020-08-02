-- SPDX-License-Identifier: LGPL-3.0

local _G   = _G
local dct = {
    _VERSION = "0.6",
    _DESCRIPTION = "DCT: DCS Dynamic Campaign Tools",
    _COPYRIGHT = "Copyright (c) 2019-2020 Jonathan Toppins"
}

_G.dct = dct
dct.settings  = require("dct.utils.settings")(dctsettings)
dct.init      = require("dct.init")
return dct
