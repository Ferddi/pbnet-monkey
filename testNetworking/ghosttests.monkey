
Strict

Import pbnet

' Test ghosting To And from a server. We implement IScoper so we don't
' have To have yet another helper Object.
Class GhostTests Implements IScoper

	Field _Ghosts:List<Ghost> = New List<Ghost>()
	Field _PriorityToggle:Bool = False

	Method ScopeObjects:Void(gm:GhostManager)

		If _PriorityToggle

			' If _PriorityToggle is set assign priority from first To last.
			'For Local i:Int = 0 Until _Ghosts.length
			Local i:Int = _Ghosts.Count()
			For Local g:Ghost = Eachin _Ghosts
				'gm.MarkGhostInScope(_Ghosts[i] as Ghost, _Ghosts.length - i);
				gm.MarkGhostInScope(g, i);
				i -= 1
			End For

		Else

			' Otherwise reverse priority.
			'For Local i:Int = 0 Until _Ghosts.length
			Local i:Int = 0
			For Local g:Ghost = Eachin _Ghosts
				'gm.MarkGhostInScope(_Ghosts[i] as Ghost, i);
				gm.MarkGhostInScope(g, i);
				i += 1
			End For

		End If

	End Method
      
	Method TestHalfDuplexGhosting:Void()

		'Local resolveLinker:GroupMemberComponent;
		'Local resolveLinker2:DataComponent;
         
		' Init our templates.
		Local tm:TemplateManager = New TemplateManager();
		
		Local xml1:String = "" +
			"<template>" +
			"	<name>TestGhost</name>" +
			"	<component>" +
			"		<name>ghost</name>" +
			"		<type>PBLabs.Networking.Ghosting.GhostComponent</type>" +
			"		<GhostInstance>" +
			"			<ProtocolName>TestGhost</ProtocolName>" +
			"			<PrototypeName>TestGhost</PrototypeName>" +
			"			<TrackedProperties>" +
			"				<_>" +
			"					<Property>@data.Value1</Property>" +
			"					<ProtocolField>payload</ProtocolField>" +
			"				</_>" +
			"				<_>" +
			"					<Property>@data.Value2</Property>" +
			"					<ProtocolField>payloadFloat</ProtocolField>" +
			"				</_>" +
			"			</TrackedProperties>" +
			"		</GhostInstance>" +
			"	</component>" +
			"	<component>" +
			"		<name>data</name>" +
			"		<type>PBLabs.Engine.Components.DataComponent</type>" +
			"		<Value1>A</Value1>" +
			"		<Value2>0.5</Value2>" +
			"	</component>" +
			"	<component>" +
			"		<name>member</name>" +
			"		<type>PBLabs.Engine.Components.GroupMemberComponent</type>" +
			"		<GroupName>ClientGroup</GroupName>" +
			"	</component>" +
			"</template>"
		tm.AddXML(xml1, "", 1)

		Local xml2:String = "" +
            "<entity>" +
            "	<name>ServerGroup</name>" +
			"	<component>" +
			"		<name>groupManager</name>" +
			"		<type>PBLabs.Engine.Components.GroupManagerComponent</type>" +
			"	</component>" +
            "</entity>"
		tm.AddXML(xml2, "", 1)

		Local xml3:String = "" +
            "<entity>" +
            "	<name>ClientGroup</name>" +
			"	<component>" +
			"		<name>groupManager</name>" +
			"		<type>PBLabs.Engine.Components.GroupManagerComponent</type>" +
			"	</component>" +
            "</entity>"
		tm.AddXML(xml3, "", 1);
         
		Local libraryXML:String =
			"<protocol>" +
			"	<event>" +
			"		<name>TestGhost</name>" +
			"		<rangedInt>" +
			"			<name>id</name>" +
			"			<min>0</min>" +
			"			<max>8191</max>" +
			"		</rangedInt>" +
			"		<dirtyFlag>" +
			"			<name>dirty01</name>" +
			"			<string>" +
			"				<name>payload</name>" +
			"				<value></value>" +
			"			</string>" +
			"			<float>" +
			"				<name>payloadFloat</name>" +
			"				<bitCount>8</bitCount>" +
			"			</float>" +
			"		</dirtyFlag>" +
			"	</event>" +
			"</protocol>";
		Local netRoot:NetRoot = New NetRoot()
		netRoot.LoadNetProtocol(libraryXML);
         
	DebugStop()

		' Instantiate the server And client groups.
		Local serverGroup:GroupManagerComponent = GroupManagerComponent(tm.InstantiateEntity("ServerGroup").LookupComponentByName("groupManager"))
		AssertNotNull(serverGroup);
		Local clientGroup:GroupManagerComponent = GroupManagerComponent(tm.InstantiateEntity("ClientGroup").LookupComponentByName("groupManager"))
		AssertNotNull(clientGroup);
         
		' And our ghost factory.
		Local tgf:TemplateGhostFactory = New TemplateGhostFactory();
		tgf.overrideTemplateManager = tm;
         
		' Set up a server ghost manager using dummy scoper.
		Local serverManager:GhostManager = New GhostManager();
		serverManager.instanceFactory = tgf;
		serverManager.scoper = Self;
		serverManager.SetGhostBitCount(8);
         
		' Set up a client ghost manager.
		Local clientManager:GhostManager = New GhostManager();
		clientManager.instanceFactory = tgf;
		clientManager.SetGhostBitCount(8);
         
		' Set up a lot of ghosts on the server - more than we can fit in scope at a time.
		Local i:Int = 0
		For i=0 Until 4*256

			' Set up the ghost And place it in the server group.
			Local g:Ghost = tgf.MakeGhost("TestGhost");
			g.trackedObject.SetProperty(New PropertyReference("@member.GroupName"), BoxString("ServerGroup"));
			g.Protocol.SetInteger("id", i);
			_Ghosts.AddLast(g);

		End For
         
		' Make sure we have the expected number.
		AssertEquals(serverGroup.EntityList.Count(), 4*256);
         
		' Run a few dozen update packets.
		Local serverToClientBuffer:BitStream = New BitStream(100);
		Local serverStringCache:NetStringCache = New NetStringCache();
		Local clientStringCache:NetStringCache = New NetStringCache();
         
		For i=0 Until 50

			serverToClientBuffer.CurrentPosition(0)
			serverToClientBuffer.StringCache(serverStringCache)
			serverManager.WritePacket(serverToClientBuffer)

			serverToClientBuffer.CurrentPosition(0)
			serverToClientBuffer.StringCache(clientStringCache)
			clientManager.ReadPacket(serverToClientBuffer);

		End For
         
		' Now, check what has been scoped To the client - is it the right stuff?
		Local clientEntityList:List<IEntity> = clientGroup.EntityList;
		For Local e:IEntity = Eachin clientEntityList

			Local gc:GhostComponent = GhostComponent(e.LookupComponentByType("GhostComponent"));
            AssertNotNull(gc);
            AssertTrue("Got back ID " + gc.ghostInstance.Protocol.GetInteger("id") + " > " + (serverGroup.EntityList.Count() / 2),
                        gc.ghostInstance.Protocol.GetInteger("id") > serverGroup.EntityList.Count() / 2);

		End For

		' Invert priority levels.
		_PriorityToggle = Not _PriorityToggle;

		' Run some more update packets.
		For i=0 Until 50

			serverToClientBuffer.CurrentPosition(0)
			serverToClientBuffer.StringCache(serverStringCache)
			serverManager.WritePacket(serverToClientBuffer);

			serverToClientBuffer.CurrentPosition(0)
			serverToClientBuffer.StringCache(clientStringCache)
			clientManager.ReadPacket(serverToClientBuffer);

		End For
         
		' Are we seeing the right stuff on the client now? (ie the other half of the data)
		clientEntityList = clientGroup.EntityList;
		For Local e:IEntity = Eachin clientEntityList

            Local gc:GhostComponent = GhostComponent(e.LookupComponentByType("GhostComponent"))
            AssertNotNull(gc);
            AssertTrue("Got back ID " + gc.ghostInstance.Protocol.GetInteger("id") + " < " + (serverGroup.EntityList.Count() / 2),
                        gc.ghostInstance.Protocol.GetInteger("id") < serverGroup.EntityList.Count() / 2);

		End For
         
		' Sweet! Now let's test dirty tracking. The first couple hundred ghosts are scoped right now.
         
		Local _g:Ghost[] = _Ghosts.ToArray()
		' Let's change the first few directly.
		Local aGhost:Ghost = _g[0];
		aGhost.Protocol.SetString("payload", "monkey");
		aGhost.MarkDirty(aGhost.Protocol.GetElementDirtyBits("payload"));

		aGhost = _g[1];
		aGhost.Protocol.SetString("payload", "pony");
		aGhost.MarkDirty(aGhost.Protocol.GetElementDirtyBits("payload"));
         
		aGhost = _g[2];
		aGhost.Protocol.SetString("payload", "pirate");
		aGhost.MarkDirty(aGhost.Protocol.GetElementDirtyBits("payload"));

		aGhost = _g[3];
		aGhost.Protocol.SetString("payload", "ninja");
		aGhost.MarkDirty(aGhost.Protocol.GetElementDirtyBits("payload"));

		' Run an update packet.
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(serverStringCache)
		serverManager.WritePacket(serverToClientBuffer)
            
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(clientStringCache)
		clientManager.ReadPacket(serverToClientBuffer)

		' Clear out the old state.
		_g[0].Protocol.SetString("payload", "monkey");
		_g[1].Protocol.SetString("payload", "pony");
		_g[2].Protocol.SetString("payload", "pirate");
		_g[3].Protocol.SetString("payload", "ninja");

		' They'd better have made it over!
		clientEntityList = clientGroup.EntityList;
		Local numChecked:Int = 0;
		For Local e:IEntity = Eachin clientEntityList

			Local gc:GhostComponent = GhostComponent(e.LookupComponentByType("GhostComponent"))
			AssertNotNull(gc);

			Select gc.ghostInstance.Protocol.GetInteger("id")
			Case 0
				AssertEquals(gc.ghostInstance.Protocol.GetString("payload"), "monkey");
				numChecked += 1
			Case 1
				AssertEquals(gc.ghostInstance.Protocol.GetString("payload"), "pony");
				numChecked += 1
			Case 2
				AssertEquals(gc.ghostInstance.Protocol.GetString("payload"), "pirate");
				numChecked += 1
			Case 3
				AssertEquals(gc.ghostInstance.Protocol.GetString("payload"), "ninja");
				numChecked += 1
			End Select

		End For

		' Make sure all 4 changes made it over.
		AssertEquals(numChecked, 4);
		Print "Checked " + numChecked + " things!"

		' Great, now let's check property tracking.
		_g[0].CheckTrackedProperties();
		_g[1].CheckTrackedProperties();
		_g[2].CheckTrackedProperties();
		_g[3].CheckTrackedProperties();

		' Send the packet.
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(serverStringCache)
		serverManager.WritePacket(serverToClientBuffer);

		serverToClientBuffer.CurrentPosition = 0;
		serverToClientBuffer.StringCache(clientStringCache)
		clientManager.ReadPacket(serverToClientBuffer);

		' Make sure we wrote some bits - should see a change here.
		AssertTrue(serverManager.SizeOfLastUpdate > 24);
         
		' Do another check/update - should see no change.
		_g[0].CheckTrackedProperties();
		_g[1].CheckTrackedProperties();
		_g[2].CheckTrackedProperties();
		_g[3].CheckTrackedProperties();

		' Send the packet.
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(serverStringCache)
		serverManager.WritePacket(serverToClientBuffer);
            
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(clientStringCache)
		clientManager.ReadPacket(serverToClientBuffer);

		' Should have seen no data.
		AssertTrue("Update size " + serverManager.SizeOfLastUpdate, serverManager.SizeOfLastUpdate < 24);
         
		' Ok, change some properties And track.
		_g[0].trackedObject.SetProperty(New PropertyReference("@data.Value1"), BoxString("B"));
		_g[0].trackedObject.SetProperty(New PropertyReference("@data.Value2"), BoxString("3.0"));
		_g[0].CheckTrackedProperties();

		' Send the packet.
		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(serverStringCache)
		serverManager.WritePacket(serverToClientBuffer);

		serverToClientBuffer.CurrentPosition(0)
		serverToClientBuffer.StringCache(clientStringCache)
		clientManager.ReadPacket(serverToClientBuffer);

		' Should have seen data.
		AssertTrue(serverManager.SizeOfLastUpdate > 24);

	End Method

End Class
