
Strict

Import pbnet

' Implements an event passing protocol. The protocol is very simple. In each
' packet, we write as many events as will fit. The protocol is a flag
' indicating the presence of an event, a cached-String containing the event 
' name, And Then the event payload. This repeats Until the flag is False.
Class EventConnection Extends NetworkConnection

	Field eventQueue:List<NetEvent> = New List<NetEvent>()
	Field netEvent:NetEvent = Null

	Method New()
	
	End Method

	Method SetNetEvent:Void(nv:NetEvent)
	
		netEvent = nv
	
	End Method

	' Queue a NetEvent For transmission.
	Method PostEvent:Void(e:NetEvent)
		eventQueue.AddLast(e)
	End Method

	Method HasDataPending:Bool()

		Local count:Int = eventQueue.Count()

		If count > 0

			Return True

		End If

		Return False
		
	End Method
      
	Method WritePacket:Void(bs:BitStream)

		Super.WritePacket(bs);
          
		Local curEventIdx:Int = 0;
		Local curPosition:Int = -1;
		
		Local eq:NetEvent[] = eventQueue.ToArray()

		While curEventIdx < eventQueue.Count()

			' Write each event; If it throws an exception
			' Then we've either errored or run out of space.
			Try

				Local curEvent:NetEvent = eq[curEventIdx];
				curPosition = bs.CurrentPosition();

				' Write the "more events" flag.
				bs.WriteFlag(True);
               
				' Write the event type.
				bs.StringCache().Write(bs, curEvent.typeName);
               
				' Serialize the event payload.
				curEvent.Serialize(Self, bs);
               
				' Trigger a rollback If we have zero bits left, too, we need
				' at least one To encode the "no more events" flag.
				If bs.RemainingBits() = 0
					Throw New EOFError();
				End If

				curEventIdx += 1;

            Catch eof:EOFError

				Print "EventConnection.WritePacket EOFError.str: " + eof.str

				' We ran off the End of the buffer, so we're done writing
				' events. Roll back And break out of the loop.
				bs.CurrentPosition(curPosition)
				Exit

			End Try

		End While
		          
		' If we couldn't send ANY events... then we are in trouble!
		If curEventIdx = 0 And eventQueue.Count()
			Throw New NetError("Could not send the first event! It is probably too big for our packet size.");
		End If
          
		' Wipe all the events we processed.
		'eventQueue.splice(0,curEventIdx);
		For Local i:Int = 0 Until curEventIdx
			eventQueue.RemoveFirst()
		End For
          
		Try
			' Awesome - spit out the "no more events" flag.
			bs.WriteFlag(False);
		Catch e:EOFError
			Print "EventConnection.WritePacket ran out of space: " + e.str
			Throw New EOFError("Ran out of space to write final flag!");
		End Try
		
	End Method
      
	Method ReadPacket:Void(bs:BitStream)

		'Print "EventConnection.ReadPacket()"

		Super.ReadPacket(bs);

		Local x:Bool = False

		If netEvent = Null Then
			Print "Error: NetEvent is null.  Please use EventConnection.SetNetEvent to specify the NetEvent."
			Return
		End If

		Repeat

			' Check If there is another event.
			If bs.ReadFlag() = False
				'Print "Event.Exit"
				Exit
			End If
			
			'DebugStop()

			' Nope - we got an event To process.
			Local eventType:String = bs.StringCache().Read(bs);

			' First, create an instance of the event.
			Local event:NetEvent = netEvent.CreateFromName(eventType)

            If Not event
				Throw New NetError("Got unknown event type '" + eventType +"'!");
			End If

			'Print "Event.Deserialize"

			' Now let it deserialize.
			event.Deserialize(Self, bs);

			'Print "Event.Process"

			' Finally, let it process. (This will eventually want To be deferred I think).
			event.Process(Self);

		Until x = True

	End Method

End Class
