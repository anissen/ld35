package states;

import luxe.Input;
import luxe.Vector;
import luxe.Color;

import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Polygon;
import nape.shape.Circle;
import nape.constraint.PivotJoint;

import luxe.AppConfig;
import luxe.physics.nape.DebugDraw;

class PlayState extends luxe.States.State {
    static public var StateId :String = 'PlayState';
    var drawer : DebugDraw;
    var cut_start :Vec2;
    var impulse = 900;
    var countdown :Float = 1;
    var shapes_cut :Int = 0;
    var min_countdown :Float = 0.8;
    var lives :Array<luxe.Sprite>;
    var shapes :Array<Array<Vec2>>;
    var game_over :Bool;
    // var last_positions :Array<luxe.Vector>;
    var trail :components.TrailRenderer;
    var cursor_entity :luxe.Entity;

    var score :Int;
    var score_text :luxe.Text;

    var particleSystem :luxe.Particles.ParticleSystem;
    var emitter :luxe.Particles.ParticleEmitter;

    var particleSystem2 :luxe.Particles.ParticleSystem;
    var emitter2 :luxe.Particles.ParticleEmitter;

    public function new() {
        super({ name: StateId });
    }

    override function init() {
        parse_svg();
        Luxe.physics.nape.space.gravity.setxy(0, 100);
    } //ready

    override function onenter(data) {
        reset_world();
    }

    override function onleave(data) {
        Luxe.scene.empty();
    }

    function parse_svg() {
        var shapes_file = Luxe.resources.text('assets/shapes/shapes.svg');
        var xml :Xml = Xml.parse(shapes_file.asset.text);

        shapes = [];
        for (svg in xml.elementsNamed('svg')) {
            for (path in svg.elementsNamed('path')) {
                var points = [];
                var d = path.get('d');
                var coords = d.substr(1, d.length - 2).split('L');
                for (coord in coords) {
                    var c = coord.split(',');
                    points.push(new Vec2(Std.parseInt(c[0]), Std.parseInt(c[1])));
                }
                points.pop();
                shapes.push(points);
            }
            for (rect in svg.elementsNamed('rect')) {
                shapes.push(Polygon.box(Std.parseInt(rect.get('width')), Std.parseInt(rect.get('height'))));
            }
        }
    }

    function reset_world() {
        luxe.tween.Actuate.reset();
        Luxe.scene.empty();

        if(drawer != null) {
            drawer.destroy();
            drawer = null;
        }

        drawer = new DebugDraw();
        Luxe.physics.nape.debugdraw = drawer;

        shapes_cut = 0;
        game_over = false;

        lives = [];
        var ui_margin = 75;
        for (i in 0 ... 3) {
            var life = new luxe.Sprite({
                pos: new Vector(ui_margin + i * 75, ui_margin),
                scale: new Vector(0.5, 0.5),
                texture: Luxe.resources.texture('assets/images/heart.png')
            });
            lives.push(life);
        }

        score = 0;
        score_text = new luxe.Text({
            pos: new Vector(Luxe.screen.w - ui_margin, ui_margin - 10),
            text: '0',
            align: luxe.Text.TextAlign.right,
            align_vertical: luxe.Text.TextAlign.top,
            point_size: 45,
            color: new Color(1, 0.0, 0.2)
        });

        cursor_entity = new luxe.Visual({
            name: 'cursor',
            geometry: Luxe.draw.circle({
                r: 5
            }),
            depth: 10
        });
        cursor_entity.pos = Luxe.screen.mid.clone();
        trail = new components.TrailRenderer({ name: 'TrailRenderer' });
        trail.trailColor.a = 0.02;
        cursor_entity.add(trail);

        var particle_data1 = Luxe.resources.json('assets/particle_systems/fireworks.json').asset.json;
        var particle_data2 = Luxe.resources.json('assets/particle_systems/fireflies.json').asset.json;
        particleSystem = load_particle_system(particle_data1, emitter);
        particleSystem2 = load_particle_system(particle_data2, emitter2);
        particleSystem2.start();

        // if (particleSystem2 != null) {
        //     particleSystem2.start();
        // }
        // last_positions = [];
    } //reset_world

    override function onmouseup(e :MouseEvent) {
        if (game_over) return;
        var cut_end = new Vec2(e.pos.x, e.pos.y);

        Luxe.draw.line({
            p0: new luxe.Vector(cut_start.x, cut_start.y),
            p1: e.pos.clone(),
            color: new luxe.Color(1, 0, 0, 0.1),
            depth: -1
        });

        // cursor_entity.remove('TrailRenderer');
        trail.trailColor.h = 200;
        trail.maxLength = 150;
        trail.trailColor.a = 0.02;
        // speedup_timer = 0;
        luxe.tween.Actuate.tween( Luxe, 0.3, { timescale: 1 });
        var cut_diff = cut_end.sub(cut_start);

        var bodies = raycast_bodies(cut_start, cut_end);
        for (body in bodies) {
            var shape = body.shapes.at(0);
            var geomPoly = new nape.geom.GeomPoly(shape.castPolygon.worldVerts);
    		var geomPolyList :nape.geom.GeomPolyList = geomPoly.cut(cut_start, cut_end, true, true);
            if (geomPolyList.length == 0) continue;

            shapes_cut++;

            var color = drawer.geometry[shape].active_color;
            var min_area = 10000.0;
            for (cutGeom in geomPolyList) {
                var cutBody = new Body(BodyType.DYNAMIC);

                var shape = new Polygon(cutGeom);
                var area = cutGeom.area();
                var area_diff = (area / geomPoly.area());
                var unfinished_cut = (area_diff < Math.max(0.9 - shapes_cut * 0.005, 0.6));
                min_area = Math.min(area, min_area);

                if (unfinished_cut) play_sound('glitch.wav', body.position.x);

                shape.filter.collisionGroup = (unfinished_cut ? 0 : 1);

				cutBody.shapes.add(shape);
                cutBody.align();

                // ignore pieces that are too small
    			// if (cutBody.bounds.width < 2 && cutBody.bounds.height < 2) continue;

    			cutBody.space = Luxe.physics.nape.space;
                cutBody.velocity.set(body.velocity);
                // cutBody.group = null; //new nape.dynamics.InteractionGroup(true);

                var active_color = color.clone();
                if (unfinished_cut) active_color.a = 0.1;
                drawer.add(cutBody, active_color);

                var power = 0.4 + 0.6 * Math.random();
    			cutBody.applyImpulse(cut_diff.muleq(power));
            }

            var diff = (min_area * geomPolyList.length) / geomPoly.area();
            var percent_diff = Math.round(diff * 100);

            score += percent_diff;
            score_text.text = '$score';

            var pos = new luxe.Vector(body.position.x, body.position.y);
            particleSystem.pos = pos;
            particleSystem.start(1);

            play_sound('slice.wav', pos.x);

            entities.Notification.Toast({
                text: '$percent_diff%',
                scene: Luxe.scene,
                pos: pos,
                color: new luxe.Color(1 - diff, diff, 0),
                randomRotation: 20,
                textSize: Math.floor(14 + diff * 20)
            });

            Luxe.camera.shake(diff * 10);
            Luxe.events.fire('chroma');
            // particleSystem.

            drawer.remove(body);
            body.space = null;
        }

        cut_start.dispose();
        cut_start = null;
        cut_end.dispose();
    } //onmouseup

    // override function onmousemove(e :MouseEvent) {
    //     cursor_entity.pos.x += e.xrel;
    //     cursor_entity.pos.y += e.yrel;
    // }

    function play_sound(sound :String, ?x :Float) {
        var handle = Luxe.audio.play(Luxe.resources.audio('assets/sounds/$sound').source);
        Luxe.audio.pan(handle, x / Luxe.screen.w);
    }

    override function onmousedown( e:MouseEvent ) {
        if (game_over) return;
        var slow_timescale = 0.5;
        luxe.tween.Actuate.tween(Luxe, 0.3, { timescale: slow_timescale });
        // speedup_timer = 3 * slow_timescale;
        cut_start = Vec2.get(e.pos.x, e.pos.y);
        trail.trailColor.h = 20;
        trail.maxLength = 200;
        trail.trailColor.a = 1;

        // var diff = luxe.Vector.Subtract(trail.points[1], trail.points[0]).normalized;
        // cursor_entity.pos = diff.multiplyScalar(100);
        // cut(cut_start.copy(), new Vec2(cursor_entity.pos.x, cursor_entity.pos.y));
    } //onmousedown

    function raycast_bodies(start :Vec2, end :Vec2) {
        var ray = nape.geom.Ray.fromSegment(start, end);
        var bodies = [];
        if (ray.maxDistance > 5) {
            for (rayResult in Luxe.physics.nape.space.rayMultiCast(ray)) {
                var body = rayResult.shape.body;
                if (!body.isDynamic()) continue;
                if (body.contains(end)) continue;
                if (body.shapes.at(0).filter.collisionGroup == 0) continue;
                bodies.push(body);
            }
        }
        return bodies;
    }

    override function update(dt :Float) {
        if (game_over) return;
        countdown -= dt;
        if (countdown <= 0) {
            countdown = Math.max(2 - shapes_cut * 0.02, min_countdown);

            var box = new Body(BodyType.DYNAMIC);
            var randomShape = shapes[Math.floor(shapes.length * Math.random())];
            box.shapes.add(new Polygon(randomShape));
            box.scaleShapes(15 + 10 * Math.random(), 15 + 10 * Math.random());
            box.align();
            box.mass = 2;
            box.rotation = Math.PI * 2 * Math.random();
            box.angularVel = (-5 + 10 * Math.random());
            var xpos = Luxe.screen.w * Math.random();
            box.position.setxy(xpos, (Luxe.screen.h + 200));
            box.space = Luxe.physics.nape.space;

            var center = new Vec2(Luxe.screen.mid.x, Luxe.screen.mid.y);
            var diff = center.sub(box.position);
            box.applyImpulse(diff.normalise().muleq(impulse));

            var color = new luxe.Color.ColorHSL(360 * Math.random(), 1, 0.5);
            drawer.add(box, color);

            var color2 = color.clone();
            color2.h = (color2.h + 100) % 360;
            color2.s = 0.1;
            color2.l = 0.1;
            var rgbColor = color2.toColor();
            Luxe.renderer.clear_color.tween(2.0, { r: rgbColor.r, g: rgbColor.g, b: rgbColor.b });

            play_sound('spawn.wav', xpos);
        }

        cursor_entity.pos = Luxe.screen.cursor.pos;
        particleSystem2.pos = Luxe.screen.cursor.pos;
        // trail.maxLength -= dt;

        // if (speedup_timer > 0) {
        //     speedup_timer -= dt;
        // } else {
        //     Luxe.timescale += dt * 2;
        //     if (Luxe.timescale > 1) {
        //         Luxe.timescale = 1;
        //     }
        // }

        for (body in Luxe.physics.nape.space.bodies) {
            var lost = (body.velocity.y > 0 && body.bounds.min.y > Luxe.screen.h) ||
                (body.bounds.max.x < 0) || (body.bounds.min.x > Luxe.screen.w);
            if (lost) {
                drawer.remove(body);
                body.space = null;

                if (body.shapes.at(0).filter.collisionGroup != 0) {
                    var life = lives.pop();
                    if (life != null) {
                        life.destroy();
                    }
                    if (life == null || lives.length == 0) {
                        game_over = true;
                        Luxe.timescale = 0.000001;
                        entities.Notification.Toast({
                            text: 'Game over!\nScore: $score\n\nPress any key to restart',
                            scene: Luxe.scene,
                            pos: Luxe.screen.mid.clone(),
                            color: new luxe.Color(1, 0, 0),
                            textSize: 34
                        });
                        play_sound('lost.wav', Luxe.screen.mid.x);
                        Luxe.camera.shake(20);
                        return;
                    }
                    entities.Notification.Toast({
                        text: 'Life Lost!',
                        scene: Luxe.scene,
                        pos: Luxe.screen.mid.clone(),
                        color: new luxe.Color(1, 0, 0),
                        textSize: 34
                    });
                    play_sound('lost.wav', Luxe.screen.mid.x);
                    Luxe.camera.shake(10);
                }
            }
        }

        if (cut_start != null) {
            Luxe.draw.line({
                p0: new luxe.Vector(cut_start.x, cut_start.y),
                p1: Luxe.screen.cursor.pos,
                color: new luxe.Color(1, 1, 1),
                depth: 2000,
                immediate: true
            });

            for (body in Luxe.physics.nape.space.bodies) {
                var shape = body.shapes.at(0);
                if (shape.filter.collisionGroup == 0) continue;
                drawer.geometry[shape].active_color.a = 0.6;
                drawer.geometry[shape].inactive_color.a = 0.5;
            }
            var hits = raycast_bodies(cut_start, Vec2.get(Luxe.screen.cursor.pos.x, Luxe.screen.cursor.pos.y));
            for (body in hits) {
                var shape = body.shapes.at(0);
                drawer.geometry[shape].active_color.a = 1.0;
                drawer.geometry[shape].inactive_color.a = 0.7;
            }
        }
    }

    override function onkeyup( e:KeyEvent ) {
        if (game_over) {
            Luxe.physics.nape.space.clear();
            reset_world();
        }
        if (e.keycode == Key.key_r) {
            Luxe.physics.nape.space.clear();
            reset_world();
        }
    }

    function load_particle_system(json :Dynamic, emitter :luxe.Particles.ParticleEmitter) :luxe.Particles.ParticleSystem {
        var emitter_template :luxe.options.ParticleOptions.ParticleEmitterOptions = {
            // name: 'template',
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
        emitter_template.particle_image = Luxe.resources.texture('assets/images/circle.png');

        var particles = new luxe.Particles.ParticleSystem();
        particles.add_emitter(emitter_template);
        emitter = particles.emitters.get(emitter_template.name);
        particles.stop();
        return particles;
    }
} //Main
