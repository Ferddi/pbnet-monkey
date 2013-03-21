
Strict

Import pbnet

' Base class for all network events. NetEvents are sent via EventConnection,
' and when they are received, process() is called on them. You subclass them
' as needed to implement your desired event functionality.
Class NetEvent

	Field smClassLookup:StringMap<NetEvent> = New StringMap<NetEvent>()
	Field netRoot:NetRoot = Null

	Method New()
	
	End Method

	Method SetNetRoot:Void(nr:NetRoot)
	
		netRoot = nr
		'Print "NetEvent.SetNetRoot"
	
	End Method

	' Associate a Class with a given event type name.
	Method RegisterClass:Void(name:String, c:NetEvent)
		smClassLookup.Set(name, c)
	End Method
      
	' Create a NetEvent subclass by event name.
	Method CreateFromName:NetEvent(name:String)

		' Grab the name.   
		Local eventClazz:NetEvent = smClassLookup.Get(name)

		Return eventClazz

'		If Not eventClazz
'			Return Null
'		End If
'		
'		If netRoot = Null Then
'			Print "Error: NetRoot is null.  Please use NetEvent.SetNetRoot to specify the NetRoot."
'			Return Null
'		End If
'
'		' Ok - so create an instance of it And Return it.
'		Try
'
'			Local cinfo:ClassInfo = GetClass(eventClazz)
'			Local newEvent:NetEvent = NetEvent(cinfo.NewInstance())
'			newEvent.data = netRoot.GetByName(name)
'			newEvent.typeName = name
'			Return newEvent
'
'		Catch e:NetError
'
 '           Error "createFromName - Error creating event of type '" + name + "' - " + e.str
'
'		End Try
'         
'		Return Null

	End Method
      
	' The name of the event type.
	Field typeName:String
      
	' The network protocol we will use To transmit our data.
	Field data:NetRoot
      
	Method Serialize:Void(conn:EventConnection, bs:BitStream)

		data.Serialize(bs);

	End Method
      
	Method Deserialize:Void(conn:EventConnection, bs:BitStream)

		data.Deserialize(bs);

	End Method

	Method SetProperty:Void(fieldName:String, value:Object)
	
	End Method

	Method GetProperty:Object(fieldName:String)
	
		Return Null
	
	End Method

	' Callback when an event is received; subclasses will implement this.
	Method Process:Void(conn:EventConnection)

	End Method

End Class
