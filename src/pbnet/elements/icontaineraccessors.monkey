
Strict

Import pbnet

' Interface describing the accessors on a NetElement container.
'
' Basically, these methods let you get typed data by name.
Interface IContainerAccessors

	Method GetString:String(name:String)
	Method GetInteger:Int(name:String)
	Method GetFloat:Float(name:String)
	Method GetBoolean:Bool(name:String)
      
	Method SetString:Void(name:String, v:String)
	Method SetInteger:Void(name:String, v:Int)
	Method SetFloat:Void(name:String, v:Float)
	Method SetBoolean:Void(name:String, v:Bool)

End Interface
