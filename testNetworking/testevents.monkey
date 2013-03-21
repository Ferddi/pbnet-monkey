
Strict

Import pbnet

Global LastServerIndex:Int = -1
Global LastClientIndex:Int = -1

' Helper event For EventConnection tests. Makes sure we receive events in
' correct order, with no mixups, with correct payloads.
Class TestEvent Extends GenericNetEvent

	Method New(nr:NetRoot, isServer:Bool = False, index:Int = 0)

		Super.New(nr, "TestEvent");

		'DebugStop()

		data.SetInteger("counter", index);
		data.SetBoolean("fromServer", isServer);
		If isServer
			data.SetString("payload", "GENERIC FILLER")
		Else
			data.SetString("payload", "GENERIC RESPONSE")
		End If

	End Method

	Method Process:Void(conn:EventConnection)

		'DebugStop()

		Local isServer:Bool = data.GetBoolean("fromServer")

		If isServer

			Local counter:Int = data.GetInteger("counter")

			' Check the index.
			If LastServerIndex + 1 <> data.GetInteger("counter")
				Print "Counter did not increase correctly! (got " + data.GetInteger("counter") + " expected " + (LastServerIndex + 1)
			End If
			LastServerIndex = data.GetInteger("counter");

			' Check the payload.
			If "GENERIC FILLER" <> data.GetString("payload")
				Print "Did not get expected payload string!"
			End If

		Else

			Local counter:Int = data.GetInteger("counter")

			' Check the index.
			If LastClientIndex + 1 <> data.GetInteger("counter")
				Print "Counter did not increase correctly!"
			End If

			LastClientIndex = data.GetInteger("counter");

			' Check the payload.
			If "GENERIC RESPONSE" <> data.GetString("payload")
				Print "Did not get expected payload string!"
			End If

		End If

	End Method

End Class
