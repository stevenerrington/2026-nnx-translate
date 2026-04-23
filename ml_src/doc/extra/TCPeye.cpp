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
		if (2 != argc) throw exception("Usage: TCPeye port");

		WSADATA w;
		winsock_init = WSAStartup(MAKEWORD(2, 2), &w);
		if (0 != winsock_init) throw exception("Could not open Windows connection.");

		struct addrinfo eye;
		ZeroMemory(&eye, sizeof(eye));
		eye.ai_family = AF_INET;
		eye.ai_socktype = SOCK_STREAM;
		eye.ai_protocol = IPPROTO_TCP;
		eye.ai_flags = AI_PASSIVE;

		result = getaddrinfo(NULL, argv[1], &eye, &addrinfo);
		if (0 != result) throw exception("Could not get address information.");

		listen_socket = socket(addrinfo->ai_family, addrinfo->ai_socktype, addrinfo->ai_protocol);
		if (INVALID_SOCKET == listen_socket) throw exception("Could not create listen socket.");

		result = bind(listen_socket, addrinfo->ai_addr, (int)addrinfo->ai_addrlen);
		if (SOCKET_ERROR == result) throw exception("Could not bind to the address.");

		const size_t bufsize = 512;
		char buf[bufsize + 1];			// for null-terminator
		double x1 = -10, y1 = -10, x2 = -10, y2 = 10, p1, p2;

		while (true)
		{
			result = listen(listen_socket, SOMAXCONN);
			if (SOCKET_ERROR == result) throw exception("Could not listen.");

			client_socket = accept(listen_socket, NULL, NULL);
			if (INVALID_SOCKET == client_socket) throw exception("Could not accept inbound connection.");

			do
			{
				// simulated data
				x1 = (10 < x1) ? -10 : x1 + 0.1;
				y1 = (10 < y1) ? -10 : y1 + 0.1;
				x2 = (10 < x2) ? -10 : x2 + 0.1;
				y2 = (y2 < -10) ? 10 : y2 - 0.1;
				p1 = rand() / 32767.0 * 2;
				p2 = rand() / 32767.0 * 5;

				result = recv(client_socket, buf, bufsize, 0);  // NIMH ML will send "ok" first. Wait for it.
				if (0 < result)
				{
					int n = sprintf_s(buf, bufsize, "%f,%f,%f,%f,%f,%f", x1, y1, x2, y2, p1, p2);
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
