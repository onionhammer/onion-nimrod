#include <stdio.h>
#include <string.h>
#include "include/uv.h"

typedef struct
{
    uv_tcp_t handle;
    uv_write_t req;
    void* nim_request;
} client_t;