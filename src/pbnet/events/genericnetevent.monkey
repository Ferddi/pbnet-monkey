
Strict

Import pbnet

' Base class for all network events. NetEvents are sent via EventConnection,
' and when they are received, process() is called on them. You subclass them
' as needed to implement your desired event functionality.
' Simplified NetEvent subclass creation.
' 
' Most NetEvents have a few fields they want To send, And a callback
' when the data is received on the other End. The GenericNetEvent exists
' To make this usage pattern simple.
' 
' @example Example of subclassing GenericNetEvent in order To make a simple
'          event:
' 
' <listing version="3.0">
'   Class ChatEvent Extends GenericNetEvent
'   {
'      Public var chatterName:String;
'      Public var chatMessage:String;
'  
'      Public Function MyEvent()
'      {
'         // Indicate what protocol fragment we are using.
'         Super("myEventProtocol");
'         
'         // Register fields with the protocol. Notice they must be the
'         // same name as the protocol has. They will Then be deserialized
'         // into automatically.
'         registerField("chatterName");
'         registerField("chatMessage");
'      }
' 
'      Public Function process(ec:EventConnection):Void
'      {
'         trace(chatterName + " said " + chatMessage);
'      }
'   }
'
' </listing>
Class GenericNetEvent Extends NetEvent

	Field fieldList:StringList = New StringList()

	Method New(nr:NetRoot, protocolName:String)

		'DebugStop()

		Super.SetNetRoot(nr)
		data = netRoot.GetByName(protocolName)
		typeName = protocolName
		
		'Print "GenericNetEvent.New"

	End Method
      
	Method RegisterField:Void(name:String)

		fieldList.AddLast(name);

	End Method

	Method Serialize:Void(conn:EventConnection, bs:BitStream)

		' Iterate over all the elements And grab members with the same name.
		For Local fieldName:String = Eachin fieldList

			' Is there a matching element in our protocol?
			Local elem:INetElement = data.GetElement(fieldName);
			If Not elem
				Continue
			End If
            
			'DebugStop()

			' Determine the type And set the value.
			Local cinfo:ClassInfo = GetClass(elem)
			Local iface:ClassInfo[] = cinfo.Interfaces()
			Local split:String[] = iface[0].Name().Split(".")
			Local ifaceStr:String = split[split.Length() - 1]
'			Print "GenericEvent.Serialize.Interface = " + ifaceStr

			If ifaceStr = "IIntegerNetElement"
				Local intElem:IIntegerNetElement = IIntegerNetElement(elem)
				intElem.SetValue(UnboxInt(Self.GetProperty(fieldName)))
			Else If ifaceStr = "IFloatNetElement"
				Local floatElem:IFloatNetElement = IFloatNetElement(elem)
				floatElem.SetValue(UnboxFloat(Self.GetProperty(fieldName)))
			Else If ifaceStr = "IStringNetElement"
				Local stringElem:IStringNetElement = IStringNetElement(elem)
				stringElem.SetValue(UnboxString(Self.GetProperty(fieldName)))
			Else If ifaceStr = "IBooleanNetElement"
				Local boolElem:IBooleanNetElement = IBooleanNetElement(elem)
				boolElem.SetValue(UnboxBool(Self.GetProperty(fieldName)));
			Else
				Throw New NetError("Unknown NetElement type!");
			End If

		End For

		Super.Serialize(conn, bs);

	End Method
      
	Method Deserialize:Void(conn:EventConnection, bs:BitStream)

		Super.Deserialize(conn, bs);
         
		' Iterate over all the elements And grab members with the same name.
		For Local fieldName:String = Eachin fieldList
			
			' Is there a matching element in our protocol?
			Local elem:INetElement = data.GetElement(fieldName);
            If Not elem
				Continue
			End If
			
			'DebugStop()

			' Determine the type And get the value.
			Local cinfo:ClassInfo = GetClass(elem)
			Local iface:ClassInfo[] = cinfo.Interfaces()
			Local split:String[] = iface[0].Name().Split(".")
			Local ifaceStr:String = split[split.Length() - 1]
			'Print "GenericEvent.Derialize.Interface = " + ifaceStr

			Local netValue:Object = Null

			If ifaceStr = "IIntegerNetElement"
				Local e:IIntegerNetElement = IIntegerNetElement(elem)
				netValue = BoxInt(e.GetValue())
				'this[fieldName] = e.getValue();
			Else If ifaceStr = "IFloatNetElement"
				Local e:IFloatNetElement = IFloatNetElement(elem)
				netValue = BoxFloat(e.GetValue())
				'this[fieldName] = e.getValue();
			Else If ifaceStr = "IStringNetElement"
				Local e:IStringNetElement = IStringNetElement(elem)
				netValue = BoxString(e.GetValue())
				'this[fieldName] = e.getValue();
			Else If ifaceStr = "IBooleanNetElement"
				Local e:IBooleanNetElement = IBooleanNetElement(elem)
				netValue = BoxBool(e.GetValue())
				'this[fieldName] = e.getValue();
            Else
				Throw New NetError("Unknown NetElement type!")
			End If
			
			Self.SetProperty(fieldName, netValue)

		End For

	End Method

	Method Process:Void(conn:EventConnection)

		' To be overriden.

	End Method

End Class
