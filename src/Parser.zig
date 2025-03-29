const std = @import("std");

const ast = @import("ast.zig");
const Statement = ast.Statement;
const Program = ast.Program;
const Expression = ast.Expression;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Parser = struct {
    const Self = @This();
    const Precedence = enum(u3) {
        LOWEST = 1,
        EQUALS,
        LESSGREATER,
        SUM,
        PRODUCT,
        PREFIX,
        CALL,
    };
    pub const Problem = union(enum) {
        unexpected_token: UnexpectedToken,
        const UnexpectedToken = struct { expected: TokenType, got: TokenType };
    };
    lexer: *Lexer,
    currentToken: Token,
    peekToken: Token,
    problems: std.ArrayList(Problem),
    program: Program,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Self {
        const parser = Self{
            .lexer = lexer,
            .currentToken = lexer.nextToken(),
            .peekToken = lexer.nextToken(),
            .problems = std.ArrayList(Problem).init(allocator),
            .program = Program.init(allocator),
        };

        return parser;
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

    // === PARSING ===

    /// Iterate over tokens from the lexer to construct a program
    pub fn parseProgram(self: *Self) !Program {
        while (!self.currentTokenIs(.eof)) {
            if (self.parseStatement()) |statement| {
                try self.program.statements.append(statement);
            } else |_| {}

            self.nextToken();
        }

        return self.program;
    }

    /// Attempt to parse a statement
    fn parseStatement(self: *Self) !Statement {
        switch (self.currentToken.type) {
            .let => {
                return Statement{ .let = try self.parseLetStatement() };
            },
            ._return => {
                return Statement{ ._return = try self.parseReturnStatement() };
            },
            else => {
                return Statement{ .expression = try self.parseExpressionStatement() };
            },
        }
    }

    /// Attempt to parse a let statement
    fn parseLetStatement(self: *Self) !Statement.Let {
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

        return Statement.Let{
            .token = letToken,
            .ident = ident,
            .value = null,
        };
    }

    /// Attempt to parse a return statement
    fn parseReturnStatement(self: *Self) !Statement.Return {
        const returnToken = self.currentToken;

        self.nextToken();

        // TODO: Parse expression
        while (!self.currentTokenIs(.semicolon)) {
            self.nextToken();
        }

        return Statement.Return{
            .token = returnToken,
            .value = null,
        };
    }

    /// Attempt to parse an expression statement
    fn parseExpressionStatement(self: *Self) !Statement.Expr {
        const exprToken = self.currentToken;
        const expression = try self.parseExpression(.LOWEST);

        if (self.peekTokenIs(.semicolon)) {
            self.nextToken();
        }

        return Statement.Expr{
            .token = exprToken,
            .expression = expression,
        };
    }

    // Expression parsing

    /// Attempt to parse an expression
    fn parseExpression(self: *Self, precedence: Precedence) !Expression {
        _ = precedence;

        if (prefixParseFn(self.currentToken.type)) |parseFn| {
            const leftExp = parseFn(self);
            return leftExp;
        } else return error.ParseFnNotFound;
    }

    /// Get the prefix parse function for a given token type
    fn prefixParseFn(tokenType: TokenType) ?(*const fn (*Self) Expression) {
        return switch (tokenType) {
            .ident => &Self.parseIdentifier,
            else => null,
        };
    }

    const InfixParseFn = fn (self: *Self, left: Expression) Expression;

    fn parseIdentifier(self: *Self) Expression {
        return .{ .ident = .{
            .token = self.currentToken,
            .value = self.currentToken.literal,
        } };
    }
};

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
    var parser_1 = Parser.init(&lexer_1, allocator);
    const program_1 = try parser_1.parseProgram();

    try expect(parser_1.problems.items.len == 0);
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
    var parser_2 = Parser.init(&lexer_2, allocator);
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

test "return statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const expect = std.testing.expect;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const input_1 =
        \\return 5;
        \\return 10;
        \\return 998877;
    ;
    var lexer_1 = Lexer.init(input_1);
    var parser_1 = Parser.init(&lexer_1, allocator);
    const program_1 = try parser_1.parseProgram();

    try expect(parser_1.problems.items.len == 0);
    try expect(program_1.statements.items.len == 3);

    for (program_1.statements.items) |statement| {
        try expect(std.meta.activeTag(statement) == ._return);
        try expectEqualStrings("return", statement.tokenLiteral());
    }
}

test "parse identifier" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const expect = std.testing.expect;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const input = "foobar;";

    var lexer = Lexer.init(input);
    var parser = Parser.init(&lexer, allocator);
    const program = try parser.parseProgram();

    try expect(parser.problems.items.len == 0);
    try expect(program.statements.items.len == 1);

    for (program.statements.items) |statement| {
        try expect(std.meta.activeTag(statement) == .expression);
        try expectEqualStrings("foobar", statement.tokenLiteral());
    }
}
