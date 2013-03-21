
class BBTcpSocket extends BBStream
{
	public function Connect(addr:String, port:int):Boolean
	{
		if (_state != 0) return false;

		// Create & connect with a socket.
		print("Host: " + addr);
		print("Port: " + port);
		socket = new Socket(addr, 1337);
		//_host = host;
		//_port = port;
		configureListeners();

		if(socket != null)
		{
			_state = 1;
			return true;
		}

		_state = 0;
		socket = null;

		return false;
	}

	public function ReadAvail():int
	{
		if(_state != 1) return 0;
		
		if (socket != null)
		{
			return socket.bytesAvailable;
		}
		
		_state = -1;
		return 0;
	}

	public function WriteAvail():int
	{
		return 0;
	}
	
	public function State():int
	{
		return _state;
	}
	
	public override function Eof():int
	{
		if (_state >= 0)
		{
			if (_state == 2)
			{
				return 1;
			}
			else
			{
				return 0;
			}
		}

		return -1;
	}	

	public override function Close():void
	{
		if (socket == null) return;
	
		socket.close();
		if (_state == 1) _state = 2;
		socket = null;
	}

	public override function Read(buffer:BBDataBuffer, offset:int, count:int):int
	{
		if(_state != 1) return 0;

		socket.readBytes(buffer._data, offset, count);
		return count;
	}

	public override function Write(buffer:BBDataBuffer, offset:int, count:int):int
	{
		if(_state != 1) return 0;
		
		socket.writeBytes(buffer._data, offset, count);
		socket.flush();	// This kinda turns off Nagle's algorithm, ie nodelay is enabled.

		return count;
	}
	
	public function SetupSocket(so:Socket, st:int):int
	{
		// HTML5 and Flash can not listen on socket.
		return 0;
	}
	
	/**
	 * Hook up listeners to our socket.
	 */
	private function configureListeners():void 
	{
		print("Configuring Listeners");
		socket.addEventListener(Event.CLOSE, closeHandler);
		socket.addEventListener(Event.CONNECT, connectHandler);
		socket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
	}

	private function closeHandler(event:Event):void
	{
		_state = 2;
		_wasConnected = true;
		print("closeHandler: " + event.toString());
         
		// Remove ourselves from the NetworkInterface.
		//NetworkInterface.instance.removeConnection(this);
	}
 
	private function connectHandler(event:Event):void 
	{
		_state = 1;
		_wasConnected = true;
		print("connectHandler - " + event.toString());
	}
 
	private function ioErrorHandler(event:IOErrorEvent):void 
	{
		_state = -1
		_wasConnected = true;
		print("ioErrorHandler - " + event.toString());
	}
 
	private function securityErrorHandler(event:SecurityErrorEvent):void 
	{
		_wasConnected = true;
		print("securityErrorHandler - " + event.toString());
	}
 
	private function socketDataHandler(event:ProgressEvent):void 
	{
		_wasConnected = true;
		//print("There are data at socketDataHandler!");
		//readPackets();
	}

	public var socket:Socket;
	private var _state:int = 0; // 0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR
	private var _wasConnected:Boolean = false;
}
