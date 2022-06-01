module engine.list.Sort;

public
{
	import tango.core.Array : sort;
}

//import engine.util.Swap;

/+void quickSort(T)(T[] buffer, int delegate(T, T) c)
{
	void sort(int l, int r)
	{
		int i = l;
		int j = r;
		T x = buffer[(l + r) / 2];
		
		while(i <= j)
		{
			while(c(buffer[i], x) < 0)
				i++;
				
			while(c(buffer[j], x) > 0)
				j--;
				
			if(i <= j)
			{
				swap(buffer[i], buffer[j]);
				
				i++;
				j--;
			}
		}
		
		if(l < j)
			sort(l, j);
			
		if(i < r)
			sort(i, r);
	}

	if(buffer.length == 0)
		return;

	sort(0, buffer.length - 1);
}+/
