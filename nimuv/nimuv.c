//TODO::
// - Add timeouts to request

#include "nimuv.h"


// Fields
static uv_tcp_t server;
static uv_loop_t* loop;


// Functions
#define CHECKCLOSE(r, x) \
    if (r) { \
        fprintf(stderr, "%s\n", uv_strerror(r)); \
        uv_close(x, on_close); \
    }

void on_close(uv_handle_t* handle, int status) {
    client_t* client = handle->data;
    free(client);
}

void end_response(client_t* client) {
    uv_close(&client->handle, on_close);
}

void on_alloc(uv_tcp_t* tcp, size_t suggested_size, uv_buf_t* buf) {
    buf->len  = suggested_size;
    buf->base = malloc(suggested_size);
}

void on_read(uv_tcp_t* tcp, ssize_t nread, const uv_buf_t* buf) {
    client_t* client = tcp->data;

    if (nread >= 0) {
        // TODO Concat buffer
        if (client->nim_request == NULL)
            client->nim_request = http_readheaders(client, buf->base, nread);
        else
            http_continue(client->nim_request, buf->base, nread);
    }
    else {
        // End response
        end_response(client);
    }

    // Free resources
    free(buf->base);
}

void on_connection(uv_tcp_t* handle) {
    client_t* client = malloc(sizeof(client_t));
    client->nim_request = NULL;
    uv_tcp_init(loop, &client->handle);

    if (uv_accept(&server, &client->handle)) {
        free(client);
        return;
    }

    client->handle.data = client;

    // Init data
    uv_read_start(&client->handle, on_alloc, on_read);
}

// External Interface
void send_response(client_t* client, char* buffer) {
    uv_buf_t resp_buffer = uv_buf_init(buffer, strlen(buffer));

    int r = uv_write(&client->req, &client->handle, &resp_buffer, 1, NULL);
    CHECKCLOSE(r, &client->handle)
}

void start_server(char* ip, int port) {
    int r;

    // Initialize uv
    loop = uv_default_loop();
    uv_tcp_init(loop, &server);

    struct sockaddr_in address;
    uv_ip4_addr(ip, port, &address);

    // Bind address
    r = uv_tcp_bind(&server, &address);
    if (r) { fprintf(stderr, "%s\n", uv_strerror(r)); }

    // Start listening
    r = uv_listen(&server, 128, on_connection);
    if (r) { fprintf(stderr, "%s\n", uv_strerror(r)); }

    // Run UV
    uv_run(loop, UV_RUN_DEFAULT);
}