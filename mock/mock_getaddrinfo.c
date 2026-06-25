// mock_getaddrinfo.c — LD_PRELOAD mock for DNS resolution functions
// Compile: gcc -fPIC -shared -o mock_getaddrinfo.so mock_getaddrinfo.c -ldl

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <time.h>

// Store original function pointers
static int (*real_getaddrinfo)(const char *, const char *,
                               const struct addrinfo *, struct addrinfo **) = NULL;

static void init_real_funcs(void)
{
    if (!real_getaddrinfo) {
        real_getaddrinfo = (int (*)(const char *, const char *,
                                     const struct addrinfo *, struct addrinfo **))
            dlsym(RTLD_NEXT, "getaddrinfo");
        if (!real_getaddrinfo) {
            fprintf(stderr, "[mock_getaddrinfo] dlsym failed: %s\n", dlerror());
            _exit(1);
        }
    }
}

// Parse MOCK_DNS_MAP env var: "host1:ip1,host2:ip2,..."
// Returns malloc'd IP string if host matches, or NULL if not found.
static const char *lookup_dns_map(const char *node)
{
    static char result_ip[64];
    const char *map = getenv("MOCK_DNS_MAP");
    if (!map || !node) return NULL;

    // Make a mutable copy for strtok
    char *buf = strdup(map);
    if (!buf) return NULL;

    const char *found = NULL;
    char *token = strtok(buf, ",");
    while (token) {
        // Trim leading whitespace
        while (*token == ' ' || *token == '\t') token++;
        char *colon = strchr(token, ':');
        if (colon) {
            *colon = '\0';
            const char *entry_host = token;
            const char *entry_ip = colon + 1;
            if (strcmp(node, entry_host) == 0) {
                strncpy(result_ip, entry_ip, sizeof(result_ip) - 1);
                result_ip[sizeof(result_ip) - 1] = '\0';
                found = result_ip;
                break;
            }
        }
        token = strtok(NULL, ",");
    }
    free(buf);
    return found;
}

// Check if we should simulate DNS failure
static int should_fail(void)
{
    const char *fail = getenv("MOCK_DNS_FAIL");
    return fail && strcmp(fail, "1") == 0;
}


// Check if we should add delay
static int get_mock_delay_ms(void)
{
    const char *delay = getenv("MOCK_DNS_DELAY");
    if (delay) {
        return atoi(delay);
    }
    return 0;
}

int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints,
                struct addrinfo **res)
{
    init_real_funcs();

    // Check if we should delay
    int delay_ms = get_mock_delay_ms();
    if (delay_ms > 0) {
        struct timespec ts = {
            .tv_sec = delay_ms / 1000,
            .tv_nsec = (delay_ms % 1000) * 1000000L
        };
        nanosleep(&ts, NULL);
    }

    if (should_fail()) {
        fprintf(stderr, "[mock_getaddrinfo] Simulating DNS failure for %s\n",
                node ? node : "(null)");
        return EAI_FAIL;
    }

    // Check DNS map for hostname
    const char *mapped_ip = NULL;
    if (node) {
        mapped_ip = lookup_dns_map(node);
    }

    if (mapped_ip) {
        fprintf(stderr, "[mock_getaddrinfo] Mapping %s -> %s\n", node, mapped_ip);

        // Allocate and fill addrinfo structure
        struct addrinfo *ai = calloc(1, sizeof(struct addrinfo));
        if (!ai) return EAI_MEMORY;

        ai->ai_family = AF_INET;
        ai->ai_socktype = hints ? hints->ai_socktype : SOCK_STREAM;
        ai->ai_protocol = hints ? hints->ai_protocol : 0;

        struct sockaddr_in *sin = calloc(1, sizeof(struct sockaddr_in));
        if (!sin) {
            free(ai);
            return EAI_MEMORY;
        }
        sin->sin_family = AF_INET;
        if (service) {
            sin->sin_port = htons(atoi(service));
        }
        inet_pton(AF_INET, mapped_ip, &sin->sin_addr);

        ai->ai_addr = (struct sockaddr *)sin;
        ai->ai_addrlen = sizeof(struct sockaddr_in);

        *res = ai;
        return 0;
    }

    // Not a mocked host — pass through to real getaddrinfo
    return real_getaddrinfo(node, service, hints, res);
}
