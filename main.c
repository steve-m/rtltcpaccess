/*
 * rtltcpaccess, a drop-in replacement for RTL283XACCESS.dll
 * https://github.com/steve-m/rtltcpaccess
 *
 * Copyright (c) 2013 Steve Markgraf <steve@steve-m.de>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <stdio.h>
#include <stdint.h>
#include <windows.h>
#include <errno.h>
#include <process.h>

#define DEFAULT_IP	"127.0.0.1"
#define DEFAULT_PORT	1234
#define BUFF_SIZE	24064

static uint8_t buff[BUFF_SIZE];
static HANDLE got_data = NULL;
static HANDLE pulled_data = NULL;
static HANDLE thread_finished = NULL;
static int exit_thread = FALSE;
static int enable_testmode = FALSE;
static SOCKET sock;

#pragma pack(push, 1)
struct command {
	unsigned char cmd;
	unsigned int param;
}__attribute__((packed));
#pragma pack(pop)

static int is_error(int perr)
{
	/* Compare error to posix error code; return nonzero if match. */
#ifndef ENOPROTOOPT
	#define ENOPROTOOPT 109
#endif
	/* All codes to be checked for must be defined below */
	int werr = WSAGetLastError();
	switch (werr) {
	case WSAETIMEDOUT:
		return(perr == EAGAIN);
	case WSAENOPROTOOPT:
		return(perr == ENOPROTOOPT);
	default:
		fprintf(stderr, "tcp: unknown error %d WS err %d\n", perr, werr);
		return 0;
	}
}

static void tcp_thread(void *param)
{
	int received_bytes, bytes_left, index;

	while (!exit_thread) {
		bytes_left = BUFF_SIZE;
		index = 0;

		while (bytes_left > 0) {
			received_bytes = recv(sock, (char *)&buff[index], bytes_left, 0);

			if (received_bytes == -1 && !is_error(EAGAIN)) {
				fprintf(stderr, "[rtltcpaccess] socket error\n");
				goto endthread;
			}

			bytes_left -= received_bytes;
			index += received_bytes;
		}

		if (got_data) {
			ResetEvent(pulled_data);
			SetEvent(got_data);
			WaitForSingleObject(pulled_data, INFINITE);
		}
	}

endthread:
	SetEvent(thread_finished);
	_endthread();
}

static BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved)
{
	switch(reason) {
	case DLL_PROCESS_ATTACH:
		DisableThreadLibraryCalls(hinst);
		break;
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

DWORD RTK_BDAFilterInit(HANDLE hnd)
{
	HKEY key;
	DWORD r, len = 0;
	const char settings_key[] = "Software\\rtltcpaccess";
	char ip_addr[16] = DEFAULT_IP;
	uint32_t port = DEFAULT_PORT;
	uint32_t testmode = 0;
	int flag = 1, tries = 0;
	struct sockaddr_in remote;
	struct command samprate_cmd = { 0x02, htonl(2048000) };
	struct command testmode_cmd = { 0x07, htonl(1) };
	WSADATA wsd;

	r = WSAStartup(MAKEWORD(2,2), &wsd);

	if (!RegOpenKeyExA(HKEY_CURRENT_USER, settings_key, 0, KEY_READ, &key)) {
		r = RegQueryValueExA(key, "address", NULL, NULL, NULL, &len);

		if (!r && len > 7 && len <= sizeof(ip_addr))
			r = RegQueryValueExA(key, "address", NULL, NULL, (BYTE *)ip_addr, &len);

		len = sizeof(port);
		r = RegQueryValueExA(key, "port", NULL, NULL, (BYTE *)&port, &len);

		if (r || port > 0xffff)
			port = DEFAULT_PORT;

		len = sizeof(testmode);
		r = RegQueryValueExA(key, "testmode", NULL, NULL, (BYTE *)&testmode, &len);

		if (!r)
			enable_testmode = testmode ? TRUE : FALSE;
	}

	sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

	memset(&remote, 0, sizeof(remote));
	remote.sin_family = AF_INET;
	remote.sin_port = htons(port);
	remote.sin_addr.s_addr = inet_addr(ip_addr);

	if (remote.sin_addr.s_addr == INADDR_NONE)
		remote.sin_addr.s_addr = inet_addr(DEFAULT_IP);

	while (connect(sock, (struct sockaddr *)&remote, sizeof(remote)) != 0) {
		fprintf(stderr, "[rtltcpaccess] trying to connect to %s:%d...\n", ip_addr, port);
		if (tries > 10) {
			fprintf(stderr, "[rtltcpaccess] timeout, aborting\n");
			return FALSE;
		}

		Sleep(500);
		tries++;
	}

	fprintf(stderr, "[rtltcpaccess] connected!\n");
	setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *)&flag, sizeof(flag));

	send(sock, (const char*)&samprate_cmd, sizeof(samprate_cmd), 0);

	if (enable_testmode) {
		fprintf(stderr, "[rtltcpaccess] enabled testmode\n");
		send(sock, (const char*)&testmode_cmd, sizeof(testmode_cmd), 0);
	}

	pulled_data = CreateEventA(0, 0, 0, 0);
	thread_finished = CreateEventA(0, 0, 0, 0);
	_beginthread(tcp_thread, 0, NULL);

	return TRUE;
}

DWORD RTK_BDAFilterRelease(HANDLE hnd)
{
	exit_thread = TRUE;

	if (thread_finished)
		WaitForSingleObject(thread_finished, INFINITE);

	if (sock != -1) {
		closesocket(sock);
		sock = -1;
	}

	WSACleanup();

	return TRUE;
}

DWORD RTK_Set_Frequency(DWORD freq)
{
	uint32_t freq_hz = freq * 1000;

	struct command cmd = { 0x01, htonl(freq_hz) };
	send(sock, (const char*)&cmd, sizeof(cmd), 0);

	return TRUE;
}

DWORD RTK_Set_Bandwidth(DWORD bw) { return TRUE; }
DWORD RTK_DeviceUpdate(void) { return TRUE; }

DWORD RTK_GetData(LPBYTE data, DWORD bufsize, LPDWORD getlen, LPDWORD discardlen)
{
	static uint8_t bcnt, uninit = 1;
	int i, lost = 0;

	if (enable_testmode) {
		if (uninit) {
			bcnt = buff[0];
			uninit = 0;
		}

		for (i = 0; i < BUFF_SIZE; i++) {
			if(bcnt != buff[i]) {
				lost += (buff[i] > bcnt) ? (buff[i] - bcnt) : (bcnt - buff[i]);
				bcnt = buff[i];
			}
			bcnt++;
		}

		if (lost)
			fprintf(stderr, "[rtltcpaccess] lost at least %d bytes\n", lost);
	}

	if (bufsize >= BUFF_SIZE) {
		memcpy(data, buff, BUFF_SIZE);
		*getlen = BUFF_SIZE;
		*discardlen = 0;
		SetEvent(pulled_data);
	}

	return TRUE;
}

DWORD RTK_Demod_Byte_Read(INT page, INT reg, INT len, PBYTE val) { return TRUE; }
DWORD RTK_Demod_Byte_Write(INT page, INT reg, INT len, PBYTE val) { return TRUE; }

DWORD RTK_SetDABEventHandle(HANDLE *handle)
{
	got_data = *handle;
	return TRUE;
}

DWORD RTK_ReleaseDABEventHandle(HANDLE *handle)
{
	got_data = NULL;
	return TRUE;
}

DWORD RTK_Get_TunerType(LPDWORD tuner_type)
{
	*tuner_type = 5;			/* E4000, doesn't matter */
	return TRUE;
}

DWORD RTK_SYS_Byte_Read(WORD addr, INT len, PBYTE val)
{
	/* expected register contents */
	const uint8_t sys_regs[] = { 0x00, 0x88, 0x09, 0xdc, 0x03 };

	if (addr < sizeof(sys_regs)) {
		*val = sys_regs[addr];
		return TRUE;
	}

	return FALSE;
}

DWORD RTK_SYS_Byte_Write(WORD addr, INT len, PBYTE val) { return TRUE; }
