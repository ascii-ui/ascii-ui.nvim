--- @class ascii-ui.Logger
local Logger = {}

-- Define log levels
--- @enum ascii-ui.Logger.LogLevel
local levels = {
	DEBUG = "DEBUG",
	INFO = "INFO",
	WARN = "WARN",
	ERROR = "ERROR",
	QUIET = "QUIET",
}

local RUNNING_ON_ACTIONS = os.getenv("GITHUB_ACTIONS") == "true"

-- Set default log level
Logger.level = RUNNING_ON_ACTIONS and levels.DEBUG or levels.QUIET

-- Get log file path
local log_dir = vim.fn.stdpath("data") .. "/ascii-ui"
local log_path = log_dir .. "/ascii-ui.log"

local function ensure_log_dir()
	if vim.fn.isdirectory(log_dir) == 0 then
		-- Logging must never crash the UI. Concurrent editor processes
		-- (e.g. parallel test workers sharing one data directory) can race
		-- to create this directory, and vim.fn.mkdir raises Vim:E739
		-- "file already exists" when the directory appears between the
		-- check above and this call. Swallow the error: the directory
		-- existing is the only precondition we care about.
		pcall(vim.fn.mkdir, log_dir, "p")
	end
end

-- Internal function to write a message to file
local function write_log(level, msg, ...)
	msg = ... and string.format(msg, ...) or msg
	if not level or not msg then
		return
	end

	if RUNNING_ON_ACTIONS then
		-- If running on GitHub Actions, log to stdout instead of file.
		-- Do not ensure the log directory here: nothing is written to it,
		-- and creating it races with other processes sharing the data dir.
		print(string.format("[%s] %s", level, msg))
		return
	end

	ensure_log_dir()

	local file = io.open(log_path, "a")
	if file then
		local time = os.date("%Y-%m-%d %H:%M:%S")
		file:write(string.format("[%s] [%s] %s\n", time, level, msg))
		file:close()
	end
end

-- Public log functions
function Logger.debug(msg, ...)
	if Logger.level == levels.DEBUG then
		write_log(levels.DEBUG, msg, ...)
	end
end

function Logger.info(msg, ...)
	if Logger.level == levels.DEBUG or Logger.level == levels.INFO then
		write_log(levels.INFO, msg, ...)
	end
end

function Logger.warn(msg, ...)
	if Logger.level ~= levels.ERROR then
		write_log(levels.WARN, msg, ...)
	end
end

function Logger.error(msg, ...)
	write_log(levels.ERROR, msg, ...)
end

-- Optional: set log level
--- @param new_level ascii-ui.Logger.LogLevel
function Logger.set_level(new_level)
	if levels[new_level] then
		Logger.level = levels[new_level]
	end
end

return Logger
