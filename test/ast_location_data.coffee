testExpression = expressionAstMatchesObject

test "AST location data as expected for NumberLiteral node", ->
  testExpression '42',
    type: 'NumericLiteral'
    start: 0
    end: 2
    range: [0, 2]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 2

test "AST location data as expected for InfinityLiteral node", ->
  testExpression 'Infinity',
    type: 'Identifier'
    start: 0
    end: 8
    range: [0, 8]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 8

test "AST location data as expected for NaNLiteral node", ->
  testExpression 'NaN',
    type: 'Identifier'
    start: 0
    end: 3
    range: [0, 3]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 3

test "AST location data as expected for IdentifierLiteral node", ->
  testExpression 'id',
    type: 'Identifier'
    start: 0
    end: 2
    range: [0, 2]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 2

test "AST location data as expected for StatementLiteral node", ->
  testExpression 'break',
    type: 'BreakStatement'
    start: 0
    end: 5
    range: [0, 5]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 5

  testExpression 'continue',
    type: 'ContinueStatement'
    start: 0
    end: 8
    range: [0, 8]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 8

  testExpression 'debugger',
    type: 'DebuggerStatement'
    start: 0
    end: 8
    range: [0, 8]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 8

test "AST location data as expected for ThisLiteral node", ->
  testExpression 'this',
    type: 'ThisExpression'
    start: 0
    end: 4
    range: [0, 4]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 4

test "AST location data as expected for UndefinedLiteral node", ->
  testExpression 'undefined',
    type: 'Identifier'
    start: 0
    end: 9
    range: [0, 9]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 9

test "AST location data as expected for NullLiteral node", ->
  testExpression 'null',
    type: 'NullLiteral'
    start: 0
    end: 4
    range: [0, 4]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 4

test "AST location data as expected for BooleanLiteral node", ->
  testExpression 'true',
    type: 'BooleanLiteral'
    start: 0
    end: 4
    range: [0, 4]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 4

test "AST location data as expected for Access node", ->
  testExpression 'obj.prop',
    type: 'MemberExpression'
    object:
      start: 0
      end: 3
      range: [0, 3]
      loc:
        start:
          line: 1
          column: 0
        end:
          line: 1
          column: 3
    property:
      start: 4
      end: 8
      range: [4, 8]
      loc:
        start:
          line: 1
          column: 4
        end:
          line: 1
          column: 8
    start: 0
    end: 8
    range: [0, 8]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 8

  testExpression 'a::b',
    type: 'MemberExpression'
    object:
      object:
        start: 0
        end: 1
        range: [0, 1]
        loc:
          start:
            line: 1
            column: 0
          end:
            line: 1
            column: 1
      property:
        start: 1
        end: 3
        range: [1, 3]
        loc:
          start:
            line: 1
            column: 1
          end:
            line: 1
            column: 3
    property:
      start: 3
      end: 4
      range: [3, 4]
      loc:
        start:
          line: 1
          column: 3
        end:
          line: 1
          column: 4
    start: 0
    end: 4
    range: [0, 4]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 4

  testExpression '''
    (
      obj
    ).prop
  ''',
    type: 'MemberExpression'
    object:
      start: 4
      end: 7
      range: [4, 7]
      loc:
        start:
          line: 2
          column: 2
        end:
          line: 2
          column: 5
    property:
      start: 10
      end: 14
      range: [10, 14]
      loc:
        start:
          line: 3
          column: 2
        end:
          line: 3
          column: 6
    start: 0
    end: 14
    range: [0, 14]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 3
        column: 6

test "AST location data as expected for Index node", ->
  testExpression 'a[b]',
    type: 'MemberExpression'
    object:
      start: 0
      end: 1
      range: [0, 1]
      loc:
        start:
          line: 1
          column: 0
        end:
          line: 1
          column: 1
    property:
      start: 2
      end: 3
      range: [2, 3]
      loc:
        start:
          line: 1
          column: 2
        end:
          line: 1
          column: 3
    start: 0
    end: 4
    range: [0, 4]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 4

  testExpression 'a?[b][3]',
    type: 'MemberExpression'
    object:
      object:
        start: 0
        end: 1
        range: [0, 1]
        loc:
          start:
            line: 1
            column: 0
          end:
            line: 1
            column: 1
      property:
        start: 3
        end: 4
        range: [3, 4]
        loc:
          start:
            line: 1
            column: 3
          end:
            line: 1
            column: 4
      start: 0
      end: 5
      range: [0, 5]
      loc:
        start:
          line: 1
          column: 0
        end:
          line: 1
          column: 5
    property:
      start: 6
      end: 7
      range: [6, 7]
      loc:
        start:
          line: 1
          column: 6
        end:
          line: 1
          column: 7
    start: 0
    end: 8
    range: [0, 8]
    loc:
      start:
        line: 1
        column: 0
      end:
        line: 1
        column: 8
