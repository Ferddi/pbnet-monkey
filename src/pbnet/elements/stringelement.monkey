
Strict

Import pbnet

' A simple String.
Class StringElement Implements IStringNetElement
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
		bs.WriteString(value);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.ReadString();
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		'value = xml.@value.toString();
		Local e:XMLElement = xml.GetFirstChildByName("value")
		If e <> Null Then
			value = e.Value
		End If
	End Method

	Method DeepCopy:INetElement()
		Return New StringElement(_name, value);
	End Method

	Method GetValue:String()
		Return value;
	End Method

	Method SetValue:Void(v:String)
		value = v;
	End Method

End Class
