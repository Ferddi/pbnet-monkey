
Strict

Import pbnet
Import brl.socket

' Tracks active network connections. This mostly operates behind
' the scenes; your code probably wants To use NetworkConnection (which will
' register itself with NetworkInterface).
Class NetworkInterface

	' The singleton NetworkInterface instance.
	'Method Instance:NetworkInterface()

	'	If _instance = Null
	'		_instance = New NetworkInterface()
	'	End If

	'	Return _instance;

	'End Method
      
	'Field _instance:NetworkInterface = Null
      
	' Called when a connection is accepted by the server; this tracks
	' the connection, gives it chances To send packets, etc.
	Method AddConnection:Void(conn:NetworkConnection)

		'DebugStop()

		connections.AddLast(conn);
         
		' Start getting ticks If we need. We use setInterval here because
		' ProcessManager may scale the reported time, but we need To deal
		' with the wide internet.
		If interval = -1
		'	interval = flash.utils.setInterval(tick, 100);
		End If

	End Method
      
	' Called when a connection has been closed And no longer requires tracking.
	Method RemoveConnection:Void(conn:NetworkConnection)
	
		If connections.Count() = 0 Then
			Return
		End If

		Local num:Int = connections.RemoveEach(conn);

		If num = 0
			Print "Tried to remove a non-existent connection!"
			'Throw New NetError("Tried to remove a non-existent connection!");
		End If

		'connections.splice(idx, 1);

	End Method
      
	' Pass a Function that takes a single NetworkConnection as an argument.
	'Method ForEachConnection:Void(f:Function)
	'	For Local nc:NetworkConnection = Eachin connections
	'		f(nc);
	'	End For
	'End Method
      
	Method Tick:Void()

		'Print Millisecs() + ". NetworkInterface.Tick"
		'Local i:Int = 1
		' Send a packet on every connection.
		For Local nc:NetworkConnection = Eachin connections
			'Print i + ". Network Connection"
			'i += 1
            nc.Tick();
		End For

	End Method
	
	Method Read:Void()
	
		' Read a packet on every connection.
'		For Local nc:NetworkConnection = Eachin connections
' 			If nc.HasPendingData() = True Then
' 				'DebugStop()
'				nc.ReadPackets()
'			End If
'		End For

	End Method
      
	Field interval:Int = -1
	Field connections:List<NetworkConnection> = New List<NetworkConnection>()

End Class
