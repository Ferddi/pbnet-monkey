
Strict

Import pbnet

' Interface For something that can contain NetElements.
Interface INetElementContainer

	' Add a NetElement To this container.
	Method AddElement:Void(e:INetElement)
      
	' Get an element by name. Searches all child containers as well.
	Method GetElement:INetElement(name:String)
      
	' Get number of NetElements in just this container (Not subcontainers).
	Method GetElementCount:Int()
     
	' Get a NetElement on this container by index.
	Method GetElementByIndex:INetElement(index:Int)

End Interface
