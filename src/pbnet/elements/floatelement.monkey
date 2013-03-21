
Strict

Import pbnet

' A floating point value that can be encoded with variable precision.
Class FloatElement Implements IFloatNetElement

	Field _name:String
	Field bitCount:Int = 30
	Field value:Float
      
	Method New(n:String = "", bc:Int = 30, v:Float = 0.0)
		_name = n;
		bitCount = bc;
		value = v;
	End Method

	Method GetName:String()
		Return _name;
	End Method

	Method SetName:Void(v:String)
		_name = v;
	End Method

	Method Serialize:Void(bs:BitStream)
		bs.WriteFloat(value, bitCount);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.ReadFloat(bitCount);
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		bitCount = Int(xml.GetFirstChildByName("bitCount").Value)
	End Method

	Method DeepCopy:INetElement()
		Return New FloatElement(_name, bitCount, value);
	End Method

	Method GetValue:Float()
		Return value;
	End Method

	Method SetValue:Void(v:Float)
		value = v;
	End Method

End Class
