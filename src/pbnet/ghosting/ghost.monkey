
Strict

Import pbnet

' Class For managing most recent state updates over a network.
'
' On the client, ghosts are created by a GhostManager, And updated And deleted
' as their state changes.
' 
' On the server, ghosts are created by user code, And marked as "in scope" To
' one Or more GhostManagers, which Then transmit their state To clients.
' 
' A note on relationships. In a client situation, a GhostManager will
' create an instance of Ghost For each replicated Object. As updates come
' in the relevant Ghost instance is used To deserialize it And push the 
' updates To its owner's properties.
' 
' In a server situation, a Ghost may be in scope for one or more 
' GhostManagers. There will be a GhostInfo For each Ghost-GhostManager
' context, And that is where the connection-specific dirty state tracking 
' happens. GhostInfos are created/destroyed/updated as Ghosts move in/out of 
' scope And their state becomes dirty.

Class InfoMap<T> Extends Map<GhostManager, T>

	Method Compare:Int(x:GhostManager, y:GhostManager)

'		If x = y Then
'			Print "InfoMap.Compare Return 0"
'			Return 0
'		End If
'
'		Print "InfoMap.Compare Return 1"
'		Return 1

		Return x.id - y.id

	End Method

End Class

Class Ghost

	Field netRoot:NetRoot = Null
	Field _protocol:NetRoot = Null

	' Map GhostManagers To their GhostInfo structures.
	'Field infoMap:Dictionary = New Dictionary(True);
	' Since you can't do object comparison! http://www.monkeycoder.co.nz/Community/posts.php?topic=1980
	'Field infoMap:InfoMap<GhostInfo> = New InfoMap<GhostInfo>()
	' You might as well just use an IntMap!!!!!!
	Field infoMap:IntMap<GhostInfo> = New IntMap<GhostInfo>()

	' String passed To clients To indicate what "type" this Object is - 
	' typically name of an Object from the TemplateManager.
	Field prototypeName:String = ""
	
    'Field randNum:Int = 0

	Method New(nr:NetRoot)
		'randNum = Rnd(1000)
		'Print "Ghost.New randNum = " + randNum

		netRoot = nr
	End Method

	' The protocol element from the NetRoot library that will be used To
	' serialize this ghost.
	Method ProtocolName:Void(v:String)

		'DebugStop()

		_protocol = netRoot.GetByName(v);
         
		If Not _protocol
            Error "set ProtocolName - Could not find protocol '" + v + "'"
		End If

		' Set everything To dirty by Default so we are in a consistent state.
		_protocol.SetDirtyState($FFFFFFFF)

	End Method
      
	Method ProtocolName:String()

		If Not _protocol
			Return ""
		End If

		Return _protocol.GetName();

	End Method
      
	' True If we are the "master" instance of an Object, the one running on a server that
	' is ghosted out To clients.
	Method IsServerObject:Bool()

		If owningManager = Null
			Return True
		End If

		Return False

	End Method

	' The protocol that will be used For processing this ghost's data on the wire.
	Method Protocol:NetRoot()

		Return _protocol;

	End Method
      
	' If we were created via ghosting, we are owned by the manager that created us.
	Field owningManager:GhostManager = Null
      
	' If we were created via ghosting, we are assigned a "Ghost Index."
	Field ghostIndex:Int = -1
      
	' Object whose properties we are tracking. Usually our owning Entity.
	'Field trackedObject:IPropertyBag
	Field trackedObject:IEntity

	' Array of properties that we are tracking - maps properties To fields in the protocol.
	'[TypeHint(type="com.pblabs.networking.ghosting.TrackedProperty")]
	'trackedProperties:Array = New Array()
	Field trackedProperties:List<TrackedProperty> = New List<TrackedProperty>()
      
	' Callback when the ghost goes out of scope.
	Field onOutOfScope:FunctionPointer = Null

	' Used To determine If we'ved touched this already in the current scope query.
	Field scopeToken:Int = -1
      
	' Our scope priority (from the last scoping operation).
	Field scopePriority:Float = 0.0

	' Get the GhostInfo, If any, For this Ghost in the context of the
	' specified manager.
	Method GetGhostInfo:GhostInfo(gm:GhostManager)

		'Print "ghost.randNum = " + randNum
		'Print "ghost.GetGhostInfo GhostManager.randNum = " + gm.randNum
		
		Local gi:GhostInfo = infoMap.Get(gm.id)
		
		If gi Then
			'Print "infoMap.Get(gm)"
			Return gi
		End If

		'Print "Return Null"

		Return Null

	End Method
      
	' Register a New GhostInfo with this ghost.
	Method RegisterGhostInfo:Void(gi:GhostInfo)

		'Print "ghost.randNum = " + randNum
		'Print "ghost.RegisterGhostInfo gi.managerInstance.randNum = " + gi.managerInstance.randNum

		If infoMap.Get(gi.managerInstance.id)
			'Print "Already have a GhostInfo for that manager!"
			Throw New NetError("Already have a GhostInfo for that manager!")
		End If
         
		'Print "before set"
		'For Local gm:GhostManager = Eachin infoMap.Keys()
		'	If infoMap.Get(gm) = Null Then
		'		Print "gm.randNum = " + gm.randNum + " infoMap.Get(gm) (GhostInfo) = null"
		'	Else
		'		Print "gm.randNum = " + gm.randNum + " infoMap.Get(gm) (GhostInfo) is something there"
		'	End If
		'End For

		'Print "Calling infoMap.Set"
		infoMap.Set(gi.managerInstance.id, gi)

		'Print "after set"
		'For Local gm:GhostManager = Eachin infoMap.Keys()
		'	If infoMap.Get(gm) = Null Then
		'		Print "gm.randNum = " + gm.randNum + " infoMap.Get(gm) (GhostInfo) = null"
		'		DebugStop()
		'	Else
		'		Print "gm.randNum = " + gm.randNum + " infoMap.Get(gm) (GhostInfo) is something there"
		'	End If
		'End For

	End Method
      
	' Indicate a GhostInfo is no longer valid.
	Method RemoveGhostInfo:Void(gi:GhostInfo)

		'Print "ghost.randNum = " + randNum
		'Print "ghost.RemoveGhostInfo gi.managerInstance.randNum = " + gi.managerInstance.randNum

		infoMap.Set(gi.managerInstance.id, Null)

	End Method
      
	' Mark this ghost as having some states dirty.
	Method MarkDirty:Void(flags:Int)

		' Hit all our GhostInfos And update their dirty flags.
		For Local gi:GhostInfo = Eachin infoMap.Values()

			If Not gi
				Continue;
			End If

			gi.MarkDirty(flags);

		End For

	End Method
      
	' Check For modifications To the tracked properties, And update dirty states
	' If any are found.
	Method CheckTrackedProperties:Void()

		' Only server objects do this, as they are the ones that have To send changes
		' out the world.
		If Not IsServerObject()
			'Print "Skipping ghost as it is not a server object."
			Return
		End If
         
		Local dirtyBits:Int = 0;

		' For each Property...
		For Local tp:TrackedProperty = Eachin trackedProperties

			If tp.initialUpdateOnly
				Continue
			End If

			' Get its current value.
			Local propVal:Object = trackedObject.GetProperty(tp.propRef)

			' Compare To stored value.
            If propVal <> tp.lastValue

				'Print "   Comparing " + propVal + " to " + tp.LastValue
               
				' If different, mark dirty.
				dirtyBits |= _protocol.GetElementDirtyBits(tp.protocolField);
               
				' Also store the New value in the protocol And the TrackedProperty.
				Local ne:INetElement = _protocol.GetElement(tp.protocolField) 
				'ne.value = propVal;

				Local cinfo:ClassInfo = GetClass(ne)
				Local iface:ClassInfo[] = cinfo.Interfaces()
				Local split:String[] = iface[0].Name().Split(".")
				Local ifaceStr:String = split[split.Length() - 1]
'				Print "CheckTrackedProperties.Interface = " + ifaceStr

				If ifaceStr = "IIntegerNetElement"
					Local intElem:IIntegerNetElement = IIntegerNetElement(ne)
					intElem.SetValue(UnboxInt(propVal));
				Else If ifaceStr = "IFloatNetElement"
					Local floatElem:IFloatNetElement = IFloatNetElement(ne)
					floatElem.SetValue(UnboxFloat(propVal));
				Else If ifaceStr = "IStringNetElement"
					Local stringElem:IStringNetElement = IStringNetElement(ne)
					stringElem.SetValue(UnboxString(propVal));
				Else If ifaceStr = "IBooleanNetElement"
					Local boolElem:IBooleanNetElement = IBooleanNetElement(ne)
					boolElem.SetValue(UnboxBool(propVal));
				Else
					Throw New NetError("Unknown NetElement type!");
				End If

				tp.lastValue = propVal;

			End If

		End For

		' Set dirty bits based on what changed.
		MarkDirty(dirtyBits);

	End Method

	' Write state To a network packet.
	Method Serialize:Void(bs:BitStream, dirtyFlags:Int)

		' Stuff our dirty flags into the protocol And let it serialize!
		_protocol.SetDirtyState(dirtyFlags);
         
		' Write a sentinel.
		If DEBUG_SENTINELS
			bs.WriteByte($BE)
		End If
		
		_protocol.Serialize(bs);

		If DEBUG_SENTINELS
			bs.WriteByte($EF)
		End If

	End Method
      
	' Read state from a network packet.
	Method Deserialize:Void(bs:BitStream, firstUpdate:Bool)

		' Parse the data.
		If DEBUG_SENTINELS
			bs.AssertByte("Pre sentinel.", $BE);
		End If

		'DebugStop()

		_protocol.Deserialize(bs);

		If DEBUG_SENTINELS
			bs.AssertByte("Post sentinel.", $EF);
		End If

		If Not trackedObject
			Return
		End If
         
		' Stuff values into our Object.
		For Local tp:TrackedProperty = Eachin trackedProperties

			If tp.initialUpdateOnly And firstUpdate = False
				Continue
			End If

			' Get the value from the protocol.
			Local ne:INetElement = _protocol.GetElement(tp.protocolField)
			Local netValue:Object = Null;

			Local cinfo:ClassInfo = GetClass(ne)
			Local iface:ClassInfo[] = cinfo.Interfaces()
			Local split:String[] = iface[0].Name().Split(".")
			Local ifaceStr:String = split[split.Length() - 1]
'			Print "Deserialize.Interface = " + ifaceStr

			If ifaceStr = "IIntegerNetElement"
				Local intElem:IIntegerNetElement = IIntegerNetElement(ne)
				netValue = BoxInt(intElem.GetValue());
			Else If ifaceStr = "IFloatNetElement"
				Local floatElem:IFloatNetElement = IFloatNetElement(ne)
				netValue = BoxFloat(floatElem.GetValue());
			Else If ifaceStr = "IStringNetElement"
				Local stringElem:IStringNetElement = IStringNetElement(ne)
				netValue = BoxString(stringElem.GetValue());
			Else If ifaceStr = "IBooleanNetElement"
				Local boolElem:IBooleanNetElement = IBooleanNetElement(ne)
				netValue = BoxBool(boolElem.GetValue());
			Else
				Throw New NetError("Unknown NetElement type!");
			End If
            
			' Set it on the Object.
            trackedObject.SetProperty(tp.propRef, netValue);
		End For
         
		' Notify people we did an update, cuz we care.
		'Print Millisecs() + ". TODO - trackedObject.eventDispatcher"
		'If trackedObject.eventDispatcher
		'	trackedObject.eventDispatcher.dispatchEvent(New Event("ghostUpdateEvent"))
		'End If

	End Method

End Class
