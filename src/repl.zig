const Lexer = @import("lexer.zig").Lexer;
const token = @import("token.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const PROMPT = ">> ";

pub fn start(
    in: std.fs.File.Reader,
    out: std.fs.File.Writer,
    allocator: Allocator,
) !void {
    while (true) {
        _ = try out.writeAll(PROMPT);
        const input = try in.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024);
        if (input) |line| {
            var lex = Lexer.init(line);

            var currentToken = lex.nextToken();
            while (currentToken.type != .eof) {
                try out.print("{any}\n", .{currentToken});
                currentToken = lex.nextToken();
            }
        }
    }
}
