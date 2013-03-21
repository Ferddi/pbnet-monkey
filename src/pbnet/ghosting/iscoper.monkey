
Strict

Import pbnet

' Used by the GhostManager to determine what objects are in scope. It will
' be called approximately once per packet, and identify what objects should
' be in scope and at what priority.
Interface IScoper

	' When called, should call GhostManager.MarkGhostInScope() on any objects
	' that should be in scope for this connection.
	Method ScopeObjects:Void(gm:GhostManager)

End Interface
