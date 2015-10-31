--[[
	Easy Configs by Sunzi

	View readme.md for functionality and example.
]]

module( "econf" )
packages = {} -- We're going to store each new config package here.

--[[
	Disclaimer: I'm shit at SQL. If you can improve my saving/loading, please do.
]]
if SERVER then
	--[[ Saving/loading ]]
	function initSQL( package )
		if not sql.TableExists( "econf_" .. package ) then
			sql.Query( "CREATE TABLE IF NOT EXISTS econf_" .. package .. " ( confid TEXT NOT NULL PRIMARY KEY, value TEXT );" )
		end
	end

	function saveData( package, confid, value )
		if not packages[ package ] then return error( "package not initialized (" .. tostring(package) .. ")" ) end
		if not packages[ package ][ confid ] then return error( "config does not exist (" .. package .. " / " .. tostring(confid) .. ")" ) end

		-- Gonna use json here to keep track of what type of data it is. Blah.
		sql.Query( "REPLACE INTO econf_" .. package .. " ( confid, value ) VALUES ( " .. SQLStr(confid) .. ", " .. SQLStr(util.TableToJSON( {value} )) .. " );")
	end

	function loadData( package, confid )
		if not packages[ package ] then return error( "package not initialized (" .. tostring(package) .. ")" ) end
		if not packages[ package ][ confid ] then return error( "config does not exist (" .. package .. " / " .. tostring(confid) .. ")" ) end

		local data = sql.QueryValue( "SELECT value FROM econf_" .. package .. " WHERE confid = " .. SQLStr(confid) .. " LIMIT 1;" )
		if not data then return packages[ package ][ confid ][ "default" ] end

		return util.JSONToTable( data )
	end

	--[[ Logging ]]
	local function pname( ply ) return "(" .. ply:SteamID() .. " | " .. SQLStr( ply:Nick() ) .. ")" end

	function logChange( package, confid, ply, newvalue )
		local fname = package .. "/" .. os.date( "%y%m%d" ) .. ".txt"
		if not file.IsDir( package ) then file.CreateDir( package ) end
		local f = file.Exists( fname, "DATA" ) and file.Write or file.Append

		f( fname, os.date( "%I:%M %p" ) .. confid .. ": Set to [" .. tostring( value ) .. "] " .. pname( ply ) )
	end

	function logTableChange( package, confid, ply, value, pushing )
		local fname = package .. "/" .. os.date( "%y%m%d" ) .. ".txt"
		if not file.IsDir( package ) then file.CreateDir( package ) end
		local f = file.Exists( fname, "DATA" ) and file.Write or file.Append

		f( fname, os.date( "%I:%M %p - " .. confid .. ": " .. ( pushing and "Added" or "Removed" ) .. " value [" .. tostring(value) .. "] " .. pname( ply ) ) )
	end
end

--[[ Local stuff we're going to use ]]
local function GetType( var )
	if type( var ) ~= "table" then return type( var ) end

	return IsColor( var ) and "color" or "table"
end

local TypeInfo = {
	string = {
		max_length = 1024,
		min_length = 1,
	},

	table = {}, -- copies string when created, only here to confirm it's a valid type.

	color = {
		transparency = false,
	},

	number = {
		max_value = false,
		min_value = false,
		decimal = false,
	},

	bool = {},
}

-- Note: this returns nil instead of false incase the value provided is false.
local function Discipline( conf, value )
	local val = GetType( value )
	if val ~= conf.type and not ( conf.type == "table" and val == "string" ) then return nil end

	if val == "string" then
		if conf.max_length and value:len() > conf.max_length then return nil end
		if conf.min_length and value:len() < conf.min_length then return nil end
	elseif val == "table" then
		-- maybe todo later?
	elseif val == "color" then
		if not conf.transparency and value.a and value.a ~= 255 then value.a = 255 end -- silently fix
		-- maybe todo later?
	elseif val == "number" then
		if not conf.decimal then value = math.floor( value ) else
			local st, en = string.find( value, "%." ) -- hackhackhack
			value = tonumber( tostring(value):sub( 1, en + conf.decimal ) )
		end
		if conf.max_value and value > conf.max_value then return nil end
		if conf.min_value and value < conf.min_value then return nil end
	end

	return value
end

local function GenericCheck( ply )
	return ply:IsSuperAdmin()
end

--[[ Get all config options for a specific config ]]
function getConfigs( name ) return ( packages[ name ] or { configs = {} } ).configs end

--[[
    Add a config to a specific config package.
--]]
function addConfig( package, confid, default, data )
	local gt_default = GetType( default )
	if not TypeInfo[ gt_default ] then return error( "invalid type sent to addConfig (" .. GetType( Default ) .. ")" ) end

	local info = table.Copy( TypeInfo[ gt_default == "table" and "string" or gt_default ] )
	table.Merge( info, data )

	info.id = confid
	info.type = gt_default
	info.default = default

	packages[ package ][ "configs" ][ confid ] = info

	info.value = SERVER and loadData( package, confid ) or default
	-- We'll send the client when it requests it in InitPostEntity.

	return { get = function() return getConfig( package, confid ) end }
end

--[[
	Returns the econf config data and checks if it's a valid config.
	Optional third argument errors if the argument type passed does not match config.type
]]
function getData( package, confid, check )
	if not packages[ package ] then return error( "package not initialized (" .. tostring(package) .. ")" ) end
	if not packages[ package ][ "configs" ][ confid ] then return error( "config does not exist (" .. package .. "/" .. tostring(confid) .. ")" ) end
	if check ~= nil then
		if GetType( check ) ~= packages[ package ][ "configs" ][ confid ] then
			return error( "type mismatch" )
		end
	end

	return packages[ package ][ "configs" ][ confid ]
end

--[[
	Returns the value of the config.
]]
function getConfig( package, confid )
	return getData( package, confid ).value
end

--[[ Used for limiting values given ]]
local function valueCollar( package, data, value )
	value = Discipline( data, value )
	if value == nil then return error( "discipline check failed on given config (" .. package .. " / " .. data.id ")" ) end

	return value
end

--[[
	Sets the config value. The last argument is the player if the player changed it.
	This is not used for tables when inserting or removing single values.
]]
function setConfig( package, confid, value, ply )
	local data = getData( package, confid, value )
	local value = valueCollar( package, data, value )

	if CLIENT then
		data.value = value
		return
	end

	if IsValid( ply ) then
		logChange( package, confid, ply, data.value, value )
	end
	saveData( package, confid, value )

	data.value = value
	if data.on_edit then
		data.on_edit( ply, value )
	end
end

--[[
	Inserts a value into the config table.
	Follows the same format as setConfig for the most part.
]]
function pushConfig( package, confid, value, ply )
	local data, err = validityCheck( package, confid )
	if err then return error( err ) end

	if data.type ~= "table" then return error( "attempting to push value to non-table config (" .. package .. " / " .. confid .. ")" ) end

	local value, err = valueCollar( package, data, value )
	if err then return error( err ) end
end

--[[
	Removes a value from the config table at the specified index.
	Follows the same format as setConfig for the most part.
]]
function popConfig( package, confid, key, ply )

end

--[[
	Config setup!
]]

function setupConfig( name, generic_canedit, is_upper )
	if not packages[ name ] then
		packages[ name ] = { configs = {}, gCanEdit = generic_canedit or GenericCheck }
	end

	if SERVER then initSQL( name ) end

	return {
		[ "getAll" ] = function() return getConfigs( name ) end,
		[ "get" ] = function( confid ) return getConfig( name, confid ) end,
		[ "add" ] = function( confid, default, data ) return addConfig( name, confid, default, data ) end,
		[ "set" ] = function( confid, value ) return setConfig( name, confid, value ) end,
		[ "push" ] = function( confid, value ) return pushConfig( name, confid, value ) end,
		[ "pop" ] = function( confid, key ) return popConfig( name, confid, key ) end,
	}
end

--[[ Networking and etc ]]

if SERVER then
	util.AddNetworkString( "econf-EditorValues" )
	util.AddNetworkString( "econf-UpdateConfig" )
	util.AddNetworkString( "econf-SendConfigPackage" )

	net.Receive( "econf-SendConfigPackage", function( _, ply )
		if not ply.econf_packages then ply.econf_packages = {} end

		local pkg = net.ReadString()
		if not packages[ pkg ] then return end
		if ply.econf_packages[ pkg ] then return end

		ply.econf_packages[ pkg ] = true

		net.Start( "econf-SendConfigPackage" )
			net.WriteString( pkg )

			local i = 0
			for name, data in pairs( packages[ pkg ][ "configs" ] ) do
				if data.server_only then continue end

				net.WriteString( name )
				net.WriteType( data.value )

				i = i + 1
			end
		net.Send( ply )
	end )
else

end
