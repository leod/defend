module engine.util.Log;

import tango.io.stream.Buffered;
import tango.io.Stdout;
import tango.io.device.File;
import tango.io.model.IFile : FileConst;
import tango.text.convert.Layout;
import tango.time.Clock;
import tango.time.WallClock;
import Integer = tango.text.convert.Integer;

version(Windows)
	import tango.sys.win32.UserGdi;

enum LogLevel
{
	Spam,
	Trace,
	Info,
	Warn,
	Fatal
}

final class Log
{
private:
	static Logger[char[]] loggers_;
	static LogAppender[] appenders_;
	static LogLevel level_;

public:
	static this()
	{
		level_ = LogLevel.Trace;
	}

	static void level(LogLevel level)
	{
		level_ = level;

		foreach(logger; loggers_)
			logger.level = level_;
	}

	static LogLevel level()
	{
		return level_;
	}

	static Logger opIndex(char[] name)
	{
		if(auto logger = (name in loggers_))
			return *logger;

		return loggers_[name] = new Logger(name);
	}

	static void add(LogAppender appender)
	{
		appenders_ ~= appender;
	}
}

private char[] levelToString(LogLevel level)
{
	switch(level)
	{
	case LogLevel.Spam:
		return "Spam";
	
	case LogLevel.Trace:
		return "Trace";
		
	case LogLevel.Info:
		return "Info";
		
	case LogLevel.Warn:
		return "Warn";
		
	case LogLevel.Fatal:
		return "Fatal";
		
	default:
		assert(false);
	}
}

abstract class LogAppender
{
	void write(char[] logger, LogLevel level, char[] text);
}

class FileAppender : LogAppender
{
private:
	File file;
	BufferedOutput buffer;

public:
	this(char[] path)
	{
		auto style = File.WriteAppending;
		style.share = File.Share.Read;
		
		file = new File(path, style);
		buffer = new BufferedOutput(file);
	}

	override synchronized void write(char[] logger, LogLevel level, char[] text)
	{
		static char[] convert(char[] tmp, long i)
        {
			return Integer.formatter(tmp, i, 'u', '?', 8);
		}
	
		auto tm = Clock.now;
		auto dt = WallClock.toDate(tm);
						
		char[20] tmp = void;
		char[256] tmp2 = void;

		static char[6] spaces = ' ';
		auto levelName = levelToString(level);

		buffer.append(Logger.layout.sprint(tmp2, "{}-{}-{} {}:{}:{},{}:{}",
			convert(tmp[0..4], dt.date.year),
			convert(tmp[4..6], dt.date.month),
			convert(tmp[6..8], dt.date.day),
			convert(tmp[8..10], dt.time.hours),
			convert(tmp[10..12], dt.time.minutes),
			convert(tmp[12..14], dt.time.seconds),
			convert(tmp[14..17], dt.time.millis),
			spaces[0 .. $ - levelName.length]
		));
		
		buffer.append(levelName);
		buffer.append(" ");
		buffer.append(logger);
		buffer.append(" - ");
		buffer.append(text);
		buffer.append(FileConst.NewlineString);
		buffer.flush();
	}
}

class ConsoleAppender : LogAppender
{
	override void write(char[] logger, LogLevel level, char[] text)
	{
		static void setColor(ushort color)
		{
			version(Windows)
				SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), color);
		}
	
		synchronized(Stdout)
		{
			version(Windows)
				const white = FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED;
			else
				const white = 0;
			
			uint bracketColor = white;
			
			version(Windows)
			{
				if(level == LogLevel.Warn || level == LogLevel.Fatal)
					bracketColor = FOREGROUND_RED;
				else if(level == LogLevel.Info || level == LogLevel.Trace)
					bracketColor = FOREGROUND_BLUE;
				else if(level == LogLevel.Spam)
					bracketColor = FOREGROUND_GREEN;
					
				bracketColor |= FOREGROUND_INTENSITY;
			}
			
			setColor(white);
			setColor(bracketColor); Stdout("[ ")();
			setColor(white); Stdout(logger)();
			setColor(bracketColor); Stdout(" ] ")();
			setColor(white); Stdout(text).newline;
			setColor(white);
		}
	}
}

final class Logger
{
private:
	static Layout!(char) layout;

	char[2048] buffer_;
	char[] name_;
	LogLevel level_;
	uint tab_;

	static this()
	{
		layout = new typeof(layout);
	}

	this(char[] string)
	{
		name_ = string;
		level_ = Log.level;
	}

	Logger log(LogLevel level, char[] format, TypeInfo[] arguments, ArgList args)
	{
		if(level < level_)
			return this;
	
		buffer_[0 .. tab_] = '\t';

		auto text = layout.vprint(buffer_[tab_ .. $], format, arguments, args);
		text = buffer_[0 .. text.length + tab_];

		synchronized(layout) foreach(appender; Log.appenders_)
			appender.write(name_, level, text);

		return this;
	}

public:
	char[] name()
	{
		return name_;
	}

	Logger indent()
	{
		tab_++;
		return this;
	}

	Logger outdent()
	{
		assert(tab_ > 0);
		tab_--;
		return this;
	}

	LogLevel level()
	{
		return level_;
	}

	Logger level(LogLevel level)
	{
		level_ = level;
		return this;
	}

	Logger spam(char[] format, ...)
	{
		return log(LogLevel.Spam, format, _arguments, _argptr);
	}

	Logger trace(char[] format, ...)
	{
		return log(LogLevel.Trace, format, _arguments, _argptr);
	}

	Logger info(char[] format, ...)
	{
		return log(LogLevel.Info, format, _arguments, _argptr);
	}

	Logger warn(char[] format, ...)
	{
		return log(LogLevel.Warn, format, _arguments, _argptr);
	}

	Logger fatal(char[] format, ...)
	{
		return log(LogLevel.Fatal, format, _arguments, _argptr);
	}
}

template MLogger()
{
	import engine.util.Log : Log, Logger;

private:
	alias typeof(this) T;

	static this()
	{
		if ("engine" == T.classinfo.name[0 .. 6] || "defend" == T.classinfo.name[0 .. 6]) {
			logger_ = Log[T.classinfo.name[7 .. $]];
		} else {
			logger_ = Log[T.classinfo.name];
		}
	}

protected:
	static const Logger logger_;
}
