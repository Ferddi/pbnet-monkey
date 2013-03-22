
#Print "Target: ${TARGET} Lang: ${LANG}"

#If (LANG="cpp" And TARGET<>"win8") Or LANG="java" Or TARGET="xna"

	Import brl.stream
	Import tcpsocket
	#If LANG="cpp" Or LANG="java"
		Import "native/tcpserver.${LANG}"
	#Else
		Import "native/tcpserver.${TARGET}.${LANG}"
	#End

	Extern
	
	Class BBTcpServer

		Method SetupListen:Bool(port:Int)
		Method CheckConnection:Bool()
		Method SetupSocket:Bool(bbTcpSocket:BBTcpSocket)

	End
	
	Public
	
	Class TcpServer

		Method New()
			_server=New BBTcpServer
		End
		
		Method SetupListen:Bool(port:Int)
			Return _server.SetupListen(port)
		End
		
		Method CheckConnection:TcpSocket()

			If _server.CheckConnection() = True Then
			
				Local tcpSocket:TcpSocket = New TcpSocket()
				
				_server.SetupSocket(tcpSocket.GetBBTcpSocket())
				
				Return tcpSocket
			
			End If
			
			Return Null

		End

		'***** INTERNAL *****
		Method GetBBTcpServer:BBTcpServer()
			Return _server
		End
		
		Private
		
		Field _server:BBTcpServer
		
	End

#Else If TARGET="html5"

	#Error "PushButton Networking server is not available on HTML5, because HTML5 can not listen for connection."

#Else If TARGET="flash"

	#Error "PushButton Networking server is not available on Flash, because Flash can not listen for connection."

#Else

	#Error "PushButton Networking is not available on this target."

#End
