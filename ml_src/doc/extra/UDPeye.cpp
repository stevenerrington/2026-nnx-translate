#include <iostream>
#include <ws2tcpip.h>

#pragma comment(lib,"ws2_32.lib")

using namespace std;

int main(int argc, char** argv)
{
	int exit_code = EXIT_SUCCESS;
	int winsock_init = WSANOTINITIALISED;
	SOCKET s = INVALID_SOCKET;

	try
	{
		if (3 != argc) throw exception("Usage: UDPeye ip_address port");

		WSADATA w;
		winsock_init = WSAStartup(MAKEWORD(2, 2), &w);
		if (0 != winsock_init) throw exception("Could not open Windows connection.");

		s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
		if (INVALID_SOCKET == s) throw exception("Could not create socket.");

		unsigned short port = static_cast<unsigned short>(atoi(argv[2]));
		struct sockaddr_in NIMH_ML;
		ZeroMemory(&NIMH_ML, sizeof(NIMH_ML));
		NIMH_ML.sin_family = AF_INET;
		NIMH_ML.sin_port = htons(port);
		inet_pton(AF_INET, argv[1], &NIMH_ML.sin_addr);

		const size_t bufsize = 512;
		char buf[bufsize + 1];			// for null-terminator
		double x1 = -10, y1 = -10, x2 = -10, y2 = 10, p1, p2;

		while (true)
		{
			// simulated data
			x1 = (10 < x1) ? -10 : x1 + 0.1;
			y1 = (10 < y1) ? -10 : y1 + 0.1;
			x2 = (10 < x2) ? -10 : x2 + 0.1;
			y2 = (y2 < -10) ? 10 : y2 - 0.1;
			p1 = rand() / 32767.0 * 2;
			p2 = rand() / 32767.0 * 5;

			int n = sprintf_s(buf, bufsize, "%f,%f,%f,%f,%f,%f", x1, y1, x2, y2, p1, p2);
			if (SOCKET_ERROR == sendto(s, buf, n, 0, (struct sockaddr*)&NIMH_ML, sizeof(NIMH_ML))) throw exception("Could not send data.");

			cout << buf << endl;
			Sleep(1);					// not to send too many packets
		}
	}
	catch (const exception& e)
	{
		cerr << e.what() << endl;
		exit_code = EXIT_FAILURE;
	}

	if (INVALID_SOCKET != s) closesocket(s);
	if (0 == winsock_init) WSACleanup();

	return exit_code;
}
