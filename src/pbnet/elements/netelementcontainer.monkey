
Strict

Import pbnet

' Base Class For NetElements that can contain other NetElements.
Class NetElementContainer Implements INetElement, INetElementContainer, IContainerAccessors

	Field name:String
	Field elementList:List<INetElement> = New List<INetElement>()

	Method GetName:String()
		Return name
	End Method
      
	Method SetName:Void(v:String)
		name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
		For Local e:INetElement = Eachin elementList
            e.Serialize(bs);
		End For
	End Method
      
	Method Deserialize:Void(bs:BitStream)
		For Local e:INetElement = Eachin elementList
			e.Deserialize(bs);
		End For
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
	End Method
      
	Method DeepCopy:INetElement()

		' Get our Class And make a New instance of it. This allows us
		' To work properly with subclasses.		
		'Local thisClassName:String = GetQualifiedClassName(e);
		'If Not thisClassName
		'	Throw New TError("Somehow we don't know about our own class's name!");
		'End If
         
		'Local thisClass:Object = GetClass(thisClassName)
		'If Not thisClass
		'	Throw New TError("Somehow we don't know about our own class!");
		'End If

		'Local thisCopy:NetElementContainer = NetElementContainer(thisClass.NewInstance())
		
		Local cinfo:ClassInfo = GetClass(Self)
		Local thisCopy:NetElementContainer = NetElementContainer(cinfo.NewInstance())
		If Not thisCopy
			Throw New NetError("Somehow we can't instantiate a new version of ourselves.");
		End If
         
		' Actually copy contents.
		thisCopy.SetName(GetName());
		'DebugStop()
		'Print "DeepCopy Name = " + GetName() + " elementList.Count() = " + elementList.Count()
		For Local e:INetElement = Eachin elementList
			thisCopy.AddElement(e.DeepCopy());
		End For

		Return thisCopy;
		
	End Method
      
	Method AddElement:Void(e:INetElement)
		elementList.AddFirst(e);
		'Print "AddElement elementList.Count() = " + elementList.Count()
	End Method
      
	Method GetElement:INetElement(name:String)

		For Local curNE:INetElement = Eachin elementList
			' Check this element For a match.
			'Local curNE:INetElement = INetElement(elementList[i])
            
			If curNE.GetName().ToLower() = name.ToLower()
				Return curNE;
			End If

			' Or maybe it's a container?
			Local curNEC:INetElementContainer = INetElementContainer(curNE);
            If Not curNEC
				Continue
			End If
               
			' Great, ask it For a match.
			Local curNECChild:INetElement = curNEC.GetElement(name);
            If curNECChild
               Return curNECChild
			End If

		End For
		
		Return Null;

	End Method

	Method GetElementCount:Int()
		Return elementList.Count();
	End Method
      
	Method GetElementByIndex:INetElement(index:Int)

		Local i:Int = 0
		Local e:INetElement = Null
		
		For e = Eachin elementList
			If i = index Then
				Return e
			End If
			i += 1
		End For

		Return e

	End Method

	Method GetString:String(name:String)
		Local netElement:IStringNetElement = IStringNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetInteger:Int(name:String)
		Local netElement:IIntegerNetElement = IIntegerNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetFloat:Float(name:String)
		Local netElement:IFloatNetElement = IFloatNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetBoolean:Bool(name:String)
		Local netElement:IBooleanNetElement = IBooleanNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method

	Method SetString:Void(name:String, v:String)
		Local netElement:IStringNetElement = IStringNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetInteger:Void(name:String, v:Int)
		Local netElement:IIntegerNetElement = IIntegerNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetFloat:Void(name:String, v:Float)
		Local netElement:IFloatNetElement = IFloatNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetBoolean:Void(name:String, v:Bool)
		Local netElement:IBooleanNetElement = IBooleanNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method

End Class
