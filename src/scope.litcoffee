The **Scope** class regulates lexical scoping within CoffeeScript. As you
generate code, you create a tree of scopes in the same shape as the nested
function bodies. Each scope knows about the variables declared within it,
and has a reference to its parent enclosing scope. In this way, we know which
variables are new and need to be declared with `var`, and which are shared
with external scopes.

    exports.Scope = class Scope

Initialize a scope with its parent, for lookups up the chain,
as well as a reference to the **Block** node it belongs to, which is
where it should declare its variables, a reference to the function that
it belongs to, and a list of variables referenced in the source code
and therefore should be avoided when generating variables.

      constructor: (@parent, @expressions, @method, @referencedVars) ->
        @variables = [{name: 'arguments', type: 'arguments'}]
        @free_variables = []
        @positions = {}
        @free_positions = {}
        @utilities = {} unless @parent

The `@root` is the top-level **Scope** object for a given file.

        @root = @parent?.root ? this

Adds a new variable or overrides an existing one.

      add: (name, type, immediate) ->
        # console.log 'add', name
        name = name?.base?.value ? name?.name?.base?.value unless typeof name is 'string'
        name = name.substr space_index + 1 if space_index = name.indexOf ' $'
        name = name.substr 1 if '&' is name.substr( 0, 1 )
        return @parent.add name, type, immediate if @shared and not immediate
        if Object::hasOwnProperty.call @positions, name
          @variables[@positions[name]].type = type
        else
          @positions[name] = @variables.push({name, type}) - 1

      add_free: (name, type, immediate) ->
        # console.log 'add_free', name
        return @parent.add_free name, type, immediate if @shared and not immediate
        # @parent.add_free name, type, immediate if @parent
        if Object::hasOwnProperty.call @free_positions, name
          @free_variables[@free_positions[name]].type = type
        else
          @free_positions[name] = @free_variables.push({name, type}) - 1
        # console.log 'free_vars after add_free', @free_variables

When `super` is called, we need to find the name of the current method we're
in, so that we know how to invoke the same method of the parent class. This
can get complicated if super is being called from an inner function.
`namedMethod` will walk up the scope tree until it either finds the first
function object that has a name filled in, or bottoms out.

      namedMethod: ->
        return @method if @method?.name or !@parent
        @parent.namedMethod()

Look up a variable name in lexical scope, and declare it if it does not
already exist.

      find: (name) ->
        # console.log name
        if @check name
          @add_free name, 'var'
          return yes
        @add name, 'var'
        no

Reserve a variable name as originating from a function parameter for this
scope. No `var` required for internal references.

      parameter: (name) ->
        return if @shared and @parent.check name, yes
        @add name, 'param'

Just check to see if a variable has already been declared, without reserving,
walks up to the root scope.

      check: (name) ->
        !!(@type(name) or @parent?.check(name))

Generate a temporary variable name at the given index.

      temporary: (name, index, single=false) ->
        if single
          '$' + (index + parseInt name, 36).toString(36).replace /\d/g, 'a'
        else
          name + (index or '')

Gets the type of a variable.

      type: (name) ->
        return v.type for v in @variables when @isNamed v, name
        null
      isNamed: ( v, name ) ->
        return yes if v.name is name
        return no unless ( equalsPos=v.name.indexOf?( '=' )) > -1
        name is v.name.substr 0, equalsPos

If we need to store an intermediate result, find an available name for a
compiler-generated variable. `_var`, `_var2`, and so on...

      freeVariable: (name, options={}) ->
        index = 0
        loop
          temp = @temporary name, index, options.single
          break unless @check(temp) or temp in @root.referencedVars
          index++
        @add temp, 'var', yes if options.reserve ? true
        temp

Ensure that an assignment is made at the top of this scope
(or at the top-level scope, if requested).

      assign: (name, value) ->
        @add name, {value, assigned: yes}, yes
        @hasAssignments = yes

Does this scope have any declared variables?

      hasDeclarations: ->
        # console.log 'uses', do @uses
        # console.log 'free_vars', @free_variables
        # console.log 'vars', @variables
        !!@declaredVariables().length

      _uses: ->
        free_var for free_var in @free_variables when not @in_variables( free_var.name ) and not @special_or_global free_var.name
      uses: ->
        # console.log 'pos', @positions
        # console.log 'vars', @variables
        # console.log 'free vars', @free_variables
        free_var.name for free_var in do @_uses
      add_uses_to_parent_free_vars: ->
        return unless @parent

        @parent.add_free free_var.name, free_var.type for free_var in do @_uses
        
      in_variables: ( name ) ->
        name = name.substr 1 if name.substr( 0, 1 ) is '&'

        return yes if name of @positions
        for _var in @variables
          val = _var.name?.base?.value
          return no unless val
          return yes if val is name
          return yes if val.substr( 0, 1 ) is '&' and val.substr( 1 ) is name
        no
      special_or_global: ( name ) ->
        return yes if name is 'this'
        return yes if name is '$GLOBALS'
        no

Return the list of variables first declared in this scope.

      declaredVariables: ->
        (v.name for v in @variables when v.type is 'var').sort()

Return the list of assignments that are supposed to be made at the top
of this scope.

      assignedVariables: ->
        "#{v.name} = #{v.type.value}" for v in @variables when v.type.assigned

