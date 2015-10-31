__This is a work in progress and currently not functional.__

# Easy Configs

Rather than creating an addon_config.lua file that you expect the end-user to modify to fit their needs, and then having it replaced every time they update your addon, this allows easy editing of config values in-game and automatic saving/loading/logging of said configs.

Example functionality:
```Lua
-- shared:
addon = { someData = 124312, thingeroo = "afsqae" }
addon.config = econf.setupConfig( "my_supercool_addon", function( ply ) return ply:IsSuperAdmin() end, true )

addon.config.add( "keyboards", true, {
	name = "Text Chat",
	desc = "Toggles users being able to use text chat.",
	can_edit = function( ply )
		return ply:IsUserGroup( "owner" )
	end,
	on_edit = function( ply, is_enabled )
		PrintMessage( HUD_PRINTTALK, "Text chat has been " .. ( is_enabled and "enabled!" or "disabled." ) )
	end,
} )

-- server:
hook.Add( "PlayerSay", "Text Chat Disable", function( ply, text )
	if not addon.config.get( "keyboards" ) then ply:PrintMessage( HUD_PRINTTALK, "Nooo!" ) return "" end
end )
```
In the above, the second argument to econf.setupConfig is the generic "can edit" for the config package. The shown function is the default behavior.

---

### Functions


```
econf.setupConfig( string PackageName[, function CanEdit, bool Logging ] )
```
	CanEdit is a generic function for the entire config package to see if a user can edit the config values.
	If a config has its own can_edit function defined, it is used instead of this.
	If this isn't defined, the default behavior is set to only allow SuperAdmins to edit configs.

	If Logging is true, changes to all config values will be saved to /data/packageName/CURRENT_DATE.txt.
	However, the logging value set on each config value is more important than this.
	If this is set to true and a single config has logging set to false, changes will not be logged.
	If this is set to false and a config does not explicitly say to log its changes, the changes will not be logged.

	Returns a config table with the related package functions.

---
```
config.add( string ConfigID, vararg Default, table Data[, table LimitedList ] )
```
	Default may only be a string, table, color, bool, or number.
	It also defines the only type that this config can be set to.

	LimitedList:
		If this is set to a table, it must contain a list of items all of the same type as Default.
		Rather than allowing the editor to freely enter the value of this config,
		they're given a dropdown containing the values listed in this table.
		If this is set, the value of this config may only ever come from this list.
		The Default can be something other than what's found in here.
		YOU CANNOT USE THIS IF THE DEFAULT IS A TABLE OR A COLOR.

	Generic data variables:
		[string] name - the display name used in a config menu. id is used if this is not defined.
		[string] desc - a short description of the config used in an editor menu.
		[bool] server_only - don't network to the client.
			Note that this value is still sent to any clients that are allowed to edit it
			when they request it (such as by openening an editor menu)
		[func] can_edit - check to see if the user can edit this specific config. return true/false.
			This function is used instead of the config-package "can edit" function if it is defined.
		[func] on_edit - this function is called on edit, first with the player who edited it and second with the new value.
		[bool] logging - If this is set to true, all changes of this will be logged to /data/packageName/CURRENT_DATE.txt

	Type-specific data variables and their defaults:
		string:
			-- Set either of these to false to disable them.
			max_length = 1024
			min_length = 1

		table:
			-- Note that tables can only contain strings.
			-- It also has all of the same type-specific options that string has.

		color:
			transparency = false

		number:
			-- Set both max/min_value vars to actual numbers to use them. They can also be negative.
			max_value = false
			min_value = false
			-- Only ints if decimal is false, otherwise a number of the amount of decimal places.
			decimal = false

	Returns a table which has a "get" function as a shortcut for config.get( ConfigID )

---
```
config.get( string ConfigID )
```
	Returns the value of the config.

---
```
config.getAll()
```
	Returns a table of all configs. Note that this returns the configs with all of their econf-related data, not just their values.

---
```
config.set( string ConfigID, configtype Value, Player Editor )
```
	Sets, saves, and logs a config change.
	Note that logging does not work properly if you feed it a table.

---
```
config.push( string ConfigID, string Value, Player Editor )
```
	Sets, saves, and logs a config change of adding a string to a table config.

---
```
config.pop( string ConfigID, number Key, Player Editor )
```
	Sets, saves, and logs a config change of removing a value from the table config at the Key index.
