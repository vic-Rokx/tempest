## Tempest

High performance, extensible, minimalist Zig web framework.

Help and questions: [Github Discussions](https://github.com/labstack/echo/discussions)

### Feature Overview



- High Performance: Built in Zig, Tempest offers fast execution and low overhead due to its efficient memory management.
- Redis inspired Cache Integration: Built-in cache support for session management, caching, and more.
- Go Echo Inspired: Familiar and intuitive API design, making it easy for Echo users to transition.
- Memory Safety: Zig’s memory-safe operations ensure reduced risk of memory leaks and undefined behavior.
- Optimized HTTP router which smartly prioritize routes
- Build robust and scalable RESTful APIs
- Group APIs
- Extensible middleware framework
- Define middleware at root, group or route level
- Data binding for JSON, XML and form payload
- Handy functions to send variety of HTTP responses
- Centralized HTTP error handling
- Template rendering with baked in template engine
- Cache baked in
- Define your format for the logger
- Highly customizable
- Automatic TLS via Let’s Encrypt
- HTTP/2 support

## Benchmarks

Date: 2020/11/11<br>
Source: https://github.com/vishr/web-framework-benchmark<br>
Lower is better!

<img src="https://i.imgur.com/qwPNQbl.png">
<img src="https://i.imgur.com/s8yKQjx.png">

The benchmarks above were run on an Intel(R) Core(TM) i7-6820HQ CPU @ 2.70GHz

## [Guide](https://echo.labstack.com/guide)

### Example

```zig
const std = @import("std");
const Tempest = @import("./tempest/server.zig");
const routes = @import("./tests/routes/index.zig");
const init = @import("./tests/data/index.zig").init;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const server_addr = "127.0.0.1";
    const server_port = 8080;
    const config = Tempest.Config{
        .server_addr = server_addr,
        .server_port = server_port,
    };

    try init(allocator);

    var tempest = try Tempest.new(config, allocator);
    defer tempest.deinit();

    try tempest.addRoute("/users", "POST", routes.createUser);
    try tempest.addRoute("/users/:id", "GET", routes.getUserById);
    try tempest.addRoute("/users/:id", "PATCH", routes.updateUserById);
    try tempest.listen();
}
```

## Contribute

**Use issues for everything**

- For a small change, just send a PR.
- For bigger changes open an issue for discussion before sending a PR.
- PR should have:
  - Test case
  - Documentation
  - Example (If it makes sense)
- You can also contribute by:
  - Reporting issues
  - Suggesting new features or enhancements
  - Improve/fix documentation

## License

[MIT](https://github.com/labstack/echo/blob/master/LICENSE)
