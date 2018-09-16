# This file contains the common helper functions that we'd like to share among
# the **Lexer**, **Rewriter**, and the **Nodes**. Merge objects, flatten
# arrays, count characters, that sort of thing.

# Peek at the beginning of a given string to see if it matches a sequence.
exports.starts = (string, literal, start) ->
  literal is string.substr start, literal.length

# Peek at the end of a given string to see if it matches a sequence.
exports.ends = (string, literal, back) ->
  len = literal.length
  literal is string.substr string.length - len - (back or 0), len

# Repeat a string `n` times.
exports.repeat = repeat = (str, n) ->
  # Use clever algorithm to have O(log(n)) string concatenation operations.
  res = ''
  while n > 0
    res += str if n & 1
    n >>>= 1
    str += str
  res

# Trim out all falsy values from an array.
exports.compact = (array) ->
  item for item in array when item

# Count the number of occurrences of a string in a string.
exports.count = (string, substr) ->
  num = pos = 0
  return 1/0 unless substr.length
  num++ while pos = 1 + string.indexOf substr, pos
  num

# Merge objects, returning a fresh copy with attributes from both sides.
# Used every time `Base#compile` is called, to allow properties in the
# options hash to propagate down the tree without polluting other branches.
exports.merge = (options, overrides) ->
  extend (extend {}, options), overrides

# Extend a source object with the properties of another object (shallow copy).
extend = exports.extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

# Return a flattened version of an array.
# Handy for getting a list of `children` from the nodes.
exports.flatten = flatten = (array) ->
  flattened = []
  for element in array
    if '[object Array]' is Object::toString.call element
      flattened = flattened.concat flatten element
    else
      flattened.push element
  flattened

# Delete a key from an object, returning the value. Useful when a node is
# looking for a particular method in an options hash.
exports.del = (obj, key) ->
  val =  obj[key]
  delete obj[key]
  val

# Typical Array::some
exports.some = Array::some ? (fn) ->
  return true for e in this when fn e
  false

# Helper function for extracting code from Literate CoffeeScript by stripping
# out all non-code blocks, producing a string of CoffeeScript code that can
# be compiled “normally.”
exports.invertLiterate = (code) ->
  out = []
  blankLine = /^\s*$/
  indented = /^[\t ]/
  listItemStart = /// ^
    (?:\t?|\ {0,3})   # Up to one tab, or up to three spaces, or neither;
    (?:
      [\*\-\+] |      # followed by `*`, `-` or `+`;
      [0-9]{1,9}\.    # or by an integer up to 9 digits long, followed by a period;
    )
    [\ \t]            # followed by a space or a tab.
  ///
  insideComment = no
  for line in code.split('\n')
    if blankLine.test(line)
      insideComment = no
      out.push line
    else if insideComment or listItemStart.test(line)
      insideComment = yes
      out.push "# #{line}"
    else if not insideComment and indented.test(line)
      out.push line
    else
      insideComment = yes
      out.push "# #{line}"
  out.join '\n'

# Merge two jison-style location data objects together.
# If `last` is not provided, this will simply return `first`.
buildLocationData = (first, last) ->
  if not last
    first
  else
    first_line: first.first_line
    first_column: first.first_column
    last_line: last.last_line
    last_column: last.last_column
    range: [
      first.range[0]
      last.range[1]
    ]

buildLocationHash = (loc) ->
  "#{loc.first_line}x#{loc.first_column}-#{loc.last_line}x#{loc.last_column}"

# Build a dictionary of extra token properties organized by tokens’ locations
# used as lookup hashes.
buildTokenDataDictionary = (parserState) ->
  tokenData = {}
  for token in parserState.parser.tokens when token.comments
    tokenHash = buildLocationHash token[2]
    # Multiple tokens might have the same location hash, such as the generated
    # `JS` tokens added at the start or end of the token stream to hold
    # comments that start or end a file.
    tokenData[tokenHash] ?= {}
    if token.comments # `comments` is always an array.
      # For “overlapping” tokens, that is tokens with the same location data
      # and therefore matching `tokenHash`es, merge the comments from both/all
      # tokens together into one array, even if there are duplicate comments;
      # they will get sorted out later.
      (tokenData[tokenHash].comments ?= []).push token.comments...
  tokenData

# This returns a function which takes an object as a parameter, and if that
# object is an AST node, updates that object's locationData.
# The object is returned either way.
exports.addDataToNode = (parserState, first, last, {forceUpdateLocation} = {}) ->
  (obj) ->
    # Add location data.
    if first?
      if obj?.updateLocationDataIfMissing?
        obj.updateLocationDataIfMissing buildLocationData(first, last), force: forceUpdateLocation

    # Add comments, building the dictionary of token data if it hasn’t been
    # built yet.
    parserState.tokenData ?= buildTokenDataDictionary parserState
    if obj.locationData?
      objHash = buildLocationHash obj.locationData
      if parserState.tokenData[objHash]?.comments?
        attachCommentsToNode parserState.tokenData[objHash].comments, obj
    obj

isToken = (obj) ->
  ("2" of obj) and ("first_line" of obj[2])

expandLocationDataToInclude = (existing, addtl) ->
  return unless existing and addtl
  {range: [start, end], first_line, first_column, last_line, last_column} = existing
  if addtl.range[0] < start
    existing.range[0] = addtl.range[0]
    existing.first_line = addtl.first_line
    existing.first_column = addtl.first_column
  if addtl.range[1] > end
    existing.range[1] = addtl.range[1]
    existing.last_line = addtl.last_line
    existing.last_column = addtl.last_column

exports.attachCommentsToNode = attachCommentsToNode = (comments, node) ->
  return if not comments? or comments.length is 0
  node.comments ?= []
  _isToken = isToken(node)
  for comment in comments
    # expandLocationDataToInclude node[2], comment.locationData if _isToken
    node.comments.push comment

# Convert jison location data to a string.
# `obj` can be a token, or a locationData.
exports.locationDataToString = (obj) ->
  if isToken(obj) then locationData = obj[2]
  else if "first_line" of obj then locationData = obj

  if locationData
    "#{locationData.first_line + 1}:#{locationData.first_column + 1}-" +
    "#{locationData.last_line + 1}:#{locationData.last_column + 1}"
  else
    "No location data"

# A `.coffee.md` compatible version of `basename`, that returns the file sans-extension.
exports.baseFileName = (file, stripExt = no, useWinPathSep = no) ->
  pathSep = if useWinPathSep then /\\|\// else /\//
  parts = file.split(pathSep)
  file = parts[parts.length - 1]
  return file unless stripExt and file.indexOf('.') >= 0
  parts = file.split('.')
  parts.pop()
  parts.pop() if parts[parts.length - 1] is 'coffee' and parts.length > 1
  parts.join('.')

# Determine if a filename represents a CoffeeScript file.
exports.isCoffee = (file) -> /\.((lit)?coffee|coffee\.md)$/.test file

# Determine if a filename represents a Literate CoffeeScript file.
exports.isLiterate = (file) -> /\.(litcoffee|coffee\.md)$/.test file

# Throws a SyntaxError from a given location.
# The error's `toString` will return an error message following the "standard"
# format `<filename>:<line>:<col>: <message>` plus the line with the error and a
# marker showing where the error is.
exports.throwSyntaxError = (message, location) ->
  error = new SyntaxError message
  error.location = location
  error.toString = syntaxErrorToString

  # Instead of showing the compiler's stacktrace, show our custom error message
  # (this is useful when the error bubbles up in Node.js applications that
  # compile CoffeeScript for example).
  error.stack = error.toString()

  throw error

# Update a compiler SyntaxError with source code information if it didn't have
# it already.
exports.updateSyntaxError = (error, code, filename) ->
  # Avoid screwing up the `stack` property of other errors (i.e. possible bugs).
  if error.toString is syntaxErrorToString
    error.code or= code
    error.filename or= filename
    error.stack = error.toString()
  error

syntaxErrorToString = ->
  return Error::toString.call @ unless @code and @location

  {first_line, first_column, last_line, last_column} = @location
  last_line ?= first_line
  last_column ?= first_column

  filename = @filename or '[stdin]'
  codeLine = @code.split('\n')[first_line]
  start    = first_column
  # Show only the first line on multi-line errors.
  end      = if first_line is last_line then last_column + 1 else codeLine.length
  marker   = codeLine[...start].replace(/[^\s]/g, ' ') + repeat('^', end - start)

  # Check to see if we're running on a color-enabled TTY.
  if process?
    colorsEnabled = process.stdout?.isTTY and not process.env?.NODE_DISABLE_COLORS

  if @colorful ? colorsEnabled
    colorize = (str) -> "\x1B[1;31m#{str}\x1B[0m"
    codeLine = codeLine[...start] + colorize(codeLine[start...end]) + codeLine[end..]
    marker   = colorize marker

  """
    #{filename}:#{first_line + 1}:#{first_column + 1}: error: #{@message}
    #{codeLine}
    #{marker}
  """

exports.nameWhitespaceCharacter = (string) ->
  switch string
    when ' ' then 'space'
    when '\n' then 'newline'
    when '\r' then 'carriage return'
    when '\t' then 'tab'
    else string

exports.locationDataToAst = ({first_line, first_column, last_line, last_column, range}) ->
  loc:
    start:
      line: first_line + 1
      column: first_column
    end:
      line: last_line + 1
      column: last_column + 1
  range: [
    range[0]
    range[1]
  ]
  start: range[0]
  end: range[1]

exports.astLocationFields = locationFields = ['loc', 'range', 'start', 'end']

# Extends the location data of an AST node to include the location data from
# another AST node.
exports.mergeAstLocationData = mergeAstLocationData = (intoNode, fromNode, {justLeading, justEnding} = {}) ->
  if Array.isArray fromNode
    mergeAstLocationData intoNode, fromItem for fromItem in fromNode
    return intoNode
  {range: intoRange} = intoNode
  {range: fromRange} = fromNode
  return intoNode unless intoRange and fromRange
  unless justEnding
    if fromRange[0] < intoRange[0]
      intoNode.range = intoRange = [
        fromRange[0]
        intoRange[1]
      ]
      intoNode.start = fromNode.start
      intoNode.loc =
        start: fromNode.loc.start
        end: intoNode.loc.end
  unless justLeading
    if fromRange[1] > intoRange[1]
      intoNode.range = [
        intoRange[0]
        fromRange[1]
      ]
      intoNode.end = fromNode.end
      intoNode.loc =
        start: intoNode.loc.start
        end: fromNode.loc.end
  intoNode

exports.isFunction = isFunction = (obj) -> Object::toString.call(obj) is '[object Function]'
exports.isNumber = isNumber = (obj) -> Object::toString.call(obj) is '[object Number]'
exports.isString = isString = (obj) -> Object::toString.call(obj) is '[object String]'
exports.isBoolean = isBoolean = (obj) -> obj is yes or obj is no or Object::toString.call(obj) is '[object Boolean]'
exports.isPlainObject = isPlainObject = (obj) -> typeof obj is 'object' and !!obj and not Array.isArray(obj) and not isNumber(obj) and not isString(obj) and not isBoolean(obj)

# Converts a string to its corresponding number value.
exports.parseNumber = parseNumber = (str) ->
  base = switch str.charAt 1
    when 'b' then 2
    when 'o' then 8
    when 'x' then 16
    else null

  if base? then parseInt(str[2..], base) else parseFloat(str)

# Converts a number, string, or node (Value/NumberLiteral/unary +/- Op) to its
# corresponding number value.
exports.getNumberValue = getNumberValue = (number) ->
  switch
    when isNumber number
      number
    when isString number
      parseNumber number
    else
      number = number.unwrap()
      return number.parsedValue if number.parsedValue?
      invert = no
      val = getNumberValue(
        if number.operator
          invert = yes if number.operator is '-'
          number.first
        else
          number.value
      )
      if invert then val * -1 else val

exports.dump = dump = (args..., obj) ->
  util = require 'util'
  console.log args..., util.inspect obj, no, null

exports.mergeLocationData = (intoNode, fromNode) ->
  {locationData: intoLocationData} = intoNode
  {locationData: fromLocationData} = fromNode
  unless intoLocationData
    intoNode.locationData = fromLocationData
    return intoNode
  {range: intoRange} = intoLocationData
  {range: fromRange} = fromLocationData
  return intoNode unless intoRange and fromRange # TODO: should figure out why don't have location data?
  if fromRange[0] < intoRange[0]
    intoLocationData = intoNode.locationData = {...intoLocationData}
    intoLocationData.range = [fromRange[0], intoRange[1]]
    intoLocationData.first_line = fromLocationData.first_line
    intoLocationData.first_column = fromLocationData.first_column
  if fromRange[1] > intoRange[1]
    intoLocationData = intoNode.locationData = {...intoLocationData}
    intoLocationData.range = [intoRange[0], fromRange[1]]
    intoLocationData.last_line = fromLocationData.last_line
    intoLocationData.last_column = fromLocationData.last_column
  intoNode

exports.assignEmptyTrailingLocationData = (intoNode, fromNode) ->
  {locationData: fromLocationData} = fromNode
  {range: fromRange} = fromLocationData
  intoNode.locationData =
    range: [fromRange[1] + 1, fromRange[1]]
    first_line: fromLocationData.last_line
    first_column: fromLocationData.last_column + 1 # TODO: refine?
    last_line: fromLocationData.last_line
    last_column: fromLocationData.last_column + 1
  intoNode

exports.mapValues = (obj, fn) ->
  Object.keys(obj).reduce (result, key) ->
    result[key] = fn obj[key], key
    result
  , {}

exports.traverseBabylonAst = traverseBabylonAst = (node, func, {skipSelf, skip, parent, key} = {}) ->
  # if skipSelf
  #   skip = [node]
  #   if skipSelf.and
  #     skip.push skipSelf.and...
  if Array.isArray node
    indexesToRemove = []
    for item, index in node
      ret = traverseBabylonAst item, func, {skip, parent, key}
      indexesToRemove.unshift index if ret is 'REMOVE'
    node.splice index, 1 for index in indexesToRemove
    return
  ret = func node, {skip, parent, key} if node? and not (skip and node in skip)
  return if ret is 'STOP'
  if isPlainObject node
    for own _key, child of node when _key not in locationFields
      childRet = traverseBabylonAst child, func, {skip, parent: node, key: _key}
      node[_key] = null if childRet is 'REMOVE'
  ret
exports.traverseBabylonAsts = traverseBabylonAsts = (node, correspondingNode, func) ->
  if Array.isArray node
    return unless Array.isArray correspondingNode
    return (traverseBabylonAsts(item, correspondingNode[index], func) for item, index in node)
  func node, correspondingNode
  if isPlainObject node
    return unless isPlainObject correspondingNode
    traverseBabylonAsts(child, correspondingNode[key], func) for own key, child of node when key not in locationFields

# Constructs a string or regex by escaping certain characters.
exports.makeDelimitedLiteral = (body, options = {}) ->
  body = '(?:)' if body is '' and options.delimiter is '/'
  regex =
    if options.justEscapeDelimiter
      ///
          \\?(#{options.delimiter})            # (Possibly escaped) delimiter.
      ///g
    else
      ///
          (\\\\)                               # Escaped backslash.
        | (\\0(?=[1-7]))                       # Null character mistaken as octal escape.
        | \\?(#{options.delimiter})            # (Possibly escaped) delimiter.
        | \\?(?: (\n)|(\r)|(\u2028)|(\u2029) ) # (Possibly escaped) newlines.
        | (\\.)                                # Other escapes.
      ///g
  body = body.replace regex, (args...) ->
    if options.justEscapeDelimiter
      [match, delimiter] = args
    else
      [match, backslash, nul, delimiter, lf, cr, ls, ps, other] = args
    switch
      # Ignore escaped backslashes.
      when backslash then (if options.double then backslash + backslash else backslash)
      when nul       then '\\x00'
      when delimiter then "\\#{delimiter}"
      when lf        then '\\n'
      when cr        then '\\r'
      when ls        then '\\u2028'
      when ps        then '\\u2029'
      when other     then (if options.double then "\\#{other}" else other)
  "#{options.delimiter}#{body}#{options.delimiter}"

unicodeCodePointToUnicodeEscapes = (codePoint) ->
  toUnicodeEscape = (val) ->
    str = val.toString 16
    "\\u#{repeat '0', 4 - str.length}#{str}"
  return toUnicodeEscape(codePoint) if codePoint < 0x10000
  # surrogate pair
  high = Math.floor((codePoint - 0x10000) / 0x400) + 0xD800
  low = (codePoint - 0x10000) % 0x400 + 0xDC00
  "#{toUnicodeEscape(high)}#{toUnicodeEscape(low)}"

# Replace `\u{...}` with `\uxxxx[\uxxxx]` in regexes without `u` flag
exports.replaceUnicodeCodePointEscapes = (str, {flags, error, delimiter = ''} = {}) ->
  shouldReplace = flags? and 'u' not in flags
  str.replace UNICODE_CODE_POINT_ESCAPE, (match, escapedBackslash, codePointHex, offset) ->
    return escapedBackslash if escapedBackslash

    codePointDecimal = parseInt codePointHex, 16
    if codePointDecimal > 0x10ffff
      error "unicode code point escapes greater than \\u{10ffff} are not allowed",
        offset: offset + delimiter.length
        length: codePointHex.length + 4
    return match unless shouldReplace

    unicodeCodePointToUnicodeEscapes codePointDecimal

UNICODE_CODE_POINT_ESCAPE = ///
  ( \\\\ )        # Make sure the escape isn’t escaped.
  |
  \\u\{ ( [\da-fA-F]+ ) \}
///g
