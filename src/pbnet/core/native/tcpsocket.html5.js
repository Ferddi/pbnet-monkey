
// Circular buffer that keeps one slot open
function CircularBuffer(size)
{
	this.buffer = new Uint8Array(size);	// array of elements
	this.start = 0;			// index at which to write new element
	this.end = 0;			// index of oldest element
	this.size = size;		// maximum number of elements
}

CircularBuffer.prototype.IsFull = function()
{
	if ((this.end + 1) % this.size == this.start)
	{
		return 1;
	}
	
	return 0;
}

CircularBuffer.prototype.IsEmpty = function()
{
	if (this.end == this.start)
	{
		return 1;
	}
	
	return 0;
}

// Write an element, overwriting oldest element if buffer is full. App can
// choose to avoid the overwrite by checking IsFull().
CircularBuffer.prototype.Write = function(elem)
{
	this.buffer[this.end] = elem;
	this.end = (this.end + 1) % this.size;
	if (this.end == this.start)
	{
		this.start = (this.start + 1) % this.size; // full, overwrite
	}
}

// Read oldest element. App must ensure !cbIsEmpty() first.
CircularBuffer.prototype.Read = function()
{
	var elem = this.buffer[this.start];

	this.start = (this.start + 1) % this.size;

	return elem;
}

CircularBuffer.prototype.Length = function()
{
	var length = this.end - this.start;
	
	if (length < 0)
	{
		length += (this.size + 1);
	}

	return length;
}

function BBTcpSocket()
{
	this.ws = null;
	this._state = 0;
	this.cb = new CircularBuffer(8192);
}

BBTcpSocket.prototype.Connect = function(addr, port)
{
	if ("WebSocket" in window)
	{
		var bbTcpSocket = this;
	
		print("WebSocket in window");

		print("Trying to create a WebSocket ...");

		ws = new WebSocket("ws://" + addr + ":" + port + "/");
		//ws = new WebSocket("ws://localhost:1337/");
		//ws = new WebSocket("ws://localhost:7777/");
		ws.binaryType = 'arraybuffer';
		
		this.ws = ws;
		print("Socket Status: "+ws.readyState);  
			
		ws.onopen = function(e)
		{
			print("Connection opened");
			bbTcpSocket._state = 1;
		};
		ws.onmessage = function(e)
		{
			//print("Receiving message: " + e.data);

			var u8 = new Uint8Array(e.data);
			//print("Length: " + u8.length);
			
			var i = 0;
			for (i = 0; i < u8.length; i ++)
			{
				if (bbTcpSocket.cb.IsFull() == 1)
				{
					print("HTML5 Circular Buffer is full!");
				}
				else
				{
					bbTcpSocket.cb.Write(u8[i]);
				}
			}
		};
		ws.onclose = function(e)
		{
			print("Connection closed");
			bbTcpSocket._state = 2;
		};
		ws.onerror = function(e)
		{
			print("Connection Error: " + e.data);
			bbTcpSocket._state = -1;
		};
	}
	else
	{
		// The browser doesn't support WebSocket
		alert("WebSocket NOT supported by your Browser!");
		this._state = -1;
	}
}

BBTcpSocket.prototype.ReadAvail = function()
{
	if(this._state != 1) return 0;

	//print("ReadAvail: " + this.cb.Length());
	return this.cb.Length();
}

BBTcpSocket.prototype.WriteAvail = function()
{
	return 0;
}

BBTcpSocket.prototype.State = function()
{
	return this._state;
}

BBTcpSocket.prototype.Eof = function()
{
	if (this._state >= 0)
	{
		if (this._state == 2)
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

BBTcpSocket.prototype.Close = function()
{
	if (this.socket == null) return;
	
	this.socket.close();
	if (this._state == 1) this._state = 2;
	this.socket = null;
}

BBTcpSocket.prototype.Read = function(buffer, offset, count)
{
	if(this._state != 1) return 0;

	var length = offset + count;
	var ab = new ArrayBuffer(length);
	var faFull = new Uint8Array(ab);
	var i = 0;
	var c = 0;
	
	for (i = 0; i < length; i ++)
	{
		if (this.cb.IsEmpty() != 1)
		{
			faFull[i] = this.cb.Read()
			c ++;
		}
	}

	buffer._Init(ab);
			
	return c;
}

BBTcpSocket.prototype.Write = function(buffer, offset, count)
{
	if(this._state != 1) return 0;
	
	//var faFull = "HelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHe"
	//var faFull = new Uint8Array(102);
	var faFull = new Uint8Array(buffer.arrayBuffer);
	
	/*
	var i;
	
	for (i=0; i<96; )
	{
		faFull[i] = 68; i++;
		faFull[i] = 69; i++;
		faFull[i] = 65; i++;
		faFull[i] = 68; i++;
		faFull[i] = 66; i++;
		faFull[i] = 69; i++;
		faFull[i] = 69; i++;
		faFull[i] = 70; i++;
	}
	*/
	
	//try
	//{
	//	this.ws.send(buffer.arrayBuffer);
	//	this.ws.send(buffer.arrayBuffer);
		this.ws.send(faFull);

	//	return buffer.arrayBuffer.length;
	//}
	//catch(exception)
	//{
	//	this._state = -1
	//}
		
	return 0;
}
