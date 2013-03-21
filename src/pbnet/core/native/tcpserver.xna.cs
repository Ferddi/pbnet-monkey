
public class BBTcpServer
{
	System.Net.Sockets.TcpListener serverSocket;
	System.Net.Sockets.Socket clientSocket;

	public BBTcpServer()
	{
		serverSocket = null;
		clientSocket = null;
	}

	public bool SetupListen(int port)
	{
 		// Set the TcpListener on port 13000.
		//Int32 port = 13000;
		System.Net.IPAddress localAddr = System.Net.IPAddress.Parse("127.0.0.1");
		//IPAddress localAddr = Dns.Resolve("localhost").AddressList[0];

		//serverSocket = new TcpListener(port);	// This is obsolete!
		serverSocket = new System.Net.Sockets.TcpListener(localAddr, port);

		// Start listening for client requests.
		serverSocket.Start();

		return true;
	}

	public bool CheckConnection()
	{
		if (serverSocket != null)
		{
			if (serverSocket.Pending() == true)
			{
				//Accept the pending client connection and return a TcpClient object initialized for communication.
				clientSocket = serverSocket.AcceptSocket();
	
				// Disable the Nagle Algorithm for this tcp socket.
				clientSocket.NoDelay = true;

				// Using the RemoteEndPoint property.
				//Console.WriteLine("I am listening for connections on " + 
				//	IPAddress.Parse(((IPEndPoint)tcpListener.LocalEndpoint).Address.ToString()) +
				//	"on port number " + ((IPEndPoint)tcpListener.LocalEndpoint).Port.ToString());
	
				return true;
			}
		}
		
		return false;
	}
	
	public bool SetupSocket(BBTcpSocket bbTcpSocket)
	{
		if (clientSocket != null)
		{
			bbTcpSocket.SetupSocket(clientSocket);
			return true;
		}

		return false;
	}
}
