
import luxe.Input;

import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Polygon;
import nape.shape.Circle;
import nape.constraint.PivotJoint;

import luxe.AppConfig;
import luxe.physics.nape.DebugDraw;

class Main extends luxe.Game {
    var drawer : DebugDraw;
    var cut_start :Vec2;
    var impulse = 1000;
    var countdown :Float = 1;
    var shapes_cut :Int = 0;
    var min_countdown :Float = 0.8;
    var shapes :Array<Array<Vec2>>;

    override function ready() {
        Luxe.renderer.batcher.on(prerender, function(_) { Luxe.renderer.state.lineWidth(3); });
        Luxe.renderer.batcher.on(postrender, function(_) { Luxe.renderer.state.lineWidth(1); });

        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        parse_svg();
        Luxe.physics.nape.space.gravity.setxy(0, 100);

        reset_world();
    } //ready

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
                    trace('Point: ' + Std.parseInt(c[0]) + ', ' + Std.parseInt(c[1]));
                }
                points.pop();
                shapes.push(points);
            }
            for (rect in svg.elementsNamed('rect')) {
                shapes.push(Polygon.box(Std.parseInt(rect.get('width')), Std.parseInt(rect.get('height'))));
            }
        }
    }

    //overriding the built in function to configure the default window
    override function config( config:AppConfig ) : AppConfig {
        if(config.user.window != null) {
            if(config.user.window.width != null) {
                config.window.width = Std.int(config.user.window.width);
            }
            if(config.user.window.height != null) {
                config.window.height = Std.int(config.user.window.height);
            }
        }

        config.preload.texts.push({ id: 'assets/shapes/shapes.svg' });
        config.render.antialiasing = 4;
        return config;

    } //config

    function reset_world() {
        if(drawer != null) {
            drawer.destroy();
            drawer = null;
        }

        drawer = new DebugDraw();
        Luxe.physics.nape.debugdraw = drawer;

        shapes_cut = 0;
    } //reset_world

    override function onmouseup( e:MouseEvent ) {
        // speedup_timer = 0;
        luxe.tween.Actuate.tween( Luxe, 0.3, { timescale: 1 });
        var cut_end = Vec2.get(e.pos.x, e.pos.y);
        var cut_diff = cut_end.sub(cut_start);

        var bodies = raycast_bodies(cut_start, cut_end);
        for (body in bodies) {
            var geomPoly = new nape.geom.GeomPoly(body.shapes.at(0).castPolygon.worldVerts);
            trace('Original area: ' + geomPoly.area());
    		var geomPolyList :nape.geom.GeomPolyList = geomPoly.cut(cut_start, cut_end, true, true);
            if (geomPolyList.length == 0) continue;

            shapes_cut++;

            var min_area = 10000.0;
            for (cutGeom in geomPolyList) {
                var cutBody = new Body(BodyType.DYNAMIC);

                var shape = new Polygon(cutGeom);
                var area = cutGeom.area();
                min_area = Math.min(area, min_area);

                shape.filter.collisionGroup = 0; // when cut enough

				cutBody.shapes.add(shape);
                cutBody.align();

                // ignore pieces that are too small
    			// if (cutBody.bounds.width < 2 && cutBody.bounds.height < 2) continue;

    			cutBody.space = Luxe.physics.nape.space;
                cutBody.velocity.set(body.velocity);
                // cutBody.group = null; //new nape.dynamics.InteractionGroup(true);

                var active_color = new luxe.Color().rgb(0xf6007b);
                active_color.a = 0.1; // when cut enough
                drawer.add(cutBody, active_color);


                var power = 0.4 + 0.6 * Math.random();
    			cutBody.applyImpulse(cut_diff.muleq(power));
            }

            var diff = (min_area * geomPolyList.length) / geomPoly.area();
            var percent_diff = Math.round(diff * 100);
            entities.Notification.Toast({
                text: '$percent_diff%',
                scene: Luxe.scene,
                pos: new luxe.Vector(body.position.x, body.position.y),
                color: new luxe.Color(1 - diff, diff, 0),
                randomRotation: 20,
                textSize: Math.floor(14 + diff * 20)
            });

            Luxe.camera.shake(diff * 10);

            drawer.remove(body);
            body.space = null;
        }

        cut_start.dispose();
        cut_start = null;
        cut_end.dispose();
    } //onmouseup

    override function onmousedown( e:MouseEvent ) {
        var slow_timescale = 0.6;
        luxe.tween.Actuate.tween(Luxe, 0.3, { timescale: slow_timescale });
        // speedup_timer = 3 * slow_timescale;
        cut_start = Vec2.get(e.pos.x, e.pos.y);
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
        countdown -= dt;
        if (countdown <= 0) {
            countdown = Math.max(2 - shapes_cut * 0.05, min_countdown);

            var box = new Body(BodyType.DYNAMIC);
            var randomShape = shapes[Math.floor(shapes.length * Math.random())];
            box.shapes.add(new Polygon(randomShape));
            box.scaleShapes(20, 20);
            box.mass = 2;
            box.rotation = Math.PI * 2 * Math.random();
            box.position.setxy(Luxe.screen.w * Math.random(), (Luxe.screen.h + 200));
            box.space = Luxe.physics.nape.space;

            var center = new Vec2(Luxe.screen.mid.x, Luxe.screen.mid.y);
            var diff = center.sub(box.position);
            box.applyImpulse(diff.normalise().muleq(impulse));

            drawer.add(box);
        }

        // if (speedup_timer > 0) {
        //     speedup_timer -= dt;
        // } else {
        //     Luxe.timescale += dt * 2;
        //     if (Luxe.timescale > 1) {
        //         Luxe.timescale = 1;
        //     }
        // }

        for (body in Luxe.physics.nape.space.bodies) {
            if (body.velocity.y > 0 && body.bounds.min.y > Luxe.screen.h) {
                trace('body lost!');
                drawer.remove(body);
                body.space = null;
            }
        }

        if (cut_start != null) {
            Luxe.draw.line({
                p0: new luxe.Vector(cut_start.x, cut_start.y),
                p1: Luxe.screen.cursor.pos,
                color: new luxe.Color(1, 1, 1),
                immediate: true
            });

            for (body in Luxe.physics.nape.space.bodies) {
                var shape = body.shapes.at(0);
                drawer.geometry[shape].active_color.set(1, 0, 1);
                drawer.geometry[shape].inactive_color.set(0, 1, 1);
            }
            var hits = raycast_bodies(cut_start, Vec2.get(Luxe.screen.cursor.pos.x, Luxe.screen.cursor.pos.y));
            for (body in hits) {
                var shape = body.shapes.at(0);
                drawer.geometry[shape].active_color.set(1, 0, 0);
                drawer.geometry[shape].inactive_color.set(0, 1, 0);
            }
        }
    }

    override function onkeyup( e:KeyEvent ) {
        if(e.keycode == Key.key_r) {
            Luxe.physics.nape.space.clear();
            reset_world();
        }

        if(e.keycode == Key.key_g) {
            Luxe.physics.nape.draw = !Luxe.physics.nape.draw;
        }
    } //onkeyup
} //Main
