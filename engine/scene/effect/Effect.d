module engine.scene.effect.Effect;

abstract class Effect
{
private:
	char[] _type;
	char[] _name;
	int _score;
	
package:
	bool initialized = false;
	
public:
	this(char[] type, char[] name, int score)
	{
		_type = type;
		_name = name;
		_score = score;
	}
	
	char[] type() { return _type; }
	char[] name() { return _name; }
	int score() { return _score; }
	
	abstract bool supported();
	
	void init() {}
	void release() {}
}
