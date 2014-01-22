// Includes
#include "include/uv.h"


// Types
typedef struct
{
    uv_tcp_t handle;
    uv_write_t req;
    void* nim_request;
} client_t;