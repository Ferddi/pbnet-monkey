
// ***** tcpsocket.h *****

#if _WIN32

#include <winsock.h>

#define EINTR WSAEINTR

#else

#include <netdb.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/time.h>
#include <errno.h>

#define closesocket close
#define ioctlsocket ioctl

#endif

#define MAX_CLIENTS		128

class BBTcpServer : public Object {
public:

	BBTcpServer();
	~BBTcpServer();
	
	bool SetupListen(int port);
	bool CheckConnection();
	bool SetupSocket(BBTcpSocket * bbTcpSocket);
	
private:

	int _master_socket;
	int _client_socket;

	struct sockaddr_in _address;
	int _addrlen;

	//set of socket descriptors
	fd_set readfds;
};

// ***** socket.cpp *****

BBTcpServer::BBTcpServer():_master_socket(-1),_client_socket(-1){
#if _WIN32
	static bool started;
	if( !started ){
		WSADATA ws;
		WSAStartup( 0x101,&ws );
		started=true;
	}
#endif
}

BBTcpServer::~BBTcpServer(){
	if( _master_socket>=0 ) closesocket( _master_socket );
}

bool BBTcpServer::SetupListen(int port)
{

	//initialise all client_socket[] to 0 so not checked
	//for (int i = 0; i < MAX_CLIENTS; i++)
	//{
	//	client_socket[i] = 0;
	//}
	_client_socket = 0;

	//create a master socket
	if( (_master_socket = socket(AF_INET , SOCK_STREAM , 0)) == 0)
	{
		return false;
	}
 
	//set master socket to allow multiple connections , this is just a good habit, it will work without this
	int opt = 1;
	if( setsockopt(_master_socket, SOL_SOCKET, SO_REUSEADDR, (const char *)&opt, sizeof(opt)) < 0 )
	{
		return false;
	}

	//disable the Nagle buffering algorithm, so even 1 byte we send it straight away.
	int nodelay = 1;
	if( setsockopt(_master_socket, IPPROTO_TCP, TCP_NODELAY, (const char*)&nodelay, sizeof(nodelay)) < 0 )
	{
		puts( "setsockopt failed!" );
		return false;
	}

	//type of socket created
	_address.sin_family = AF_INET;
	_address.sin_addr.s_addr = INADDR_ANY;
	_address.sin_port = htons( port );

	//bind the socket to localhost port.
	if (bind(_master_socket, (struct sockaddr *)&_address, sizeof(_address))<0)
	{
		return false;
	}

	//try to specify maximum of 5 pending connections for the master socket
	if (listen(_master_socket, 5) < 0)
	{
		return false;
	}

	//accept the incoming connection
	_addrlen = sizeof(_address);
	//puts("Waiting for connections...");

	return true;
}

bool BBTcpServer::CheckConnection()
{
	int i = 0;
	int s = 0;

	//clear the socket set
	FD_ZERO(&readfds);

	//add master socket to set
	FD_SET(_master_socket, &readfds);

	//add child sockets to set
//	for (i = 0 ; i < max_clients ; i++)
//	{
//		s = client_socket[i];
//		if (s > 0)
//		{
//			FD_SET( s , &readfds);
//		}
//	}

	s = _client_socket;
	if (s > 0)
	{
		FD_SET(s, &readfds);
	}

	//wait for an activity on one of the sockets , timeout is zero, so dont wait at all.
	struct timeval tv;
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	int activity = select( MAX_CLIENTS + 3 , &readfds , NULL , NULL , &tv);

	if ((activity < 0) && (errno!=EINTR))
	{
		return false;
	}

	//If something happened on the master socket , then its an incoming connection
	if (FD_ISSET(_master_socket, &readfds))
	{
		int new_socket = 0;
	
		//if ((new_socket = accept(_master_socket, (struct sockaddr *)&_address, (socklen_t*)&_addrlen))<0)
		if ((new_socket = accept(_master_socket, (struct sockaddr *)&_address, &_addrlen))<0)
		{
			return false;
		}
		
		//disable the Nagle buffering algorithm, so even 1 byte we send it straight away.
		int nodelay = 1;
		if( setsockopt(new_socket, IPPROTO_TCP, TCP_NODELAY, (const char*)&nodelay, sizeof(nodelay)) < 0 )
		{
			puts( "setsockopt failed!" );
			return false;
		}

		_client_socket = new_socket;

		//inform user of socket number - used in send and receive commands
		//printf("New connection , socket fd is %d , ip is : %s , port : %d \n" , new_socket , inet_ntoa(_address.sin_addr) , ntohs(_address.sin_port));
             
		//add new socket to array of sockets
//		for (i = 0; i < MAX_CLIENTS; i++)
//		{
//			s = client_socket[i];
//			if (s == 0)
//			{
//				client_socket[i] = new_socket;
//				//printf("Adding to list of sockets as %d\n" , i);
//				i = MAX_CLIENTS;
//			}
//		}

		//else its some IO operation on some other socket :)
//		for (i = 0; i < max_clients; i++)
//		{
//			s = client_socket[i];
//
//			if (FD_ISSET( s , &readfds))
//			{
//				//Check if it was for closing , and also read the incoming message
//				if ((valread = read( s , buffer, 1024)) == 0)
//				{
//					//Somebody disconnected , get his details and print
//					getpeername(s , (struct sockaddr*)&_address , (socklen_t*)&_addrlen);
//					printf("Host disconnected , ip %s , port %d \n" , inet_ntoa(_address.sin_addr) , ntohs(_address.sin_port));
//
//					//Close the socket and mark as 0 in list for reuse
//					close( s );
//					client_socket[i] = 0;
//				}

				//Echo back the message that came in
				//else
				//{
					//set the terminating NULL byte on the end of the data read
				//	buffer[valread] = '\0';
				//	send( s , buffer , strlen(buffer) , 0 );
				//}
//			}
//		}

		return true;
	}

	return false;
}

bool BBTcpServer::SetupSocket(BBTcpSocket * bbTcpSocket)
{
	if (_client_socket > 0)
	{
		bbTcpSocket->SetupSocket(_client_socket);
		
		return true;
	}

	return false;
}

