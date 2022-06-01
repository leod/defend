module engine.util.Swap;

void swap(T)(ref T a, ref T b)
{
	T temp = a;
	a = b;
	b = temp;
}
