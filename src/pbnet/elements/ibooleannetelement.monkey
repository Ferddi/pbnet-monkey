
Strict

Import pbnet

' Interface For a NetElement that exposes boolean data.
Interface IBooleanNetElement Extends INetElement
	Method GetValue:Bool()
	Method SetValue:Void(v:Bool)
End Interface
