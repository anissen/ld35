
package states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Sprite;
import luxe.Color;

using Lambda;

class MenuState extends State {
    static public var StateId :String = 'MenuState';

    public function new() {
        super({ name: StateId });
    }

    override function onenter(data :Dynamic) {
        var min_size = Math.min(Luxe.screen.w, Luxe.screen.h);
        var logo = new Sprite({
            pos: Luxe.screen.mid.clone(),
            texture: Luxe.resources.texture('assets/images/logo.png'),
            size: new Vector(min_size, min_size),
            color: new Color(1, 1, 1)
        });
        logo.color.a = 0;
        luxe.tween.Actuate.tween(logo.color, 2, { a: 1 });
        luxe.tween.Actuate.tween(logo.color, 2, { r: 0.5 }).reflect().repeat();
        luxe.tween.Actuate.tween(logo.color, 3, { g: 0.5 }).reflect().repeat();
        luxe.tween.Actuate.tween(logo.color, 4, { b: 0.5 }).reflect().repeat();
    }

    override function onleave(data) {
        Luxe.scene.empty();
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        Main.states.set(InfoState.StateId);
    }

    override public function onkeyup(event :luxe.Input.KeyEvent) {
        Main.states.set(InfoState.StateId);
    }
}
