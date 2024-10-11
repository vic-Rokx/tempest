const std = @import("std");
// const Context = @import("../../context/index.zig");
// Define a type for the handler function

// Define the Context struct (you can extend it as needed)
const Context = struct {
    // Add fields for context data
    user_id: u32,
};

const HandlerFunc = *const fn (*Context) void;
const MiddleFunc = *const fn (HandlerFunc) HandlerFunc;

// pub fn acceptCookie(ctx: *Context) anyerror!void {
//     var user = try ctx.bind(User);
//     user.id = try helpers.convertStringToSlice(user.id.?, std.heap.c_allocator);
//     try cache.user_db.put(user.id.?, user);
//     const cached_user = try cache.user_db.get(user.id.?);
//     _ = try ctx.JSON(User, cached_user);
// }

fn verifyAuth(next: HandlerFunc) HandlerFunc {
    const next_fn = next;
    const Func = struct {
        next: HandlerFunc = next_fn,
        fn call(ctx: *Context) void {
            next_fn(ctx);
        }
    };
    const fncall = Func.call;
    return fncall;
    // return struct {
    //     fn call(ctx: *Context) void {
    //         // Call the next handler
    //         next_fn(ctx);
    //     }
    // }.call;
}

// fn validate(next: HandlerFunc) HandlerFunc {
//     const Call = struct {
//         const Self = @This();
//         next: HandlerFunc, // Store the next handler as a field
//
//         fn init(next_fn: HandlerFunc) Self {
//             return Self{
//                 .next = next_fn,
//             };
//         }
//
//         fn call(self: *Self, ctx: *Context) void {
//             // Modify the context
//             ctx.user_id += 100;
//
//             // Call the next handler
//             self.next(ctx); // Access 'next' from the struct
//         }
//     };
//     const call_strct = Call.init(next);
//     call_strct.call;
//     return next;
// }

const HandlerFuncC = *const fn (i32, i32) fn () i32;
fn createCounter(initial: i32, step: i32) fn () i32 {
    const Contextt = struct {
        count: i32,
        increment: i32,

        pub fn increment(self: *@This()) i32 {
            self.count += self.increment;
            return self.count;
        }
    };

    const context = Contextt{ .count = initial, .increment = step };

    return struct {
        pub fn call() i32 {
            return context.increment();
        }
    }.call;
}

// Example handler function
fn myHandler(ctx: *Context) void {
    std.debug.print("Hello, user {}!\n", .{ctx.user_id});
}

const wrappedHandler = verifyAuth(myHandler);
// const doubleWrappedHandler = validate(wrappedHandler);

fn addRoute(_: HandlerFunc, middlewares: []MiddleFunc) void {
    _ = middlewares;
    // parseMiddleWare(0, middlewares);
}

fn parseMiddleWare(func_num: usize, middleswares: []MiddleFunc) void {
    const first_func = middleswares[func_num];
    const second_func = middleswares[func_num + 1];
    first_func(second_func);
    // parseMiddleWare(func_num + 1, second_func);
}

const HandlerStruct = struct {
    handler: HandlerFuncC,
};

fn executeHandlers(handlers: []HandlerStruct, ctx: *Context) void {
    for (handlers) |handler| {
        handler.handler(ctx);
    }
}

pub fn main() !void {
    // var ctx = Context{ .user_id = 1234 };

    // Create an ArrayList to store handlers dynamically
    const allocator = std.heap.page_allocator;
    var handler_list = std.ArrayList(HandlerStruct).init(allocator);

    // Add handlers to the list
    try handler_list.append(HandlerStruct{ .handler = createCounter });

    // Convert the ArrayList to a slice and pass it to another function
    // const handler_slice = handler_list.toOwnedSlice();
    // executeHandlers(handler_list, &ctx);

    // Free the memory used by the ArrayList
    handler_list.deinit();
}
