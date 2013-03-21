
class BBTcpServer
{
//	java.nio.channels.Selector acceptSelector;
//	java.net.Socket clientSocket;

	java.nio.channels.Selector selector;
	java.net.ServerSocket ss;
	java.nio.channels.SocketChannel clientSocketChannel;

	// A pre-allocated buffer for encrypting data
	// TODO 1024 should really be PACKETSIZE! may be should be defined in the servergame.monkey.
	private final ByteBuffer buffer = ByteBuffer.allocate( 1024 );
	private final HashMap<String, BBTcpSocket> hashMap;

	BBTcpServer()
	{
//		acceptSelector = null;
//		clientSocket = null;

		selector = null;
		
		hashMap =  new HashMap<String, BBTcpSocket>();

	}

	boolean SetupListen( int port )
	{
		java.nio.channels.ServerSocketChannel ssc = null;
//		InetAddress lh = null;

		try
		{
			// Instead of creating a ServerSocket,
			// create a ServerSocketChannel
			ssc = java.nio.channels.ServerSocketChannel.open();

			// Set it to non-blocking, so we can use select
			ssc.configureBlocking( false );

			// Get the Socket connected to this channel, and bind it
			// to the listening port
			ss = ssc.socket();
			InetSocketAddress isa = new InetSocketAddress( port );
			ss.bind( isa );

			// Create a new Selector for selecting
			selector = java.nio.channels.Selector.open();

			// Register the ServerSocketChannel, so we can
			// listen for incoming connections
			ssc.register( selector, java.nio.channels.SelectionKey.OP_ACCEPT );
			//System.out.println( "Listening on port "+port );
		}
		catch(IOException ie)
		{
		}
/*
		try
		{
			// Selector for incoming time requests
			acceptSelector = java.nio.channels.spi.SelectorProvider.provider().openSelector();
			
			// Create a new server socket and set to non blocking mode
			ssc = java.nio.channels.ServerSocketChannel.open();
			ssc.configureBlocking(false);
		}
		catch( IOException ex )
		{
		}

//		try
//		{
//			// Bind the server socket to the local host and port
//			lh = InetAddress.getLocalHost();
//		}
//		catch(UnknownHostException ex)
//		{
//		}
	
		//InetSocketAddress isa = new InetSocketAddress(lh, port);
		InetSocketAddress isa = new InetSocketAddress(port);
		try
		{
			ssc.socket().bind(isa);
		}
		catch( IOException ex )
		{
		}

		try
		{
			// Register accepts on the server socket with the selector. This
			// step tells the selector that the socket wants to be put on the
			// ready list when accept operations occur, so allowing multiplexed
			// non-blocking I/O to take place.
			java.nio.channels.SelectionKey acceptKey = ssc.register(acceptSelector, java.nio.channels.SelectionKey.OP_ACCEPT);
		}
		catch( java.nio.channels.ClosedChannelException ex )
		{
		}
*/
		return true;
	}
	
	boolean CheckConnection()
	{
		boolean result = false;

		try
		{
			// See if we've had any activity -- either
			// an incoming connection, or incoming data on an
			// existing connection
			int num = selector.selectNow();

			// If we don't have any activity, loop around and wait
			// again
			if (num == 0)
			{
				return result;
			}

			// Get the keys corresponding to the activity
			// that has been detected, and process them
			// one by one
			Set keys = selector.selectedKeys();
			Iterator it = keys.iterator();
			while (it.hasNext())
			{
				// Get a key representing one of bits of I/O
				// activity
				java.nio.channels.SelectionKey key = (java.nio.channels.SelectionKey)it.next();

				// What kind of activity is it?
				if ((key.readyOps() & java.nio.channels.SelectionKey.OP_ACCEPT) == java.nio.channels.SelectionKey.OP_ACCEPT)
				{
					//System.out.println( "acc" );
								bb_std_lang.print( "Accept!" );

					// It's an incoming connection.
					// Register this socket with the Selector
					// so we can listen for input on it

					java.net.Socket s = ss.accept();
					bb_std_lang.print( "Got connection from "+s );
					
					s.setTcpNoDelay(true);

					// Make sure to make it non-blocking, so we can
					// use a selector on it.
					java.nio.channels.SocketChannel sc = s.getChannel();
					sc.configureBlocking( false );
					clientSocketChannel = sc;

					// Register it with the selector, for reading
					sc.register( selector, java.nio.channels.SelectionKey.OP_READ );

					result = true;
					
				}
				else if ((key.readyOps() & java.nio.channels.SelectionKey.OP_READ) == java.nio.channels.SelectionKey.OP_READ)
				{
					java.nio.channels.SocketChannel sc = null;
								bb_std_lang.print( "Found socket channel!" );

					try
					{
						// It's incoming data on a connection, so
						// process it
						sc = (java.nio.channels.SocketChannel)key.channel();
						boolean ok = true;
												
						buffer.clear();
						sc.read( buffer );
						buffer.flip();

						// If no data, close the connection
						if (buffer.limit()==0)
						{
							ok = false;
						}
						else
						{
							// find the socket channel in the hashmap
							BBTcpSocket bbTcpSocket = hashMap.get(sc.toString());
							if (bbTcpSocket != null)
							{
								// and queue the buffer to be processed at a later date.
								int length = buffer.remaining();
								byte[] byteArr = new byte[length];
								buffer.get(byteArr);
								for (int i = 0; i < length; i ++)
								{
									if (bbTcpSocket.cbIsFull() == 1)
									{
										bb_std_lang.print("Java Circular Buffer is full!");
									}
									else
									{
										bbTcpSocket.cbWrite(byteArr[i]);
									}
								
								}
							}

							//byte[] byteArr = new byte[buffer.remaining()];
							//buffer.get(byteArr);
							//String s = new String(byteArr);
							//bb_std_lang.print( "buffer: " + s );
							
						}
						
						//bb_std_lang.print( "Processed "+buffer.limit()+" from "+sc );

						// If the connection is dead, then remove it
						// from the selector and close it
						if (!ok) 
						{
							key.cancel();

							java.net.Socket s = null;
							try
							{
								s = sc.socket();
								s.close();
							}
							catch( IOException ie )
							{
								bb_std_lang.print( "Error closing socket "+s+": "+ie );
							}
						}

					}
					catch( IOException ie )
					{

						// On exception, remove this channel from the selector
						key.cancel();

						try
						{
							sc.close();
						}
						catch( IOException ie2 )
						{
							System.out.println( ie2 );
						}

						bb_std_lang.print( "Closed "+sc );
					}
				}
			}

			// We remove the selected keys, because we've dealt
			// with them.
			keys.clear();
		}
		catch(IOException ie)
		{
		}
	
	
/*
		int keysAdded = 0;
		boolean result = false;

		try
		{
			// Here's where everything happens. The select method will
			// return when any operations registered above have occurred, the
			// thread has been interrupted, etc.
			if ((keysAdded = acceptSelector.selectNow()) > 0)
			{
				//bb_.bb__debugStr.m_AddLast5("selectNow() has something");

				// Someone is ready for I/O, get the ready keys
				Set readyKeys = acceptSelector.selectedKeys();
				Iterator i = readyKeys.iterator();
		
				// Walk through the ready keys collection and process date requests.
				while (i.hasNext())
				{
					//bb_.bb__debugStr.m_AddLast5("hasNext() has something");

					java.nio.channels.SelectionKey sk = (java.nio.channels.SelectionKey)i.next();
					i.remove();
	
					// The key indexes into the selector so you
					// can retrieve the socket that's ready for I/O
					java.nio.channels.ServerSocketChannel nextReady = (java.nio.channels.ServerSocketChannel)sk.channel();
	
					// Save the client socket that we need to send to TcpSocket class.
					clientSocket = nextReady.accept().socket();
	
					// Disable the Nagle Algorithm for this tcp socket.
					clientSocket.setTcpNoDelay(true);
					
					result = true;
	
					// Accept the date request and send back the date string
					// Write the current time to the socket
	//				PrintWriter out = new PrintWriter(s.getOutputStream(), true);
	//				Date now = new Date();
	//				out.println(now);
	//				out.close();
				}
			}
		}
		catch( IOException ex )
		{
		}
*/
		return result;
	}
	
	boolean SetupSocket(BBTcpSocket bbTcpSocket)
	{
		if (clientSocketChannel != null)
		{
			hashMap.put(clientSocketChannel.toString(), bbTcpSocket);

			bbTcpSocket.SetupSocket(clientSocketChannel);
			return true;
		}

		return false;
	}
}
