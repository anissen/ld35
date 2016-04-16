
import luxe.States;
import luxe.Input.KeyEvent;
import luxe.Input.Key;

import states.*;

import phoenix.Batcher.BlendMode;
import phoenix.RenderTexture;
import phoenix.Texture;
import phoenix.Batcher;
import phoenix.Shader;
import luxe.Sprite;
import luxe.Vector;
import luxe.Color;

class PostProcess {
    var output: RenderTexture;
    var batch: Batcher;
    var view: Sprite;
    public var shader: Shader;

    public function new(shader :Shader) {
        output = new RenderTexture({ id: 'render-to-texture', width: Luxe.screen.w, height: Luxe.screen.h });
        batch = Luxe.renderer.create_batcher({ no_add: true });
        this.shader = shader;
        view = new Sprite({
            no_scene: true,
            centered: false,
            pos: new Vector(0,0),
            size: Luxe.screen.size,
            texture: output,
            shader: shader, //Luxe.renderer.shaders.textured.shader,
            batcher: batch
        });
    }

    public function toggle() {
        view.shader = (view.shader == shader ? Luxe.renderer.shaders.textured.shader : shader);
    }

    public function prerender() {
        Luxe.renderer.target = output;
        Luxe.renderer.clear(new Color(0,0,0,1));
    }

    public function postrender() {
        Luxe.renderer.target = null;
        Luxe.renderer.clear(new Color(1,0,0,1));
        Luxe.renderer.blend_mode(BlendMode.src_alpha, BlendMode.zero);
        batch.draw();
        Luxe.renderer.blend_mode();
    }
}

class Main extends luxe.Game {
    static public var states :States;
    var fullscreen :Bool = false;
    var postprocess :PostProcess;

    override function config(config :luxe.AppConfig) {
        config.preload.textures.push({ id: 'assets/images/luxe.png' });
        config.preload.jsons.push({ id: 'assets/particle_systems/fireworks.json' });
        config.preload.sounds.push({ id: 'assets/sounds/sound.ogg', is_stream: false });
        config.preload.shaders.push({ id: 'postprocess', frag_id: 'assets/shaders/postprocess.glsl', vert_id: 'default' });
        config.preload.texts.push({ id: 'assets/shapes/shapes.svg' });

        if(config.user.window != null) {
            if(config.user.window.width != null) {
                config.window.width = Std.int(config.user.window.width);
            }
            if(config.user.window.height != null) {
                config.window.height = Std.int(config.user.window.height);
            }
        }

        config.render.antialiasing = 4;
        return config;
    }

    override function ready() {
        trace('Built ${MacroHelper.CompiledAt()}');

        Luxe.renderer.batcher.on(prerender, function(_) { Luxe.renderer.state.lineWidth(3); });
        Luxe.renderer.batcher.on(postrender, function(_) { Luxe.renderer.state.lineWidth(1); });

        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        // Luxe.renderer.clear_color.set(1, 1, 1);

        states = new States({ name: 'state_machine' });
        // states.add(new MenuState());
        states.add(new PlayState());
        states.set(PlayState.StateId);

        var shader = Luxe.resources.shader('postprocess');
        shader.set_vector2('resolution', Luxe.screen.size);
        postprocess = new PostProcess(shader);
        // postprocess.toggle();
    }

    // Scale camera's viewport accordingly when game is scaled, common and suitable for most games
	override function onwindowsized(e: luxe.Screen.WindowEvent) {
        Luxe.camera.viewport = new luxe.Rectangle(0, 0, e.x, e.y);
    }

    override function onkeyup(e :KeyEvent) {
        if (e.keycode == Key.enter && e.mod.alt) {
            fullscreen = !fullscreen;
            Luxe.snow.runtime.window_fullscreen(fullscreen, true /* true-fullscreen */);
        } else if (e.keycode == Key.key_s) {
            postprocess.toggle();
        }
        #if desktop
        if (e.keycode == Key.escape) {
            if (!Luxe.core.shutting_down) Luxe.shutdown();
        }
        #end
    }

    override function onprerender() {
        if (postprocess != null) postprocess.prerender();
    }

    override function update(dt :Float) {
        if (postprocess != null) postprocess.shader.set_float('time', Luxe.core.tick_start + dt);
    }

    override function onpostrender() {
        if (postprocess != null) postprocess.postrender();
    }
}
