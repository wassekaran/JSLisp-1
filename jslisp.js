/****************************************************************************\
******************************************************************************
**                                                                          **
**  Copyright (c) 2011 by Andrea Griffini                                   **
**                                                                          **
**  Permission is hereby granted, free of charge, to any person obtaining   **
**  a copy of this software and associated documentation files (the         **
**  "Software"), to deal in the Software without restriction, including     **
**  without limitation the rights to use, copy, modify, merge, publish,     **
**  distribute, sublicense, and/or sell copies of the Software, and to      **
**  permit persons to whom the Software is furnished to do so, subject to   **
**  the following conditions:                                               **
**                                                                          **
**  The above copyright notice and this permission notice shall be          **
**  included in all copies or substantial portions of the Software.         **
**                                                                          **
**  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         **
**  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      **
**  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND                   **
**  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE  **
**  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION  **
**  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION   **
**  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.         **
**                                                                          **
******************************************************************************
\****************************************************************************/

d$$$42_start_time$42_ = (new Date).getTime();

d$$$42_current_module$42_ = "";
d$$$42_modules$42_ = {"" : { "*module-aliases*": {},
                             "*symbol-aliases*": {},
                             "*exports*": {}}};
d$$$42_module_aliases$42_ = d$$$42_modules$42_[""]["*module-aliases*"];
d$$$42_symbol_aliases$42_ = d$$$42_modules$42_[""]["*symbol-aliases*"];
d$$$42_exports$42_ = d$$$42_modules$42_[""]["*exports*"];
d$$$42_outgoing_calls$42_ = {};
d$$$42_used_globals$42_ = {};
d$$$42_debug$42_ = false;
d$$$42_function_context$42_ = [];
d$$$42_function_type_info$42_ = [];
d$$$42_function_closure$42_ = [];
d$$$42_timeout$42_ = null;
d$$$42_code_timeout$42_ = 20000;
d$$node_js = false;

var watchdog = setInterval(function(){
    d$$$42_timeout$42_ = (new Date).getTime() + d$$$42_code_timeout$42_;
}, 100);

var ck = 0;

function tock() {
    if (d$$$42_timeout$42_ &&
        !(++ck & 4095) &&
        (new Date).getTime() > d$$$42_timeout$42_) {
        throw "Execution timeout";
    }
}

var glob;

if (typeof window === "undefined")
{
    // node.js
    var glob = global;
    exports.eval = function (x)
    {
        return eval(f$$js_compile(f$$read(x)));
    };

    glob["f$$display"] = f$$display = function(x)
    {
        console.log(x);
    };

    glob["f$$warning"] = f$$warning = function(x)
    {
        console.error(x);
    };

    f$$display.outcalls = [];
    f$$display.usedglobs = [];

    d$$node_js = glob.d$$node_js = true;

    glob["fnode$$require"] = fnode$$require = function(x) { return require(x); };
    fnode$$require.outcalls = [];
    fnode$$require.usedglobs = [];
}
else
{
    glob = window;
}

function stringify(x)
{
    return JSON.stringify(x).substr(0); // Opera bug
}

function JSLSymbol(name, interned)
{
    this.name = name;
    if (!interned) this.interned = interned;
}

JSLSymbol.prototype.interned = true;

JSLSymbol.prototype.toString = function () {
    var ix = this.name.indexOf("$$");
    var mod = f$$demangle("$$" + this.name.substr(0, ix)) + ":";
    if (mod === ":" || mod === d$$$42_current_module$42_ + ":")
        mod = "";
    return mod + f$$demangle(this.name);
};

function Namespace()
{
    this.vars = {};
    this.props = {};
    this.stack = [];
    this.current_frame = 0;

    this.get = function(name, nouse)
    {
        name = "!" + name;
        var res = this.vars[name], fc, i;
        if (res && !nouse) this.props[name].used = true;
        if (res && (fc = this.props[name].fc) !== d$$$42_function_context$42_[i = d$$$42_function_context$42_.length-1]) {
            this.props[name].captured = true;
            while (i >= 0 && d$$$42_function_context$42_[i] !== fc) {
                d$$$42_function_closure$42_[i--] = true;
            }
        }
        return res;
    }

    this.add = function(name, value)
    {
        name = "!" + name;
        this.stack.push([name, this.vars[name], this.props[name]]);
        this.vars[name] = value;
        this.props[name] = {fc: d$$$42_function_context$42_[d$$$42_function_context$42_.length-1]};
    };

    this.begin = function()
    {
        this.stack.push(false);
        this.stack.push(["", this.vars[""], this.props[""]]);
        this.props[""] = {};
        this.current_frame += 1;
    };

    this.end = function(warn_unused)
    {
        if (this.stack.length === 0)
            throw new String("Internal error: Stack underflow in Namespace.end()");
        for (var x=this.stack.pop(); x; x=this.stack.pop())
        {
            if (warn_unused &&
                x[0] !== "" &&
                !this.props[""].ignorable &&
                !this.props[x[0]].used &&
                !this.props[x[0]].ignorable)
                f$$warning("Local name " +
                           f$$demangle(x[0].substr(1)) +
                           " defined but not used");
            this.vars[x[0]] = x[1];
            this.props[x[0]] = x[2];
            if (this.stack.length === 0)
                throw new String("Internal error: Stack underflow in Namespace.end()");
        }
    };

    return this;
}

var lisp_literals = [];

var lexvar = new Namespace();
var lexfunc = new Namespace();
var lexmacro = new Namespace();
var lexsmacro = new Namespace();

var specials = {};

glob["f$$mangle"] = f$$mangle = function(x)
{
    var res = "";
    for (var i=0; i<x.length; i++)
    {
        if (x[i] === '-')
        {
            res += '_';
        }
        else if ((x[i] >= 'a' && x[i] <= 'z') ||
                 (x[i] >= 'A' && x[i] <= 'Z'))
        {
            res += x[i];
        }
        else
        {
            res += ("$" + x.charCodeAt(i) + "_");
        }
    }
    return "$$" + res;
};
f$$mangle.documentation = ("[[(mangle x)]]\n" +
                           "Returns the javascript version of a lisp symbol name [x] "+
                           "by quoting characters forbidden in javascript identifiers");

glob["f$$intern"] = f$$intern = function(name, module, lookup_only)
{
    var x;
    // Keywords END with a colon and are always in the global module
    if (name[name.length-1] === ":")
        module = "";

    // Anything before the colon is the module name (global module being "").
    if ((typeof module === "undefined") && (x = name.indexOf(":")) >= 0)
    {
        module = name.substr(0, x);
        name = name.substr(x + 1);
    }
    // Imported symbols lookup
    if ((typeof module === "undefined") && (x = d$$$42_symbol_aliases$42_["!"+name]))
        return x;
    // Check for a nicknamed module
    var m = (typeof module === "undefined") ? d$$$42_current_module$42_ : (d$$$42_module_aliases$42_["!"+module]||module);
    m = f$$mangle(m).substr(2);
    var mangled = f$$mangle(name);
    var mname = m + mangled;
    x = glob["s" + mname];
    if (x === undefined)
    {
        if ((typeof module === "undefined") && (x = glob["s" + mangled]))
            return x;
        if (lookup_only) return null;
        x = glob["s" + mname] = new JSLSymbol(mname, true);
        eval("s" + mname + " = glob['s" + mname + "']");
        if (name[name.length-1] === ':')
        {
            glob["d" + mname] = x;
            eval("d" + mname + " = glob['d" + mname + "']");
        }
    }
    return x;
};
f$$intern.documentation = ("[[(intern name &optional module lookup-only)]]\n" +
                           "Create and returns an interned symbol with the specified [name] into " +
                           "[module] or just returns that symbol if it has been already interned. " +
                           "If the name ends with a colon ':' character then the module is ignored " +
                           "interning the symbol in the global module instead and the symbol value " +
                           "cell is also bound to the symbol itself (keyword symbol). If no module " +
                           "parameter is specified and the symbol is listed in [*symbol-aliases*] " +
                           "then that value is returned, otherwise if it is not found in current " +
                           "module then before performing the interning operation the symbol is " +
                           "first looked up also in the global module. If [lookup-only] is true " +
                           "then no symbol creation is performed in any case and [null] is " +
                           "returned if no symbol can be found.");
f$$intern.arglist = [f$$intern("name"), f$$intern("&optional"), f$$intern("module"), f$$intern("lookup-only")];
f$$mangle.arglist = [f$$intern("x")];
f$$intern.usedglobs = f$$intern.outcalls = f$$mangle.usedglobs = f$$mangle.outcalls = [];

var constants = {};
constants[f$$intern('null').name] = 'null';
constants[f$$intern('true').name] = 'true';
constants[f$$intern('false').name] = 'false';
constants[f$$intern('undefined').name] = 'undefined';
constants[f$$intern('NaN').name] = 'NaN';
constants[f$$intern('infinity').name] = 'Infinity';
constants[f$$intern('-infinity').name] = '(-Infinity)';

f$$intern("js-code");
f$$intern("declare");
f$$intern("ignorable");
f$$intern("type");
f$$intern("return-type");

function defun(name, doc, f, arglist, usedglobs, outcalls)
{
    var s = f$$intern(name);
    glob["f" + s.name] = f;
    eval("f" + s.name + " = glob['f" + s.name + "']");
    f.documentation = doc;
    f.arglist = arglist;
    f.usedglobs = usedglobs;
    f.outcalls = outcalls;
}

function defmacro(name, doc, f, arglist)
{
    var s = f$$intern(name);
    glob["m" + s.name] = f;
    eval("m" + s.name + " = glob['m" + s.name + "'];");
    f.documentation = doc;
    f.arglist = arglist;
}

defun("demangle",
      "[[(demangle x)]]\n" +
      "Returns a lisp name [x] by decoding a javascript name produced by [(mangle ...)]",
      function(x)
      {
          var i = x.indexOf("$$");
          return x.substr(i+2)
              .replace(/_/g,"-")
              .replace(/(\$[0-9]+-)/g,
                       function(s)
                       {
                           return String.fromCharCode(parseInt(s.substr(1, s.length-2)));
                       });
      },
      [f$$intern("x")], [], []);

defun("symbol-module",
      "[[(symbol-module x)]]\n" +
      "Returns the module name of symbol [x] or [undefined] if the symbol is uninterned.",
      function(x)
      {
          if (x.interned)
              return f$$demangle("$$" + x.name.substr(0, x.name.indexOf("$$")));
          return undefined;
      },
      [s$$x],[],["$$demangle"]);

defun("module-symbol",
      "[[(module-symbol x &optional module)]]\n"+
      "Returns a symbol with same name as symbol [x] after interning it " +
      "in the specified [module] or in current module if no module is " +
      "specified. If the symbol [x] is already interned in [module] then " +
      "simply returns it. As side effect an eventually defined alias for the " +
      "symbol in [module] will be removed.",
      function(x, module)
      {
          if (typeof module === "undefined") module = d$$$42_current_module$42_;
          var name = f$$demangle(x.name);
          var s = f$$intern(name, module);
          delete d$$$42_modules$42_[module]["*symbol-aliases*"]["!" + name];
          return s;
      },
      [s$$x, f$$intern("&optional"), f$$intern("module")],[],["$$intern","$$demangle"]);

defun("documentation",
      "[[(documentation x)]]\n" +
      "Returns the documentation string for function [x].",
      function(x)
      {
          return x.documentation;
      },
      [s$$x]);

defun("set-documentation",
      "[[(set-documentation x doc)]]\n" +
      "Sets the documentation string for function [x] to [doc].",
      function(x, doc)
      {
          x.documentation = doc;
      },
      [s$$x, f$$intern("doc")]);

defun("arglist",
      "[[(arglist x)]]\n" +
      "Returns the argument list for function [x].",
      function(x)
      {
          return x.arglist || null;
      },
      [s$$x]);

defun("set-arglist",
      "[[(set-arglist x arglist)]]\n" +
      "Sets the argument list for function [x] to [arglist].",
      function(x, arglist)
      {
          x.arglist = arglist;
      },
      [s$$x, f$$intern("arglist")]);

defmacro("arglist",
         "[[(arglist x)]]\n" +
         "Returns the argument list for function [x].",
         function(x)
         {
             return [s$$js_code, "(" + f$$js_compile(x) + ".arglist)"];
         },
         [s$$x]);

defmacro("set-arglist",
         "[[(set-arglist x arglist)]]\n" +
         "Sets the argument list for function [x] to [arglist].",
         function(x, arglist)
         {
             return [s$$js_code, "(" + f$$js_compile(x) +
                                       ".arglist=" +
                                       f$$js_compile(arglist) + ")"];
         },
         [s$$x, f$$intern("arglist")]);

defun("number?", "[[(number? x)]]\nReturns true if and only if [x] is a number (including [NaN])",
      function(x) { return (typeof x) === "number"; }, [s$$x], [], []);

defun("string?", "[[(string? x)]]\nReturns true if and only if [x] is a string",
      function(x) { return (typeof x) === "string"; }, [s$$x], [], []);

defun("list?", "[[(list? x)]]\nReturns true if and only if [x] is a list",
      function(x) { return (x && x.constructor === Array)  ? true : false; }, [s$$x], [], []);

defun("symbol?", "[[(symbol? x)]]\nReturns true if and only if [x] is a symbol",
      function(x) { return (x && x.constructor === JSLSymbol) ? true : false; }, [s$$x], [], []);

defun("js-eval",
      "[[(js-eval x)]]\n" +
      "Javascript evaluation of a string at runtime.",
      function(x) { return eval(x); }, [s$$x], [], []);

defun("symbol-function",
      "[[(symbol-function x)]]\n" +
      "Returns the function cell of a symbol [x] or [undefined] if that function is not present. " +
      "Lookup doesn't consider lexical function definitions (e.g. [(labels ...)]).",
      function(x) { return x.interned ? glob["f" + x.name] : x.f; }, [s$$x], [], []);

defun("set-symbol-function",
      "[[(set-symbol-function x f)]]\n" +
      "Sets the function cell of a symbol [x] to the specified function [f]. It doesn't affect "+
      "lexical function definitions (e.g. [(lables ...)]).",
      function(x, y) { return x.interned ? (glob["f" + x.name] = y) : (x.f = y); }, [s$$x, f$$intern("f")], [], []);

defun("symbol-value",
      "[[(symbol-value x)]]\n" +
      "Returns the current value cell of a symbol [x] or [undefined] if that symbol has no value. " +
      "Lookup doesn't consider lexical symbols.",
      function(x) { return x.interned ? glob["d" + x.name] : x.d; }, [s$$x], [], []);

defun("set-symbol-value",
      "[[(set-symbol-value x y)]]\n" +
      "Sets the current value cell of a symbol [x] to [y]. It doesn't affect lexical bindings.",
      function(x, y) { return x.interned ? (glob["d" + x.name] = y) : (x.d = y); }, [s$$x, f$$intern("y")], [], []);

defun("symbol-macro",
      "[[(symbol-macro x)]]\n" +
      "Returns the current macro expander function cell of a symbol [x] or [undefined] if that " +
      "symbol has no macro expander function set. Lookup doesn't consider lexical macros.",
      function(x) { return x.interned ? glob["m" + x.name] : x.m; }, [s$$x]);

defun("set-symbol-macro",
      "[[(set-symbol-macro x f)]]\n" +
      "Sets the macro expander function cell of a symbol [x] to [y]. It doesn't affect lexical macros.",
      function(x, f) { return x.interned ? (glob["m" + x.name] = f) : (x.m = f); }, [s$$x, s$$f]);

defun("symbol-name",
      "[[(symbol-name x)]]\n" +
      "Returns the lisp symbol name of a symbol [x] as a string object.",
      function(x) { return f$$demangle(x.name); }, [s$$x], [], ["$$demangle"]);

defun("symbol-full-name",
      "[[(symbol-name x)]]\n" +
      "Returns the qualified lisp symbol name of a symbol [x] as a string object.",
      function(x) {
          var ix = x.name.indexOf("$$");
          var mod = f$$demangle("$$" + x.name.substr(0, ix)) + ":";
          if (mod === ":") mod = "";
          return mod + f$$demangle(x.name);
      }, [s$$x], [], ["$$demangle"]);

defmacro("define-symbol-macro",
         "[[(define-symbol-macro x y)]]\n" +
         "Sets the global symbol-macro expansion of unevaluated symbol [x] to be the unevaluated form [y].",
         function(x, y)
         {
             var i = lisp_literals.indexOf(y);
             if (i === -1)
             {
                 i = lisp_literals.length;
                 lisp_literals.push(y);
             }
             d$$$42_used_globals$42_["q#"+i] = true;
             return [s$$js_code, "s" + x.name + ".symbol_macro=lisp_literals[" + i + "]"];
         },
         [f$$intern("x"), f$$intern("y")]);

defmacro("if",
         "[[(if condition then-part &optional else-part)]]\n" +
         "Conditional evaluation form. Evaluates either [then-part] only or [else-part] only (not both) "+
         "depending on whether or not the evaluation of [condition] returned a true value.",
         function(condition, then_part, else_part)
         {
             return [s$$js_code, ("(" +
                                  f$$js_compile(condition) +
                                  "?" +
                                  f$$js_compile(then_part) +
                                  ":" +
                                  f$$js_compile(else_part) +
                                  ")")];
         },
         [f$$intern("condition"), f$$intern("then-part"), f$$intern("&optional"), f$$intern("else-part")]);

defmacro("defvar",
         "[[(defvar variable &optional value)]]\n" +
         "Sets the value cell of [variable] only if is not already defined, and also marks the " +
         "symbol as 'special' so that future value bindings on this symbol will always be dynamic " +
         "and not lexical.",
         function(name, value)
         {
             var v = f$$module_symbol(name).name;
             specials[v] = "d" + v;
             return [s$$js_code, "(d" + v + " = ((glob['d" + v + "']!=undefined)?d" + v + ":" + f$$js_compile(value) + "))"];
         },
         [f$$intern("variable"), f$$intern("&optional"), f$$intern("value")]);

function implprogn(x)
{
    var res = "(";
    var sep = "";
    for (var i=0; i<x.length; i++)
    {
        var y = f$$js_compile(x[i]);
        if (y !== "null") {
            res += sep + y;
            sep = ",";
        }
    }
    res += ")";
    if (res === "()") res = "(null)";
    return res;
}

defmacro("progn",
         "[[(progn &rest body)]]\n" +
         "Evaluates all the forms of [body] in sequence, returning as value the value of the last one.",
         function()
         {
             return [s$$js_code, implprogn(Array.prototype.slice.call(arguments))];
         },
         [f$$intern("&rest"), f$$intern("body")]);

defmacro("let",
         "[[(let ((x1 v1)(x2 v2) ... (xn vn)) &rest body)]]\n" +
         "Evaluates all the forms of [body] by first establishing lexical/dynamic bindings " +
         "for the variables [x1=v1], [x2=v2] ... [xn=vn]. The evaluation of the forms [v1]...[vn] " +
         "does /NOT/ consider the bindings that will be established by [(let ...)].",
         function(bindings)
         {
             var body = Array.prototype.slice.call(arguments, 1);
             if (bindings.length == 0)
                 return [f$$intern("progn")].concat(body);
             lexvar.begin();
             lexsmacro.begin();

             var osmacro = [];

             var spe = [];
             var res = "((function(";
             for (var i=0; i<bindings.length; i++)
             {
                 if (bindings[i].length != 2 ||
                     !f$$symbol$63_(bindings[i][0]))
                     throw new String("Invalid 'let' binding " + f$$str_value(bindings[i]));
                 if (i > 0) res += ",";
                 var name = bindings[i][0].name;
                 if (specials[name])
                 {
                     res += "sd" + name;
                     spe.push(name);
                 }
                 else
                 {
                     lexvar.add(name, "d" + lexvar.current_frame + "_" + name);
                     res += "d" + lexvar.current_frame + "_" + name;
                 }
                 lexsmacro.add(name, undefined);
                 if (bindings[i][0].symbol_macro)
                 {
                     osmacro.push([bindings[i][0], bindings[i][0].symbol_macro]);
                     bindings[i][0].symbol_macro = undefined;
                 }
             }
             res += "){";

             var cbody = implprogn(body);

             // Check if we can avoid creating a nested function
             // scope because all bindings are local and are not
             // captured in the body. In such a case the bindings
             // are just function-level locals of the closest
             // function scope (this works because the *compiled*
             // name of a lexical is already unique).
             var canlift = d$$$42_function_context$42_.length > 0;
             for (var i=0; canlift && i<bindings.length; i++)
             {
                 var name = bindings[i][0].name;
                 var vp;
                 if (specials[name] || !(vp = lexvar.props["!"+name]) || vp.captured)
                     canlift = false;
             }
             if (canlift) {
                 // This LET form can be simplified to a sequence
                 // of assignments to locals followed by the body
                 // and there's no need of a nested scope.
                 var cfc = d$$$42_function_context$42_[d$$$42_function_context$42_.length-1];
                 var lnames = [];
                 for (var i=0; i<bindings.length; i++)
                 {
                     var cname = lexvar.get(bindings[i][0].name, true);
                     lnames.push(cname);
                     cfc.push(cname);
                 }
                 lexsmacro.end();
                 lexvar.end(true);
                 for (var i=0; i<osmacro.length; i++)
                     osmacro[i][0].symbol_macro = osmacro[i][1];
                 res = "(";
                 for (var i=0; i<lnames.length; i++)
                 {
                     if (i > 0) res += ",";
                     res += lnames[i] + "=(" + f$$js_compile(bindings[i][1]) + ")";
                 }
                 if (lnames.length > 0) res += ",";
                 res += cbody + ")";
             }
             else
             {
                 // A full nested scope is necessary
                 if (spe.length)
                 {
                     for (var i=0; i<spe.length; i++)
                     {
                         res += "var osd" + spe[i] + "=d" + spe[i] + ";";
                         res += "d" + spe[i] + "=sd" + spe[i] + ";";
                     }
                     res += "var res=";
                     res += cbody;
                     res += ";";
                     for (var i=0; i<spe.length; i++)
                     {
                         res += "d" + spe[i] + "=osd" + spe[i] + ";";
                     }
                     res += "return res;})(";
                 }
                 else
                 {
                     res += "return " + cbody + "})(";
                 }
                 lexsmacro.end();
                 lexvar.end(true);
                 for (var i=0; i<osmacro.length; i++)
                     osmacro[i][0].symbol_macro = osmacro[i][1];

                 for (var i=0; i<bindings.length; i++)
                 {
                     if (i > 0) res += ",";
                     res += f$$js_compile(bindings[i][1]);
                 }
                 res += "))";
             }
             return [s$$js_code, res];
         },
         [f$$intern("bindings"), f$$intern("&rest"), f$$intern("body")]);

defmacro("lambda",
         "[[(lambda (arg-1 ... arg-n) &rest body)]]\n" +
         "Returns a function object that when called will lexically/dynamically bind " +
         "parameters to [arg1], [arg2], ... [arg-n] and that will evaluate all forms " +
         "in [body] in sequence returning the last evaluated form value as result",
         function(args)
         {
             // Poor version of &optional to help bootstrapping (no support for
             // default values; just removes the keyword from the arg list)
             var iopt = args.indexOf(s$$$38_optional);
             if (iopt >= 0) args = args.slice(0,iopt).concat(args.slice(1+iopt));

             // Create a function context so LET bindings that are not
             // captured can be lifted to simple local variables (for
             // unknown reasons recent Android implementations have a
             // very low limit for nested functions).  A function
             // context is simply a list of extra local variables to
             // declare
             d$$$42_function_context$42_.push([]);

             // Type declarations for this function. Types can be
             // optionally declared for arguments and/or return value
             // to help finding type errors at compile time.  TODO:
             // Add deduction logic for simple cases when return type
             // is not declared.
             d$$$42_function_type_info$42_.push({});

             // True if the function is indeed a closure
             d$$$42_function_closure$42_.push(false);

             var current_outgoing_calls = d$$$42_outgoing_calls$42_;
             d$$$42_outgoing_calls$42_ = {};
             var current_used_globals = d$$$42_used_globals$42_;
             d$$$42_used_globals$42_ = {};
             var body = Array.prototype.slice.call(arguments, 1);
             lexvar.begin();
             lexsmacro.begin();
             try
             {
                 var osmacro = [];
                 var spe = [];
                 var res = "(function(";
                 var rest = null;
                 var nargs = 0;
                 for (var i=0; i<args.length; i++)
                 {
                     var v = args[i].name;
                     if (v === "$$$38_rest")
                     {
                         rest = args[i+1].name;
                         if (!specials[rest])
                             lexvar.add(rest, "d"+ rest);
                         lexsmacro.add(rest, undefined);
                     }
                     else if (!rest)
                     {
                         if (i > 0) res += ",";
                         if (specials[v])
                         {
                             res += "sd" + v;
                             spe.push(v);
                         }
                         else
                         {
                             res += "d" + v;
                             lexvar.add(v, "d" + v);
                         }
                         nargs++;
                         lexsmacro.add(v, undefined);
                         if (args[i].symbol_macro)
                         {
                             osmacro.push([args[i], args[i].symbol_macro]);
                             args[i].symbol_macro = undefined;
                         }
                     }
                 }
                 res += "){";
                 for (var i=0; i<spe.length; i++)
                 {
                     res += "var osd" + spe[i] + "=d" + spe[i] + ";";
                     res += "d" + spe[i] + "=sd" + spe[i] + ";";
                 }
                 if (rest)
                 {
                     if (specials[rest])
                     {
                         spe.push(rest);
                         res += "var osd" + rest + "=d" + rest + ";";
                     }
                     else
                     {
                         res += "var ";
                     }
                     res += "d" + rest + "=Array.prototype.slice.call(arguments,"+nargs+");";
                 }
                 var cbody = "";
                 if (spe.length === 0)
                 {
                     cbody += "return " + implprogn(body) + ";})";
                 }
                 else
                 {
                     cbody += "var res=";
                     cbody += implprogn(body);

                     cbody += ";"
                     for (var i=0; i<spe.length; i++)
                     {
                         cbody += "d" + spe[i] + "=osd" + spe[i] + ";";
                     }
                     cbody += "return res;})";
                 }
                 // We compiled the body so now we can check if any
                 // lifted LET binding should be declared as
                 // function-level local
                 var lb = d$$$42_function_context$42_.pop();
                 if (lb.length) {
                     res += "var " + lb.join(", ") + ";";
                 }
                 res += cbody;
                 var ocnames = "";
                 var ugnames = "";
                 for (var k in d$$$42_outgoing_calls$42_)
                 {
                     ocnames += "," + stringify(k);
                     current_outgoing_calls[k] = true;
                 }
                 for (var k in d$$$42_used_globals$42_)
                 {
                     ugnames += "," + stringify(k);
                     current_used_globals[k] = true;
                 }
                 var li = lisp_literals.length;
                 lisp_literals[li] = args;
                 lisp_literals[li+1] = d$$$42_function_type_info$42_.pop();
                 var cl = d$$$42_function_closure$42_.pop();

                 // Copy parameter type declarations to fti for compile-time checking
                 for (var i=0; i<args.length; i++) {
                     var v = args[i];
                     if (f$$symbol$63_(v)) {
                         var p = lexvar.props["!"+v.name];
                         if (p && p.type) {
                             lisp_literals[li+1][v.name] = p.type;
                         }
                     }
                 }
                 res = ("((function(){" +
                        "var f =" +
                        res +
                        ";" +
                        "f.usedglobs=[" +
                        ugnames.substr(1) +
                        "];f.outcalls=[" +
                        ocnames.substr(1) +
                        "];f.arglist=lisp_literals[" + li +
                        "];f.fti=lisp_literals[" + (li+1) +
                        "];f.closure=" + cl + ";return f;})())");
                 return [s$$js_code, res];
             }
             finally
             {
                 lexvar.end(true);
                 lexsmacro.end();
                 for (var i=0; i<osmacro.length; i++)
                     osmacro[i][0].symbol_macro = osmacro[i][1];
                 d$$$42_outgoing_calls$42_ = current_outgoing_calls;
                 d$$$42_used_globals$42_ = current_used_globals;
             }
         },
         [f$$intern("args"), f$$intern("&rest"), f$$intern("body")]);

defun("logcount",
      "[[(logcount x)]]\n" +
      "Returns the number of bits set to 1 in the binary representation of the integer number [x].",
      function(x)
      {
          var n = 0;
          while (x)
          {
              x &= x-1;
              n++;
          }
          return n;
      },
      [s$$x],[],[]);

defun("list",
      "[[(list &rest args)]]\n" +
      "Returns the list containing the value of the expressions in [args].",
      function()
      {
          return Array.prototype.slice.call(arguments);
      },
      [f$$intern("&rest"), f$$intern("args")],[],[]);

defun("funcall",
      "[[(funcall f &rest args)]]\n" +
      "Calls the function object [f] passing specified values as parameters.",
      function()
      {
          return arguments[0].apply(glob, Array.prototype.slice.call(arguments, 1));
      },
      [f$$intern("f"), f$$intern("&rest"), f$$intern("args")],[],[]);

defmacro("labels",
         "[[(labels ((func1 (x1 x2 ... xn) f1 f2 .. fn)...) &rest body)]]\n" +
         "Excutes the forms in [body] by first establishing a lexical binding for the " +
         "function names [func1], [func2] ... [funcn]. When compiling the body forms any "+
         "macros defined outside the [(labels ...)] form with names [func1], [func2], "+
         "... [funcn] will be ignored.",
         function(bindings)
         {
             var body = Array.prototype.slice.call(arguments, 1);
             // First hide all macros and lexical macros named as defined functions
             // and also adds immediately the functions to the lexical functions list
             lexfunc.begin();
             lexmacro.begin();
             try
             {
                 var hmacros = [];
                 for (var i=0; i<bindings.length; i++)
                 {
                     var v = bindings[i][0].name;
                     lexmacro.add(v, undefined);
                     if (glob["m" + v])
                     {
                         hmacros.push([v, glob["m" + v]]);
                         glob["m" + v] = undefined;
                     }
                     lexfunc.add(v, {arglist:bindings[i][1]});
                 }

                 // Compile function definitions
                 var res = "((function(){";
                 for (var i=0; i<bindings.length; i++)
                 {
                     var v = bindings[i][0].name;
                     res += "var f" + v + "=" +
                         f$$js_compile([f$$intern("lambda")].concat(bindings[i].slice(1))) + ";";
                 }
                 res += "return ";
                 res += implprogn(body);
                 res += ";})())";
             }
             finally
             {
                 lexfunc.end();
                 lexmacro.end();
                 // Restore hidden global macros
                 for (var i=0; i<hmacros.length; i++)
                     glob["m" + hmacros[i][0]] = hmacros[i][1];
             }
             return [s$$js_code, res];
         },
         [f$$intern("bindings"), f$$intern("&rest"), f$$intern("body")]);

defmacro("setq",
         "[[(setq name value)]]\n" +
         "Sets the current value of variable [name]. When [name] is not a symbol or is " +
         "currently globally or lexically bound to a symbol macro [setq] is transformed " +
         "in a corresponding [(setf ...)] form.",
         function(name, value)
         {
             if (f$$symbol$63_(name) &&
                 !name.symbol_macro &&
                 !lexsmacro.get(name.name))
             {
                 return [s$$js_code, "(d" + name.name + "=" + f$$js_compile(value) + ")"];
             }
             else
             {
                 return [f$$intern("setf"), name, value];
             }
         },
         [f$$intern("name"), f$$intern("value")]);

defmacro("quote",
         "[[(quote x)]]\n" +
         "Returns the unevaluated form [x] as result.",
         function(x)
         {
             if (f$$symbol$63_(x) && x.interned)
             {
                 d$$$42_used_globals$42_["s#" + x.name] = true;
                 return [s$$js_code, "s" + x.name];
             }
             if (f$$number$63_(x) || f$$string$63_(x))
                 return [s$$js_code, stringify(x)];
             var i = lisp_literals.indexOf(x);
             if (i === -1)
             {
                 i = lisp_literals.length;
                 lisp_literals.push(x);
             }
             d$$$42_used_globals$42_["q#"+i] = true;
             return [s$$js_code, "lisp_literals[" + i + "]"];
         },
         [s$$x]);

defun("eval",
      "[[(eval x)]]\n" +
      "Evaluates the expression [x] without considering lexical bindings.",
      function(x)
      {
          var jscode = f$$js_compile(x);
          return eval(jscode);
      },
      [s$$x],[],["$$js_compile"]);

defun("macroexpand-1",
      "[[(macroexpand-1 x)]]\n" +
      "Expands the macro call or symbol in [x] or returns [x] unaltered if " +
      "it's neither a macro invocation nor a macro symbol. Lexical macro bindings are NOT considered.",
      function(x)
      {
          if (f$$symbol$63_(x) && x.symbol_macro)
              x = x.symbol_macro;
          else if (f$$list$63_(x) && f$$symbol$63_(x[0]) && glob["m" + x[0].name])
              x = glob["m" + x[0].name].apply(glob, x.slice(1));
          return x;
      },
      [s$$x]);

defun("macroexpand",
      "[[(macroexpand x)]]\n" +
      "Repeats macro expansion process of [macroexpand-1] on [x] until no more expansions are possible.",
      function(x)
      {
          for (;;)
          {
              if (f$$symbol$63_(x) && x.symbol_macro)
                  x = x.symbol_macro;
              else if (f$$list$63_(x) && f$$symbol$63_(x[0]) && glob["m" + x[0].name])
                  x = glob["m" + x[0].name].apply(glob, x.slice(1));
              else break;
          }
          return x;
      },
      [s$$x]);

defun("append",
      "[[(append &rest lists)]]\n"+
      "Returns a list obtained by concatenating all specified lists.",
      function()
      {
          var res = [];
          return res.concat.apply(res, arguments);
      },
      [f$$intern("&rest"), f$$intern("lists")], [], []);

defun("nappend",
      "[[(nappend x y)]]\n"+
      "Appends all elements of list [y] to list [x] and returns [x]",
      function(x, y)
      {
          x.push.apply(x, y);
          return x;
      },
      [f$$intern("x"), f$$intern("y")],[],[]);

defun("apply",
      "[[(apply f args)]]\n" +
      "Calls the function [f] passing the list [args] as arguments",
      function(f, args)
      {
          return f.apply(null, args);
      },
      [f$$intern("f"), f$$intern("args")],[],[]);

defun("lexical-macro",
      "[[(lexical-macro x)]]\n" +
      "Returns the lexical macro function associated to symbol [x] if present or undefined otherwise",
      function(x)
      {
          return lexmacro.get(x.name);
      },
      [s$$x]);

defun("lexical-symbol-macro",
      "[[(lexical-symbol-macro x)]]\n" +
      "Returns the lexical symbol-macro associated to symbol [x] if present or undefined otherwise",
      function(x)
      {
          return lexsmacro.get(x.name);
      },
      [s$$x]);

defun("lexical-function",
      "[[(lexical-function x)]]\n" +
      "Returns the lexical function associated to symbol [x] if present or undefined otherwise",
      function(x)
      {
          return lexfunc.get(x.name);
      },
      [s$$x]);

defmacro("apply",
         "[[(apply f args)]]\n" +
         "Calls the function [f] passing the list [args] as arguments",
         function(f, args)
         {
             var res = f$$js_compile(f);
             return [s$$js_code, res + ".apply(null," + f$$js_compile(args) + ")"];
         },
         [f$$intern("f"), f$$intern("args")]);

defmacro("and",
         "[[(and &rest expressions)]]\n" +
         "Returns the value of last expression form if all forms evaluate to logically true or otherwise " +
         "returns the first logically false result without evaluating subsequent forms.",
         function()
         {
             var x = Array.prototype.slice.call(arguments);
             if (x.length === 0)
                 return "true";
             var res = "(";
             for (var i=0; i<x.length; i++)
             {
                 if (i > 0) res += "&&";
                 res += f$$js_compile(x[i]);
             }
             return [s$$js_code, res + ")"];
         },
         [f$$intern("&rest"), f$$intern("expressions")]);

defmacro("or",
         "[[(or &rest expressions)]]\n" +
         "Returns the value of the first expression that evaluates to logically true without evaluating " +
         "subsequent forms, or otherwise returns the value of last expression if all of them evaluate " +
         "to logicall false.",
         function()
         {
             var x = Array.prototype.slice.call(arguments);
             if (x.length === 0)
                 return "false";
             var res = "(";
             for (var i=0; i<x.length; i++)
             {
                 if (i > 0) res += "||";
                 res += f$$js_compile(x[i]);
             }
             return [s$$js_code, res + ")"];
         },
         [f$$intern("&rest"), f$$intern("expressions")]);

defmacro("cond",
         "[[(cond (t1 f1)(t2 f2)...(tn fn))]]\n" +
         "Evaluates in sequence [t1], [t2] ... [tn] and returns the value of the first corresponding form " +
         "[f] when the value is logically true without evaluating subsequent conditions. " +
         "Returns [null] if no condition [t] evaluates to logically true",
         function()
         {
             var wrapper = false;
             var x = Array.prototype.slice.call(arguments);
             var res = "(";
             for (var i=0; i<x.length; i++)
             {
                 if (i > 0)
                     res += ":";
                 if (x[i].length > 1)
                 {
                     res += (f$$js_compile(x[i][0]) + "?" +
                             implprogn(x[i].slice(1)));
                 }
                 else
                 {
                     wrapper = true;
                     res += "(cx=(" + f$$js_compile(x[i][0]) + "))?cx";
                 }
             }
             if (x.length > 0) res += ":"
             res += "null)";
             if (wrapper)
             {
                 res = "(function(){var cx; return " + res + ";})()";
             }
             return [s$$js_code, res];
         },
         [f$$intern("&rest"), f$$intern("body")]);

defmacro("do",
         "[[(do ((v1 init1 [inc1])...)(exit-test res1 res2 ...) &rest body)]]\n" +
         "Loops over the body forms by first establishing a lexical/dynamic binding " +
         "[v1=init1], [v2=init2], ... and by assigning the value of the increment forms [inc1] to [v1], " +
         "[inc2] to [v2] ... where they are present after each iteration. " +
         "Before entering each loop iteration the [exit-test] form is evaluated and if logically true the " +
         "iteration is not performed and the result forms [res1], [res2] ... are evaluated in sequence "+
         "with the value of last of them being used as the final result of the [(do ...)] form.",
         function(vars, test)
         {
             var body = Array.prototype.slice.call(arguments, 2);
             lexsmacro.begin();
             lexvar.begin();
             try
             {
                 var spe = [];
                 var res = "(function(";
                 for (var i=0; i<vars.length; i++)
                 {
                     var v = vars[i][0].name;
                     if (i > 0) res += ",";
                     if (specials[v])
                     {
                         res += "sd" + v;
                         spe.push(v);
                     }
                     else
                     {
                         res += "d" + v;
                         lexvar.add(v, "d" + v);
                     }
                     lexsmacro.add(v, undefined);
                 }
                 res += "){";
                 for (var i=0; i<spe.length; i++)
                 {
                     res += "var osd" + spe[i] + "=d" + spe[i] + ";";
                     res += "d" + spe[i] + "=sd" + spe[i] + ";";
                 }
                 res += "for(;;){tock();";
                 res += "if(" + f$$js_compile(test[0]) + "){";
                 if (spe.length)
                 {
                     res += "var res=" + implprogn(test.slice(1)) + ";";
                     for (var i=0; i<spe.length; i++)
                     {
                         res += "d" + spe[i] + "=osd" + spe[i] + ";";
                     }
                     res += "return res;}";
                 }
                 else
                 {
                     res += "return " + implprogn(test.slice(1)) + "}";
                 }
                 res += implprogn(body) + ";";
                 for (var i=0; i<vars.length; i++)
                 {
                     if (vars[i].length === 3)
                     {
                         var v = vars[i][0].name;
                         res += "d" + v + "=(" + f$$js_compile(vars[i][2]) + ");";
                     }
                 }
                 res += "}})(";
             }
             finally
             {
                 lexsmacro.end();
                 lexvar.end(true);
             }
             for (var i=0; i<vars.length; i++)
             {
                 if (i > 0) res += ",";
                 res += f$$js_compile(vars[i][1]);
             }
             return [s$$js_code, res + ")"];
         },
         [f$$intern("init&step"), f$$intern("quit-condition"), f$$intern("&rest"), f$$intern("body")]);

function domacrolet(bindings, body, body_process)
{
    lexmacro.begin();
    for (var i=0; i<bindings.length; i++)
    {
        var name = bindings[i][0].name;
        var args = bindings[i][1];
        var mbody = bindings[i].slice(2);
        var ouc = d$$$42_outgoing_calls$42_;
        var oug = d$$$42_used_globals$42_;
        d$$$42_outgoing_calls$42_ = {};
        d$$$42_used_globals$42_ = {};
        lexmacro.add(name, eval(f$$js_compile([f$$intern("lambda"), args].concat(mbody))));
        d$$$42_outgoing_calls$42_ = ouc;
        d$$$42_used_globals$42_ = oug;
    }
    var res = body_process(body);
    lexmacro.end();
    return res;
}

function dosymbolmacrolet(bindings, body, body_process)
{
    lexsmacro.begin();
    for (var i=0; i<bindings.length; i++)
    {
        var name = bindings[i][0].name;
        var value = bindings[i][1];
        lexsmacro.add(name, value);
    }
    var res = body_process(body);
    lexsmacro.end();
    return res;
}

defmacro("macrolet",
         "[[(macrolet ((m1 (x1 x2 ...) b1 b2 ...) ...) &rest body)]]\n" +
         "Evaluates the body forms that are compiled by first installing " +
         "the lexical macros [m1], [m2] ... [mn]. Global macros accessible with [(symbol-macro x)] are not " +
         "affected by these local definitions.",
         function(bindings)
         {
             var body = Array.prototype.slice.call(arguments, 1);
             return [s$$js_code, domacrolet(bindings, body, implprogn)];
         },
         [f$$intern("bindings"), f$$intern("&rest"), f$$intern("body")]);

defmacro("symbol-macrolet",
         "[[(symbol-macrolet ((x1 def1)(x2 def2)...) &rest body)]]\n" +
         "Evaluates the body forms that are compiled by first installing "+
         "the lexical symbol macros [x1=def1] [x2=def2] ... [xn=defn].",
         function(bindings)
         {
             var body = Array.prototype.slice.call(arguments, 1);
             return [s$$js_code, dosymbolmacrolet(bindings, body, implprogn)];
         },
         [f$$intern("bindings"), f$$intern("&rest"), f$$intern("body")]);

if (typeof window !== "undefined")
    defun("warning",
          "[[(warning msg)]]\n" +
          "Function called by the compiler to emit warnings about possible logical errors in the compiled code.",
          function(msg)
          {
              f$$display("WARNING: " + msg.replace(/\$\$[a-zA-Z_0-9\$]*/g, f$$demangle));
          },
          [f$$intern("msg")],[],["$$demangle"]);

d$$$42_error_location$42_ = null;

function erl(x, f)
{
    try {
        return f();
    } catch(err) {
        if (err instanceof Error) {
            err = {error: err+"",
                   stack_trace: []};
            setTimeout(function(){
                up({id: id,
                    req: -1,
                    reply: err});
            }, 0);
        }
        if (err.stack_trace) {
            err.stack_trace.push(x);
        }
        throw err;
    }
}

d$$$42_declarations$42_ = [];

defun("js-compile",
      "[[(js-compile x)]]\n" +
      "Returns a string containing Javascript code that when evaluated in javascript will perform the " +
      "evaluation of the passed form [x].",
      function(x)
      {
          if (f$$symbol$63_(x))
          {
              var v;
              if ((v = lexsmacro.get(x.name))) return f$$js_compile(v);

              if ((v = lexvar.get(x.name))) return v;

              if (x.symbol_macro)
                  return f$$js_compile(x.symbol_macro);

              if (specials[x.name])
              {
                  d$$$42_used_globals$42_[x.name] = true;
                  return specials[x.name];
              }

              var v = constants[x.name];
              if ((typeof v) === "undefined")
              {
                  if ((typeof glob["d" + x.name]) === "undefined")
                      f$$warning("Undefined variable " + f$$demangle(x.name));
                  v = "d" + x.name;
                  if (x.constant &&
                      ((typeof glob["d" + x.name]) === "string" ||
                       (typeof glob["d" + x.name]) === "number"))
                  {
                      v = stringify(glob["d" + x.name]);
                  }
                  else
                  {
                      d$$$42_used_globals$42_[x.name] = true;
                  }
              }

              return v;
          }
          else if (f$$list$63_(x) && x[0] === s$$declare)
          {
              d$$$42_declarations$42_.push(x);
              for (var j=1; j<x.length; j++)
              {
                  var decl = x[j];
                  if (f$$list$63_(decl)) {
                      var d = decl[0];
                      if (d === s$$ignorable) {
                          if (decl.length === 2 && decl[1].name === "$$$42_") {
                              lexvar.props[""].ignorable = true;
                          } else {
                              for (var i=1; i<decl.length; i++)
                              {
                                  var p = lexvar.props["!" + decl[i].name];
                                  if (p) p.ignorable = true;
                              }
                          }
                      } else if (d === s$$type) {
                          for (var i=2; i<decl.length; i++) {
                              var p = lexvar.props["!" + decl[i].name];
                              if (p) p.type = decl[1];
                          }
                      } else if (d === s$$return_type) {
                          d$$$42_function_type_info$42_[d$$$42_function_type_info$42_.length-1][""] = decl[1];
                      } else {
                          f$$warning("Invalid declaration");
                      }
                  } else {
                      f$$warning("Invalid declaration format");
                  }
              }
          }
          else if (f$$list$63_(x))
          {
              try {
                  var declsz = d$$$42_declarations$42_.length;

                  var wrapper = function(r) {
                      return r;
                  };
                  if (x.location)
                  {
                      if (d$$$42_debug$42_)
                      {
                          wrapper = function(r) {
                              return ("erl(" +
                                      "\"" + x.location.join(":") + "\"" +
                                      ",function(){return(" +
                                      r +
                                      ")})");
                          };
                      }
                  }
                  var f = x[0];
                  if (f$$symbol$63_(f))
                  {
                      if (f === s$$js_code)
                      {
                          if (x.length != 2 || !f$$string$63_(x[1]))
                              throw "js-code requires a string literal";
                          return x[1].replace(/d[a-z0-9_]*\$[a-zA-Z_$0-9]+/g,
                                              function(x) {
                                                  return "d" + (lexvar.get(x.substr(1)) || x).substr(1);
                                              });
                      }
                      else if (lexmacro.get(f.name))
                      {
                          var lmf = lexmacro.get(f.name);
                          if (lmf.arglist)
                          {
                              var caf = glob["f$$static_check_args"];
                              if (caf && caf!=42)
                                  caf(x, lmf);
                          }
                          var ouc = d$$$42_outgoing_calls$42_;
                          var oug = d$$$42_used_globals$42_;
                          d$$$42_outgoing_calls$42_ = {};
                          d$$$42_used_globals$42_ = {};
                          var macro_expansion = lmf.apply(glob, x.slice(1));
                          d$$$42_outgoing_calls$42_ = ouc;
                          d$$$42_used_globals$42_ = oug;
                          return wrapper(f$$js_compile(macro_expansion));
                      }
                      else if (glob["m" + f.name])
                      {
                          var gmf = glob["m" + f.name];
                          if (gmf.arglist)
                          {
                              var caf = glob["f$$static_check_args"];
                              if (caf && caf!=42)
                                  caf(x, glob["f" + f.name] || gmf);
                          }
                          var macro_expansion = gmf.apply(glob, x.slice(1));
                          return wrapper(f$$js_compile(macro_expansion));
                      }
                      else
                      {
                          var gf = glob["f" + f.name];
                          var lf = null;
                          if (!(lf = lexfunc.get(f.name)))
                          {
                              d$$$42_outgoing_calls$42_[f.name] = true;
                              if (!gf)
                              {
                                  f$$warning("Undefined function " + f$$demangle(f.name));
                              }
                              else if (gf.arglist)
                              {
                                  var caf = glob["f$$static_check_args"];
                                  if (caf && caf!=42)
                                      caf(x, gf);
                              }
                          }
                          else
                          {
                              var caf = glob["f$$static_check_args"];
                              if (caf && caf!=42)
                                  caf(x, lf);
                          }

                          var res = "f" + f.name + "(";
                          for (var i=1; i<x.length; i++)
                          {
                              if (i > 1) res += ",";
                              res += f$$js_compile(x[i]);
                          }
                          res += ")";
                          return wrapper(res);
                      }
                  }
                  else if (f$$list$63_(f))
                  {
                      var res = "((" + f$$js_compile(f) + ")(";
                      for (var i=1; i<x.length; i++)
                      {
                          if (i > 1) res += ",";
                          res += f$$js_compile(x[i]);
                      }
                      res += "))";
                      return wrapper(res);
                  }
                  else
                  {
                      throw new String("Invalid function call");
                  }
              }
              finally
              {
                  d$$$42_declarations$42_.length = declsz;
              }
          }
          else if ((typeof x) === "undefined")
          {
              return "undefined";
          }
          else
          {
              try
              {
                  return stringify(x);
              }
              catch(err)
              {
                  return "<" + x.constructor.name + ">";
              }
          }
      },
      [s$$x]);

///////////////////////////////////////////////////////////////////////////////////////////

d$$$42_spaces$42_ = " \t\r\n";
d$$$42_stopchars$42_ = "()\"";

defun("skip-spaces",
      "[[(skip-spaces src)]]\n" +
      "Keeps consuming characters from the char source [src] until it's exhausted or " +
      "until the current character is not included in [*spaces*].",
      function(src)
      {
          while(true)
          {
              while (d$$$42_spaces$42_.indexOf(src.s[src.i]) != -1)
                  src.i++;
              if (src.s[src.i] === ';')
              {
                  while (src.s[src.i] != undefined && src.s[src.i] != "\n")
                      src.i++;
              }
              else
              {
                  break;
              }
          }
      },
      [f$$intern("src")],["$$$42_space$42_"],[]);

defun("parse-stopping",
      "[[(parse-stopping x)]]\n" +
      "True if symbol parsing should stop before character [x] because [x] is [undefined] or " +
      "it's listed in [*stopchars*].",
      function f$$parse_stopping(c)
      {
          return (c === undefined ||
                  d$$$42_spaces$42_.indexOf(c) != -1 ||
                  d$$$42_stopchars$42_.indexOf(c) !=-1);
      },
      [f$$intern("src")],["$$$42_space$42_","$$$42_stopchars$42_"],[]);

defun("parse-number-or-symbol",
      "[[(parse-number-or-symbol src)]]\n" +
      "Parses a number or a symbol from character source [src] depending on if after the number "+
      "the next character is a stop character.",
      function(src)
      {
          var res = "";
          var oknum = false;
          if (src.s[src.i] === "-" || src.s[src.i] === "+")
              res += src.s[src.i++];
          while (src.s[src.i] >= "0" && src.s[src.i] <= "9")
          {
              oknum = true;
              res += src.s[src.i++];
          }
          if (src.s[src.i] === ".")
          {
              res += src.s[src.i++];
              while (src.s[src.i] >= "0" && src.s[src.i] <= "9")
              {
                  oknum = true;
                  res += src.s[src.i++];
              }
          }
          if (oknum && (src.s[src.i] == "e" || src.s[src.i] == "E"))
          {
              oknum = false;
              res += src.s[src.i++];
              if (src.s[src.i] == "-" || src.s[src.i] == "+")
                  res += src.s[src.i++];
              while (src.s[src.i] >= "0" && src.s[src.i] <= "9")
              {
                 oknum = true;
                 res += src.s[src.i++];
              }
          }
          if (oknum && f$$parse_stopping(src.s[src.i]))
              return parseFloat(res);
          while (!f$$parse_stopping(src.s[src.i]))
              res += src.s[src.i++];
          return f$$intern(res);
      },
      [f$$intern("src")],[],["$$parse_stopping"]);

defun("parse-delimited-list",
      "[[(parse-delimited-list src stop)]]\n" +
      "Parses a list of values from character source [src] stopping when next character is [stop] " +
      "also consuming this stopping character.",
      function(src, stop)
      {
          var res = [];
          f$$skip_spaces(src);
          var oldstops = d$$$42_stopchars$42_;
          d$$$42_stopchars$42_ += stop;
          while (src.s[src.i] != undefined && src.s[src.i] != stop)
          {
              try {
                  res.push(f$$read(src));
              } catch(err) {
                  if (err == "Value expected") {
                      f$$skip_spaces(src);
                      if (src.s[src.i] == stop) {
                          // Hack, after skipping a comment we found
                          // the stop character; just quit reading elements
                          // without errors
                          break;
                      }
                  }
                  throw err;
              }
              f$$skip_spaces(src);
          }
          d$$$42_stopchars$42_ = oldstops;
          if (src.s[src.i] != stop)
              throw new String(stringify(stop) + " expected");
          src.i++;
          return res;
      },
      [f$$intern("src"), f$$intern("stop")],
      ["$$$42_stopchars$42_"],
      ["$$skip_spaces", "$$read"]);

defun("make-source",
      "[[(make-source x &optional location)]]\n" +
      "Creates a character source that will produce the content of the specified string [x]." +
      " If the optional [location] is provided, debug traceback information will be added to " +
      " each form parsed from this character source (traceback information is used when " +
      " forms are compiled while `*debug*` is true).",
      function(s, location)
      {
          return ({"s":s.replace(/\r/g,""), i:0, location:location});
      },
      [s$$x, f$$intern("&optional"), f$$intern("location")],[],[]);

defun("parse-symbol",
      "[[(parse-symbol src &optional (start \"\"))]]\n" +
      "Parses a symbol from given source optionally considering a [start] prefix",
      function(src, start)
      {
          var res = start || "";
          while (!f$$parse_stopping(src.s[src.i]))
          {
              if (src.s[src.i] === "\\") src.i++;
              res += src.s[src.i++];
          }
          if (res === "")
              throw new String("Value expected");
          return f$$intern(res);
      },
      [f$$intern("src"), f$$intern("&optional"), f$$intern("start")],[],["$$intern", "$$parse_stopping"]);

d$$$42_hash_readers$42_ = { "'": function(src)
                            {
                                src.i++;
                                return [f$$intern("function"), f$$read(src)]
                            },

                            "\\": function(src)
                            {
                                src.i++;
                                return src.s[src.i++];
                            },

                            ".": function(src)
                            {
                                src.i++;
                                return f$$toplevel_eval(f$$read(src));
                            },

                            "|": function(src)
                            {
                                src.i++;
                                var balance = 1;
                                while (src.s[src.i] && balance != 0)
                                {
                                    var x = src.s[src.i++];
                                    if (x == "#")
                                    {
                                        if (src.s[src.i++] == "|") balance++;
                                    }
                                    else if (x == "|")
                                    {
                                        if (src.s[src.i++] == "#") balance--;
                                    }
                                }
                                return f$$read(src);
                            }
                          };

d$$$42_readers$42_ = { "|": function(src)
                       {
                           src.i++;
                           var res = "";
                           while (src.s[src.i] != undefined && src.s[src.i] != '|')
                           {
                               if (src.s[src.i] === '\\') src.i++;
                               res += src.s[src.i++];
                           }
                           if (src.s[src.i++] != '|') throw new String("'|' expected");
                           return f$$intern(res);
                       },

                       '"': function(src)
                       {
                           var i0 = src.i;
                           while (i0 > 0 && src.s[i0-1] != '\n') --i0;
                           src.i++;
                           var ilev = src.i - i0;
                           var res = "";
                           while (src.s[src.i] != undefined && src.s[src.i] != '"')
                           {
                               if (src.s[src.i] === '\\')
                               {
                                   src.i++;
                                   var c = src.s[src.i++];
                                   if (c === "n") res += "\n";
                                   else if (c === "b") res += "\b";
                                   else if (c === "t") res += "\t";
                                   else if (c === "n") res += "\n";
                                   else if (c === "v") res += "\v";
                                   else if (c === "f") res += "\f";
                                   else if (c === "r") res += "\r";
                                   else if (c === "0") {
                                       var oct = 0;
                                       while (src.s[src.i] >= "0" && src.s[src.i] <= "7")
                                           oct = oct*8 + (src.s[src.i++].charCodeAt(0) - 48);
                                       res += String.fromCharCode(oct);
                                   }
                                   else if (c === "x") {
                                       var hx1 = "0123456789ABCDEF".indexOf(src.s[src.i++].toUpperCase());
                                       var hx2 = "0123456789ABCDEF".indexOf(src.s[src.i++].toUpperCase());
                                       if (hx1 < 0 || hx2 < 0) throw new String("Invalid hex char escape");
                                       res += String.fromCharCode(hx1*16 + hx2);
                                   }
                                   else if (c === "u")
                                   {
                                       hx = 0;
                                       for (var i=0; i<4; i++)
                                       {
                                           var d = "0123456789ABCDEF".indexOf(src.s[src.i++].toUpperCase());
                                           if (d < 0) throw new String("Invalid unicode char escape");
                                           hx = hx*16 + d;
                                       }
                                       res += String.fromCharCode(hx);
                                   }
                                   else if (c === "\n")
                                   {
                                       // Indent-aware line continuation
                                       var i1 = src.i + ilev;
                                       while (src.s[src.i] === ' ' && src.i < i1)
                                           src.i++;
                                   }
                                   else
                                   {
                                       res += c;
                                   }
                               }
                               else if (src.s[src.i] === "\n")
                               {
                                   // Indent-aware newline
                                   res += src.s[src.i++];
                                   var i1 = src.i + ilev;
                                   while (src.s[src.i] === ' ' && src.i < i1)
                                       src.i++;
                               }
                               else
                               {
                                   res += src.s[src.i++];
                               }
                           }
                           if (src.s[src.i++] != '"') throw new String("'\"' expected");
                           return res;
                       },

                       "'": function(src)
                       {
                           src.i++;
                           return [f$$intern("quote"), f$$read(src)];
                       },

                       "`": function(src)
                       {
                           src.i++;
                           return [f$$intern("`"), f$$read(src)];
                       },

                       ",": function(src)
                       {
                           src.i++;
                           if (src.s[src.i] === '@')
                           {
                               src.i++;
                               return [f$$intern(",@"), f$$read(src)];
                           }
                           else
                           {
                               return [f$$intern(","), f$$read(src)];
                           }
                       },

                       "#": function(src)
                       {
                           src.i++;
                           var f = d$$$42_hash_readers$42_[src.s[src.i]];
                           if (f) return f(src);
                           throw new String("Unsupported hash combination");
                       },

                       "(": function(src)
                       {
                           var srcstart;
                           if (src.location)
                           {
                               // copy source location info if available
                               srcstart = [src.location, src.i];
                           }
                           src.i++;
                           var result = f$$parse_delimited_list(src, ")");
                           if (src.location)
                           {
                               // copy end of list source location info if available
                               srcstart.push(src.i);
                               result.location = srcstart;
                           }
                           return result;
                       },

                       "0": f$$parse_number_or_symbol,
                       "1": f$$parse_number_or_symbol,
                       "2": f$$parse_number_or_symbol,
                       "3": f$$parse_number_or_symbol,
                       "4": f$$parse_number_or_symbol,
                       "5": f$$parse_number_or_symbol,
                       "6": f$$parse_number_or_symbol,
                       "7": f$$parse_number_or_symbol,
                       "8": f$$parse_number_or_symbol,
                       "9": f$$parse_number_or_symbol,
                       "-": f$$parse_number_or_symbol,
                       "+": f$$parse_number_or_symbol,
                       ".": f$$parse_number_or_symbol,

                       "default": f$$parse_symbol
                     };

defun("read",
      "[[(read src)]]\n" +
      "Parses a value from the given character source or string.",
      function(src)
      {
          if (src.constructor === String)
              src = f$$make_source(src);
          f$$skip_spaces(src);
          if (src.s[src.i] === undefined)
              throw new String("Value expected");
          return (d$$$42_readers$42_[src.s[src.i]] || d$$$42_readers$42_["default"])(src);
      },
      [f$$intern("src")],
      ["$$$42_readers$42_","$$$42_hash_readers$42_"],
      ["$$make_source","$$skip_spaces"]);

defun("str-value",
      "[[(str-value x &optional (circle-print true))]]\n" +
      "Computes a string representation of the value [x], handling back-references.",
      function(x, circle_print)
      {
          if ((typeof circle_print) === "undefined" ||
              ((typeof circle_print) === "boolean" && circle_print))
              circle_print = [];
          if (f$$symbol$63_(x))
          {
              return x + "";
          }
          else if (f$$list$63_(x))
          {
              if (x.length === 2 && f$$symbol$63_(x[0]))
              {
                  if (x[0].name === "$$quote")
                      return "'" + f$$str_value(x[1], circle_print);
                  if (x[0].name === "$$function" &&
                      f$$symbol$63_(x[1]))
                      return "#'" + f$$demangle(x[1].name);
              }
              if ((typeof circle_print) === "object")
              {
                  if (circle_print.indexOf(x) != -1)
                      return "#" + circle_print.indexOf(x);
                  circle_print.push(x);
              }
              var res = "(";
              for (var i=0; i<x.length; i++)
              {
                  if (i > 0) res += " ";
                  res += f$$str_value(x[i], circle_print);
              }
              return res + ")";
          }
          else if (x && x.constructor === Function)
          {
              return "#CODE";
          }
          else if ((typeof x) === "undefined")
          {
              return "undefined";
          }
          else if ((typeof x) === "number" && isNaN(x))
          {
              return "NaN";
          }
          else if (x === Infinity)
          {
              return "infinity";
          }
          else if (x === -Infinity)
          {
              return "-infinity";
          }
          else
          {
              try
              {
                  return stringify(x);
              }
              catch(err)
              {
                  return "#<" + x.constructor.name + ">";
              }
          }
      },
      [s$$x, f$$intern("&optional"), f$$intern("circle-print")]);

defun("toplevel-eval",
      "[[(toplevel-eval x)]]\n"+
      "Evaluates the form or symbol [x] by macroexpanding, compiling and "+
      "executing it. If however the form to be compiled is a "+
      "[(progn/if/macrolet/symbol-macrolet ...)] "+
      "form then evaluation is performed by interpretation and recursive "+
      "[toplevel-eval] calls are used for body forms. "+
      "The main difference between [toplevel-eval] and [eval] "+
      "is about eventual macro and code side effects that can influence "+
      "compilation of subsequent forms in [(progn/macrolet/symbol-macrolet...)] and " +
      "that code in top-level conditional parts not being evaluated is also not compiled.",
      function(x)
      {
          // Ignore outgoing calls and used globals at toplevel
          var outc = d$$$42_outgoing_calls$42_;
          var ug = d$$$42_used_globals$42_;
          d$$$42_outgoing_calls$42_ = {};
          ug = {};

          var f, result;
          if (f$$symbol$63_(x))
          {
              if (x.symbol_macro)
                  return f$$toplevel_eval(x.symbol_macro);
              result = f$$eval(x);
          }
          else if (f$$list$63_(x))
          {
              if (x[0] === s$$progn)
              {
                  result = null;
                  for (var i=1; i<x.length; i++)
                      result = f$$toplevel_eval(x[i]);
              }
              else if (x[0] === s$$if)
              {
                  var caf = glob["f$$static_check_args"];
                  if (caf && caf!=42)
                      caf(x, m$$if);
                  if (f$$js_eval(f$$toplevel_eval(x[1])))
                  {
                      result = f$$toplevel_eval(x[2]);
                  }
                  else
                  {
                      result = f$$toplevel_eval(x[3]);
                  }
              }
              else if (x[0] === s$$macrolet)
              {
                  result = null;
                  domacrolet(x[1], x.slice(2), function(body) {
                      for (var i=0; i<body.length; i++)
                          result = f$$toplevel_eval(body[i]);
                  });
              }
              else if (x[0] === s$$symbol_macrolet)
              {
                  result = null;
                  dosymbolmacrolet(x[1], x.slice(2), function(body) {
                      for (var i=0; i<body.length; i++)
                          result = f$$toplevel_eval(body[i]);
                  });
              }
              else if (f$$symbol$63_(x[0]) && (f = glob["m" + x[0].name]))
              {
                  if (f.arglist)
                  {
                      var caf = glob["f$$static_check_args"];
                      if (caf && caf!=42)
                          caf(x, f);
                  }
                  result = f$$toplevel_eval(f.apply(glob, x.slice(1)));
              }
              else result = f$$eval(x);
          }
          else
          {
              result = f$$eval(x);
          }
          d$$$42_outgoing_calls$42_ = outc;
          d$$$42_used_globals$42_ = ug;
          return result;
      },
      [s$$x]);

defun("stack-trace",
      "[[(stack-trace location)]]\n"+
      "Displays a stack trace of specified error location stack in an "+
      "exception if that information is available or does nothing otherwise. "+
      "Stack trace information is enabled if at the time the code was "+
      "compiled the variable [*debug*] was [true] and if source filename "+
      "was provided. See {{load}}.",
      function(location)
      {
          if (location)
          {
              var filecache = {};
              f$$display("ERROR Location stack (innermost last):");
              for (var i=location.length-1; i>=0; i--)
              {
                  var fname = location[i][0];
                  var start = location[i][1];
                  var stop = location[i][2];
                  var file = (filecache[fname] ||
                              (filecache[fname] = f$$http_get(fname)));
                  var line = 1 + file.substr(0, start).replace(/[^\n]/g,"").length;
                  var fragment = file.substr(start, stop - start).replace(/[\r\n]/g, " ").replace(/ +/g, " ");
                  if (fragment.length > 50)
                      fragment = fragment.substr(0, 47) + " ...";
                  f$$display("  " + fname + " : " + line + " " + fragment);
              }
          }
      },
      [f$$intern("location")]);

defun("load",
      "[[(load src &optional name)]]\n" +
      "Parses, compiles and evaluates all forms in the character source or string [src] " +
      "one at a time in sequence. If [name] is passed and [src] is a string then source location information is attached to each parsed list.",
      function(src, name)
      {
          if (f$$string$63_(src))
              src = ({"s":src.replace(/\r/g,""), "i":0, "location": name});
          var nforms = 0;
          var last = null;
          try
          {
              f$$skip_spaces(src);
              while (src.s[src.i])
              {
                  var phase = "parsing";
                  var form = f$$read(src);
                  ++nforms;
                  phase = "toplevel-evaluating";
                  last = f$$toplevel_eval(form);
                  f$$skip_spaces(src);
              }
          }
          catch(err)
          {
              var werr = new String("Error during load (form=" + nforms + ", phase = " + phase + "):\n" +
                                    err + "\n" +
                                    ((phase != "parsing") ?
                                     f$$macroexpand_$49_(f$$str_value(form)) : ""));
              werr.location = err.location;
              f$$stack_trace(err.location);
              throw werr;
          }
          return last;
      },
      [f$$intern("src"), f$$intern("&optional"), f$$intern("name")]);

defun("http",
      "[[(http verb url data &optional success-function failure-function binary)]]\n" +
      "Executes the specified http request (\"GET\" or \"POST\") for the specified [url] " +
      "either asynchronously (if [success-function] is specified) or synchronously if no " +
      "callback is specified. The success function if specified will be passed " +
      "the content, the url and the request object. The failure function if specified " +
      "will be passed the url and the request status code in case of an error.",
      function(verb, url, data, onSuccess, onFail, binary)
      {
          var req = new XMLHttpRequest();
          if (onSuccess)
          {
              req.onreadystatechange = function()
              {
                  if (req.readyState === 4) {
                      if (req.status === 200) {
                          onSuccess(req.responseText, url, req);
                      }
                      else
                      {
                          if (onFail)
                              onFail(url, req.status);
                          else
                              throw new String("Ajax request error (url=" +
                                               url +
                                               ", status=" +
                                               req.status + ")");
                      }
                  }
              }
          }
          req.open(verb, url, !!onSuccess);
          if (binary)
          {
              var encoding = "text/plain; charset=x-user-defined";
              req.setRequestHeader("Content-type", encoding);
              if (req.overrideMimeType)
                  req.overrideMimeType(encoding);
          }
          req.send(data);
          return onSuccess ? req : req.responseText;
      },
      [f$$intern("verb"), f$$intern("url"), f$$intern("data"), f$$intern("&optional"),
       f$$intern("success-function"), f$$intern("failure-function"),
       f$$intern("binary")], [], []);

defun("http-get",
      "[[(http-get url &optional success-function failure-function binary)]]\n" +
      "Acquires the specified resource. Executes " +
      "either asynchronously (if [success-function] is specified) or synchronously if no " +
      "callback is specified. The success function if specified will be passed " +
      "the content, the url and the request object. The failure function if specified " +
      "will be passed the url and the request status code in case of an error.",
      function(url, onSuccess, onFailure, binary)
      {
          return f$$http("GET", url, null, onSuccess, onFailure, binary);
      },
      [f$$intern("url"), f$$intern("&optional"),
       f$$intern("success-function"), f$$intern("failure-function"),
       f$$intern("encoding")], [], ["$$http"]);

defun("get-file",
      "[[(get-file filename &optional (encoding \"utf-8\"))]]\n" +
      "Reads and returns the content of the specified file",
      function(name, encoding)
      {
          if (arguments.length === 1)
              encoding = "utf-8";
          var fs = require("fs");
          return fs.readFileSync(name, encoding);
      },
      [f$$intern("filename"), f$$intern("&optional"), f$$intern("encoding")], [], []);

defun("put-file",
      "[[(put-file filename data &optional (encoding \"utf-8\"))]]\n" +
      "Writes a file with specified [data]",
      function(name, data, encoding)
      {
          if (arguments.length === 2)
              encoding = "utf-8";
          var fs = require("fs");
          return fs.writeFileSync(name, data, encoding);
      },
      [f$$intern("filename"), f$$intern("data"), f$$intern("&optional"), f$$intern("encoding")], [], []);

defun("append-file",
      "[[(append-file filename data &optional (encoding \"utf-8\"))]]\n" +
      "Appends to a file the specified [data]",
      function(name, data, encoding)
      {
          if (arguments.length === 2)
              encoding = "utf-8";
          var fs = require("fs");
          return fs.appendFileSync(name, data, encoding);
      },
      [f$$intern("filename"), f$$intern("data"), f$$intern("&optional"), f$$intern("encoding")], [], []);

defun("delete-file",
      "[[(delete-file filename)]]\n" +
      "Removes (unlinks) the specified filename",
      function(name)
      {
          var fs = require("fs");
          return fs.unlinkSync(name);
      },
      [f$$intern("filename")], [], []);

if (d$$node_js)
{
    var fs = require("fs");
    f$$load(f$$get_file("boot.lisp"), "boot.lisp");
    for (var i=2; i<process.argv.length; i++)
    {
        var fname = process.argv[i];
        if (fname[0] == "(") {
            f$$toplevel_eval(f$$read(fname));
        } else {
            f$$load(f$$get_file(fname), fname);
        }
    }
    clearInterval(watchdog);
}
