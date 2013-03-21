
Strict

Import pbnet

' Information about a ghost in the context of a specific GhostManager.
Class GhostInfo

	' Manager who is ghosting us.
	Field managerInstance:GhostManager

	' Ghost For which we are storing information.
	Field ghostInstance:Ghost
      
	' What states of ours are dirty? Used To test when we need To
	' do updates.
	Field dirtyFlags:Int
      
	' How important is it To update this ghost in this context?
	Field priority:Float
      
	' How many times have we been skipped? This is necessary so that updates
	' eventually make it through.
	Field timesSkipped:Int
      
	' Is the ghost currently in scope?
	Field inScope:Bool = False
             
	' Is the ghost active on the client?
	Field isGhosted:Bool = False
      
	' Do we need To kill this ghost?
	Field shouldKill:Bool = False
      
	Const csmAllDirty:Int = Int($FFFFFFFF)
      
	' Clear our dirty state, as we have completed an update. This is called
	' by the GhostManager For you.
	Method MarkUpdated:Void()
		dirtyFlags = 0
		timesSkipped = 0
	End Method

	' Indicate that one Or more state flags have become dirty.
	Method MarkDirty:Void(flags:Int)
		dirtyFlags |= flags;
	End Method

	' Mark all state flags as dirty.
	Method MarkAllDirty:Void()
		dirtyFlags = csmAllDirty;
	End Method
      
	' Clear one Or more state flags. The GhostManager will deal with clearing
	' dirty state For you.
	Method ClearDirty:Void(flags:Int)
		dirtyFlags &= ~flags;
	End Method
      
	' Constructor 
	Method New(g:Ghost, m:GhostManager)
	'DebugStop()
		ghostInstance = g;
		managerInstance = m;
		MarkAllDirty();
	End Method

	' Indicate that the ghost is out of scope in this context And should be
	' removed.
	Method MarkShouldKill:Void()
		shouldKill = True
		priority = 9999999999 '3.4028234 * 100000000000000000000000000000000000000
	End Method

End Class
