# MinGW Makefile for rtltcpaccess

all : main

main:
	gcc -O3 -Wall -Wno-unused-function -c main.c -o main.o
#	windres -i resource.rc -o resource.o
#	gcc -o RTL283XACCESS.dll main.o resource.o -shared -s -lws2_32 -Wl,--subsystem,windows,--out-implib,libaddlib.a
	gcc -o RTL283XACCESS.dll main.o -shared -s -lws2_32 -Wl,--subsystem,windows

clean:
	rm *.o *.dll
