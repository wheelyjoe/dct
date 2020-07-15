# Administrators

Administration is relatively straight forward. This section will walk
you through installation and configuration.

## Installation

DCT is distributed as a standard DCS module. You can download the
[latest release](https://github.com/jtoppins/dct/releases/latest)
zip file and copy the `DCT` folder contained in the zip file to your
DCS saved games directory and place in;

	<dcs-saved-games>/Mods/tech

If the path does not exist just create it. If installed properly DCT
will be displayed as a module in the game's module manager.


## DCS Server Modification

DCT requires the DCS mission scripting environment to be modified, the
file needing to be changed can be found at
`$DCS_ROOT\\Scripts\\MissionScripting.lua.`
Comment out the removal of lfs and io and the setting of 'require' to nil.


## Configuration

Configuration is also relatively straight forward. DCT comes with a
limited amount of server side configuration, these configuration options
are described and listed below.

### File Location

DCT stores its server side configuration in a standard lua file located in:

	<dcs-saved-games>/Config/dct.cfg

The configuration file's syntax is the same as other DCS configuration files
the game uses so it should be familiar to an experienced DCS server
administrator.

A change to the configuration file will require the mission be restarted
before the settings take effect.

_Note: if you have multiple dedicated server saved game folders (referred to
a "write directory" in the DCS dedicated server documentation) you will need
a dct.cfg in each instance._

### Options

All DCT server configuration can be accessed via LUA's global table at:

	_G.dct.settings.server.<config-item>

Where `<config-item>` is the name of the configuration option below.

#### `debug`

 * _value:_ boolean (true/false)

Globally enable debug logging and debugging checks.

#### `profile`

 * _value:_ boolean (true/false)

Globally enable profiling. Can cause performance issues.

#### `statepath`

Defines where the statefile for the campaign will be stored.

 * _value:_ string
 * _default path:_ `<dcs-saved-games>/<name-of-theater>_<name-of-mission>.state`

Where `<name-of-theater>` is the name of the map the .miz mission file was
built for and `<name-of-mission>` is the "sortie" name given to the mission
when building the mission in the mission editor.

_Note: An adminstrator likely does not need to modify this from the default._

#### `theaterpath`

 * _value:_ string

Defines where the "theater definition" exists. See
[Campaign Designer](03-designer.md) documentation for what a
"theater definition" is.

_Note: A campaign designer likely will want to define this while building
their campaign._

#### `schedfreq`

 * _value:_ number in hertz
 * _default:_ 2 hertz

DCT has a central command scheduler on which everything is driven. A higher
number will mean both AI and player UI will be more responsive but at the
cost of lower server performance.

_Note: the default is likely a reasonable value._

#### `tgtfps`

 * _value:_ number in frames-per-second
 * _default:_ 75 fps

DCT has a central command scheduler on which everything is driven. This
scheduler implements a
[clamped game loop](https://gameprogrammingpatterns.com/game-loop.html)
which will prevent additional commands from executing once DCT's calculated
quanta has been reached. This allows the server to "catch-up". A lower
value will effectively allocate more time for DCT to run at the expense of
stealing server cycles for things like networking.

_Note: Caution sould be taken when changing this value._

#### `percentTimeAllowed`

 * _value:_ decimal from 0.0 to 1.0
 * _default:_ .3

Used in calculation of the quanta. Specifies the percent of time in a given
frame DCT is allowed to run.

	example:
	    percentTimeAllowed = .3
	    tgtfps = 75
	    quanta = (1/75)*.3 = 0.004 or 4 milliseconds
	      This means per-frame DCT is only allowed 4ms of execution time.

#### `logger.<subsystem>`

Defines the logging level for various subsystems in the framework. The
logging levels are:

 * `(0) error`
 * `(1) warn`
 * `(2) info`
 * `(4) debug`

The default level is the "warn" level.