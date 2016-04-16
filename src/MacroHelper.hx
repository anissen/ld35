import haxe.macro.Expr;
import haxe.macro.Context;

// from https://github.com/MarcWeber/haxe-macro-examples

class MacroHelper {
    macro static public function CompiledAt() :Expr {
        var now_str = Date.now().toString();
        return { expr: EConst(CString(now_str)), pos : Context.currentPos() };
    }
}
