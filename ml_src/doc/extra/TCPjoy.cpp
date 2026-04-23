#include <iostream>
#include <ws2tcpip.h>

#pragma comment(lib,"ws2_32.lib")

using namespace std;

int main(int argc, char** argv)
{
	int exit_code = EXIT_SUCCESS;
	int winsock_init = WSANOTINITIALISED;
	struct addrinfo* addrinfo = nullptr;
	SOCKET listen_socket = INVALID_SOCKET;
	SOCKET client_socket = INVALID_SOCKET;
	int result;

	try
	{
		if (2 != argc) throw exception("Usage: TCPjoy port");

		WSADATA w;
		winsock_init = WSAStartup(MAKEWORD(2, 2), &w);
		if (0 != winsock_init) throw exception("Could not open Windows connection.");

		struct addrinfo joy;
		ZeroMemory(&joy, sizeof(joy));
		joy.ai_family = AF_INET;
		joy.ai_socktype = SOCK_STREAM;
		joy.ai_protocol = IPPROTO_TCP;
		joy.ai_flags = AI_PASSIVE;

		result = getaddrinfo(NULL, argv[1], &joy, &addrinfo);
		if (0 != result) throw exception("Could not get address information.");

		listen_socket = socket(addrinfo->ai_family, addrinfo->ai_socktype, addrinfo->ai_protocol);
		if (INVALID_SOCKET == listen_socket) throw exception("Could not create listen socket.");

		result = bind(listen_socket, addrinfo->ai_addr, (int)addrinfo->ai_addrlen);
		if (SOCKET_ERROR == result) throw exception("Could not bind to the address.");

		const size_t bufsize = 512;
		char buf[bufsize + 1];			// for null-terminator
		long x = -10000, y = -10000, button1, button2;

		while (true)
		{
			result = listen(listen_socket, SOMAXCONN);
			if (SOCKET_ERROR == result) throw exception("Could not listen.");

			client_socket = accept(listen_socket, NULL, NULL);
			if (INVALID_SOCKET == client_socket) throw exception("Could not accept inbound connection.");

			do
			{
				// simulated data
				x = (10000 < x) ? -10000 : x + 80;
				y = (10000 < y) ? -10000 : y + 80;
				button1 = 16383 < rand();
				button2 = 0 == button1;

				result = recv(client_socket, buf, bufsize, 0);  // NIMH ML will send "ok" first. Wait for it.
				if (0 < result)
				{
					int n = sprintf_s(buf, bufsize, "%d,%d,%d,%d", x, y, button1, button2);
					if (SOCKET_ERROR == send(client_socket, buf, n, 0)) throw exception("Could not send data.");

					cout << buf << endl;
					Sleep(1);			// not to send too many packets
				}
				else if (0 == result)
				{
					if (SOCKET_ERROR == shutdown(client_socket, SD_SEND)) throw exception("Could not shutdown.");
					cout << "Disconnected normally." << endl;
				}
				else
				{
					cerr << "Disconnected with an error." << endl;
				}
			} while (0 < result);
		}
	}
	catch (const exception& e)
	{
		cerr << e.what() << endl;
		exit_code = EXIT_FAILURE;
	}

	if (INVALID_SOCKET != client_socket) closesocket(client_socket);
	if (INVALID_SOCKET != listen_socket) closesocket(listen_socket);
	if (!addrinfo) freeaddrinfo(addrinfo);
	if (0 == winsock_init) WSACleanup();

	return exit_code;
}
