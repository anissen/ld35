
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
        //the debug drawer
    var drawer : DebugDraw;

    var cut_start :Vec2;

        //the impulse to apply when pressing arrows
    var impulse = 900;

    var countdown :Float = 1;

    var shapes :Array<Array<Vec2>>;

    override function ready() {

        Luxe.renderer.batcher.on(prerender, function(_) { Luxe.renderer.state.lineWidth(2); });
        Luxe.renderer.batcher.on(postrender, function(_) { Luxe.renderer.state.lineWidth(1); });

        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        parse_svg();

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
                // var points = [];
                // var d = path.get('d');
                // var coords = d.substr(1, d.length - 2).split('L');
                // for (coord in coords) {
                //     var c = coord.split(',');
                //     points.push(new Vec2(Std.parseInt(c[0]), Std.parseInt(c[1])));
                //     trace('Point: ' + Std.parseInt(c[0]) + ', ' + Std.parseInt(c[1]));
                // }
                // points.pop();
                // shapes.push(points);
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

        // config.preload.textures.push({ id: 'assets/images/tex.png' });
        config.preload.texts.push({ id: 'assets/shapes/shapes.svg' });

        config.render.antialiasing = 4;

        return config;

    } //config

    function reset_world() {
        if(drawer != null) {
            drawer.destroy();
            drawer = null;
        }

        //create the drawer, and assign it to the nape debug drawer
        drawer = new DebugDraw();
        Luxe.physics.nape.debugdraw = drawer;

        Luxe.physics.nape.space.gravity.setxy(0, 100);
    } //reset_world

    override function onmouseup( e:MouseEvent ) {
        luxe.tween.Actuate.tween( Luxe, 0.3, { timescale: 1 });
        var cut_end = Vec2.get(e.pos.x, e.pos.y);
        var cut_diff = cut_end.sub(cut_start);

        var bodies = raycast_bodies(cut_start, cut_end);
        for (body in bodies) {
            var geomPoly = new nape.geom.GeomPoly(body.shapes.at(0).castPolygon.worldVerts);
            trace('Original area: ' + geomPoly.area());
    		var geomPolyList :nape.geom.GeomPolyList = geomPoly.cut(cut_start, cut_end, true, true);

            for (cutGeom in geomPolyList) {
                var cutBody = new Body(BodyType.DYNAMIC);
				// cutBody.setShapeMaterials(Material.steel());

				cutBody.shapes.add(new Polygon(cutGeom));
                cutBody.align();

                // ignore pieces that are too small
    			if (cutBody.bounds.width < 2 && cutBody.bounds.height < 2) continue;

    			cutBody.space = Luxe.physics.nape.space;
                cutBody.velocity.set(body.velocity);
                drawer.add(cutBody);

                // trace('cut area: ' + cutPoly.area);

                var power = 0.3 + 0.4 * Math.random();
                // apply small random impulse
    			cutBody.applyImpulse(cut_diff.muleq(power));
            }

            drawer.remove(body);
            body.space = null;
        }

        cut_start.dispose();
        cut_start = null;
        cut_end.dispose();
    } //onmouseup

    override function onmousedown( e:MouseEvent ) {
        luxe.tween.Actuate.tween( Luxe, 0.3, { timescale: 0.1 });
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
                bodies.push(body);
            }
        }
        return bodies;
    }

    override function update(dt :Float) {
        countdown -= dt;
        if (countdown <= 0) {
            countdown = 3;

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

            // var end = Vec2.get(Luxe.screen.cursor.pos.x, Luxe.screen.cursor.pos.y);
            // var ray = nape.geom.Ray.fromSegment(cut_start, end);
            // if (ray.maxDistance > 5) {
            //     for (rayResult in Luxe.physics.nape.space.rayMultiCast(ray)) {
            //         var body = rayResult.shape.body;
            //         if (!body.isDynamic()) continue;
            //         if (body.contains(end)) continue;
            //         var shape = body.shapes.at(0);
            //         drawer.geometry[shape].active_color.set(canCut ? 1 : 0, !canCut ? 1 : 0, 0);
            //         drawer.geometry[shape].inactive_color.set(0, canCut ? 1 : 0, !canCut ? 1 : 0);
            //     }
            // }
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
