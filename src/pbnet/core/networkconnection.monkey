
Strict

Import pbnet
Import brl.socket
Import sha1
Import diddy.base64

Class TcpSocket Implements IOnConnectComplete, IOnSendComplete, IOnReceiveComplete

	Field _socket:Socket ' Using brl.socket asynchronous.
	Field _netCon:NetworkConnection
	Field _data:DataBuffer
	
	Const INIT:Int = 0
	Const CONNECTED:Int = 1
	Const CLOSED:Int = 2
	
	Field _state:Int

	Method New(nc:NetworkConnection, s:Socket = Null)
	
		_data = New DataBuffer(1024)
		_socket = s
		_netCon = nc

		If _socket = Null Then 
			_state = INIT
		Else
			_state = CONNECTED
		End If

	End Method
	
	Method Receive:Void()
	
		If _state = CONNECTED Then 
			_socket.ReceiveAsync(_data, 0, _data.Length, Self)
		End If

	End Method
	
	Method Send:Void(db:DataBuffer, offset:Int, count:Int)
	
		If _state = CONNECTED Then
			_socket.SendAsync(db, offset, count, Self)
		End If
	
	End Method

	Method Connect:Void(host:String, port:Int)

		_socket = New Socket("stream")
		_socket.ConnectAsync(host, port, Self)
		_state = CONNECTED

	End Method
	
	Method OnConnectComplete:Void(connected:Bool, source:Socket)

		Print "OnConnectComplete"

		If Not connected Error "Client has error connecting."

		' Start to receive the messages a synchronously.
		Receive()

	End Method
	
	Method OnSendComplete:Void(data:DataBuffer, offset:Int, count:Int, source:Socket)

		Print "OnSendComplete count = " + count
		
		If count < 0 Then
			_state = CLOSED
		End If

		'_socket.ReceiveAsync _data,0,_data.Length,Self

	End Method

	Method OnReceiveComplete:Void(data:DataBuffer, offset:Int, count:Int, source:Socket)

		Print "OnReceiveComplete count = " + count

		If count < 0 Then 
			_state = CLOSED
		End If

		'Print "Received response:"+data.PeekString( offset,count )
		_netCon.ReadPackets(data, offset, count)
	
		' We complete that message, look for another message, and another, and another ...
		Receive()

	End Method

End Class

' Basic network connection which can send And receive fixed size "packets"
' over a TCP Socket. We refer To "packets" because If we ever support UDP
' Then they will become real individual packets flying over the wire.
' 
' This deals with most of the hassle around opening Or accepting a connection.
' 
' Packets are (currently) 100 bytes in size with a 2 byte short indicating
' how many bytes are in use. These are configured using constants.
' 
' We use fixed size packets at a fixed rate in order to have very consistent
' bandwidth usage. This is important because routers will tend to allocate
' bandwidth to those that use it. If we have an uneven bandwidth usage, then
' when a lot of activity comes down the wire, there may be a lag spike or
' dropped packets as routers along the network path adjust to the new load.
'
' Subclasses implement their own logic in ReadPacket/WritePacket (making
' sure to pass control up to the super class).
' 
' You will not ever need to call any of the send packet methods except in
' test/debug situations as NetworkInterface deals with it for you. The
' receive methods are called automatically as data comes in, as well.
Class NetworkConnection

	Field netInt:NetworkInterface = Null
	Field netDbg:NetworkDebugVisualizer = Null
	Field tcpSocket:TcpSocket = Null

	Method New()
	
	End Method
	
	Method SetNetworkInterface:Void(ni:NetworkInterface)
		netInt = ni
	End Method

	Method SetNetworkDebugVisualizer:Void(ndv:NetworkDebugVisualizer)
		netDbg = ndv
	End Method

	' The host name or IP that we are connected to.
	Method Host:String()

		Return _host;

	End Method
      
	' The port that we are connected To.
	Method Port:Int()

		Return _port;

	End Method
      
	' Called every so often from the NetworkInterface To give us a chance 
	' To send packets.
	Method Tick:Void()

		' For now, just send a packet every network tick (about 10hz).
		'If tcpSocket._state = TcpSocket.CONNECTED Then 
		'TODO need to remove connection!!!
			SendPacket()
		'End If

	End Method

	' Associate this connection with a socket that's been opened to us.
	' Called by the server, And only called once on a connection.
	Method AcceptClientConnection:Void(s:Socket, host:String, port:Int)

		If netInt = Null Then
			Print "Error: NetworkInterface is null.  Please use NetworkConnection.SetNetworkInterface to specify the NetworkInterface."
			Return
		End If

		' Add us To the network Interface.
		netInt.AddConnection(Self);

		' Note who the connection is with.
		_host = host;
		_port = port;

		' Set up the socket.
		tcpSocket = New TcpSocket(Self, s)
		tcpSocket.Receive()

		ConfigureListeners()

	End Method
      
	' Create a New socket And open a connection To a host.
	Method ConnectToServer:Void(host:String, port:Int)

		If netInt = Null Then
			Print "Error: NetworkInterface is null.  Please use NetworkConnection.SetNetworkInterface to specify the NetworkInterface."
			Return
		End If

		' Add us To the network Interface.
		netInt.AddConnection(Self);

		' Create & connect with a socket.
		'Print "Trying to connect TCP Socket ..."
		'tcpSocket = New TcpSocket()
		'If tcpSocket.Connect(host, port) = True Then
		'	Print "TCP Socket is connected!"
		'End If

		tcpSocket = New TcpSocket(Self)
		tcpSocket.Connect(host, port)
		
		'socket = New Socket(host, port);
		_host = host
		_port = port

		ConfigureListeners()

	End Method
      
	' Returns True when there is data To send.
	Method HasDataPending:Bool()

		'Print "tcpSocket.ReadAvail(): " + tcpSocket.ReadAvail()
		Print "PROBLEM: HasDataPending Method is called!"

'		If tcpSocket.ReadAvail() > 0 Then
'			Return True			
'		End If

        Return False

	End Method

	' Read a packet contained in a BitStream.
	Method ReadPacket:Void(bs:BitStream)

         bs.StringCache(stringCache)
         
		' Do nothing - subclasses will implement this!

	End Method
      
	' Write a packet To the provided BitStream.
	Method WritePacket:Void(bs:BitStream)

		bs.StringCache(stringCache)

		' Do nothing - subclasses will implement this!

	End Method
      
	' Prepare And send a packet.
	Method SendPacket:Void()

		'If Not socket.connected
'		If firstResponse = False And tcpSocket.State() <> 1 Then
		If firstResponse = False And tcpSocket._socket.IsConnected() = False Then

			' Just wait If we never were connected.
			If Not _wasConnected
				Return
			End If

			If netInt = Null Then
				Print "Error: NetworkInterface is null.  Please use NetworkConnection.SetNetworkInterface to specify the NetworkInterface."
				Return
			End If

			'Print "SendPacket - Could not send packet on a closed socket!"
			netInt.RemoveConnection(Self)

			Return

		End If
          
		_wasConnected = True
          
		'DebugStop()

		Local bs:BitStream = New BitStream(PACKETSIZE);
		bs.Reset();
		WritePacket(bs);
		TransmitPacket(bs);

	End Method

	' En-packet-ize And transmit a BitStream down the wire.
	Method TransmitPacket:Void(bs:BitStream)
		'Print Millisecs() + ". NetworkConnection.TransmitPacket"
		' Write bitstream.
		'Local ba:ByteArray = New ByteArray();
		'ba.WriteShort(Math.ceil(bs.currentPosition / 8.0));
		'ba.WriteBytes(bs.GetByteArray(), 0, PACKETSIZE);
		'ba.position = 0;
		
		'DebugStop()
		
		'Print "bs.CurrentPosition(): " + bs.CurrentPosition()
		
		If isClientHtml5WebSocket = True Then

			' 10 - worst case scenario is fin & opcode (8-bits), mask & payload len (8-bits),
			' and lastly extended payload can be 0-bit, 16-bits or 64-bits
			' 8 bits + 8 bits + 64 bits = 80 bits / 8 = 10 bytes, hence + 10
			Local ba:Int[PACKETSIZE + LENGTHFIELDSIZE + 10]
			Local pos:Int = Ceil(bs.CurrentPosition() / 8.0)
			Local bsBytes:Int[] = bs.GetByteArray()

			' Encode a text for sending to clients via ws://
			Local b1:Int = $80 | $02	'$02 means binary frame
			Local length:Int = PACKETSIZE + LENGTHFIELDSIZE
			Local headerLen:Int = 0

			If length <= 125 Then

				ba[0] = b1
				ba[1] = length
				headerLen = 2

			Else If length > 125 And length < 65536 Then

				Print "TODO: the following if statement has not been tested!"
				ba[0] = b1
				ba[1] = 126
				ba[2] = (length Shl 8) & $FF
				ba[3] = length & $FF
				headerLen = 4

			Else If length >= 65536

				Print "TODO: the following if statement has not been tested!"
				ba[0] = b1
				ba[1] = 127
				ba[2] = 0
				ba[3] = 0
				ba[4] = 0
				ba[5] = 0
				ba[6] = (length Shl 24) & $FF
				ba[7] = (length Shl 16) & $FF
				ba[8] = (length Shl 8) & $FF
				ba[9] = length & $FF
				headerLen = 10

			End If

			ba[headerLen + 0] = (pos Shl 8) & $FF
			ba[headerLen + 1] = pos & $FF
			
			For Local i:Int = 0 Until PACKETSIZE
				ba[headerLen + 2 + i] = bsBytes[i] 
			End For
	
			If netDbg = Null Then
				Print "Error: NetworkDebugVisualizer is null.  Please use NetworkConnection.SetNetworkDebugVisualizer to specify the NetworkDebugVisualizer."
				Return
			End If
	
			netDbg.ReportOutgoingTraffic(ba)
	
			Local dataBuffer:DataBuffer = New DataBuffer(headerLen + PACKETSIZE + LENGTHFIELDSIZE)
			dataBuffer.PokeBytes(0, ba, 0, headerLen + PACKETSIZE + LENGTHFIELDSIZE)
			tcpSocket.Send(dataBuffer, 0, headerLen + PACKETSIZE + LENGTHFIELDSIZE)
			'tcpSocket._socket.SendAsync(dataBuffer, 0, headerLen + PACKETSIZE + LENGTHFIELDSIZE, tcpSocket)

		Else
		
			Local ba:Int[PACKETSIZE + LENGTHFIELDSIZE]
			Local pos:Int = Ceil(bs.CurrentPosition() / 8.0)
			Local bsBytes:Int[] = bs.GetByteArray()
			
			ba[0] = (pos Shl 8) & $FF
			ba[1] = pos & $FF
			
			For Local i:Int = 0 Until PACKETSIZE
				ba[i + 2] = bsBytes[i] 
			End For
	
			If netDbg = Null Then
				Print "Error: NetworkDebugVisualizer is null.  Please use NetworkConnection.SetNetworkDebugVisualizer to specify the NetworkDebugVisualizer."
				Return
			End If
	
			netDbg.ReportOutgoingTraffic(ba)
	
			Local dataBuffer:DataBuffer = New DataBuffer(PACKETSIZE + LENGTHFIELDSIZE)
			dataBuffer.PokeBytes(0, ba, 0, PACKETSIZE + LENGTHFIELDSIZE)
			'Print Millisecs() + ". NetworkConnection.tcpSocket.Write Start"
			tcpSocket.Send(dataBuffer, 0, PACKETSIZE + LENGTHFIELDSIZE)
			'tcpSocket._socket.SendAsync(dataBuffer, 0, PACKETSIZE + LENGTHFIELDSIZE, tcpSocket)
			'Print Millisecs() + ". NetworkConnection.tcpSocket.Write Stop"
			'socket.writeBytes(ba, 0, PACKETSIZE + LENGTHFIELDSIZE);
			'socket.flush();

		End If

	End Method
      
	' Same as SendPacket, but write To a buffer rather than across the wire.
	Method SendPacketToBuffer:Void(buffer:ByteArray)

		' Prepare packet.
		Local bs:BitStream = New BitStream(PACKETSIZE);
		bs.Reset();
		WritePacket(bs);

		' Write bitstream.
		Local ba:ByteArray = buffer
		ba.WriteShort(Ceil(bs.CurrentPosition() / 8.0));
		ba.WriteBytes(bs.GetByteArray(), PACKETSIZE);
		ba.position = 0;

	End Method
      
	' Send data Until there is none more remaining. NOTE: This can
	' run Forever If there is always data available (like with networked
	' state).
	Method SendPackets:Void()

		Local bs:BitStream = New BitStream(PACKETSIZE);
          
		While HasDataPending()

             bs.Reset();
             WritePacket(bs);
             TransmitPacket(bs);

		End While

	End Method

	' TODO ReadBegin, ReadAvail, ReadByte, and ReadString are for ReadPackets, so it is more readable.

	Field readStart:Int = 0
	Field readCount:Int = 0

	Method ReadBegin:Void(c:Int)
	
		readStart = 0
		readCount = c
		
	End Method
	
	Method ReadAvail:Int()

		Return readCount

	End Method
	
	Method ReadByte:Int(db:DataBuffer)
	
		Local result:Int = db.PeekByte(readStart)

		readStart += 1
		readCount -= 1

		Return result

	End Method
	
	Method ReadString:String(db:DataBuffer)

		Local result:String = db.PeekString(readStart)

		readStart += readCount
		readCount = 0

		Return result

	End Method
	
	Method ReadBytes:Int[](db:DataBuffer, length:Int)
	
		Local bytes:Int[] = db.PeekBytes(readStart, length)

		readStart += length
		readCount -= length
		
		Return bytes

	End Method

	' Look For one Or more packets buffered in the socket, parse And process
	' them.
	Method ReadPackets:Void(dataBuffer:DataBuffer, offset:Int, count:Int)

		ReadBegin(count)

		' We are looking For a specific scenario here - If there are say 16
		' bytes available And it's the first response, then it's probably
		' a policy request. So we check For a certain starting length which
		' indicates that the first two bytes are '<p' (the start of
		' the policy request). If they are, Then we respond with the policy
		' response that allows access. If Not Then we Continue with our lives
		' normally.

		Local firstDataLen:Int = -1

		'This is to make sure ReadAvail can be re-use several times!
		'Print "Bytes Available = " + tcpStream.ReadAvail()
		'Print "Bytes Available = " + tcpStream.ReadAvail()
		'Print "Bytes Available = " + tcpSocket.ReadAvail()
'		Local dataBuffer:DataBuffer = New DataBuffer(tcpSocket.ReadAvail())

		'Print "Bytes Available = " + count

'		If firstResponse And tcpSocket.ReadAvail() > 10
		If firstResponse And ReadAvail() > 10
		
			'DebugStop()

			firstResponse = False

			'tcpSocket.Read(dataBuffer, 0, 2)
			Local byte1:Int = ReadByte(dataBuffer)
			Local byte2:Int = ReadByte(dataBuffer)
			
			' Need to look whether the client it HTML5 or not.  HTML client will send
			' a HTTP header, "GET / HTTP/1.1", hence $47 and $45 for GE
			'If dataBuffer.PeekByte(start + 0) = $47 And dataBuffer.PeekByte(start + 1) = $45 Then
			If byte1 = $47 And byte2 = $45 Then
					
				'DebugStop()
								
				'tcpSocket.Read(dataBuffer, 0, tcpSocket.ReadAvail())

				Local httpHeader:String = "GE" + ReadString(dataBuffer)
				Local httpHeaderChar:Int[] = httpHeader.ToChars()
				Local headerLines:String[] = httpHeader.Split("~n")
				Local acceptKey:String = ""
				
				Print "Http Header: " + httpHeader
				
				Local version:Int = 0

				For Local line:Int = 0 Until headerLines.Length()

					If headerLines[line].Contains("Sec-WebSocket-Version:") = True Then
						Local split:String[] = headerLines[line].Split(":")
						Local versionStr:String = split[1].Trim()
						Local versionChar:Int[] = versionStr.ToChars()
						
						version = 0
						
						For Local i:Int = 0 Until versionChar.Length()
							version *= 10
							version += (versionChar[i] - 48)
						End For
						
					End If

					If headerLines[line].Contains("Sec-WebSocket-Key:") = True Then

						Local split:String[] = headerLines[line].Split(":")
						Local key:String = split[1].Trim()
						
						Print "Sec-WebSocket-Key: " + key
						
						'key += "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
						 key += "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
						Print "Key with magic number: " + key 

						acceptKey = EncodeBase64(Sha1(key), True)
						Print "Accept Key: " + acceptKey
						Print ""

					End If

				End For
				
				If version < 13 Then
				
					Error "Only Websocket Version 13 and above are supported!"

				Else

					Local upgrade:String = "HTTP/1.1 101 Switching Protocols~r~n" +
	                   "Upgrade: websocket~r~n" +
    	               "Connection: Upgrade~r~n" +
        	           "Sec-WebSocket-Accept: " + acceptKey +
            	       "~r~n~r~n"
				
					Print "Handshake Message: " + upgrade
				
					'DebugStop()
				
					Local db:DataBuffer = New DataBuffer(upgrade.Length())
					
					db.PokeBytes(0, upgrade.ToChars(), 0, upgrade.Length())
					'tcpSocket.Write(db, 0, upgrade.Length())
					tcpSocket.Send(db, 0, upgrade.Length())
					'tcpSocket._socket.SendAsync(db, 0, upgrade.Length(), tcpSocket)
					
					isClientHtml5WebSocket = True

				End If
				
				Return

			Else 
			
				'firstDataLen = dataBuffer.PeekByte(start + 0) * 256 + dataBuffer.PeekByte(start + 1)
				firstDataLen = byte1 * 256 + byte2
				Print "First len was " + firstDataLen + " with " + count + " bytes available."
	
				' If the length is equal To '<p' then it is a policy request. 
				If firstDataLen = 15472 Then
	
					Print "sending cross-domain-policy XML response."
					
					'tcpSocket.Read(dataBuffer, 0, tcpSocket.ReadAvail())
					Local policyRequest:String = "<p" + ReadString(dataBuffer)
					Print "Policy Request: " + policyRequest
					Print " "
					
					Local xmlResponse:String = "<?xml version=~q1.0~q?>" + 
										 "<!DOCTYPE cross-domain-policy SYSTEM ~q/xml/dtds/cross-domain-policy.dtd~q>"+
										 "<cross-domain-policy>"+
										 "<allow-access-from domain=~q*~q to-ports=~q" + _port + "~q />" + 
										 "</cross-domain-policy>"
					Print "XML Response: " + xmlResponse

					Local db:DataBuffer = New DataBuffer(xmlResponse.Length())
					
					db.PokeString(0, xmlResponse)
					'tcpSocket.Write(db, 0, db.Length())
					tcpSocket.Send(db, 0, db.Length())
					'tcpSocket._socket.SendAsync(db, 0, db.Length(), tcpSocket)
	                
	                'socket.writeUTFBytes("<?xml version=~q1.0~q?>" + 
	                '"<!DOCTYPE cross-domain-policy SYSTEM ~q/xml/dtds/cross-domain-policy.dtd~q>"+
	                '"<cross-domain-policy>"+
	                '"<allow-access-from domain=~q*~q to-ports=~q133~q />" + 
	                '"</cross-domain-policy>")
	
	                'socket.flush();
	                
	                Return
	
				End If

			End If

		End If

		' Ok, go into our normal parse loop.
		' While tcpSocket.ReadAvail() >= PACKETSIZE + LENGTHFIELDSIZE Or firstDataLen <> -1
		While ReadAvail() >= PACKETSIZE + LENGTHFIELDSIZE Or firstDataLen <> -1

			If isClientHtml5WebSocket = True Then

				' Reuse the original read If we made one, otherwise it's -1 and
				' we read it ourselves.
				Local length:Int = firstDataLen

				If length = -1 Then
					' FIN (1-bit), 3 Reserved Bits, 4-bits opcode, 1-bit mask, 7-bits payload length
					' 1 + 3 + 4 + 1 + 7 = 16-bits / 8 = 2 bytes
					'tcpSocket.Read(dataBuffer, 0, 2)				
					' The mask bit is always 1 at position $80, so zero it with $7F
					' Then we know the length of the message
					'length = dataBuffer.PeekByte(1) & $7F
					ReadByte(dataBuffer)	' We don't care about this byte.
					length = ReadByte(dataBuffer) & $7F
				Else
					Print "Suppressing readShort"
				End If

				' All subsequent reads are done properly.
				firstDataLen = -1

				If length = 126 Then

					'tcpSocket.Read(dataBuffer, 0, 2)	' 16-bits extended payload length
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)

				Else If length = 127 Then

					'tcpSocket.Read(dataBuffer, 0, 8)	' 64-bits extended payload length
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)
					ReadByte(dataBuffer)

				End If

				'tcpSocket.Read(dataBuffer, 0, 4)	' 32-bits Masking-key
				Local masks:Int[4]
				masks[0] = ReadByte(dataBuffer)
				masks[1] = ReadByte(dataBuffer)
				masks[2] = ReadByte(dataBuffer)
				masks[3] = ReadByte(dataBuffer)
				
				Local byte1:Int = ReadByte(dataBuffer)
				Local byte2:Int = ReadByte(dataBuffer)

				'tcpSocket.Read(dataBuffer, 0, PACKETSIZE + LENGTHFIELDSIZE)
				Local chars:Int[] = ReadBytes(dataBuffer, PACKETSIZE + LENGTHFIELDSIZE)

				For Local i:Int = 0 Until (PACKETSIZE + LENGTHFIELDSIZE)
				
					'Local peek:Int = dataBuffer.PeekByte(readStart + i)
					Local peek:Int = chars[i]
					Local poke:Int = peek ~ masks[(i & 3)]
					chars[i] = poke
					'dataBuffer.PokeByte(readStart + i, poke)

				End For
				
				'Print String.FromChars(chars)
				
				'Local dataLen:Int = (dataBuffer.PeekByte(readStart + 0) Shl 8) + dataBuffer.PeekByte(readStart + 1)
				Local dataLen:Int = (chars[0] Shl 8) + chars[1]

				If dataLen Then
	
					Local bytes:Int[PACKETSIZE]
					For Local i:Int = 0 Until PACKETSIZE
						bytes[i] = chars[i + 2]
					End For

					If netDbg
						'netDbg.ReportIncomingTraffic(dataBuffer.PeekBytes(readStart + LENGTHFIELDSIZE));
						netDbg.ReportIncomingTraffic(bytes);
					End If
	
					'Print "Got " + dataLen + " bytes of real data."
	                'Local bs:BitStream = New BitStream(dataBuffer.PeekBytes(readStart + LENGTHFIELDSIZE));
	                Local bs:BitStream = New BitStream(bytes);
	                ReadPacket(bs);
	
				End If

			Else

				' Reuse the original read If we made one, otherwise it's -1 and
				' we read it ourselves.
				Local dataLen:Int = firstDataLen

				If dataLen = -1
					'tcpSocket.Read(dataBuffer, 0, 2);
					dataLen = ReadByte(dataBuffer) * 256 + ReadByte(dataBuffer)
					'dataLen = tcpSocket.ReadByte() * 256 + tcpSocket.ReadByte()
				Else
					Print "Suppressing readShort"
				End If
	                
				' All subsequent reads are done properly.
				firstDataLen = -1
	             
				'tcpSocket.Read(dataBuffer, 0, PACKETSIZE)
				'Print "dataLen: " + dataLen
				'Print "data: " + dataBuffer.PeekString(0)
				'Print "Now ReadAvail is: " + tcpSocket.ReadAvail()

				'Local dataBufferStr:String = ""
				'For Local i:Int = 0 Until firstDataLen + 2
				'	dataBufferStr += dataBuffer.PeekByte(i) + ", "
				'End For
				'Print "dataBuffer: " + dataBufferStr

				If dataLen Then
				
					Local chars:Int[] = ReadBytes(dataBuffer, PACKETSIZE)
	
					If netDbg
						netDbg.ReportIncomingTraffic(chars);
					End If
	
					Print "Got " + dataLen + " bytes of real data."
	                Local bs:BitStream = New BitStream(chars);
	                ReadPacket(bs);
	
				End If

			End If

		End While      

	End Method
      

	' Parse a buffer of packets And process them with ReadPacket.
	Method ReadPacketsFromBuffer:Void(ba:ByteArray)

		While ba.BytesAvailable() >= PACKETSIZE + LENGTHFIELDSIZE

			Local dataLen:Int = ba.ReadShort()
			Local bytes:Int[PACKETSIZE]
			ba.ReadBytes(bytes, PACKETSIZE)
              
			' Skip empty packets.
            If Not dataLen
				Continue
			End If

			Local bs:BitStream = New BitStream(bytes);
			ReadPacket(bs);

		End While

	End Method

	' Hook up listeners To our socket.
	Method ConfigureListeners:Void()

		'Print "Socket Configure Listeners"
		'socket.addEventListener(Event.CLOSE, closeHandler);
		'socket.addEventListener(Event.CONNECT, connectHandler);
		'socket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		'socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		'socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);

	End Method

	'Method CloseHandler:Void(event:Event)
	'	_wasConnected = True;
	'	Print "closeHandler: " + event    
		' Remove ourselves from the NetworkInterface.
	'	NetworkInterface.instance.removeConnection(this);
	'End Method
 
	'Method ConnectHandler:Void(event:Event)
	'	_wasConnected = True;
	'	Error "connectHandler - " + event.toString()
	'End Method
 
	'Method IoErrorHandler:Void(event:IOErrorEvent) 
	'	_wasConnected = True;
	'	Error "ioErrorHandler - " + event.toString()
	'End Method
 
	'Method SecurityErrorHandler:Void(event:SecurityErrorEvent)
	'	_wasConnected = True;
	'	Error "securityErrorHandler - " + event.toString()
	'End Method
 
	'Method SocketDataHandler:Void(event:ProgressEvent)
	'	_wasConnected = True;
	'	ReadPackets();
	'End Method
	
	' This is set to true if the server connects to a HTML5 client.
	Field isClientHtml5WebSocket:Bool = False

	Field stringCache:NetStringCache = New NetStringCache()
	Field firstResponse:Bool = True
	'Field socket:Socket = Null
	Field _host:String
	Field _port:Int
	Field _wasConnected:Bool = False

	' Size of the packets in bytes that we will be sending over the wire. You
	' can tweak this To suit your application.
	Const PACKETSIZE:Int = 100

	' Size of the length Field preceding each packet in bytes. This 
	' is sizeof(short) currently.
	Const LENGTHFIELDSIZE:Int = 2

End Class
