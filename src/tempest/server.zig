const std = @import("std");
const Context = @import("../context/index.zig");
const Radix = @import("../core/Radix.zig");
const helpers = @import("../helpers/index.zig");
const mem = std.mem;
const Parsed = std.json.Parsed;
const print = std.debug.print;
const net = std.net;

const Self = @This();

const HandlerFunc = *const fn (*Context) anyerror!void;

pub const Config = struct {
    server_addr: []const u8,
    server_port: u16,
};

routes: std.StringHashMap(Radix.Router),
allocator: mem.Allocator,
config: Config,

pub fn new(config: Config, allocator: mem.Allocator) !Self {
    const routes_map = std.StringHashMap(Radix.Router).init(allocator);
    return Self{
        .config = config,
        .allocator = allocator,
        .routes = routes_map,
    };
}

pub fn deinit(self: *Self) void {
    var routes_it = self.routes.valueIterator();
    while (routes_it.next()) |value| {
        try value.deinit();
    }

    self.routes.deinit();
}

pub fn addRoute(
    self: *Self,
    comptime path: []const u8,
    comptime method: []const u8,
    handler: HandlerFunc,
) !void {
    var router = try Radix.Router.init(self.allocator);
    try router.addRoute(path, handler);
    try self.routes.put(method, router);
    return;
}

pub fn callRoute(self: *Self, path: []const u8, method: []const u8, ctx: *Context) !void {
    var routesResult = self.routes.get(method);
    if (routesResult == null) {
        return error.MethodNotSupported;
    }
    const entry = try routesResult.?.searchRoute(path);
    if (entry == null) {
        return error.MethodNotSupported;
    }
    const entry_fn: *const fn (Context) anyerror!void = @ptrCast(entry.?.handler);
    const param_args = entry.?.param_args;

    for (param_args.items) |param| {
        // std.debug.print("\n param {s}", .{param.param});
        try ctx.addParam(param.param, param.value);
    }

    try entry_fn(ctx.*);
    // const httpMethods = self.routes.get(path) orelse return error.NoPath;
    // const func = httpMethods.methods.get(method) orelse return error.NoMethod;
    // try func(ctx);
}

pub fn parser(self: Self, comptime CacheType: type, haystack: []const u8) !Parsed(CacheType) {
    const payload_start = std.mem.indexOf(u8, haystack, "\r\n\r\n") orelse {
        std.debug.print("Failed to find payload start.\n", .{});
        return error.PostFailed;
    } + 4; // Skip the "\r\n\r\n"
    const json_payload = haystack[payload_start..];

    const parsed = std.json.parseFromSlice(
        CacheType,
        self.allocator,
        json_payload,
        .{},
    ) catch return error.MalformedJson;
    defer parsed.deinit();

    return parsed;
}

pub fn createContext(self: *Self, comptime T: type, data: T) !Context {
    const ctx = try Context.init(self.allocator, data);
    return ctx;
}

pub fn listen(self: *Self) !void {
    const color = "\x1b[38;5;57m";
    const red = "\x1b[31m"; // ANSI escape code for red color
    const background = "\x1b[36m"; // ANSI escape code for red color
    const reset = "\x1b[0m"; // ANSI escape code to reset color
    const bold = "\x1b[1m"; // ANSI escape code to reset color

    const ascii_art =
        \\  ______    ______     __    __     ______   ______     ______     ______
        \\ /\__  _\  /\  ___\   /\ "-./  \   /\  == \ /\  ___\   /\  ___\   /\__  _\
        \\ \/_/\ \/  \ \  __\   \ \ \-./\ \  \ \  _-/ \ \  __\   \ \___  \  \/_/\ \/
        \\    \ \_\   \ \_____\  \ \_\ \ \_\  \ \_\    \ \_____\  \/\_____\    \ \_\
        \\     \/_/    \/_____/   \/_/  \/_/   \/_/     \/_____/   \/_____/     \/_/
    ;
    print("\n{s}{s}{s}\n", .{ color, ascii_art, reset });

    const self_addr = try net.Address.resolveIp(self.config.server_addr, self.config.server_port);
    var server = try self_addr.listen(.{ .reuse_address = true });

    print("\n{s}{s}Running  {s}:{}{s}\n", .{ bold, background, self.config.server_addr, self.config.server_port, reset });

    while (server.accept()) |conn| {
        print("{s}{s}Accepted connection from:{s} {}\n", .{ red, bold, reset, conn.address });

        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;
        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            if (recv_len == 0) break;
            recv_total += recv_len;
            if (mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
                break;
            }
        } else |read_err| {
            return read_err;
        }
        const recv_data = recv_buf[0..recv_total];
        if (recv_data.len == 0) {
            // Browsers (or firefox?) attempt to optimize for speed
            // by opening a connection to the server once a user highlights
            // a link, but doesn't start sending the request until it's
            // clicked. The request eventually times out so we just
            // go agane.
            std.debug.print("Got connection but no header!\n", .{});
            continue;
        }
        var header = try helpers.parseHeader(recv_data);
        const path = helpers.parsePath(header.request_line) catch |err| {
            if (err == error.MalformedJson) {
                _ = try conn.stream.writer().write(helpers.httpJsonMalformed());
                continue;
            } else if (err == error.Success) {
                _ = try conn.stream.writer().write(helpers.http200());
                continue;
            } else {
                return err;
            }
        };
        const method = try helpers.parseMethod(header.request_line);
        header.method = method;

        var ctx = try Context.init(self.allocator, method, path, conn);

        try ctx.setJson(recv_data);
        const callRouteErr = self.callRoute(path, method, &ctx);
        try ctx.deinit();

        if (callRouteErr == error.MethodNotSupported) {
            _ = try conn.stream.write(helpers.http404());
            conn.stream.close();
        }

        // _ = try conn.stream.write(helpers.http200());

        // print("{s}", .{recv_data});
        // const buf: []u8 = undefined;
        // const mime: []const u8 = "";
        // std.debug.print("SENDING----\n", .{});
        // const httpHead =
        //     "HTTP/1.1 200 OK \r\n" ++
        //     "Connection: close\r\n" ++
        //     "Content-Type: {s}\r\n" ++
        //     "Content-Length: {}\r\n" ++
        //     "\r\n";
        // _ = try conn.stream.writer().print(httpHead, .{ mime, buf.len });
        // _ = try conn.stream.writer().write(buf);
    } else |err| {
        std.debug.print("error in accept: {}\n", .{err});
    }
}
