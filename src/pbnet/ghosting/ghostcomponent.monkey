
Strict

Import pbnet

' Implements most-recent-state networking in the context of components.
Class GhostComponent Extends EntityComponent Implements ITickedObject

	Field netRoot:NetRoot

	' The actual Ghost which interfaces with the networking system.
	Field ghostInstance:Ghost
	
	Method New(nr:NetRoot)
	
		netRoot = nr
		ghostInstance = New Ghost(netRoot)
	
	End Method
      
	Method OnInterpolateTick:Void(factor:Float)

		' Nothing For now.

	End Method
      
	Method OnTick:Void(tickRate:Float)

		' Give the ghost a chance To check For changes To our state.
		ghostInstance.CheckTrackedProperties();         

	End Method

	Method OnAdd:Void()

		' Bind the ghost To us.
		ghostInstance.trackedObject = Owner();
         
		' Destroy ourselves when we go out of scope.
		'Print "TODO: GhostComponent.OnAdd check onOutOfScope and addTickedObject"
		'ghostInstance.onOutOfScope = Function():Void { owner.destroy(); }
		ghostInstance.onOutOfScope = New OnOutOfScope(Owner())

		' Tick so we update our dirty state.
		'PBE.processManager.addTickedObject(Self);

	End Method
      
	Method OnRemove:Void()

		ghostInstance.trackedObject = Null;
		ghostInstance.onOutOfScope = Null;

		Print "Process Manager remove ticked object is not working"
		'PBE.processManager.removeTickedObject(this);

	End Method

End Class
