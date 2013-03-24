
// author: Sascha Schmidt(Rone)

/*

Add the following usings to MonkeyGame.cpp

using namespace Windows::Networking;
using namespace Windows::Networking::Sockets;
using namespace Windows::Storage::Streams;
using namespace concurrency;
using namespace Windows::UI::Core;

*/

#define _HIDE_GLOBAL_ASYNC_STATUS 100 


#include <windows.networking.sockets.h>
#include <wrl.h>
#include <robuffer.h>
#include <vector>
#include <mutex>
#include <atomic>
#include <list>
#include <condition_variable>
#include <thread>

// ***** tcpsocket.h *****


static byte* GetIBufferPointer(IBuffer^ buffer);

// used to wrap BBDataBuffer when using DataWriter::WriteBuffer
class NativeBuffer : public Microsoft::WRL::RuntimeClass<
						Microsoft::WRL::RuntimeClassFlags< Microsoft::WRL::RuntimeClassType::WinRtClassicComMix >,
						ABI::Windows::Storage::Streams::IBuffer,
						Windows::Storage::Streams::IBufferByteAccess >
{

public:
	virtual ~NativeBuffer();
	STDMETHODIMP RuntimeClassInitialize(UINT totalSize, byte* ptr);
	STDMETHODIMP Buffer( byte **value);
	STDMETHODIMP get_Capacity(UINT32 *value);        
	STDMETHODIMP get_Length(UINT32 *value);                
	STDMETHODIMP put_Length(UINT32 value);
private:
	UINT32 m_length;
	byte * m_buffer;
};

class CircularBuffer{
public:
	CircularBuffer();
	void Write(byte value);
	byte Read();
	bool IsFull();
	bool IsEmty();
	int Read(byte* buffer, int count);
	int Length();
private:
	std::vector<byte> _data; 
	int _start;
	int _end;
	int _size;
};

class BBTcpSocket : public BBStream
{
public:

	BBTcpSocket();
	~BBTcpSocket();
	
	bool Connect( String addr,int port );
	int ReadAvail();
	int WriteAvail();
	int State();
	
	int Eof();
	void Close();
	int Read( BBDataBuffer *buffer,int offset,int count );
	int Write( BBDataBuffer *buffer,int offset,int count );
	
	int SetupSocket(int so);
	
private:

	void ReceiveLoop(DataReader^ reader, StreamSocket^ socket);
	IBuffer^ CreateBuffer(UINT32 cbBytes, byte* ptr);

	std::atomic_int _state;	//0=INIT, 1=CONNECTED, 2=CLOSED, -1=ERROR
	Microsoft::WRL::ComPtr<NativeBuffer> _nativeBuffer;
	StreamSocket^ _socket;
	DataWriter^ _writer;
	DataReader^ _reader;
	std::mutex _mx;
	CircularBuffer _cb;
};

// ***** tcpsocket.cpp *****


CircularBuffer::CircularBuffer(){
	_size = 8096;
	_data.resize(_size);
	_start = 0;
	_end = 0;
}

void CircularBuffer::Write(byte value)
{
	_data[_end] = value;
	_end = (_end + 1) % _size;
	if( _end == _start ){
		_start = (_start + 1) % _size; // full, overwrite
	}
}

byte CircularBuffer::Read()
{
	byte value = _data[_start];
	_start = (_start + 1) % _size;
	return value;
}

bool CircularBuffer::IsFull()
{
	return ((_end + 1) % _size == _start);
}

bool CircularBuffer::IsEmty()
{
	return (_end == _start);
}

int CircularBuffer::Read(byte* buffer, int count)
{
	if( (_start + count ) >= _end )
	{
		count = _end - _start;
	}
	memcpy(buffer, &_data[_start], count);
	_start = (_start + count) % _size;
	return count;
}

int CircularBuffer::Length()
{
	int length = _end - _start;
	if (length < 0)
	{
		length += (_size + 1);
	}
	return length;
}

NativeBuffer::~NativeBuffer()
{
}

STDMETHODIMP NativeBuffer::RuntimeClassInitialize(UINT totalSize, byte* ptr)
{
	m_length = totalSize;
	m_buffer = ptr;
	return S_OK;
}

STDMETHODIMP NativeBuffer::Buffer( byte **value)
{
	*value = &m_buffer[0];
	return S_OK;
}

STDMETHODIMP NativeBuffer::get_Capacity(UINT32 *value)
{
	*value = 0;
	return S_OK;
}
                        
STDMETHODIMP NativeBuffer::get_Length(UINT32 *value)
{
	*value = m_length;
	return S_OK;
}
                        
STDMETHODIMP NativeBuffer::put_Length(UINT32 value)
{
	m_length = value;
	return S_OK;
}

BBTcpSocket::BBTcpSocket():
	_socket(nullptr),
	_writer(nullptr),
	_reader(nullptr),
	_nativeBuffer(nullptr)
{
	_state = 0;
	_socket = ref new StreamSocket();
	_socket->Control->NoDelay = true;// Make sure Nagle's algorithm is off!
}

BBTcpSocket::~BBTcpSocket()
{
	Close();
}

bool BBTcpSocket::Connect( String addr,int port )
{
	if( _state ) return false;

	auto str_addr = ref new Platform::String(addr.ToCString<wchar_t>(), addr.Length());
	auto str_port = ref new Platform::String(String(port).ToCString<wchar_t>(), String(port).Length());

	std::condition_variable cond_var;
	std::mutex m;

	try
	{
		auto hostName = ref new HostName(str_addr);

		std::thread connector([&]() 
		{
			auto val = _socket->ConnectAsync(hostName, str_port, SocketProtectionLevel::PlainSocket);
			task<void>(val).then([this,&cond_var] (task<void> previousTask)  
			{
				std::unique_lock<std::mutex> lock(_mx);

				try
				{
					previousTask.get();
					Print("Connection opened");
					_state = 1;	
				}
				catch (Platform::Exception^ exception)
				{
					Print("Error: failed to connect.");
					_state = -1;
				}

				if( _state == 1 )
				{
					// start listening
					auto reader = ref new DataReader(_socket->InputStream);
					reader->InputStreamOptions = InputStreamOptions::Partial;
					//reader->ByteOrder = Windows::Storage::Streams::ByteOrder::LittleEndian;
					_writer = ref new DataWriter(_socket->OutputStream);

					ReceiveLoop(reader,_socket);
				}

				cond_var.notify_one();
			});
		});

		connector.join();
		std::unique_lock<std::mutex> lock(_mx);
		cond_var.wait(lock);
	}
	catch (ThrowableObject* exception)
	{
		Print("Error: Invalid host name.");
		_state = -1;
	}

	return _state == 1;

}

int BBTcpSocket::ReadAvail(){
	std::lock_guard<std::mutex> lock(_mx);
	if( _state!=1 ) return 0;
	return _cb.Length();
}

int BBTcpSocket::WriteAvail(){
	std::lock_guard<std::mutex> lock(_mx);
	if( _state!=1 ) return 0;
	return 0;
}

int BBTcpSocket::State(){
	std::lock_guard<std::mutex> lock(_mx);
	return _state;
}

int BBTcpSocket::Eof(){
	std::lock_guard<std::mutex> lock(_mx);
	if( _state>=0 ) return _state==2;
	return -1;
}

void BBTcpSocket::Close(){
	if( _socket==nullptr ) return;
	if( _state==1 ) _state=2;
	try
	{
		delete _socket;
	}
	catch(Platform::Exception^ exception)
	{
	}
	_socket=nullptr;
}

int BBTcpSocket::Read( BBDataBuffer *buffer,int offset,int count ){

	std::lock_guard<std::mutex> lock(_mx);
	if( _state!=1 ) return 0;

	int i = 0;
	for (i = 0; i < count; ++i)
	{
		if (!_cb.IsEmty() )
		{
			buffer->PokeByte(offset+i,_cb.Read());
		}
	}

	//int n=_cb.Read( (byte*)buffer->WritePointer(offset), count);
	if( i>0 || (i==0 && count==0) ) return i;
	_state=(i==0) ? 2 : -1;
	return 0;
}


int BBTcpSocket::Write( BBDataBuffer *buffer,int offset,int count ){

	std::lock_guard<std::mutex> lock(_mx);

	if( _state!=1 ) return 0;

	_writer->WriteBuffer(CreateBuffer( buffer->Length(), (byte*)buffer->ReadPointer()));

	try
	{
		task<unsigned int>(_writer->StoreAsync())
		.then([this] (task<unsigned int> writeTask)
		{
			try
			{
				writeTask.get();
			}
			catch (Platform::Exception^ exception)
			{
				Print("Send Error.");
				// Send failed with error: " + exception->Message
			}
		});
	}
	catch(Platform::ObjectDisposedException ^ ex)
	{
		// error
	}
	
	return 0;
}

IBuffer^ BBTcpSocket::CreateBuffer(UINT32 cbBytes, byte* ptr){
	if( _nativeBuffer == nullptr ){
		Microsoft::WRL::MakeAndInitialize<NativeBuffer>(&_nativeBuffer, cbBytes, ptr);
	}
	else{
		_nativeBuffer->RuntimeClassInitialize(cbBytes, ptr);
	}
	auto iinspectable = (IInspectable*)reinterpret_cast<IInspectable*>(_nativeBuffer.Get());
	IBuffer^ buffer = reinterpret_cast<IBuffer^>(iinspectable);
	return buffer;
}

void BBTcpSocket::ReceiveLoop(DataReader^ reader, StreamSocket^ socket)
{
	task<unsigned int>(reader->LoadAsync(1024)).then([this, reader, socket] (unsigned int size)
	{
		try
		{
			std::lock_guard<std::mutex> lock(_mx);

			for( int i = 0; i < size; ++i ){
				if( _cb.IsFull() )
				{
					Print("Win8 Circular Buffer is full!");
				}
				else
				{
					_cb.Write(reader->ReadByte());
				}
			}
		}
		catch (Platform::Exception^ exception)
		{
		}

	}).then([this, reader, socket] (task<void> previousTask)
	{
		try
		{
			// Try getting all exceptions from the continuation chain above this point.
			previousTask.get();

			// Everything went ok, so try to receive more... 
			// The receive will continue until the stream is broken (i.e. peer closed closed the socket).
			ReceiveLoop(reader, socket);
		}
		catch (Platform::Exception^ exception)
		{
			// Explicitly close the socket.
			Close();
		}
		catch (task_canceled&)
		{
			// Do not print anything here - this will usually happen because user closed the client socket.
			// Explicitly close the socket.
			Close();
		}
	});
}

/*
static byte* GetIBufferPointer(IBuffer^ buffer)
{
	// Cast to Object^, then to its underlying IInspectable interface.

	Platform::Object^ obj = buffer;
	Microsoft::WRL::ComPtr<IInspectable> insp(reinterpret_cast<IInspectable*>(obj));

	// Query the IBufferByteAccess interface.
	Microsoft::WRL::ComPtr<IBufferByteAccess> bufferByteAccess;
	//ThrowIfFailed(insp.As(&bufferByteAccess));

	// Retrieve the buffer data.
	byte* pixels = nullptr;
	//ThrowIfFailed(bufferByteAccess->Buffer(&pixels));

	return pixels;
}
*/
