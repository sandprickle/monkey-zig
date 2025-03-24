const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ast = @import("ast.zig");
const Statement = ast.Statement;
const Program = ast.Program;
const LetStatement = ast.LetStatement;
const ReturnStatement = ast.ReturnStatement;
const Expression = ast.Expression;
const ExpressionStatement = ast.ExpressionStatement;

pub const Parser = struct {
    const Self = @This();
    const PrefixParseFn = fn (self: *Self) Expression;
    const InfixParseFn = fn (self: *Self, left: Expression) Expression;
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
    prefixParseFns: std.HashMap(TokenType, PrefixParseFn),
    infixParseFns: std.HashMap(TokenType, InfixParseFn),

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Self {
        const parser = Self{
            .lexer = lexer,
            .currentToken = lexer.nextToken(),
            .peekToken = lexer.nextToken(),
            .problems = std.ArrayList(Problem).init(allocator),
            .program = Program.init(allocator),
            .prefixParseFns = std.HashMap(TokenType, PrefixParseFn).init(allocator),
            .infixParseFns = std.HashMap(TokenType, InfixParseFn).init(allocator),
        };

        parser.registerPrefix(.ident, parser.parseIdentifier);

        return parser;
    }

    pub fn parseProgram(self: *Self) !Program {
        while (!self.currentTokenIs(.eof)) {
            if (self.parseStatement()) |statement| {
                try self.program.statements.append(statement);
            } else |_| {}

            self.nextToken();
        }

        return self.program;
    }

    fn registerPrefix(self: *Self, tokenType: TokenType, parseFn: PrefixParseFn) void {
        try self.prefixParseFns.put(tokenType, parseFn);
    }

    fn registerInfix(self: *Self, tokenType: TokenType, parseFn: InfixParseFn) void {
        try self.infixParseFns.put(tokenType, parseFn);
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

    fn parseStatement(self: *Self) !Statement {
        switch (self.currentToken.type) {
            .let => {
                return Statement{ .let = try self.parseLetStatement() };
            },
            ._return => {
                return Statement{ ._return = try self.parseReturnStatement() };
            },
            .expression => {
                return Statement{ .expression = try self.parseExpressionStatement() };
            },
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

    fn parseReturnStatement(self: *Self) !ReturnStatement {
        const returnToken = self.currentToken;

        self.nextToken();

        // TODO: Parse expression
        while (!self.currentTokenIs(.semicolon)) {
            self.nextToken();
        }

        return ReturnStatement{
            .token = returnToken,
            .value = null,
        };
    }

    fn parseExpressionStatement(self: *Self) !ExpressionStatement {
        const exprToken = self.currentToken;
        const expression = self.parseExpression(.LOWEST);

        if (self.peekTokenIs(.semicolon)) {
            self.nextToken();
        }

        return ExpressionStatement{
            .token = exprToken,
            .expression = expression,
        };
    }

    fn parseExpression(self: *Self, precedence: Precedence) !Expression {
        _ = precedence;

        const prefixFn = self.prefixParseFns.get(
            self.currentToken.type,
        );

        if (prefixFn) |prefix| {
            const leftExp = prefix(&self);
            return leftExp;
        } else return error.ParseFnNotFound;
    }

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
