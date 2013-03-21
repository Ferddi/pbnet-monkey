
class BBTcpSocket extends BBStream{
	
	java.nio.channels.SocketChannel _sockChannel = null;
	java.net.Socket _sock;
	InputStream _input;
	OutputStream _output;
	int _state;				//0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR

	byte[] elems = null;
	int size = 0;
	int start = 0;
	int end = 0;
	
	void cbInit(int sz)
	{
		bb_std_lang.print("cbInit");
		elems = new byte[sz];
		start = 0;
		end = 0;
		size = sz;
	}
	
	int cbIsFull()
	{
		if ((end + 1) % size == start)
		{
			return 1;
		}
	
		return 0;
	}
	
	int cbIsEmpty()
	{
		if (end == start)
		{
			return 1;
		}
	
		return 0;
	}
	
	void cbWrite(byte elem)
	{
		elems[end] = elem;
		end = (end + 1) % size;
		if (end == start)
		{
			start = (start + 1) % size; // full, overwrite
		}
	}
	
	byte cbRead()
	{
		byte elem = elems[start];
		start = (start + 1) % size;

		return elem;
	}
	
	int cbLength()
	{
		int length = end - start;

		if (length < 0)
		{
			length += (size + 1);
		}

		return length;
	}

	boolean Connect( String addr,int port ){
	
		if( _state!=0 ) return false;
		
		try{
			_sock=new java.net.Socket( addr,port );
			if( _sock.isConnected() ){

				// Disable the Nagle Algorithm for this tcp socket.
				_sock.setTcpNoDelay(true);

				_input=_sock.getInputStream();
				_output=_sock.getOutputStream();
				_state=1;
				
				_sockChannel = null;

				return true;
			}
		}catch( IOException ex ){
		}
		
		_state=1;
		_sock=null;
		return false;
	}
	
	int ReadAvail()
	{
		if (_sockChannel == null)
		{
			try{
				bb_std_lang.print("read buffer: " + _input.available());
				
				return _input.available();
			}catch( IOException ex ){
			}
		}
		else
		{
	        int avail = cbLength();
	        
	        //bb_std_lang.print("ReadAvail(): " + avail);

			return avail;
		}
		_state=-1;
		return 0;
	}
	
	int WriteAvail(){
		return 0;
	}
	
	int State(){
		return _state;
	}
	
	int Eof(){
		if( _state>=0 ) return (_state==2) ? 1 : 0;
		return -1;
	}
	
	void Close(){

		if( _sock==null ) return;
		
		try{
			_sock.close();
			if( _state==1 ) _state=2;
		}catch( IOException ex ){
			_state=-1;
		}
		_sock=null;
	}
	
	int Read( BBDataBuffer buffer,int offset,int count ){

		if( _state!=1 ) return 0;

		if (_sockChannel == null)
		{
			bb_std_lang.print("read buffer: " + buffer._data.array());
			try{
				int n=_input.read( buffer._data.array(),offset,count );
				return n;
				//if( n>=0 ) return n;
				//_state=2;
			}catch( IOException ex ){
				_state=-1;
			}
		}
		else
		{
			int length = offset + count;
			byte[] byteArr = new byte[length];
			int c = 0;
	
			//bb_std_lang.print("length: " + length);

			for (int i = 0; i < length; i ++)
			{
				if (cbIsEmpty() != 1)
				{
					byteArr[i] = cbRead();
					c ++;
				}
			}

			buffer._data.clear();
			buffer._data.put(byteArr);
			
			return c;
		}

		return 0;
	}
	
	int Write( BBDataBuffer buffer,int offset,int count ){

		if( _state!=1 ) return 0;
		
		if (_sockChannel == null)
		{
			try{
				_output.write( buffer._data.array(),offset,count );
				return count;
			}catch( IOException ex ){
				_state=-1;
			}
		}
		else
		{
			try
			{		
				_sockChannel.write( buffer._data );
				return buffer._data.limit();
			}
			catch(IOException ex)
			{
				_state = -1;
			}
		}

		return 0;
	}
	
	int SetupSocket(java.nio.channels.SocketChannel sc)
	{
		bb_std_lang.print("SetupSocket is called.");
		if (sc != null)
		{
			_sockChannel = sc;
			_sock = _sockChannel.socket();
			_state = 0;

			try
			{
				bb_std_lang.print("_sock.isConnected() ??? : " + _sock.isConnected());
				if (_sock.isConnected())
				{
					cbInit(1024);
					
					bb_std_lang.print("Yes it is connected");
					// Disable the Nagle Algorithm for this tcp socket.
					_sock.setTcpNoDelay(true);
					_input = _sock.getInputStream();
					_output = _sock.getOutputStream();
				
					_state = 1;
				
					return 1;
				}
			}
			catch( IOException ex )
			{
			}
		}

		return 0;
	}
}
