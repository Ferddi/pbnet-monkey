
Strict

Import pbnet

' Interface for a NetElement that exposes Object data.
Interface IObjectNetElement Extends INetElement
	Method GetValue:Object()
	Method SetValue:Void(v:Object)     
End Interface
