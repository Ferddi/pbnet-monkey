
Strict

Import pbnet

' Interface for a NetElement that exposes String data.
Interface IStringNetElement Extends INetElement
	Method GetValue:String()
	Method SetValue:Void(v:String)     
End Interface
