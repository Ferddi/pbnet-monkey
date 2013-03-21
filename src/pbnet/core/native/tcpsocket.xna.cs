
public class BBTcpSocket
{	
	System.Net.Sockets.Socket socket;
	int _state;				//0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR

	public BBTcpSocket()
	{
		_state = 0;
	}

	public bool Connect(string addr, int port)
	{
		if (_state == 1) return false;
	
//		IPHostEntry hostEntry = null;

		// Get host related information.
//		hostEntry = Dns.GetHostEntry(addr);

		// Loop through the AddressList to obtain the supported AddressFamily. This is to avoid 
		// an exception that occurs when the host IP Address is not compatible with the address family 
		// (typical in the IPv6 case). 
//		foreach(IPAddress address in hostEntry.AddressList)
//		{
			System.Net.IPAddress address = System.Net.IPAddress.Parse(addr);
			System.Net.IPEndPoint ipe = new System.Net.IPEndPoint(address, port);
			System.Net.Sockets.Socket tempSocket = new System.Net.Sockets.Socket(ipe.AddressFamily, 
				System.Net.Sockets.SocketType.Stream, System.Net.Sockets.ProtocolType.Tcp);

			tempSocket.Connect(ipe);

			if(tempSocket.Connected)
			{
				// Disable the Nagle Algorithm for this tcp socket.
				tempSocket.NoDelay = true;

				_state = 1;
				socket = tempSocket;

				return true;
			}
//			else
//			{
//				continue;
//			}
//		}

		_state = 0;
		socket = null;

		return false;		
	}
	
	public int ReadAvail()
	{
		if (_state != 1) return 0;
		return socket.Available;
	}
	
	public int WriteAvail()
	{
		if (_state != 1) return 0;
		return 0;
	}
	
	public int State()
	{
//		if (_state > 0)
//		{
//			if (socket != null)
//			{
//				bb_std_lang.Print("_state = " + _state);
//
//				if (socket.Connected)
//				{
//				}
//				else
//				{
//					Close();
//				}
//			}
//			else
//			{
//				_state = 2;
//			}
//		}

		return _state;
	}
	
	public int Eof()
	{
		if (_state >= 0)
		{
			if (_state == 2)
			{
				return 1;
			}

			return 0;
		}

		return -1;
	}
	
	public void Close()
	{
		if (socket != null)
		{
			if (_state == 1) _state=2;
		
			socket.Shutdown(System.Net.Sockets.SocketShutdown.Both);
			socket.Close();

			socket = null;
		}
	}

	public int Read(BBDataBuffer buffer, int offset, int count)
	{
		if(_state != 1) return 0;

		return socket.Receive(buffer._data, offset, count, 0);
	}

	public int Write(BBDataBuffer buffer, int offset, int count)
	{
		if(_state != 1) return 0;

		bool blockingState = socket.Blocking;
		int result = 0;

		try
		{
			socket.Blocking = false;
			result = socket.Send(buffer._data, offset, count, 0);
			//bb_std_lang.Print("Connected!");
		}
		catch(System.Net.Sockets.SocketException e)
		{
		    // 10035 == WSAEWOULDBLOCK 
			if (e.NativeErrorCode.Equals(10035))
			{
				bb_std_lang.Print("Still Connected, but the Send would block");
			}
			else
			{
				bb_std_lang.Print("Disconnected: error code {" + e.NativeErrorCode + "}!");
				_state = 2;
			}
		}
		finally
		{
			socket.Blocking = blockingState;
		}

		return result;
	}
	
	public int SetupSocket(System.Net.Sockets.Socket so)
	{
		if (so != null)
		{
			socket = so;
			_state = 0;

			if (socket.Connected)
			{
				// Disable the Nagle Algorithm for this tcp socket.
				socket.NoDelay = true;
				_state = 1;

				return 1;
			}
		}

		return 0;
	}
}
