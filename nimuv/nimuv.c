//TODO::
// - Add timeouts to request


// Includes
#include <stdio.h>
#include "include/uv.h"


// Types
typedef struct
{
    uv_tcp_t handle;
    uv_write_t req;
    void* nim_request;
} client_t;


// Fields
static uv_tcp_t server;
static uv_loop_t* loop;


// Declaration
void end_response(client_t* client);


// Events
void on_close(uv_handle_t* handle, int status) {
    client_t* client = handle->data;
    free(client);
}

void on_alloc(uv_tcp_t* tcp, size_t suggested_size, uv_buf_t* buf) {
    buf->len  = suggested_size;
    buf->base = malloc(suggested_size);
}

char* get_endpoint(uv_tcp_t* tcp, short *port) {
    int r;

    // Retrieve ip & port
    struct sockaddr_in peer;
    int len = sizeof peer;
    if (r = uv_tcp_getpeername(tcp, &peer, &len))
        fprintf(stderr, "%s\n", uv_strerror(r));

    *port = ntohs(peer.sin_port);
    return inet_ntoa(peer.sin_addr);
}

void on_read(uv_tcp_t* tcp, ssize_t nread, const uv_buf_t* buf) {
    int r;
    client_t* client = tcp->data;

    if (nread >= 0) {
        // Concat buffer
        if (client->nim_request == NULL) {
            short port;
            char* ip = get_endpoint(tcp, &port);

            client->nim_request = http_readheader(
                client, buf->base,
                ip, port, nread
            );
        }
        else if (!http_continue(client->nim_request, buf->base, nread))
            // Request is now completely read
            client->nim_request = NULL;
    }
    else {
        //If this is a broken request, give opportunity
        //to free memory
        if (client->nim_request != NULL)
            http_end(client->nim_request);

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

    // Attach client to handle
    client->handle.data = client;

    // Init data
    uv_read_start(&client->handle, on_alloc, on_read);
}


// Functions
void end_response(client_t* client) {
    uv_close(&client->handle, on_close);
}

void send_response(client_t* client, char* buffer) {
    uv_buf_t resp_buffer = uv_buf_init(buffer, strlen(buffer));

    int r = uv_write(&client->req, &client->handle, &resp_buffer, 1, NULL);
    if (r) {
        fprintf(stderr, "%s\n", uv_strerror(r));

        if (client->nim_request != NULL)
            http_end(client->nim_request);

        uv_close(&client->handle, on_close);
    }
}

void start_server(char* ip, int port) {
    int r;

    // Initialize uv
    loop = uv_default_loop();
    uv_tcp_init(loop, &server);

    struct sockaddr_in address;
    uv_ip4_addr(ip, port, &address);

    // Bind address
    r = uv_tcp_bind(&server, &address, 0);
    if (r) { fprintf(stderr, "%s\n", uv_strerror(r)); }

    // Start listening
    r = uv_listen(&server, 128, on_connection);
    if (r) { fprintf(stderr, "%s\n", uv_strerror(r)); }

    // Run UV
    uv_run(loop, UV_RUN_DEFAULT);
}