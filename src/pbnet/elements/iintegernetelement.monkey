
Strict

Import pbnet

' Interface For a NetElement that exposes integer data.
Interface IIntegerNetElement Extends INetElement
	Method GetValue:Int()
	Method SetValue:Void(v:Int)
End Interface
