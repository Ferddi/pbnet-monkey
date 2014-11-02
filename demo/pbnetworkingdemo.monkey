
Strict

#MOJO_AUTO_SUSPEND_ENABLED=0

#REFLECTION_FILTER="pbnet.elements.*|pbnet.events.*|pbnet.ghosting.*"
Import reflection

Import mojo
Import pbnet
Import servergame

Function Main:Int()

	New PBNetworkingDemo

	Return 0

End Function

'---------------------------------------------------------------------------------------------------

' SimpleInput from Angelfont Banana by Beaker.
Class SimpleInput

	Private
	Global count:Int = 0
	Field cursorPos:Int = 0

	Public
	Const cursorWidth:Int = 2
	
	Field text:String	
	
	Field x:Int = 0
	Field y:Int = 0
	
	Field height:Int
	Field heightOffset:Int
	
	Method New(txt:String, x:Int=0,y:Int=0)
		Self.text = txt
		Self.x = x
		Self.y = y
		Self.height = 13
		Self.heightOffset = 0
		Self.cursorPos = txt.Length
	End Method
	
	Method Draw:Void()
		Draw(x,y)
	End Method

	Method Draw:Void(x:Int,y:Int)
		DrawText(">" + text,x,y)
		SetAlpha(0.5)
		DrawRect(x+cursorPos*7+7,y,7,13)
		SetAlpha(1.0)

		SetColor(255,255,255)		
		If bkspcFlag = True Then
			SetColor(255,0,0)
		End If
		DrawText("BKSPC", 640 - 7 * 6 * 2, y)

		SetColor(255,255,255)		
		If enterFlag = True Then
			SetColor(255,0,0)
		End If
		DrawText("ENTER", 640 - 7 * 6, y)
		'If count > 3 DrawRect x+font.TextWidth(text[..cursorPos]),y+heightOffset,cursorWidth,height
	End Method
	
	' Flag To store whether we've cleared the chat info message.
	Field clearOnce:Bool = False
      
	' Clear out the helpful message in the chat box the first time we click on it.
	Method HandleChatClear:Void()

		If text = "Type here and press enter to chat." Or text = "Type here and press enter to input commands."

			If clearOnce
				Return
			End If

			clearOnce = True
            
			text = ""
			cursorPos = text.Length

		End If

	End Method
	
	Field bkspcFlag:Bool = False
	Field enterFlag:Bool = False

	Method Update:Int()	
		count = (count+1) Mod 7
		Local asc:Int = GetChar()
		
		Local mx:Int = MouseX()
		Local my:Int = MouseY()
		
		' Backspace and Enter does not work in XNA.  Enuff said.
		Local x1:Int = 640 - 7 * 6 * 2
		bkspcFlag = False
		If mx >= x1 And mx <= x1 + 7 * 5 And
			my >= y And my <= y + 13 Then
			bkspcFlag = True
			If MouseHit(0) = True Then
				asc = 8
			End If
		End If

		x1 = 640 - 7 * 6
		enterFlag = False
		If mx >= x1 And mx <= x1 + 7 * 5 And
			my >= y And my <= y + 13 Then
			enterFlag = True
			If MouseHit(0) = True Then
				asc = 13
			End If
		End If
		
		'Print "Asc: " + asc
		If asc > 31 And asc < 127
			HandleChatClear()
			text = text[0..cursorPos]+String.FromChar(asc)+text[cursorPos..text.Length]
			cursorPos += 1
		Else
			Select asc
				Case 8
					HandleChatClear()
					If cursorPos > 0	'And text.Length > 0
						text = text[0..cursorPos-1]+text[cursorPos..text.Length]
						cursorPos -= 1
					Endif
				Case 13
					HandleChatClear()
'					Case KEY_LEFT, 65573
				Case 65573
					HandleChatClear()
					cursorPos -= 1
					If cursorPos < 0 cursorPos = 0
'					Case KEY_RIGHT, 65575
				Case 65575
					HandleChatClear()
					cursorPos += 1
					If cursorPos > text.Length cursorPos = text.Length
			End
		Endif
		Return asc
	End
	
End Class

'---------------------------------------------------------------------------------------------------

Interface Screen

	Method OnCreate:Int()
	Method OnUpdate:Int()
	Method OnRender:Int()

End Interface

'---------------------------------------------------------------------------------------------------

Global connectScreen:ConnectScreen
Global demoScreen:DemoScreen
Global currentScreen:Screen

Class PBNetworkingDemo Extends App
	
	Field updateCount:Int = 0
	Field startTime:Int = 0
	Field fps:Float = 0

	Method OnCreate:Int()

		connectScreen = New ConnectScreen
		demoScreen = New DemoScreen
		
		' 60 frames per second, please!
		SetUpdateRate 60
		
		EnableKeyboard()

		connectScreen.OnCreate()
		demoScreen.OnCreate()
		
		currentScreen = connectScreen
		
		Return 0
	
	End Method

	Method OnUpdate:Int()
	
		updateCount += 1

		If (Millisecs() - startTime) >= 1000 Then
		
			fps = updateCount / ((Millisecs() - startTime) / 1000)
			startTime = Millisecs()
			updateCount = 0

		End If	

		'Print Millisecs() + ". OnUpdate"

		If KeyHit(KEY_CLOSE) Then Error ""
		
		UpdateAsyncEvents()

		currentScreen.OnUpdate()

		Return 0
	
	End Method
	
	Method OnRender:Int()
	
		Cls 0, 0, 0						' Clear screen

		currentScreen.OnRender()
	
		DrawText(fps, 0, 0)
		
		Return 0

	End Method

End Class

'---------------------------------------------------------------------------------------------------

Class ConnectScreen Implements Screen

	Field simpleInput:SimpleInput

	' MessageStr is for the chat box texts
	Field messageStr:StringList
	
	Field host:String
	Field port:Int
	Field username:String

	Method OnCreate:Int()

		simpleInput = New SimpleInput("Type here and press enter to input commands.", 0, 480 - 16)
		messageStr = New StringList()
		
		host = "127.0.0.1"
		port = 1337
		username = "user"
		
		#If TARGET="android"
			username += "Android"
		#Else If TARGET="ios"
			username += "IOS"
		#Else If TARGET="glfw"
			username += "GLFW"
		#Else If TARGET="flash"
			username += "Flash"
		#Else If TARGET="html5"
			username += "HTML5"
		#Else If TARGET="xna"
			username += "XNA"
		#End

		messageStr.AddLast("Host: " + host)
		messageStr.AddLast("Port: " + port)
		messageStr.AddLast("Username: " + username)
		messageStr.AddLast(" ")
		messageStr.AddLast("Type ~qhelp~q to see the command list.")
		messageStr.AddLast(" ")

		Return 0
	
	End Method
	
	Method OnUpdate:Int()
	
		While messageStr.Count() > 34
			messageStr.RemoveFirst()
		End While
	
		' keycode 13 is Enter
		If simpleInput.Update() = 13 Then
		
			Local split:String[] = simpleInput.text.Split(" ")
			
			Select split[0].ToLower()
			
			Case "host"
				If split.Length() = 2 Then
					host = split[1]
					messageStr.AddLast("Host: " + host)
				End If
			
			Case "port"
				If split.Length() = 2 Then
					port = Int(split[1].Trim())
					messageStr.AddLast("Port: " + port)
				End If
			
			Case "username"
				If split.Length() = 2 Then
					username = split[1]
					messageStr.AddLast("Username: " + username)
				End If
			
			Case "connect"
				messageStr.AddLast("Creating connection to " + host + ":" + port + " as '" + username + "'...")
				demoScreen.StartConnect(host, port, username)
				currentScreen = demoScreen
				
			Case "info"
				messageStr.AddLast("Host: " + host)
				messageStr.AddLast("Port: " + port)
				messageStr.AddLast("Username: " + username)
				
			Case "help"
				messageStr.AddLast("Commands:")
				messageStr.AddLast("host <ip address> - eg host 192.168.1.86 or host 127.0.0.1")
				messageStr.AddLast("port <port number> - eg port 1337")
				messageStr.AddLast("username <user name> eg username admin")
				messageStr.AddLast("connect - to start connection")
				messageStr.AddLast("info - print current ip, port and username")
				messageStr.AddLast("help - this message")					
				
			End Select
			
			messageStr.AddLast(" ")

			simpleInput.text = ""
			simpleInput.cursorPos = simpleInput.text.Length
			
		End If
	
		Return 0
	
	End Method
	
	Method OnRender:Int()
	
		Local y:Int = 0
	
		For Local s:String = Eachin messageStr
			DrawText(s, 4, y  + 480 - 16 - 34 * 13)
			y += 13
		End For
		
		simpleInput.Draw()

		Return 0

	End Method

End Class

'---------------------------------------------------------------------------------------------------

Class ClientChatEvent Extends ChatEvent

	Field client:DemoScreen

	Method New(c:DemoScreen, nr:NetRoot, msg:String = "")

		Super.New(nr, msg)
		client = c

	End Method

	Method Process:Void(conn:EventConnection)

		' Make it so we can handle chat events.
		'ChatEvent.onChatCallback = Function(e:ChatEvent):Void
        '    {

               ' Push the chat text at the End of the Array.
               'lastChatMessages.push(e.message);
               'lastChatMessages.shift();

               ' Update the chat window.
               'UpdateChatWindow();
        '    };
         
		client.messageStr.AddLast(message)

	End Method

End Class

Class ClientCircleEvent Extends CircleEvent

	Field client:DemoScreen

	Method New(c:DemoScreen, nr:NetRoot, _x:Int, _y:Int)

		Super.New(nr)
		client = c
		
		x = _x
		y = _y

	End Method

	Method Process:Void(conn:EventConnection)
	
		client.messageStr.AddLast("Client x: " + x + " y: " + y)
	
	End Method

End Class

Class DemoGhostFactory Extends TemplateGhostFactory

	Field client:DemoScreen

	Method New(c:DemoScreen)
	
		client = c
	
	End Method

	Method MakeGhost:Ghost(prototypeName:String, nr:NetRoot)
	
		'Print "MakeGhost is called."
	
		If prototypeName = "ClientCircle" Then

			Local entity:CircleEntity = New CircleEntity(nr)
			
			'need to figure out netroot
			'need to figure out _protocol
			'need to figure out owningmanager
			
			entity.ghostComponent.OnAdd()
			entity.ghostComponent.ghostInstance.ProtocolName("CircleGhost")
			entity.ghostComponent.ghostInstance.trackedObject = entity
			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.x", "x"))
			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(False, "@Mover.goalPosition.y", "y"))
			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.x", "x"))
			entity.ghostComponent.ghostInstance.trackedProperties.AddLast(New TrackedProperty(True, "@Mover.position.y", "y"))
		
			client.circleList.AddLast(entity)
			
			Return entity.ghostComponent.ghostInstance
			
		End If
		
		Return Null
	
	End Method

End Class

Class DemoScreen Implements Screen

	Const STAGE_WIDTH:Int = 640
	Const STAGE_HEIGHT:Int = 246

	Field netRoot:NetRoot
	Field netEvent:NetEvent
	
	Field simpleInput:SimpleInput

	Field clientChatEvent:ClientChatEvent

	' MessageStr is for the chat box texts
	Field messageStr:StringList = New StringList()
	Field circleList:List<CircleEntity>
	
	' Stuff to do on startup...
	Method OnCreate:Int()
	
		simpleInput = New SimpleInput("Type here and press enter to chat.", 0, 480 - 16)
	
		circleList = New List<CircleEntity>

		netRoot = New NetRoot()
		netEvent = New NetEvent()
		netEvent.SetNetRoot(netRoot)

		Kickoff()
		_OnLoaded()
		
		onTickTime = Millisecs()
		
		'Local key:String = "dGhlIHNhbXBsZSBub25jZQ=="
		'Print "key: " + key
		'Local concat:String = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
		'Print "Concat: " + concat
		'Local sha1:Int[] = Sha1(concat)
		'Print "Sha1: " + sha1
		'Local base64:String = EncodeBase64(sha1, True)
		'Print "Base 64: " + base64
		
		'DebugStop()
		
		'Sha1("The quick brown fox jumps over the lazy dog")
		'Sha1("The quick brown fox jumps over the lazy cog")
		'Sha1("")
		'Sha1("Hello World")Got ghost on id

		Return 0

	End Method

	Field onTickTime:Int = 0

	' Stuff to do while running...
	Method OnUpdate:Int()

'		If connection.HasDataPending() = True Then
'			connection.ReadPackets()
'		End If

		For Local cc:CircleEntity = Eachin circleList

			Local dx:Float = cc.goalX - cc.x
			Local dy:Float = cc.goalY - cc.y
			Local mag:Float = dx * dx + dy * dy
			Local dis:Float = Sqrt(mag)
			
			' This if statment is to stop the jitters when the circle reach the goal.
			If dis < 1 Then
			
				cc.x = cc.goalX
				cc.y = cc.goalY
				
			Else
			
				dx /= dis
				dy /= dis
				
				dx *= 2
				dy *= 2
				
				cc.x += dx
				cc.y += dy
				
			End If
			
			'Print "x: " + cc.x + " y: " + cc.y + " gx: " + cc.goalX + " gy: " + cc.goalY

		End For
		
		If MouseHit() = 1 Then
	
			If MouseX() > 0 And MouseX() < STAGE_WIDTH And MouseY() > 0 And MouseY() < STAGE_HEIGHT Then
				
				connection.PostEvent(New ClientCircleEvent(Self, netRoot, MouseX(), MouseY()))
			
			End If
		
		End If
		
		' keycode 13 is Enter
		If simpleInput.Update() = 13 Then
		
			' Send a chat message on the EventConnection And clear the text box.
			If connection
				connection.PostEvent(New ClientChatEvent(Self, netRoot, username + ": " + simpleInput.text))
			End If

			simpleInput.text = ""
			simpleInput.cursorPos = simpleInput.text.Length

			
'			Local ba:Int[108]
			
'			For Local i:Int = 0 Until 102 Step 9
			
'				ba[i+0] = 87;
'				ba[i+1] = 69;
'				ba[i+2] = 66;
'				ba[i+3] = 83;
'				ba[i+4] = 79;
'				ba[i+5] = 67;
'				ba[i+6] = 75;
'				ba[i+7] = 69;
'				ba[i+8] = 84;
			
'			End For
			
'			Local dataBuffer:DataBuffer = New DataBuffer(102)
'			dataBuffer.PokeBytes(0, ba, 0, 102)
'			connection.tcpSocket.Write(dataBuffer,0,102)
		
		End If
		
		If (Millisecs() - onTickTime) > 100 Then

			'Print Millisecs() + ". OnTick"
			'DebugStop()
			connection.Tick()
			onTickTime += 100
			
		End If

		Return 0

	End Method
	
	Method DrawRectLine:Int(x:Float, y:Float, w:Float, h:Float)
	
		DrawLine(x,   y,   x+w, y)
		DrawLine(x,   y+h, x+w, y+h)
		DrawLine(x,   y,   x,   y+h)
		DrawLine(x+w, y,   x+w, y+h)
		
		Return 0
	
	End Method

	' Drawing code...
	Method OnRender:Int()

		DrawRectLine(1, 1, STAGE_WIDTH - 1, STAGE_HEIGHT - 1)
		
		Local helpText:String = "Click anywhere in the box to move all circles there.";
		DrawText(helpText, STAGE_WIDTH / 2 - helpText.Length() * 7 / 2, STAGE_HEIGHT / 2 - 13 / 2)
		
		SetAlpha(0.5)

		SetColor(0,255,0)
		'Print "cicleList.Count = " + circleList.Count()
		For Local cc:CircleEntity = Eachin circleList
			DrawCircle(cc.x, cc.y, 33)
		End For

		SetColor(255,0,255)		
		For Local cc:CircleEntity = Eachin circleList
			DrawCircle(cc.x, cc.y, 31)	
		End For

		SetAlpha(1.0)

		Local y:Int = 0
		
		SetColor(255,255,255)
		
		For Local s:String = Eachin messageStr
			DrawText(s, 4, y + STAGE_HEIGHT + 6)
			y += 13
		End For

		simpleInput.Draw()

		Return 0

	End Method

	'------------------------------------------------------------------------------------------------

	' Connection To the server.
	Field connection:GhostConnection
	Field netInt:NetworkInterface
	Field netDbg:NetworkDebugVisualizer
      
	' Last six chat/log messages are stored here.
	'Field lastChatMessages:List<String> = New List<String>(6);
      
	' We do a very cheap trick To have usernames show up - prepend them when
	' we send the chat messages! This is a bad idea For any sort of production
	' code.
	Field username:String = "None"

	' Called once app is loaded.
	Method Kickoff:Void()

		'PBE.startup(Self);

		' Hook into the logger so the user can see status messages.
		'Logger.RegisterListener(Self);

		'DebugStop()

		' This just loads our network protocol And register our net events.
		' We could run the code directly here, but having it in one shared
		' place saves time And headache.
		InitializeGameData(netRoot, messageStr)

		clientChatEvent = New ClientChatEvent(Self, netRoot, "Hello")

		' Register our event.
		messageStr.AddLast("Registering events")
		netEvent.RegisterClass("chat", clientChatEvent)
		'netEvent.RegisterClass("circle", clientCircleEvent)
         
		' Start loading the level data.
		'PBE.TemplateManager.AddEventListener(TemplateManager.LOADED_EVENT, _OnLoaded)
		'PBE.TemplateManager.LoadFile("level.xml")

	End Method
      
	' Called when we have loaded And parsed our level data.
	Method _OnLoaded:Void()

		messageStr.AddLast("Loaded templates!")

		' Create the scene.
		messageStr.AddLast("Creating SpatialDB and Scene...")
		'messageStr.AddLast("Basically creating a place to draw - no need in Monkey.")
		'PBE.TemplateManager.InstantiateEntity("SpatialDB");
		'PBE.TemplateManager.InstantiateEntity("Scene");

		'DebugStop()

		' So no dialog, just connect to local host.
		'StartConnect("127.0.0.1", 1337, "Anonymous")
		'StartConnect("192.168.1.80", 1337, "Anonymous")
		'StartConnect("192.168.1.170", 1337, "Anonymous")

		' Pop up the dialog.
		'Field cd:ConnectDialog = New ConnectDialog();
		'AddChild(cd);
		'cd.x = (640 / 2) - cd.width / 2;
		'cd.y = (480 / 2) - cd.height / 2;

	End Method

	' Fill the chat window with the last few chat messages.
	'Method UpdateChatWindow:Void()

		'txtChatLog.text = "";
		'For each(var m:String in lastChatMessages)
		'	txtChatLog.text += (m != Null ? m : "") + "\n";
		'End For

	'End Method
      
'	' Flag To store whether we've cleared the chat info message.
'	Field clearOnce:Bool = False
'
'	' Clear out the helpful message in the chat box the first time we click on it.
'	Method HandleChatClear:Void()
'
'		If txtChatInput.text = "Type here and press enter to chat."
'
'			If clearOnce
'				Return
'			End If
'
'			clearOnce = True
'
'			txtChatInput.text = ""
'
'		End If
'
'	End Method

	Method StartConnect:Void(host:String, port:Int, inUsername:String)

'		#If TARGET="android"
'			inUsername += "Android"
'		#Else If TARGET="ios"
'			inUsername += "IOS"
'		#Else If TARGET="glfw"
'			inUsername += "GLFW"
'		#Else If TARGET="flash"
'			inUsername += "Flash"
'		#Else If TARGET="html5"
'			inUsername += "HTML5"
'		#Else If TARGET="xna"
'			inUsername += "XNA"
'		#End

		' Connect, as we now have access To our templates.
		messageStr.AddLast("Creating connection to " + host + ":" + port + " as '" + inUsername + "'...")

		netInt = New NetworkInterface()
		netDbg = New NetworkDebugVisualizer()
		
		connection = New GhostConnection()
		connection.SetNetEvent(netEvent)
		connection.SetNetworkInterface(netInt)
		connection.SetNetworkDebugVisualizer(netDbg)
		connection.ConnectToServer(host, port)
		connection.ActivateGhosting(netRoot, New DemoGhostFactory(Self))

		username = inUsername;

	End Method

	' Send a chat event If user hits enter.
'	Method HandleChatKey:Void(e:KeyboardEvent)
'
'		' keycode 13 is Enter
'		If e.keyCode = 13
'
'			' Send a chat message on the EventConnection And clear the text box.
'			If connection
'				connection.PostEvent(New ClientChatEvent(username + ": " + txtChatInput.text));
'			End If
'
'			txtChatInput.text = ""
'
'		End If
'
'	End Method
      
	' When user clicks on the graphics canvas, send an event with the position To the server.
	Method _OnCircleClick:Void(event:MouseEvent)

		Local localPoint:Point = graphicsCanvas.globalToLocal(New Point(event.stageX, event.stageY));

		Local c:CircleEvent = New CircleEvent();         

		c.x = localPoint.x;
		c.y = localPoint.y;

		If connection
			connection.PostEvent(c)
		End If

	End Method
          
	' Add log messages To the chat window
	Method AddLogMessage:Void(level:String, loggerName:String, message:String)

		messageStr.AddLast("Log: " + message)

		'lastChatMessages.push("Log: " + message);
		'lastChatMessages.shift();
           
		'UpdateChatWindow();           

	End Method

End Class
