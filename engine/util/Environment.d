// vim: set tw=100:
module engine.util.Environment;

import Path = tango.io.Path;
import Util = tango.text.Util;
import tango.sys.Environment : Environment;

import engine.util.Log : MLogger;

SearchPath gSearchPath;

final class SearchPath
{
	mixin MLogger;

	class NotFoundException
		: Exception
	{
		this(char[] message)
		{
			super(message);
		}
	}

	void warn(char[] path, char[] message)
	{
		logger_.warn(notFoundMessage(path) ~ (message ? "\n" ~ message : ""));
	};

	void abort(char[] path, char[] message)
	{
		throw new NotFoundException(notFoundMessage(path) ~ (message ? "\n" ~ message : ""));
	};

	this(char[][] programArgs)
	{
		/*
			logger will create debug.log in the first directory not 0 if more then
			1 directory is found, or 0 if only 1 is found

			0: current directory
			1: ~/.defend (on Posix), ~/Defend (on Windows)
			2: location of the executbale
			3: parent of executable
			installation directory (FIXME)
		*/

		searchPaths_ ~= checkFound("working", "./");

		char[] homeTemp = findHome();
		checkFound("personal", homeTemp);

		if (homeTemp) {
			char[] hybridTemp;

			version (Windows) {
				homeTemp ~= "\\Defend";
			} else {
				homeTemp ~= "/.defend";
			}

			searchPaths_ ~= checkFound("personal defend", homeTemp);
		}

		auto exePath = Environment.exePath(programArgs[0]);
		

		if (exePath) {
			searchPaths_ ~= checkFound("executable", exePath.parent());
		}
	}

	alias void delegate(char[], char[]) FailDelegate;

	/* search multiple paths in one go, call faildg if none exists */
	char[][] find(char[][] paths, FailDelegate faildg = null, char[] message = null)
	{
		char[][] results;

		foreach (path; paths) {
			results ~= find(path);

			if (results) {
				break;
			}
		}

		if (!results && faildg) {
			foreach (path; paths) {
				faildg(path, message);
			}
		}

		return results;
	}

	/* search one path, call faildg if it doesn't exist */
	char[][] find(char[] path, FailDelegate faildg = null, char[] message = null)
	{
		char[][] results;
		char[][] searchPaths = Path.parse(path).isAbsolute ? [path] : searchPaths_;

		foreach (searchPath; searchPaths) {
			final auto finalPath = Path.join(searchPath, path);
			logSearch(searchPath, path);

			if (Path.exists(finalPath)) {
				results ~= finalPath;
			}
		}

		if (!results && faildg) {
			faildg(path, message);
		}

		return results;
	}

	char[] file(char[] path)
	{
		final results = gSearchPath.find(path);

		if (!results.length) {
			if (searchPaths_.length <= 1) {
				throw new Exception("No place to create `" ~ path ~ "`.");
			} else {
				return Path.join(searchPaths_[0], path);
			}
		}

		return results[0];
	}

	private
	{
		const char[][] searchPaths_;

		char[] findHome()
		{
			char[] homeTemp;

			version (Windows) {
				homeTemp = Environment.get("HOME");

				if (homeTemp) {
					return homeTemp;
				}

				homeTemp = Environment.get("USERPROFILE");

				if (homeTemp) {
					return homeTemp;
				}

				homeTemp = Environment.get("HOMEDRIVE");

				if (Path.exists(homeTemp)) {
					char[] path = Environment.get("HOMEPATH");

					return homeTemp ~ '\\' ~ path;
				}
			} else { // Posix
				homeTemp = Environment.get("HOME");

				if (homeTemp) {
					return homeTemp;
				}
			}

			return homeTemp;
		}

		void logSearch(char[] searchPath, char[] path)
		{
			logger_.spam("searching for `{}` in `{}`", path, searchPath);
		}

		char[] checkFound(char[] desc, char[] path)
		{
			if (path) {
				char[] addDir = Path.FS.stripped(path);
				logger_.trace("determined " ~ desc ~ " directory: `{}`", addDir);
				return addDir;
			} else {
				logger_.trace("unable to determine " ~ desc ~ ", ignored...");
			}
			return null;
		}

		char[] notFoundMessage(char[] path)
		{
			return "The path `" ~ path ~ "` was not found in any of:\n" ~
			       Util.join(searchPaths_, "\n");
		}
	}
}
