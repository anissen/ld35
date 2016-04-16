
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;

import game.ds.MapData;
import game.ds.GridLayout;

using Lambda;

class PlayState extends State {
    static public var StateId :String = 'PlayState';

    var particleSystem :luxe.Particles.ParticleSystem;
    var emitter :luxe.Particles.ParticleEmitter;

    public function new() {
        super({ name: StateId });
    }

    override function onenter(data :Dynamic) {

    }

    function play_sound(sound :String, ?x :Int) {
        var handle = Luxe.audio.play(Luxe.resources.audio('assets/sounds/$sound').source);
        if (x == null) return;
        Luxe.audio.pan(handle, map_data.layout.get_width() / (x + 1));
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {

    }

    override function onrender() {

    }

    function load_particle_system(json :Dynamic) :luxe.Particles.ParticleSystem {
        var emitter_template :luxe.options.ParticleOptions.ParticleEmitterOptions = {
            name: 'template',
            emit_time: json.emit_time,
            emit_count: json.emit_count,
            direction: json.direction,
            direction_random: json.direction_random,
            speed: json.speed,
            speed_random: json.speed_random,
            end_speed: json.end_speed,
            life: json.life,
            life_random: json.life_random,
            rotation: json.zrotation,
            rotation_random: json.rotation_random,
            end_rotation: json.end_rotation,
            end_rotation_random: json.end_rotation_random,
            rotation_offset: json.rotation_offset,
            pos_offset: new Vector(json.pos_offset.x, json.pos_offset.y),
            pos_random: new Vector(json.pos_random.x, json.pos_random.y),
            gravity: new Vector(json.gravity.x, json.gravity.y),
            start_size: new Vector(json.start_size.x, json.start_size.y),
            start_size_random: new Vector(json.start_size_random.x, json.start_size_random.y),
            end_size: new Vector(json.end_size.x, json.end_size.y),
            end_size_random: new Vector(json.end_size_random.x, json.end_size_random.y),
            start_color: new Color(json.start_color.r, json.start_color.g, json.start_color.b, json.start_color.a),
            end_color: new Color(json.end_color.r, json.end_color.g, json.end_color.b, json.end_color.a)
        };

        var particles = new luxe.Particles.ParticleSystem({
            name: 'particles',
            scene: keepScene
        });
        particles.add_emitter(emitter_template);
        emitter = particles.emitters.get('template');
        particles.stop();
        return particles;
    }

    override public function onkeyup(event :luxe.Input.KeyEvent) {

    }
}
