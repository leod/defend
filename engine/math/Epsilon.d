module engine.math.Epsilon;

template Epsilon(T)
{
	static if(is(T : float))
		const T Epsilon = 0.0001;
	else static if(is(T : uint) || is(T : int))
		const T Epsilon = 0; // lol
	else
		static assert(false);
}
