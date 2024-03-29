---@meta

-- The `java` module provides a way to interact with Java classes and objects.
---@class java
java = {}

-- For a `jclass` `clazz`:
-- - `clazz.memberVar` performs the following in sequence:
--     1. It looks for a field named `memberVar`. It returns the public static member if it finds it.
--        - If you have an inner class also named `memberVar`, you would have to manually `java.import` it.
--     2. It then looks for an inner class named `memberVar`, and returns that if it is available.
--        - If you have a method also named `memberVar`, you need to use `java.method` to look that up.
--     4. Otherwise, it prepares for a method call. See `clazz:memberMethod(...)` below.
-- - `clazz.memberVar = value` assigns to the public static member. If exceptions occur, a Lua error is generated.
-- - `clazz:memberMethod(...)` calls the public static member method `memberMethod`. See [Proxied Method Calls](https://gudzpoz.github.io/luajava/api.html#proxied-method-calls) for more info.
-- - `class(...)`:
--   - For an interface, this expects a table as the parameter and creates a proxy for it. See [`java.proxy`](https://gudzpoz.github.io/luajava/api.html#proxy-jclass-table-function).
--   - Otherwise, it calls the corresponding constructor. See [`java.new`](https://gudzpoz.github.io/luajava/api.html#new-jclass-function).
-- - `clazz.class` returns a `jobject`, wrapping an instance of `java.lang.Class<clazz>`.
--
-- ::: tip
-- Don't confuse `jclass` with an instance of `java.lang.Class<?>`.
-- The former one corresponds to Java classes, i.e., `java.lang.String` in Java.
-- The latter one is just a `jobject`, i.e., `java.lang.String.class` in Java.
--
-- ::: tip There's more!
-- Actually, if you load the built-in `package` library (either by `Lua#openLibraries()` or `Lua#openLibrary("package")`),
-- you can use the Lua `require` functions to load Java side things.
--
-- See [Java-Side Modules](https://gudzpoz.github.io/luajava/examples/modules.html) for a brief introduction.
---@class jclass
jclass = {}

--For a `jobject` `object`:
--
-- - `object.memberVar` returns the public member named `memberVar`.
-- - `object.memberVar = value` assigns to the public static member. If exceptions occur, a Lua error is generated.
-- - `object:memberMethod(...)` calls the public member method `memberMethod`. See [Proxied Method Calls](https://gudzpoz.github.io/luajava/api.html#proxied-method-calls) for more info.
--
-- ::: example
-- ```lua
-- Integer = java.import('java.lang.Integer')
-- i = java.new(Integer, 1024)
-- -- Calling a method
-- print(i:toString())
-- ```
--
-- Since a Lua type maps to different Java types (for example, `lua_Number` may be mapped to any Java numerical type), we have to iterate through every method to find one matching Lua parameters. For each possible method, we try to convert the values on stack from Lua to Java. If such conversion is possible, the call is then proxied to this method and the remaining methods are never tried.
--
-- ::: warning
-- By the nature of this procedure, we do not prioritize any of the method.
--
-- For example, if you are calling `java.lang.Math.max`, which can be `Math.max(int, int)`, `Math.max(double, double)`, etc., then nobody knows which will ever get called.
-- :::
--
-- ::: warning
-- We do not support varargs. You will need to combine `java.method` and `java.array` to make that happen.
--
-- For `Object... object` however, things are easier:
--
-- ```lua
-- String = java.import('java.lang.String')
-- -- We automatically convert lua tables into Object[]
-- assert(String:format('>>> %s', { 'content' }) == '>>> content')
-- ```
---@class jobject
jobject = {}

-- For a `jarray` `array`:
--
-- - `array[i]` returns `array[i - 1]`. Unlike Lua tables, we raise Lua errors if the index goes out of bounds.
-- - `array[i] = value` assigns to `array[i - 1]`. If exceptions occur, a Lua error is generated.
-- - `array:memberMethod(...)` calls the public member method `memberMethod` (of `java.lang.Object` of course), for example, `array:getClass()`.
--
-- ::: tip
-- Lua tables usually start the index from 1, while Java arrays from 0.
---@class jarray
jarray = {}

-- Creates a Java array.
--
-- Generates a Lua error if types mismatch or some dimensions are negative.
--
-- ::: example
-- ```lua
-- int = java.import('int')
-- arr = java.array(int, 2, 16)
-- assert(#arr == 2)
-- assert(#arr[1] == 16)
-- ```
---@param jclass jclass|jobject The component type. One may pass a `jclass` or a `jobject` of `Class<?>`.
---@param dim1 number The size of the first dimension.
---@param ... number The size of the N-th dimension.
---@return jarray # An N-dimentional array with fixed sizes, `new "jclass"[dim1][dim2]...[dimN]`
function java.array(jclass, dim1, ...) end

-- Return the latest captured Java `java.lang.Throwable` during a Java method call.
---@return jobject|nil # A `java.lang.Throwable` if some recent Java method call threw, `nil` otherwise.
function java.catched() end

-- Detach the sub-thread from registry to allow for GC.
-- - Generates a Lua error if the thread is a main thread.
--
-- ::: danger Check before detaching
--
-- 1. Most often, you only want to use `java.detach` on threads created on the Lua side.
-- 2. You need to ensure that proxies created on that thread is no longer used.
-- 3. If you are not creating tons of sub-threads, you can worry less about GC
--    by letting `mainThread#close` handle it all instead of manually `detach`ing.
--
-- ::: details Thread interface explained
--
-- In LuaJava, an `AbstractLua` instance just wraps around a `lua_State *`.
-- We ensure that one `lua_State *` maps to no more than one `AbstractLua` instance
-- by assigning each state an ID when:
-- 1. a main state is created;
-- 2. or when a sub-thread is created on the Java side (with `Lua#newThread`);
-- 3. or when a sub-thread, created on the Lua side (with `coroutine.create`),
--    eventually requests for an ID if it finds it necessary.
--
-- IDs are stored both on:
--
-- - the Java side: IDs are stored in `AbstractLua` instances.
-- - and the Lua side: IDs are stored in the table at `LUA_REGISTRYINDEX`, *with the thread itself as the key*.
--
-- However, since we keep references to the thread in the `LUA_REGISTRYINDEX`, it prevents the thread from garbage collection
-- (which is intentional though, as you need threads alive for proxies).
--
-- If you are sure that neither the Java side (proxies, Java API, etc.) nor the Lua side uses the thread any more,
-- you may manually call `java.detach` or `Lua#close` to free the thread from the global registry.
---@param thread thread The thread (e.g., a return value of `coroutine.create`)
---@return nil
function java.detach(thread) end


-- Import a Java class or package.
-- - Generates a Lua error if class not found.
--
-- ::: example
-- ```lua
-- lang = java.import('java.lang.*')
-- print(lang.System:currentTimeMillis())
--
-- R = java.import('android.R.*')
-- print(R.id.input)
--
-- j = java.import('java.*.*')
-- print(j.lang.System:currentTimeMillis())
-- -- Both works
-- j = java.import('java.*')
-- print(j.lang.System:currentTimeMillis())
--
-- System = java.import('java.lang.System')
-- print(System:currentTimeMillis())
-- ```
---@param name string Either: The full name, including the package part, of the class. or Any string, appended with possibly multiple `.*`.
---@return jclass|table # If `name` is the name of a class, return a `jclass` of the class. If `name` is a string appended with `.*`, return a Lua table, which looks up classes directly under a package or inner classes inside a class when indexed.
function java.import(name) end


-- This function provides similar functionalities to Lua's `loadlib`. It looks for a method `static public int yourSuppliedMethodName(Lua L);` inside the class, and returns it as a C function.
--
-- You might also want to check out [Java-Side Modules](https://gudzpoz.github.io/luajava/examples/modules.html) to see how we use this function to extend the Lua `require`.
---@param classname string The class name.
---@param method string The method name. We expect the method to accept a single `Lua` parameter and return an integer.
---@return function|nil|string # If the method is found, we wrap it up with a C function wrapper and return it. If no valid method is found, we return `nil` plus a error message. Similar to `package.loadlib`, we do not generate a Lua error in this case.
function java.loadlib(classname, method) end


-- Converts a Java object into its Lua equivalence. It does a [`FULL` conversion](https://gudzpoz.github.io/luajava/conversions.html#java-to-lua). See [Type Conversions](https://gudzpoz.github.io/luajava/conversions.html) for more information.
---@param jobject jobject The object to get converted.
---@return boolean|integer|number|table|jclass # Depending on the Java type of `jobject`. Notably, it converts `Map<?, ?>` and `Collection<?>` to Lua tables, and `Class<?>` to `jclass`.
function java.luaify(jobject) end

-- Finds a method of the `jobject` or `jclass` matching the name and signature. See [Method Resolution](https://gudzpoz.github.io/luajava/api.html#method-resolution).
--
-- ::: example
-- ```lua
-- AtomicInteger = java.import('java.util.concurrent.atomic.AtomicInteger')
-- Constructor = java.method(AtomicInteger, 'new', 'int')
-- integer = Constructor(100)
-- compareAndSet = java.method(integer, 'compareAndSet', 'int,int')
-- compareAndSet(100, 200)
-- compareAndSet(200, 400)
-- assert(integer:get() == 400)
--
-- iter = java.proxy('java.util.Iterator', {
--   remove = function(this)
--     java.method(iter, 'java.util.Iterator:remove')()
--   end
-- })
-- -- iter:remove() -- This throws an exception
-- ```
--
-- To help with precisely calling a specific method, you may specify the signature of the method that you intend to call.
-- Take the above `java.lang.Math.max` as an example. You may call `Math.max(int, int)` with the following:
--
-- ```lua
-- Math = java.import('java.lang.Math')
-- max = java.method(Math, 'max', 'int,int')
-- assert(max(1.2, 2.3) == 2)
-- ```
--
-- You may call `Math.max(double, double)` with the following:
--
-- ```lua
-- Math = java.import('java.lang.Math')
-- max = java.method(Math, 'max', 'double,double')
-- assert(max(1.2, 2.3) == 2.3)
-- ```
--
-- If you would like to access an overridden default method from a proxy object,
-- you may also use 
--
-- ```lua
-- iter1 = java.proxy('java.util.Iterator', {})
-- -- Calls the default method
-- iter1:remove()
--
-- -- What if we want to access the default method from a overridden one?
-- iterImpl = {
--   remove = function(this)
--     -- Calls the default method from java.util.Iterator.
--     java.method(this, 'java.util.Iterator:remove', '')()
--     -- Equivalent to the following in Java
--     --     Iterator.super.remove();
--   end
-- }
--
-- iter = java.proxy('java.util.Iterator', iterImpl)
-- -- Calls the implemented `remove`, which then calls the default one
-- iter:remove()
-- ```
--
-- ::: note
-- For proxy object, it is possible to explicitly call the default methods in the interfaces.
-- Use `complete.interface.name:methodName` to refer to the method. See the examples below.
---@param jobject jobject|jclass The object.
---@param method string The method name. Use `new` to refer to the constructor.
---@param signature string|nil Comma separated argument type list. If not supplied, treated as an empty one.
---@return function # Never `nil`. The real method lookup begins after you supply arguments to this returned function.
function java.method(jobject, method, signature) end



-- Call the constructor of the given Java type.
-- - Generates a Lua error if exceptions occur or unable to locate a matching constructor.
--
-- ::: example
-- ```lua
-- String = java.import('java.lang.String')
-- --         new String ("This is the content of the String")
-- str = java.new(String, 'This is the content of the String')
-- ```
--
---@param jclass jclass|jobject The class. One may pass a `jclass` or a `jobject` of `Class<?>`.
---@param ... any Extra parameters are passed to the constructor. See also [Type Conversions](https://gudzpoz.github.io/luajava/conversions.html) to find out how we locate a matching method.
---@return jobject # The created object.
function java.new(jclass, ...) end

-- Creates a Java object implementing the specified interfaces, proxying calls to the underlying Lua table.
-- See also [Proxy Caveats](https://gudzpoz.github.io/luajava/proxy.html).
-- - Generates a Lua error if exceptions occur or unable to find the interfaces.
--
-- ::: example
-- ```lua
-- button = java.new(java.import('java.awt.Button'), 'Execute')
-- callback = {}
-- function callback:actionPerformed(ev)
--   -- do something
-- end
--
-- buttonProxy = java.proxy('java.awt.ActionListener', callback)
-- button:addActionListener(buttonProxy)
-- ```
--
-- Java allows method overloading, which means we cannot know which method you are calling until you supply the parameters. Method finding and parameter supplying is integrated in Java.
--
-- However, for calls in Lua, the two steps can get separated:
--
-- ```lua
-- obj:method(param1)
-- -- The above is actually:
-- m = obj.method
-- m(obj, param1)
-- ```
--
-- To proxy calls to Java, we treat all missing fields, such as `obj.method`, `obj.notAField`, `obj.whatever` as a possible method call. The real resolution starts only after you supply the parameters.
-- The side effect of this is that a missing field is never `nil` but always a possible `function` call, so don't depend on this.
--
-- ```lua
-- assert(type(jobject.notAField) == 'function')
-- ```
---@param jclass jclass|string|jobject The first interface.
---@param table table The table implementing the all the methods in the interfaces. Or, if the interfaces sum up to a [functional interface](https://docs.oracle.com/javase/specs/jls/se8/html/jls-9.html#jls-9.8) of wider sense (that is, we allow different signatures as long as they share the same name), an intermediate table will be created and back the actual proxy automatically.
---@return jobject # The created object.
function java.proxy(jclass, table) end

-- Return the backing table of a proxy object.
-- See also [Proxy Caveats](https://gudzpoz.github.io/luajava/proxy.html).
-- - Generates a Lua error if the object is not a Lua proxy object, or belongs to another irrelevant Lua state.
---@param jobject jobject The proxy object created with [`java.proxy`](https://gudzpoz.github.io/luajava/api.html#proxy-jclass-table-function) or [`party.iroiro.luajava.Lua#createProxy`](https://gudzpoz.github.io/luajava/javadoc/party/iroiro/luajava/Lua.html#createProxy(java.lang.Class%5B%5D,party.iroiro.luajava.Lua.Conversion))
---@return table # The backing Lua table of the Lua proxy.
function java.unwrap(jobject) end
