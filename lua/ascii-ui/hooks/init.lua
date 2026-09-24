--- @class ascii-ui.Hooks
local Hooks = {
	useState = require("ascii-ui.hooks.use_state"),
	useEffect = require("ascii-ui.hooks.use_effect"),
	useReducer = require("ascii-ui.hooks.use_reducer"),
	useConfig = require("ascii-ui.hooks.use_config"),
	useTheme = require("ascii-ui.hooks.use_theme"),
	useInterval = require("ascii-ui.hooks.use_interval"),
	useTimeout = require("ascii-ui.hooks.use_timeout"),
	useAsync = require("ascii-ui.hooks.use_async"),
}

return Hooks
