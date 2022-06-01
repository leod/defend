module engine.math.Misc;

T min(T, U)(T a, U b)
{
	return a < b ? a : b;
}

T max(T, U)(T a, U b)
{
	return a > b ? a : b;
}

T clamp(T, U, V)(T value, U min_, V max_)
{
	return max(min(value, max_), min_);
}

uint nextPowerTwo(uint a)
{
	uint b = 1;
	
	while(b < a)
		b *= 2;
		
	return b;
}

void catmullRomInterp(T)(float t, T a, T b, T c, T d, ref T res) {
	res = .5f * ((b * 2.f) +
				 (c - a) * t +
				 (a * 2.f - b * 5.f + c * 4.f - d) * t * t +
				 (b * 3.f - c * 3.f + d - a) * t * t * t);
}
