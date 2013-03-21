
Strict

Import pbnet

' A boolean element that, if true, serializes its children as well.
Class FlagElement Extends NetElementContainer Implements IBooleanNetElement

	Field value:Bool
      
	Method New(n:String = "", v:Bool = False)
		Super.New();
		SetName(n);
		value = v;
	End Method

	Method GetName:String()
		Return Super.GetName()
	End Method
      
	Method SetName:Void(v:String)
		Super.SetName(v)
	End Method

	Method Serialize:Void(bs:BitStream)
		If bs.WriteFlag(value)
			Super.Serialize(bs)
		End If
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.ReadFlag()
		If value
			Super.Deserialize(bs)
		End If
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
		Super.InitFromXML(xml)
	End Method
	
	Method DeepCopy:INetElement()
		Return Super.DeepCopy()
	End Method

	Method GetValue:Bool()
		Return value;
	End Method
      
	Method SetValue:Void(v:Bool)
		value = v;
	End Method

End Class
