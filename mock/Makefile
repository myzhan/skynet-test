CC = gcc
CFLAGS = -fPIC -shared -Wall -O2
export PATH := /usr/bin:/bin:$(PATH)

all: mock_getaddrinfo.so

mock_getaddrinfo.so: mock_getaddrinfo.c
	$(CC) $(CFLAGS) -o $@ $< -ldl

clean:
	rm -f *.so
