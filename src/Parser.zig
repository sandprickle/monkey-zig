const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ast = @import("ast.zig");
const Statement = ast.Statement;
const Program = ast.Program;
const LetStatement = ast.LetStatement;

const Self = @This();

lexer: *Lexer,
currentToken: Token,
peekToken: Token,
allocator: std.mem.Allocator,
problems: std.ArrayList(Problem),

pub const Problem = union(enum) {
    unexpected_token: UnexpectedToken,

    const UnexpectedToken = struct { expected: TokenType, got: TokenType };
};

pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Self {
    return Self{
        .lexer = lexer,
        .currentToken = lexer.nextToken(),
        .peekToken = lexer.nextToken(),
        .allocator = allocator,
        .problems = std.ArrayList(Problem).init(allocator),
    };
}

pub fn parseProgram(self: *Self) !Program {
    var statements = std.ArrayList(Statement).init(self.allocator);

    while (!self.currentTokenIs(.eof)) {
        if (self.parseStatement()) |statement| {
            try statements.append(statement);
        }
        self.nextToken();
    }

    return Program{
        .statements = statements,
    };
}

fn nextToken(self: *Self) void {
    self.currentToken = self.peekToken;
    self.peekToken = self.lexer.nextToken();
}

fn expectPeek(self: *Self, tokenType: TokenType) !void {
    if (self.peekTokenIs(tokenType)) {
        self.nextToken();
        return;
    }
    try self.problems.append(.{ .unexpected_token = .{
        .expected = tokenType,
        .got = self.peekToken.type,
    } });
    return error.UnexpectedToken;
}

fn currentTokenIs(self: *Self, tokenType: TokenType) bool {
    return self.currentToken.type == tokenType;
}

fn peekTokenIs(self: *Self, tokenType: TokenType) bool {
    return self.peekToken.type == tokenType;
}

fn parseStatement(self: *Self) ?Statement {
    switch (self.currentToken.type) {
        .let => {
            if (self.parseLetStatement()) |let_statement| {
                return Statement{ .let = let_statement };
            } else |_| return null;
        },
        else => return null,
    }
}

fn parseLetStatement(self: *Self) !LetStatement {
    const letToken = self.currentToken;

    try self.expectPeek(.ident);

    const ident = ast.Identifier{
        .token = self.currentToken,
        .value = self.currentToken.literal,
    };

    try self.expectPeek(.assign);

    self.nextToken();

    // TODO: Parse expression
    while (!self.currentTokenIs(.semicolon)) {
        self.nextToken();
    }

    return LetStatement{
        .token = letToken,
        .ident = ident,
        .value = null,
    };
}

test "let statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const expect = std.testing.expect;
    const expectEqualStrings = std.testing.expectEqualStrings;

    // Valid input
    const input_1 =
        \\let x = 5;
        \\let y = 10;
        \\let foobar = 838383;
    ;
    var lexer_1 = Lexer.init(input_1);
    var parser_1 = Self.init(&lexer_1, allocator);
    const program_1 = try parser_1.parseProgram();

    try expect(program_1.statements.items.len == 3);

    const expected_idents_1 = [_][]const u8{
        "x",
        "y",
        "foobar",
    };

    for (expected_idents_1, 0..) |_, i| {
        const s = program_1.statements.items[i];
        try expectEqualStrings("let", s.tokenLiteral());
        // try expect(@TypeOf(s.let.ident) == ast.Identifier);
        // try expectEqualStrings(name, s.let.ident.value);
    }

    // Invalid input
    const input_2 =
        \\let x 5;
        \\let = 10;
        \\let 838383;
    ;

    var lexer_2 = Lexer.init(input_2);
    var parser_2 = Self.init(&lexer_2, allocator);
    const program_2 = try parser_2.parseProgram();

    try expect(parser_2.problems.items.len == 3);
    try expect(program_2.statements.items.len == 0);

    for (parser_2.problems.items) |problem| {
        switch (problem) {
            .unexpected_token => |ut| {
                std.debug.print("Unexpected token: expected {}, got {}\n", .{
                    ut.expected,
                    ut.got,
                });
            },
        }
    }
}
