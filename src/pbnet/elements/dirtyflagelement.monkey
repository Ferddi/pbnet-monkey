
Strict

Import pbnet

' Just like FlagElement, but also assigns itself a dirty bit, And participates
' in dirty bit tracking. Used in ghosts.
Class DirtyFlagElement Extends FlagElement Implements IBooleanNetElement, INetElementContainer

	' The index of the dirty bit that corresponds To this flag.
	Field dirtyFlagIndex:Int
      
	Method New(n:String="", v:Bool=False)
		Super.New(n, v)
	End Method

	Method GetName:String()
		Return Super.GetName()
	End Method
      
	Method SetName:Void(v:String)
		Super.SetName(v)
	End Method

	Method Serialize:Void(bs:BitStream)
		Super.Serialize(bs)
	End Method

	Method Deserialize:Void(bs:BitStream)
		Super.Deserialize(bs)
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		Super.InitFromXML(xml)
	End Method

	Method DeepCopy:INetElement()
		Local c:DirtyFlagElement = DirtyFlagElement(Super.DeepCopy())
		c.dirtyFlagIndex = dirtyFlagIndex;
		c.value = value;
		Return c;
	End Method

	Method GetValue:Bool()
		Return Super.GetValue()
	End Method
      
	Method SetValue:Void(v:Bool)
		Super.SetValue(v)
	End Method
	
	Method AddElement:Void(e:INetElement)
		Super.AddElement(e)
	End Method
      
	Method GetElement:INetElement(name:String)
		Return Super.GetElement(name)
	End Method	

	Method GetElementCount:Int()
		Return Super.GetElementCount()
	End Method

	Method GetElementByIndex:INetElement(index:Int)
		Return Super.GetElementByIndex(index)
	End Method

End Class
