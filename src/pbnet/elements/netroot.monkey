
Strict

Import pbnet
Import diddy.xml

' NetRoot wraps an XML bitstream protocol description to simplify 
' serializing/deserializing your data.
' 
' Basically, you describe the protocol you want in a simple XML syntax. Then
' the XML description is used To construct a tree of NetElement subclasses,
' which do the actual serialization/deserialization.
' 
' Elements in the tree are named, and can have their values set or retrieved
' by those names. So you can have an element named "id" and set it to 12.
' But because the protocol is defined in XML, you can tweak how many bits
' are used, Or wrap it in a flag so that the data is only sent If the flag
' is true.
' 
' The NetElements system also interfaces with Ghosts. Using the dirtyFlag
' tag, you can group like fields together. If any one of them changes in the
' ghosted object, then all are updated.

Class NetRoot Extends NetElementContainer Implements INetElement, INetElementContainer

	Field smRoots:StringMap<NetRoot> = New StringMap<NetRoot>()
	Field xmlReader:XMLParser = New XMLParser
      
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
		Return Super.DeepCopy()
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

	' Parse XML descriptions of protocol And store by name.
	Method LoadNetProtocol:Void(libraryText:String)

		'Local parsedData:XML = New XML(libraryText);
		'For Local e:XML = Eachin parsedData
		'	smRoots.Add(e.name.ToString().ToLowerCase(), CreateFromXML(e.ToString()))
		'End For

		Local doc:XMLDocument 
		Try
			doc = xmlReader.ParseString(libraryText)
		Catch e:XMLParseException
			Print "Error: " + e.Message()
		End Try
		
		Local rootElement:XMLElement = doc.Root

		For Local xml:XMLElement = Eachin rootElement.Children
			
			Local nr:NetRoot = New NetRoot(xml)
			Local name:String = xml.GetFirstChildByName("name").Value.ToLower()
			'DebugStop()
			smRoots.Add(name, nr)

		End For
		
	End Method
	      
	' Fetch a NetRoot from a named item in the library. This makes a deep
	' copy, so serialization state is not shared between objects.
	Method GetByName:NetRoot(name:String)

		If Not smRoots
			Return Null
		End If
		
		'DebugStop()

		Local r:NetRoot = smRoots.Get(name.ToLower())

		If Not r
			Return Null
		End If

		Return NetRoot(r.DeepCopy())

	End Method

	Method New()
	
	End Method

	' Create a NetRoot directly from an XML description.
	'Method CreateFromXML:NetRoot(x:String)
	Method New(xmlStr:String)
		'Local nr:NetRoot = New NetRoot();
		'ParseFromXML(parsedData, nr);
		'nr.setName(parsedData.@name.toString());
		'Return nr;
		
		'DebugStop()

		Local doc:XMLDocument = xmlReader.ParseString(xmlStr)
		Local rootElement:XMLElement = doc.Root
		
		'For Local xml:XMLElement = Eachin rootElement.Children
		'	Print "element = " + xml.Name()
		'	Print "name = " + xml.GetFirstChildByName("name").Value
		'End For

		ParseFromXML(rootElement, Self)
		
		
		SetName(rootElement.Name())
		
	End Method
      
	' Create a NetRoot directly from an XML description.
	'Method CreateFromXML:NetRoot(x:String)
	Method New(x:XMLElement)

		Local element:XMLElement = x
		
		'For Local xml:XMLElement = Eachin x.Children
		'	Print "element = " + xml.Name()
		'	Print "name = " + xml.GetFirstChildByName("name").Value
		'End For

		ParseFromXML(element, Self)
		
		SetName(element.GetFirstChildByName("name").Value)
		
	End Method

	Method ParseFromXML:Void(x:XMLElement, container:INetElementContainer, calledByFlag:Bool = False)
	
		'DebugStop()
	
		For Local e:XMLElement = Eachin x.Children
			Local ne:INetElement = Null;
            
			' Identify the kind of element we need To add...
			Local newElemName:String  = e.Name()
			'Print "element = " + newElemName
			'Print "name = " + e.GetFirstChildByName("name").Value

			Local foundElement:Bool = True
			If newElemName.ToLower() = "string"

				ne = New StringElement();

			Else If newElemName.ToLower() = "cachedstring"

				ne = New CachedStringElement();

			Else If newElemName.ToLower() = "float"

				ne = New FloatElement();

			Else If newElemName.ToLower() = "flag"

				ne = New FlagElement();
				ParseFromXML(e, INetElementContainer(ne), True);

			Else If newElemName.ToLower() = "dirtyflag"

				ne = New DirtyFlagElement();
				ParseFromXML(e, INetElementContainer(ne), True);

			Else If newElemName.ToLower() = "rangedint"

				ne = New RangedIntElement();
				
			'Else If calledByFlag = True And newElemName.ToLower() = "name"
			Else If newElemName.ToLower() = "name"
			
				' Do nothing, so it doesn't throw an error.
				foundElement = False

			Else

				'Throw New NetError("Unknown tag = " + newElemName);
				Print "Unknown tag = " + newElemName
				foundElement = False

			End If

			If foundElement = True
				' Set the name
				ne.SetName(e.GetFirstChildByName("name").Value);
	            
				' Let it parse itself...
				ne.InitFromXML(e);
	            
				' Add it To the root...
				container.AddElement(ne);
			End If
			
		End For

	End Method

	' Map dirty bit indices To a DirtyFlagElement.
	Field bitToDirtyFlagMap:List<DirtyFlagElement> = Null
      
	' Map INetElements to their dirty flags.
	Field elementsToDirtyFlagsMap:StringMap<Int> = Null
      
	Method UpdateDirtyFlagMap_r:Void(item:INetElement, activeDirtyFlags:Int)

		' Is this one a dirty flag?
		Local curFlag:DirtyFlagElement = DirtyFlagElement(item)

		If curFlag
		
			' Assign an ID.
			curFlag.dirtyFlagIndex = bitToDirtyFlagMap.Count();
			bitToDirtyFlagMap.AddLast(curFlag);
            
			' Note the New bit in our parameter.
			activeDirtyFlags |= 1 Shl curFlag.dirtyFlagIndex;
			
		End If

		' Note what flags this element is affected by.
		elementsToDirtyFlagsMap.Set(item.GetName(), activeDirtyFlags)
         
		' Process children.
		Local curContainer:INetElementContainer = INetElementContainer(item)
		If Not curContainer
            Return
		End If

		For Local i:Int = 0 Until curContainer.GetElementCount()
            UpdateDirtyFlagMap_r(curContainer.GetElementByIndex(i), activeDirtyFlags);
		End For

	End Method
      
	Method UpdateDirtyFlagMap:Void()

		' Wipe existing data.
		bitToDirtyFlagMap = New List<DirtyFlagElement>()
		'elementsToDirtyFlagsMap = New Dictionary(True)
		elementsToDirtyFlagsMap = New StringMap<Int>()
         
		' Traverse the whole tree And assign dirty flags.
		UpdateDirtyFlagMap_r(Self, 0);

	End Method

	' An element may have one Or more dirty bits that correspond To it.
	' For instance, it might nested two deep in DirtyFlags. So this 
	' returns whatever bits need To be set when it changes For it To
	' get serialized.
	Method GetElementDirtyBits:Int(name:String)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap()
		End If
         
		'Return elementsToDirtyFlagsMap[getElement(name)];
		Return elementsToDirtyFlagsMap.Get(name)
	End Method
      
	' Tells you the name of the DirtyFlag element that corresponds to
	' the specified bit. Notice that bit is a log2 parameter, ie the 4th
	' bit would be 0x8 from GetElementDirtyBits but 4 here.
	Method GetDirtyBitElement:DirtyFlagElement(bit:Int)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap()
		End If

		'Return bitToDirtyFlagMap[bit];
		'TODO
		
		Local i:Int = 0
		For Local e:DirtyFlagElement = Eachin bitToDirtyFlagMap
			If i = bit
				Return e
			End If
			i += 1
		End For

		Return Null
		
	End Method
      
	' Set the state of all the DirtyFlag nodes in this root based on 
	' dirty bits.
	Method SetDirtyState:Void(v:Int)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap();
		End If

		Local i:Int = 0
		For Local e:DirtyFlagElement = Eachin bitToDirtyFlagMap
			e.value = Bool((1 Shl i) & v);'
			i += 1
		End For
		
	End Method

End Class

