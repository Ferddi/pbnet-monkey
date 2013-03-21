
Strict

Import pbnet

' MXML Tag To automatically register a NetEvent subclass with an event name.
' 
' Wraps NetEvent.registerClass(). 

Class RegisterNetEvent 'Implements IMXMLObject

	'Field eventClass:Class;
	Field eventName:String;

	Method Initialized:Void(document:Object, id:String)

         'NetEvent.registerClass(eventName, eventClass);            

	End Method

End Class