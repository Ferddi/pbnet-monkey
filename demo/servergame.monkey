
Strict

Import pbnet
Import chatevent
Import circleevent
Import circleentity

Class ServerChatEvent Extends ChatEvent

	Field serverGame:ServerGame

	Method New(sg:ServerGame, nr:NetRoot, msg:String = "")

		Super.New(nr, msg)
		serverGame = sg
				
		'Print "ServerChatEvent.New"

	End Method

	Method Process:Void(conn:EventConnection)

		serverGame.messageStr.AddLast("Handling Chat: " + message)
		
		For Local nc:NetworkConnection = Eachin serverGame.netInt.connections
			Local ec:EventConnection = EventConnection(nc)
            ec.PostEvent(New ChatEvent(netRoot, message));
		End For

		' Echo chat messages.
		'ChatEvent.onChatCallback = Function(ce:ChatEvent):Void
        '    {
		'		Print "Chat: " + ce.message
               
				' Echo events out To each connection.
        '       NetworkInterface.instance.forEachConnection(Function (nc:NetworkConnection):Void
        '       {
        '          If(nc is EventConnection)
        '             (nc as EventConnection).postEvent(New ChatEvent(ce.message));
        '       });
        '    }

	End Method
	
End Class

Class ServerCircleEvent Extends CircleEvent

	Field serverGame:ServerGame

	Method New(sg:ServerGame, nr:NetRoot)

		Super.New(nr)
		serverGame = sg

	End Method

	Method Process:Void(conn:EventConnection)

		serverGame._Click(x, y)
	
		' Update circle state.
		'CircleEvent.onCircleCallback = Function(ce:CircleEvent):Void
        '    {
		'		Print "Handling click!"
		'		_lastClickTime = PBE.processManager.virtualTime;
		'		For each(var circle:IEntity in circles)
		'			circle.setProperty(New PropertyReference("@Mover.goalPosition"), New Point(ce.x, ce.y));
		'		End For
        '    }

	End Method

End Class

'Class ServerGhostFactory Extends TemplateGhostFactory
'
'	Method MakeGhost:Ghost(prototypeName:String, nr:NetRoot)
'	
'		Print "ServerGhostFactory MakeGhost is called."
'	
'		If prototypeName = "ServerCircle" Then
'
'			Local entity:CircleEntity = New CircleEntity(nr)
'			
'			'need to figure out netroot
'			'need to figure out _protocol
'			'need to figure out owningmanager
'			
'			entity.ghostComponent.OnAdd()
'			entity.ghostComponent.ghostInstance.ProtocolName("CircleGhost")
'			entity.ghostComponent.ghostInstance.trackedObject = entity
'			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.x", "x"))
'			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.y", "y"))
'			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.x", "x"))
'			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.y", "y"))
'		
'			'clientCircleList.AddLast(entity)
'			
'			Return entity.ghostComponent.ghostInstance
'			
'		End If
'		
'		Return Null
'	
'	End Method
'
'End Class

' Common initialization of networking protocol + events.
Function InitializeGameData:Void(nr:NetRoot, ms:StringList)

	' Load up some network protocol XML.
	ms.AddLast("Initializing networking protocol.")

	Local eventXML:String = "" +
	"<library>" +
	"	<event>" +
	"		<name>chat</name>" +
	"		<string>" +
	"			<name>message</name>" +
	"		</string>" +
	"	</event>" +
	"	<event>" +
	"		<name>circle</name>" +
	"		<rangedInt>" +
	"			<name>x</name>" +
	"			<min>0</min>" +
	"			<max>1000</max>" +
	"		</rangedInt>" +	
	"		<rangedInt>" +
	"			<name>y</name>" +
	"			<min>0</min>" +
	"			<max>1000</max>" +
	"		</rangedInt>" +	
	"	</event>" +
	"	<ghost>" +
	"		<name>CircleGhost</name>" +
	"		<dirtyFlag>" +
	"			<name>flag1</name>" +
	"			<rangedInt>" +
	"				<name>x</name>" +
	"				<min>0</min>" +
	"				<max>1000</max>" +
	"			</rangedInt>" +
	"			<rangedInt>" +
	"				<name>y</name>" +
	"				<min>0</min>" +
	"				<max>1000</max>" +
	"			</rangedInt>" +
	"			<flag>" +
	"				<name>state</name>" +
	"			</flag>" +
	"		</dirtyFlag>" +
	"	</ghost>" +
	"</library>"

	'DebugStop()

	nr.LoadNetProtocol(eventXML)

End Function      

' Implementation of server side game logic. Extends Sprite so it can be
' compiled as a root For a SWF
Class ServerGame Implements IServerGame, IScoper

	Field netRoot:NetRoot
	Field netEvent:NetEvent
	
	Field netInt:NetworkInterface
	Field netDbg:NetworkDebugVisualizer

	Field serverChatEvent:ServerChatEvent
	Field serverCircleEvent:ServerCircleEvent
	
'	Field serverGhostFactory:ServerGhostFactory
	Field messageStr:StringList
	
	Field port:Int

	Method New(ms:StringList)
	
		messageStr = ms
	
	End Method

	' Called by the server binary when it starts up.
	Method OnStart:Void(nr:NetRoot, ne:NetEvent, ni:NetworkInterface, nd:NetworkDebugVisualizer, p:Int)

		' Register some types
		'PBE.registerType(Interpolated2DMoverComponent);
		'PBE.registerType(BasicSpatialManager2D);

		' Startup the engine first
		'PBE.startup(main);
		
		netRoot = nr
		netEvent = ne
		
		netInt = ni
		netDbg = nd
		
		port = p
		
		'DebugStop()

		' Load up some network protocol XML.
		InitializeGameData(netRoot, messageStr)
		
		serverChatEvent = New ServerChatEvent(Self, netRoot)
		serverCircleEvent = New ServerCircleEvent(Self, netRoot)
		
'		serverGhostFactory = New ServerGhostFactory()

		' Register our event.
		netEvent.RegisterClass("chat", serverChatEvent)
		netEvent.RegisterClass("circle", serverCircleEvent)

		circles = New List<IEntity>

         
		' Load the level XML.
		'PBE.templateManager.addEventListener(TemplateManager.LOADED_EVENT, _onLoadComplete)
		'PBE.templateManager.loadFile("level.xml")
		
		OnLoadComplete()

	End Method

	' Called by the server binary when a connection comes in.
	Method OnConnection:Void(ts:TcpSocket)

		'DebugStop()

		' Set up the connection, And add it To the list.
		Local ec:GhostConnection = New GhostConnection();
		ec.SetNetEvent(netEvent)
		ec.SetNetworkInterface(netInt)
		ec.SetNetworkDebugVisualizer(netDbg)
		ec.ActivateGhosting(netRoot, Null, True)
		ec.ScopeObject(Self)
		ec.AcceptClientConnection(ts, "", port)

		' Send a welcome message.
		'ec.PostEvent(New ServerChatEvent(netRoot, "Welcome to Circle Click: Multiplayer Edition!"))
         
		'ec.SendPacket()

	End Method
      
	' Scope callback; set all the circles in scope.
	Method ScopeObjects:Void(gm:GhostManager)

		For Local circle:IEntity = Eachin circles

			If Not circle
				Continue
			End If

			Local gc:GhostComponent = circle.ghostComponent
			Local g:Ghost = gc.ghostInstance;

			g.CheckTrackedProperties();
			gm.MarkGhostInScope(g, 1.0);

		End For

	End Method

	' Kick off game simulation once level load is done.
	Method OnLoadComplete:Void() '(e:*)

		messageStr.AddLast("Loaded level data, initializing ghosts.")
		'PBE.templateManager.instantiateEntity("SpatialDB");

		For Local i:Int=0 Until 10

			'Local newC:IEntity = PBE.templateManager.instantiateEntity("ServerCircle");
			Local newC:CircleEntity = New CircleEntity(netRoot)
			
			'need to figure out netroot
			'need to figure out _protocol
			'need to figure out owningmanager
			
			'DebugStop()
			
			newC.ghostComponent.OnAdd()
			newC.ghostComponent.ghostInstance.prototypeName = "ClientCircle"
			newC.ghostComponent.ghostInstance.ProtocolName("CircleGhost")
			newC.ghostComponent.ghostInstance.trackedObject = newC
			newC.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.x", "x"))
			newC.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.y", "y"))
			'newC.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.x", "x"))
			'newC.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.y", "y"))
			
			'newC.SetProperty(New PropertyReference("@Mover.initialPosition"), New Point(50 * i, 25));

			newC.SetProperty("@Mover.position.x", BoxInt(50 * i))
			newC.SetProperty("@Mover.position.y", BoxInt(25))

			circles.AddLast(newC);

		End For

		messageStr.AddLast("Ghosts initialized.")
         
		' Every 1 second, assign a New random position.
		'SetInterval(_MoveGhosts, 1000);

	End Method
      
	' Update the target position on all the circles.
	Method _Click:Void(x:Int, y:Int)
	
		_lastClickTime = Millisecs()
         
		messageStr.AddLast( "Handling Click X: " + x + " Y: " + y)

		For Local circle:IEntity = Eachin circles
			circle.SetProperty("@Mover.goalPosition.x", BoxInt(x));
			circle.SetProperty("@Mover.goalPosition.y", BoxInt(y));
		End For

	End Method

	' Update the target position on all the circles.
	Method _MoveGhosts:Void()

		If (Millisecs() - _lastClickTime) < 2000 Then
			Return
		End If
         
        'messageStr.AddLast(Millisecs() + ". Moving ghosts.")
		'Print Millisecs() + ". Moving ghosts."

		For Local circle:IEntity = Eachin circles
			circle.SetProperty("@Mover.goalPosition.x", BoxInt(500 * Rnd() + 25));
			circle.SetProperty("@Mover.goalPosition.y", BoxInt(50  * Rnd() + 25));
		End For

	End Method

	Field _lastClickTime:Int = 0
	'Field circleStates:Array = New Array(10)
	Field circles:List<IEntity> '= New Array()

End Class
