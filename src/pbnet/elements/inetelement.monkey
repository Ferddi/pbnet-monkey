
Strict

Import pbnet

' Interface for a NetElement.
Interface INetElement

	Method GetName:String()
	Method SetName:Void(v:String)

	' Write this NetElement's current state to a BitStream.
	Method Serialize:Void(bs:BitStream)

	' Read state from a BitStream And store it in this NetElement.
	Method Deserialize:Void(bs:BitStream)
      
	' After instantiation, access any attributes from the XML describing
	' this NetElement.
	Method InitFromXML:Void(xml:XMLElement)
      
	' Make a deep copy of this NetElement. Used when initializing a New
	' NetRoot.
	Method DeepCopy:INetElement()

End Interface
