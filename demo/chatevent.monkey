
Import pbnet

Class ChatEvent Extends GenericNetEvent

	Field message:String
	'Field onChatCallback:Function = Null

	Method New(nr:NetRoot, msg:String = "")

		Super.New(nr, "chat")
		RegisterField("message")
		message = msg

		'Print "ChatEvent.New"

	End Method

	Method SetProperty:Void(fieldName:String, value:Object)
	
		message = UnboxString(value)
	
	End Method

	Method GetProperty:Object(fieldName:String)

		Return BoxString(message)

	End Method

	Method Process:Void(conn:EventConnection)

		'If onChatCallback <> Null
		'	onChatCallback(this)
		'End If

	End Method

End Class
