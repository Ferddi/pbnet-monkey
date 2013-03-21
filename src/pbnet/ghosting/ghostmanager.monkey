
Strict

Import pbnet

' Set this to true to enable debug sentinels in the network stream.
' Both ends must have this on/off.
Const DEBUG_SENTINELS:Bool = False

' Manage ghosts across a connection. This is used in two ways. Internally
' by GhostConnection And pals, And as a component which will automatically
' connect To a 
Class GhostManager
      
	Field netRoot:NetRoot
      
	Field connection:GhostConnection = Null
      
	' What object is responsible for scoping? Until this is set, ghosting
	' cannot occur (since there won't be anything indicating what ghosts
	' to look at!).
	Field scoper:IScoper
      
	' This object is responsible for creating new object instances with
	' associated ghosts, and returning the ghost to us for further processing.
	Field instanceFactory:IGhostFactory
    
    'Field randNum:Int = 0
    
    Field id:Int = 0
    Global idCounter:Int = 0

	Method New(nr:NetRoot, gf:IGhostFactory)

		'DebugStop()
		
		id = idCounter
		idCounter += 1
		
		'randNum = Rnd(1000)
		'Print "GhostManager.New randNum = " + randNum

		SetGhostBitCount(ghostBitCount)
		instanceFactory = gf
		netRoot = nr

	End Method
      
	' Set the number of bits we will use To encode ghost IDs. This affects
	' a variety of secondary things. If you change it during a ghosting session,
	' you will suffer, since it truncates structures with no regard For what's
	' in them And does Not inform the other End about the change!
	Method SetGhostBitCount:Void(count:Int)

		ghostBitCount = count;
		maxGhostCount = 1 Shl ghostBitCount;
		If ghostMap.Length() < maxGhostCount Then
			ghostMap = ghostMap.Resize(maxGhostCount)
		End If
		'ghostMap.length = maxGhostCount;

	End Method

	' Perform scoping And write as many ghost updates as will fit in the
	' BitStream.
	Method WritePacket:Void(bs:BitStream)

		'DebugStop()

		' Scope And prioritize.
		DoScopeQuery();
         
		'Print "Beginning ghost serialization for " + pendingUpdates.Count() + " ghosts"
		Local startPos:Int = bs.CurrentPosition();
         
		If DEBUG_SENTINELS
			bs.WriteByte($1A)
		End If
         
		' Then, write pending updates Until the bitstream is full.
		While bs.RemainingBits() > (ghostBitCount + 5) And pendingUpdates.Count() > 0
		
			'Print "bs.RemainingBits(): " + bs.RemainingBits() + " ghostBitCount: " + ghostBitCount

			' Get the first guy on the list. TODO: Reverse order so this isn't O(n^2)
			Local curGhost:GhostInfo = pendingUpdates.RemoveFirst()

			' If it is ghosted and has no updates, we can skip it.
            If Not curGhost.shouldKill And curGhost.isGhosted = True And curGhost.dirtyFlags = 0
				Continue
			End If

			' Speculatively write this update. If it fails, back up And indicate the stream has ended.
			Local lastStreamPos:Int = bs.CurrentPosition()

			Try
				' Indicate we have another ghost.
				bs.WriteFlag(True)

				If DEBUG_SENTINELS
					bs.WriteByte($1B)
				End If

				' Determine the ghost's id.
				Local id:Int = FindGhostId(curGhost.ghostInstance);
				If id = -1
					Throw New NetError("All ghosts must have an ID by the time we start writing a packet!");
				End If
               
				' Note it in the stream.
				bs.WriteInt(id, ghostBitCount);

				' Check If the existing ghost is marked For death.
				If bs.WriteFlag(curGhost.shouldKill)

					' Clear out the ghost info. Safe To do shere because we have written all we need To.
					DetachGhost(curGhost.ghostInstance);
                  
					' And move on To Next ghost.
					Continue

				End If
               
				' Is this the first update For this id?
				If Not curGhost.isGhosted

					If curGhost.ghostInstance.prototypeName = ""
						Throw New NetError("Warning - you did not set GhostInstance.PrototypeName so the ghosting system will not be able to instantiate a proxy!")
					End If

					' Yes, new ghost. Write its template name so the other end can make it.
					bs.StringCache().Write(bs, curGhost.ghostInstance.prototypeName);

					' Send the entity name too if it is set
					'If curGhost.ghostInstance.trackedObject is IEntity
					'Since in Monkey version of PBNet it is always IEntity, we don't need to check for this.

						Local owningEntity:IEntity = curGhost.ghostInstance.trackedObject
						If owningEntity.name <> "" Then

							' Write wheter or not we should expect a entityName
							bs.WriteFlag(True);
							bs.StringCache().Write(bs, owningEntity.name);

						Else

							' Write wheter or not we should expect a entityName
							bs.WriteFlag(False);

						End If

					'End If

				End If

				' Serialize this ghost.
				curGhost.ghostInstance.Serialize(bs, curGhost.dirtyFlags)

			Catch eof:EOFError

				Print "GhostManager.WritePacket EOFError.str: " + eof.str
				' Ran out of space, so roll back.
				bs.CurrentPosition(lastStreamPos)
               
				' And leave the loop.
				Exit

			End Try

			' It has been ghosted at this point.
			curGhost.isGhosted = True;

			' Mark it as updated.
			curGhost.MarkUpdated();

		End While
         
		' Ok, write a terminating flag, And we're done.
		bs.WriteFlag(False)
         
		' Report And wipe pending updates; we regenerate Next time around.
		_sizeOfLastUpdate = bs.CurrentPosition() - startPos;
		'Print "Wrote " + _sizeOfLastUpdate + " bits. There are " + pendingUpdates.Count() + " ghosts waiting for update"
         
		' Wipe the pending list.
		pendingUpdates.Clear()

	End Method      

	' Read ghost updates from a BitStream, And apply them To ghosts.
	Method ReadPacket:Void(bs:BitStream)

		'Print "GhostManager.ReadPacket"

		If DEBUG_SENTINELS
			bs.AssertByte("Packet pre sentinel", $1A)
		End If
         
		While bs.ReadFlag()
			If DEBUG_SENTINELS
				bs.AssertByte("Ghost pre sentinel", $1B)
			End If
            
			' What ghost ID does this update pertain To?
			Local ghostId:Int = bs.ReadInt(ghostBitCount)
			            
			' Are we deleting it?
            If bs.ReadFlag()

				' Sanity check.
				If ghostMap[ghostId] = Null
					Throw New NetError("Trying to delete a ghost ID that has no ghost!")
				End If

				Local g:GhostInfo = ghostMap[ghostId]

				g.ghostInstance.onOutOfScope.Main()
				g.ghostInstance.owningManager = Null
				ghostMap[ghostId] = Null

				' Done!
				Continue

			End If
            
			' Nope, it's a real update. Is the slot empty?
            If ghostMap[ghostId]

				' An active ghost, let it parse the update.
				Local g:GhostInfo = ghostMap[ghostId]
				g.ghostInstance.Deserialize(bs, False);

            Else

				' Empty slot, this is a New ghost.
				Local newGhostTemplate:String = bs.StringCache().Read(bs)
				Local newEntityName:String = ""

				' Does the New ghost have a name we should know?
				If bs.ReadFlag() Then
					newEntityName = bs.StringCache().Read(bs)
				End If

				If instanceFactory <> Null Then
					Local newGhost:Ghost = instanceFactory.MakeGhost(newGhostTemplate, netRoot)

					If Not newGhost
						Throw New NetError("Instantiated template '" + newGhostTemplate + "' with no GhostComponent, deleted it.")
					End If
	
					' Let the ghost update itself.
					newGhost.Deserialize(bs, True)
	
					' Map it.
					Local gi:GhostInfo = New GhostInfo(newGhost, Self)
					ghostMap[ghostId] = gi
					newGhost.ghostIndex = ghostId
					newGhost.owningManager = Self
	               
					'Print "Got ghost on id " + ghostId + ": " + newGhostTemplate + " entityName " + newEntityName
				End If
               
			End If

		End While

	End Method
      
	' Get the ID we have assigned a ghost, If any. If none, Return -1.
	Method FindGhostId:Int(g:Ghost)

		For Local i:Int = 0 Until ghostMap.Length()
			If ghostMap[i] 
				Local gi:GhostInfo = ghostMap[i]
				If gi.ghostInstance = g
					Return i
				End If
			End If
		End For

		Return -1;

	End Method
      
	' Indicate that a ghost is now in scope - called by the IScoper during
	' scope queries.
	'
	' @param priority Priority To assign To this ghost.
	Method MarkGhostInScope:Void(g:Ghost, priority:Float = 1.0)

		If g.scopeToken = scopePassToken
			Return
		End If

		g.scopeToken = scopePassToken;
		g.scopePriority = priority;
		scopeQueue.AddLast(g);

	End Method
      
	Method AttachedGhosts:Int()

		Return _attachedGhosts;

	End Method

	' Size in bits of the last update this manager sent.
	Method SizeOfLastUpdate:Int()

		Return _sizeOfLastUpdate;

	End Method

	Method AttachGhost:GhostInfo(g:Ghost)

		'DebugStop()

		' Set up the ghost info.
		Local gi:GhostInfo = New GhostInfo(g, Self);

		gi.priority = g.scopePriority;
		g.RegisterGhostInfo(gi);
		AssignGhostID(gi);

		Return gi;

	End Method
      
	Method AssignGhostID:Int(gi:GhostInfo)

		' Look For an empty slot To assign To this ghost.
		For Local i:Int = 0 Until ghostMap.Length()

			' If a slot is in use, skip it.
			If ghostMap[i]
				Continue;
			End If

			'Print "Empty Slot: " + i

			' Great, we found an empty slot.
			ghostMap[i] = gi;
			_attachedGhosts += 1;
			
			Return i;

		End For
         
		Throw New NetError("No free IDs!");
		Return -1;

	End Method
      
	Method DetachGhost:Void(g:Ghost)

		' Get the ghosts id.
		Local ghostId:Int = FindGhostId(g);
		If ghostId = -1
			Throw New NetError("Did not know about this ghost, so could not detach it.");
		End If
         
		' Remove it from the ghost map.
		ghostMap[ghostId] = Null;

		' Remove the ghost info from the ghost.
		g.RemoveGhostInfo(g.GetGhostInfo(Self));
         
		_attachedGhosts -= 1;

	End Method
      
	Method DoScopeQuery:Void()

		' Increment the token, taking care To skip -1, as that is the Default.
		scopePassToken += 1;
		If scopePassToken = -1
			scopePassToken = 0;
		End If

		' Clear the query Array.
		'scopeQueue.length = 0;
		scopeQueue.Clear()

		' Do the query.
		If Not scoper
			Throw New NetError("Cannot ghost with no scoper!");
		End If
		scoper.ScopeObjects(Self);
         
		' Now we have everything buffered... So prioritize it.
		'scopeQueue.sortOn("scopePriority", Array.DESCENDING | Array.NUMERIC);
		scopeQueue.Sort(False)	' False for Descending.
         
		' Take the top MaxGhostCount - that's what we want ideally to be scoped. Mark
		' the remainder as Not-scoped.
		Local sq:Ghost[] = scopeQueue.ToArray()
		'Print "ScopeQueue Length: " + sq.Length()
		'Print "maxGhostCount: " + maxGhostCount
		'Print "scopeQueue.Count(): " + scopeQueue.Count()
		For Local i:Int = maxGhostCount Until scopeQueue.Count()
			sq[i].scopeToken = scopePassToken - 1;
		End For
		'scopeQueue.splice(maxGhostCount);
		While scopeQueue.Count() >= maxGhostCount
			scopeQueue.RemoveLast()
		End While
         
		' Now - look at our GhostMap And mark anything Not in the current scoping pass
		' For deletion.
		Local gi:GhostInfo = Null
		Local x:Int = 0
		For gi = Eachin ghostMap

			' Skip empties Or stuff from this scoping query.
			If Not gi Or gi.ghostInstance.scopeToken = scopePassToken
				Continue
			End If
						
			' Great, it wasn't in this pass, so we can kill it.
			If gi.isGhosted
				'Print x + ". isGhosted is true, gi.MarkShouldKill()"
				gi.MarkShouldKill()
			'Else
				'Print x + ". isGhosted is false"
			End If

		End For
         
		' Now, Until we hit the max ghost count, add things from the top of
		' the list on down.
		' For i=0; i < scopeQueue.length && _attachedGhosts < maxGhostCount; i++)
		For Local g:Ghost = Eachin scopeQueue

			If _attachedGhosts >= maxGhostCount
				Exit
			End If

			'Print "Looping AttachGhost"

			'DebugStop()

            gi = g.GetGhostInfo(Self);
            
            If Not gi
            	'Print "Calling AttachGhost"
				' Wasn't attached.
				AttachGhost(g);
				Continue
			End If
            
			' Was attached, but update priority.
			gi.priority = g.scopePriority;
		End For
         
		' At this point we have everything in the GhostMap. So put it into pendingUpdates.
		'pendingUpdates.length = 0;
		pendingUpdates.Clear()
		For gi = Eachin ghostMap

			If Not gi
				Continue
			End If

			'Print "looping ghostMap"

			If gi.shouldKill Or gi.dirtyFlags Or Not gi.isGhosted
				pendingUpdates.AddLast(gi);
				'Print "pendingUpdates.Count() = " + pendingUpdates.Count()
				If pendingUpdates.Count() > 10 Then	
					DebugStop()
				End If
			End If
		End For
         
		' Sort by priority.
		'pendingUpdates.sortOn("priority", Array.DESCENDING | Array.NUMERIC);
		pendingUpdates.Sort(False)	' False for descending.
         
		' And we are ready To go!

	End Method

	' Map ghost IDs To ghost instances.
	Field ghostMap:GhostInfo[1024]

	Field scopeQueue:GhostList = New GhostList()
      
	Field scopePassToken:Int = 1
     
	Field _attachedGhosts:Int = 0
	Field _sizeOfLastUpdate:Int = 0

	' List of ghosts with pending updates. 
	Field pendingUpdates:GhostInfoList = New GhostInfoList()

	Field ghostBitCount:Int = 10
	Field maxGhostCount:Int = 1 Shl 10

End Class

Class GhostList Extends List<Ghost>
	Method Compare:Int(a:Ghost, b:Ghost)
		If a.scopePriority > b.scopePriority Return 1
		If a.scopePriority = b.scopePriority Return 0
		Return -1
	End Method
End Class

Class GhostInfoList Extends List<GhostInfo>
	Method Compare:Int(a:GhostInfo, b:GhostInfo)
		If a.priority > b.priority Return 1
		If a.priority = b.priority Return 0
		Return -1
	End Method
End Class