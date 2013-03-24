
#Print "Target: ${TARGET} Lang: ${LANG}"

#If LANG="cpp" Or LANG="java" Or TARGET="flash" Or TARGET="html5" Or TARGET="xna"


	Import brl.stream
	#If TARGET="win8"
		Import "native/tcpsocket.${TARGET}.${LANG}"
	#If LANG="cpp" Or LANG="java"
		Import "native/tcpsocket.${LANG}"
	#Else
		Import "native/tcpsocket.${TARGET}.${LANG}"
	#End

	Extern
	
	Class BBTcpSocket Extends BBStream

		Method Connect:Bool(host:String, port:Int)
		Method ReadAvail:Int()
		Method WriteAvail:Int()
		Method State:Int()		' 0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR

	End
	
	Public
	
	Class TcpSocket Extends Stream
	
		Method New()
			_socket=New BBTcpSocket
		End
	
		Method Connect:Bool(host:String, port:Int)
			Return _socket.Connect(host, port)
		End
		
		Method ReadAvail:Int()

			'Local db:DataBuffer= New DataBuffer(200)
			'_socket.Read(db,0,2)
			'Local length:Int = db.PeekByte(0) * 256 + db.PeekByte(1)
			'Print "Length: " + length		
					
			Return _socket.ReadAvail()
		End
		
		Method WriteAvail:Int()
			Return _socket.WriteAvail()
		End
		
		Method State:Int()
			' 0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR
			Return _socket.State()
		End

		'Stream
		Method Close:Void()
			If _socket 
				_socket.Close
				_socket=Null
			Endif
		End
		
		Method Eof:Int()
			Return _socket.Eof()
		End
		
		Method Length:Int()
			Return _socket.Length()
		End
		
		Method Position:Int()
			Return _socket.Position()
		End
		
		Method Seek:Int( position:Int )
			Return _socket.Seek( position )
		End
		
		Method Read:Int( buffer:DataBuffer,offset:Int,count:Int )
			Return _socket.Read( buffer,offset,count )
		End
		
		Method Write:Int( buffer:DataBuffer,offset:Int,count:Int )
			Return _socket.Write( buffer,offset,count )
		End
		
		'***** INTERNAL *****
		Method GetBBTcpSocket:BBTcpSocket()
			Return _socket
		End
		
		Private
		
		Field _socket:BBTcpSocket
		
	End

#Else

	#Error "PushButton Networking is not available on this target."

#End
