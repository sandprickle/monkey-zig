const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const token = @import("token.zig");

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
            _ = Parser.init(&lex, allocator);

            var currentToken = lex.nextToken();
            while (currentToken.type != .eof) {
                try out.print("{any}\n", .{currentToken});
                currentToken = lex.nextToken();
            }
        }
    }
}
