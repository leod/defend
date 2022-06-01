// vim: set tw=100:
module engine.util.Meta;

template Unstatic(T) { alias T Unstatic; }
template Unstatic(T : T[]) { alias T[] Unstatic; }

template Init(T) { const T Init; }

template ForeachTypeOf(T)
{
	alias typeof(function { foreach(x; Init!(T)) return x; }()) ForeachTypeOf;
}

char[] toString(T)(T x)
{
    return (x == 0) ?
        "" ~ '0' :
        ((x / 10) > 0) ?
            toString(x / 10) ~ toString(x % 10) :
            "" ~ cast(char)('0' + (x % 10));
}

char lowerChar(char c) {
	return (c >= 'A' && c <= 'Z') ? c + ('a' - 'A') : c;
}

char upperChar(char c) {
	return (c >= 'A' && c <= 'Z') ? c : c - ('a' - 'A');
}

char[] lowerString(char[] string) {
	return string.length ? lowerChar(string[0]) ~ lowerString(string[1 .. $]) : "";
}

char[] upperString(char[] string) {
	return string.length ? upperChar(string[0]) ~ upperString(string[1 .. $]) : "";
}
