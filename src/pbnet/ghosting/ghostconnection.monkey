
Strict

Import pbnet

' EventConnection subclass which adds support For ghosting. This largely
' passes control To a GhostManager.
Class GhostConnection Extends EventConnection

	' The GhostManager which manages our ghosting state.
	Field manager:GhostManager

	Field isSendingGhosts:Bool = False
	Field isReceivingGhosts:Bool = True

	' Call this Method To initialize ghosting over this connection.
	' 
	' @param isServer If True, we transmit ghosts. If False, we receive.
	Method ActivateGhosting:Void(nr:NetRoot, gf:IGhostFactory, isServer:Bool = False)

		manager = New GhostManager(nr, gf)
         
		If isServer = True Then

            isSendingGhosts = True
            isReceivingGhosts = False

		Else

            isSendingGhosts = False
            isReceivingGhosts = True

		End If

	End Method
      
	' The Object that will be used To determine what ghosts are in scope, And 
	' what priority they have.
	Method ScopeObject:Void(v:IScoper)

		manager.scoper = v;

	End Method
      
	Method ScopeObject:IScoper()

		If Not manager
			Return Null
		End If

		Return manager.scoper;

	End Method

	' I have move HadPendingData method into networkconnection.monkey
	'Method HasPendingData:Bool()
	'	If tcpStream.ReadAvail() > 0 Then
	'		Return True
	'	End If
	'	Return False
	'End Method

	Method WritePacket:Void(bs:BitStream)
		'Print Millisecs() + ". GhostConnection.WritePacket"
		' Give events priority.
		Super.WritePacket(bs);
         
		' Let the ghost manager write data.
		If manager And isSendingGhosts		
			manager.WritePacket(bs)
		End If

	End Method
      
	Method ReadPacket:Void(bs:BitStream)

		'Print "GhostConnection.ReadPacket"

		' Let events read.
		Super.ReadPacket(bs);
         
		' And give the ghosts a chance.
		If manager And isReceivingGhosts
			manager.ReadPacket(bs);
		End If

	End Method

End Class
