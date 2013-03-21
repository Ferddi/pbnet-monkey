
Strict

Import pbnet

' A String, cached using a NetStringCache.
Class CachedStringElement Implements IStringNetElement

	Field _name:String
	Field value:String
      
	Method New(n:String = "", v:String = "")
		_name = n;
		value = v;
	End Method

	Method GetName:String()
		Return _name;
	End Method

	Method SetName:Void(v:String)
		_name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
		bs.StringCache().Write(bs, value);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.StringCache().Read(bs);
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
	End Method
      
	Method DeepCopy:INetElement()
		Return New CachedStringElement(_name, value);
	End Method
      
	Method GetValue:String()
		Return value;
	End Method

	Method SetValue:Void(v:String)
		value = v;
	End Method

End Class
