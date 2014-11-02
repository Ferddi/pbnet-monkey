
Strict

#MOJO_AUTO_SUSPEND_ENABLED=0

#REFLECTION_FILTER="pbnet.elements.*|pbnet.events.*|pbnet.ghosting.*"
Import reflection

Import mojo
Import pbnet
'Import pbnet.core.tcpserver
Import brl.socket
Import servergame

Global pbnetServer:PBNetworkingServer

Function Main:Int()

	pbnetServer = New PBNetworkingServer

	Return 0

End Function

Class TcpServer Implements IOnAcceptComplete

	Method New(port:Int)

		_socket = New Socket("server")

		If Not _socket.Bind("", port) Then
			Error "Bind failed"
		End If

		_socket.AcceptAsync(Self)

	End Method
	
	Private
	
	Field _socket:Socket

	Method OnAcceptComplete:Void( socket:Socket, source:Socket )
		If Not socket Error "Accept error"
		pbnetServer.messageStr.AddLast("serverGame.OnConnection(tcpSocket)")
		pbnetServer.serverGame.OnConnection(socket)
		_socket.AcceptAsync( Self )
	End Method
	
End Class

Class PBNetworkingServer Extends App

	Const STAGE_WIDTH:Int = 640
	Const STAGE_HEIGHT:Int = 246

	Field netRoot:NetRoot
	Field netEvent:NetEvent
	'Field clientChatEvent:ClientChatEvent
	Field netInt:NetworkInterface
	Field netDbg:NetworkDebugVisualizer

	Field messageStr:StringList = New StringList

	' Stuff to do on startup...
	Method OnCreate:Int()
		
		'clientCircleList = New List<ClientCircle>

		netRoot = New NetRoot()
		netEvent = New NetEvent()
		netEvent.SetNetRoot(netRoot)
		
		netInt = New NetworkInterface()
		netDbg = New NetworkDebugVisualizer()

		' 60 frames per second, please!
		SetUpdateRate 60

		OnInvoke()
		
		onMoveGhostsTime = Millisecs()
		onTickTime = Millisecs()
		
		Return 0

	End Method

	Field onMoveGhostsTime:Int = 0
	Field onTickTime:Int = 0
	
'	Field tcpSocketFerdi:TcpSocket = Null
	Field _socket:Socket

	' Stuff to do while running...
	Method OnUpdate:Int()

		UpdateAsyncEvents()
		
		If KeyHit(KEY_CLOSE) Then Error ""
		
		While messageStr.Count() > 18 
		
			messageStr.RemoveFirst()

		End While

'		Local tcpSocket:TcpSocket = tcpServer.CheckConnection()
'		If tcpSocket <> Null Then
'			'DebugStop()
'			messageStr.AddLast("serverGame.OnConnection(tcpSocket)")
'			serverGame.OnConnection(tcpSocket)
'			tcpSocketFerdi = tcpSocket
'		End If
				
'		netInt.Read()
		
		If (Millisecs() - onMoveGhostsTime) > 1000 Then
		
			serverGame._MoveGhosts()
			onMoveGhostsTime += 1000
		
		End If

		If (Millisecs() - onTickTime) > 100 Then

			'Print Millisecs() + ". onTick"

			netInt.Tick()
			onTickTime += 100
			
		End If

'		If MouseHit(0) > 0 Then
'
'			serverGame._Click(MouseX(), MouseY())			
'
'			If tcpSocketFerdi <> Null Then
'
'				Local str:String = "GLFWServerGLFWServerGLFWServerGLFWServerGLFWServerGLFWServerGLFWServerGLFWServerGLFWServerGLFWServer"
'
'				Const PACKETSIZE:Int = 100
'				Const LENGTHFIELDSIZE:Int = 2
'
'				Local bs:BitStream
'
'				' Encode a text for sending to clients via ws://
'				'Local b1:Int = $80 | $01	' Text
'				Local b1:Int = $80 | $02	' Binary
'				Local length = str.Length + 2
'
'				If length <= 125 Then
'					bs = BitStream(length + 2)
'					bs.WriteByte(b1)
'					bs.WriteByte(length)
'				Else If length > 125 And length < 65536 Then
'					bs = BitStream(length + 4)	'extended payload length is 16-bit.
'					bs.WriteByte(b1)
'					bs.WriteByte(126)
'					bs.WriteInt(length, 16)
'				Else If length >= 65536
'					bs = BitStream(length + 4 + 4)	'extended payload length is 64-bit!
'					bs.WriteByte(b1)
'					bs.WriteByte(127)
'					bs.WriteInt(0, 32)
'					bs.WriteInt(length, 32)
'				End If
'				
'				bs.WriteByte(0)
'				bs.WriteByte(100)
'				
'				Local strChars:Int[] = str.ToChars()
'				For Local i:Int = 0 Until 100
'					bs.WriteByte(strChars[i])
'				End For
'				
'				
'				'Local ba:Int[PACKETSIZE + LENGTHFIELDSIZE]
'				'Local pos:Int = Ceil(bs.CurrentPosition() / 8.0)
'				Local bsBytes:Int[] = bs.GetByteArray()
'				Local totalBytes:Int = Ceil(bs.totalBits / 8.0)
'				
'				'ba[0] = (pos Shl 8) & $FF
'				'ba[1] = pos & $FF
'				
'				'For Local i:Int = 0 Until totalBytes
'				'	ba[i + 2] = bsBytes[i] 
'				'End For
'
'				Local dataBuffer:DataBuffer = New DataBuffer(totalBytes)
'				dataBuffer.PokeBytes(0, bsBytes, 0, totalBytes)
'				Print Millisecs() + ". NetworkConnection.tcpSocket.Write Start"
'				tcpSocketFerdi.Write(dataBuffer, 0, totalBytes)
'				
'			End If
'		
'		End If
		
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

		Cls 0, 0, 0						' Clear screen
		
		DrawRectLine(1, 1, STAGE_WIDTH-1, STAGE_HEIGHT)
		
		Local y:Int = 0
		
		For Local s:String = Eachin messageStr
			DrawText(s, 4, y + 6)
			y += 13
		End For

		y = 0
		For Local s:String = Eachin netDbg.log
			DrawText(s, 4, STAGE_HEIGHT + y + 6)
			y += 13
		End For

		Return 0

	End Method
	
	Method OnConnectComplete:Void( connected:Bool,source:Socket )
		If Not connected Error "Error connecting"
		'SendMore
	End Method
	
	Method OnSendComplete:Void( data:DataBuffer,offset:Int,count:Int,source:Socket )
		_socket.ReceiveAsync(_data,0,_data.Length,Self)
	End Method

	Method OnReceiveComplete:Void( data:DataBuffer,offset:Int,count:Int,source:Socket )
		Print "Received response:" + data.PeekString( offset,count )
	End Method

	'------------------------------------------------------------------------------------------------

	Const DEFAULT_PORT:Int = 1337

	Field started:Bool = False
	'Field swfPath:String = ""
	'Field serverGameClass:String = ""
	Field port:Int = DEFAULT_PORT

	'Field configLoader:URLLoader
	'Field swfLoader:Loader

'	Field tcpServer:TcpServer
	Field _server:TcpServer
	Field serverGame:ServerGame

	Method OnInvoke:Void()

		'Print "Invoked: "

		' If we are allready started just return
		If started = True
			Return
		End If

		' Set started so this only happens once
		started = True

		' Activate the window so enter frames are send
		'stage.nativeWindow.activate()

		' Load config
		LoadConfig()
		ParseConfig()
		InitializeServerGame();

	End Method
            
	Method LoadConfig:Void()

		'configLoader = New URLLoader()
		'configLoader.addEventListener(Event.COMPLETE, OnConfigLoaded)
		'configLoader.addEventListener(IOErrorEvent.IO_ERROR, OnConfigError)
		'configLoader.load(New URLRequest("app:/config.xml"))

	End Method

	'Method OnConfigLoaded:Void(e:Event)

		'e.target.removeEventListener(Event.COMPLETE, OnConfigLoaded)
		'e.target.removeEventListener(IOErrorEvent.IO_ERROR, OnConfigError)

		'ParseConfig()

	'End Method

	'Method OnConfigError:Void(e:IOErrorEvent)

		'e.target.removeEventListener(Event.COMPLETE, OnConfigLoaded)
		'e.target.removeEventListener(IOErrorEvent.IO_ERROR, OnConfigError)                

		'Error "Could not loading config from config.xml"

	'End Method

	Method ParseConfig:Void()

		'Local config:XML = New XML(configLoader.data)
		'Print config.toXMLString()
                
		' Parse the config
		'For Local child:XML = Eachin config.children()

		'	If child.name() = "port" Then
		'		Self.port = 1337 'child.valueOf()
		'	End If

		'	If child.name() = "serverGameClass" Then
		'		this.serverGameClass = "ServerGame" 'child.valueOf(); 
		'	End If

		'	If child.name() = "swf" Then
		'		this.swfPath = "ServerGame.swf" 'child.valueOf(); 
		'	End If

		'End For

		'If swfPath = "" Then
		'	Error "swf is not specified in config"
		'End If

		'If serverGameClass = "" Then
		'	Error "serverGameClass is not specified in config"
		'End If

		messageStr.AddLast("Connecting to ServerGame on port " + port)
                  
		LoadSWF()

	End Method

	Method LoadSWF:Void()

		' NOTE: AIR cannot load swf files outside the app:// directory. The workaround
		' is To load the bytes first And than load the swf from the bytes
                
	'	this.swfLoader = New Loader();
	'	this.swfLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, OnSWFLoaded);
	'	this.swfLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, OnSWFError);
	'	this.swfLoader.load(New URLRequest("app:/"+this.swfPath), New LoaderContext(False, ApplicationDomain.currentDomain));   

	End Method
            
	'Method OnSWFError:Void(e:IOErrorEvent)

	'	e.target.removeEventListener(Event.COMPLETE, OnSWFLoaded);
	'	e.target.removeEventListener(IOErrorEvent.IO_ERROR, OnSWFError);
                
	'	Error "Could not load the swf from '" + this.swfPath + "' error: " + e.text

	'End Method

	'Method OnSWFLoaded:Void(e:Event)

	'	e.target.removeEventListener(Event.COMPLETE, OnSWFLoaded);
	'	e.target.removeEventListener(IOErrorEvent.IO_ERROR, OnSWFError);

	'	Print "SWF loaded from '"+this.swfPath+"'"

	'	InitializeServerGame();

	'End Method
            
	Method InitializeServerGame:Void()

		messageStr.AddLast("Initializing IServerGame")

		Try

			'Local serverGameType:Class = getDefinitionByName(serverGameClass) as Class;
			'Print "Class: " + serverGameType
			'serverGame = New serverGameType()
			serverGame = New ServerGame(messageStr)
			'Logger.registerListener(this)
			serverGame.OnStart(netRoot, netEvent, netInt, netDbg, port)    
			' Initialize the socket
			InitializeSocket();

		Catch e:NetError

			Error "Could not instantiate IServerGame type 'ServerGame' error: " + e.ToString()
			'Throw e

		End Try

	End Method
            
	Method InitializeSocket:Void()
	
'		tcpServer = New TcpServer()
'		tcpServer.SetupListen(port)

		_server = New TcpServer(port)

		' Setup the server socket
		'serverSocket = New ServerSocket();
		'serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, OnConnect);
		'serverSocket.bind(port);
		'serverSocket.listen();      

		' Start the debug visualize
		netDbg.smEnabled = True;     
                
		' Note: now we are finished in the server 

	End Method

	'Method Error:Void(message:String)

	'	Print "Error: " + message
	'	Alert.show(message, "Fatal Error")

	'End Method

	'Method OnConnect:Void(e:ServerSocketConnectEvent)
	'	serverGame.onConnection(e.socket)
	'End Method
            
	' Last six chat/log messages are stored here.
	Field lastLogMessages:StringList = New StringList()
            
	' Add log messages To the chat window
	Method AddLogMessage:Void(level:String, loggerName:String, message:String)

		lastLogMessages.push(level+": " + loggerName+" - "+ message)
		lastLogMessages.shift()

		UpdateLogWindow()

	End Method

	' Fill the chat window with the last few chat messages.
	Method UpdateLogWindow:Void()
	
		Local y:Int = 0

		For Local m:String = Eachin lastLogMessages

			DrawText(m, 0, y * 13)
			y += 1

		End For

	End Method

End Class
