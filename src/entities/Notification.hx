
package entities;

import luxe.Color;
import luxe.Text;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Scene;
import luxe.options.TextOptions;
import snow.api.Promise;

typedef NotificationOptions = {
    > TextOptions,
    duration :Float
}

typedef ToastOptions = {
    text :String,
    scene :Scene,
    ?pos :Vector,
    ?color :Color,
    ?duration :Float,
    ?randomOffset :Float,
    ?randomRotation :Float,
    ?textSize :Int
}

class Notification extends Text {
    var duration :Float;
    var textShadow :Text;
    var promise :Promise;
    var promise_func :Void->Void;
    // var background :luxe.Sprite;

    public function new(options :NotificationOptions) {
        super(options);
        textShadow = new Text(options);
        textShadow.pos.x += 1;
        textShadow.pos.y += 1;
        textShadow.color = new Color(0, 0, 0);
        textShadow.depth -= 1;
        duration = options.duration;
        // background = new luxe.Sprite({
        //     color: new Color(1, 1, 1, 0.0),
        //     size: new Vector(this.geom.text_width, this.geom.text_height),
        //     depth: this.depth - 2,
        //     parent: this,
        //     scene: options.scene
        // });
        promise = new Promise(function(resolve, reject) {
            promise_func = resolve;
        });
    }

    override function init() {
        Actuate.tween(color, duration, { a: 0 });
        // Actuate.tween(background.color, duration, { a: 0 });
        Actuate.tween(textShadow.color, duration, { a: 0 });
        Actuate.tween(textShadow.pos, duration, { y: pos.y - 100 });
        Actuate
            .tween(pos, duration, { y: pos.y - 100 })
            .onComplete(times_up);
    }

    function times_up() {
        promise_func();
        destroy();
    }

    public function get_promise() :Promise {
        return promise;
    }

    static public function Toast(options :ToastOptions) :Notification {
        var pos = (options.pos != null ? options.pos : Luxe.screen.mid.clone());
        var offset = (options.randomOffset != null ? options.randomOffset : 10);
        var rotation = (options.randomRotation != null ? options.randomRotation : 0);
        var textSize = (options.textSize != null ? options.textSize : 24);
        return new Notification({
            pos: new Vector(pos.x - (offset / 2) + offset * Math.random(), pos.y - (offset / 2) + offset * Math.random()),
            text: options.text,
            color: (options.color != null ? options.color : new Color(1, 1, 1)),
            point_size: textSize,
            align: TextAlign.center,
            align_vertical: TextAlign.center,
            rotation_z: (- (rotation / 2) + rotation * Math.random()),
            scene: options.scene,
            depth: 1000,
            duration: (options.duration != null ? options.duration : 3)
        });
    }
}
