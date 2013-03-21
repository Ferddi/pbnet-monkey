
Strict

Import pbnet

' Interface For a NetElement that exposes floating point data.
Interface IFloatNetElement Extends INetElement
	Method GetValue:Float()
	Method SetValue:Void(v:Float)
End Interface
