
Strict

Import pbnet

' An integer value that can range from min To max.
Class RangedIntElement Implements IIntegerNetElement

	Field _name:String
	Field min:Int
	Field max:Int
	Field value:Int
      
	Method New(n:String = "", mn:Int = 0, mx:Int = 100, v:Int = 1)
         _name = n;
         min = mn;
         max = mx;
         value = v;   
	End Method

	Method GetName:String()
         Return _name;
	End Method
      
	Method SetName:Void(v:String)
         _name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
         bs.WriteRangedInt(value, min, max);
	End Method
      
	Method Deserialize:Void(bs:BitStream)
         value = bs.ReadRangedInt(min, max);
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
         'min = xml.@min;
         'max = xml.@max;
         min = Int(xml.GetFirstChildByName("min").Value)
         max = Int(xml.GetFirstChildByName("max").Value)
	End Method
      
	Method DeepCopy:INetElement()
         Return New RangedIntElement(_name, min, max, value);
	End Method

	Method GetValue:Int()
		Return value;
	End Method
      
	Method SetValue:Void(v:Int)
		value = v;
	End Method

End Class
