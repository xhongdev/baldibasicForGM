function bb_detail_meshes(_meshes, _dy = 0, _wall = "", _map = undefined) {
    if (array_length(_meshes)==0) return;
    if (!variable_global_exists("detail_cache")) global.detail_cache={};
    var _scene=variable_struct_exists(global.E,"source_scene")?global.E.source_scene:"School";
    var _key=_scene+"|"+_meshes[0].source_id+"|"+_wall+"|"+(is_undefined(_map)?"":_map.texture);
    if (!variable_struct_exists(global.detail_cache,_key)) {
        var _groups={};
        for (var _i=0; _i<array_length(_meshes); _i++) {
            var _q=_meshes[_i],_m=_q;
            if (_q.source_id==_wall && !is_undefined(_map)) _m=_map;
            var _group_key="texture:"+_m.texture;
            if (!variable_struct_exists(_groups,_group_key)) {
                var _vb=vertex_create_buffer();vertex_begin(_vb,global.vf_3d);
                _groups[$ _group_key]={vb:_vb,tex:(_m.texture=="")?-1:sprite_get_texture(global.PS[$ _m.texture],0)};
            }
            var _batch=_groups[$ _group_key];
            if (variable_struct_exists(_q,"triangles")) {
                for (var _vi=0; _vi<array_length(_q.triangles); _vi++) {
                    var _v=_q.triangles[_vi];
                    bb3d_vert(_batch.vb,_v[0],_v[1],_v[2],0,1,0,_v[3]*_m.uv[0]+_m.uv[2],_v[4]*_m.uv[1]+_m.uv[3],_m.colour,1);
                }
            } else bb3d_emit_vertices(_batch.vb,_q.v,_m.uv,_m.colour);
        }
        var _names=variable_struct_get_names(_groups),_batches=[];
        for (var _i=0; _i<array_length(_names); _i++) {
            var _batch=_groups[$ _names[_i]];
            vertex_end(_batch.vb);vertex_freeze(_batch.vb);array_push(_batches,_batch);
        }
        global.detail_cache[$ _key]=_batches;
    }
    bb3d_world_filter(true);
    gpu_set_cullmode(cull_clockwise);
    gpu_set_zwriteenable(true);
    gpu_set_texrepeat(true);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(16);
    matrix_set(matrix_world, matrix_build(0, _dy, 0, 0, 0, 0, 1, 1, 1));
    var _batches=global.detail_cache[$ _key];
    for (var _i=0; _i<array_length(_batches); _i++) vertex_submit(_batches[_i].vb,pr_trianglelist,_batches[_i].tex);
    matrix_set(matrix_world, matrix_build_identity());
    gpu_set_cullmode(cull_noculling);
    gpu_set_texrepeat(false);
    bb3d_world_filter(false);
}

function bb_draw_entrances() {
    for (var _i = 0; _i < array_length(global.G.exits); _i++) {
        var _e = global.G.exits[_i], _s = _e.source;
        bb_detail_meshes(_s.meshes, _e.down ? -2 : 0, _s.wall, _e.used ? _s.map : undefined);
    }
}

function bb_detail_wall(_b, _dy, _furniture=false) {
    if (_furniture) { if (_b[1]+_dy>=1.6 || _b[4]+_dy<=0.1) return; }
    else if (_b[1]+_dy >= 1 || _b[4]+_dy <= 1) return;
    var _xt = (_b[3]-_b[0] < 0.001) ? 0.08 : 0;
    var _zt = (_b[5]-_b[2] < 0.001) ? 0.08 : 0;
    array_push(global.walls, {x0:_b[0]-_xt, z0:_b[2]-_zt, x1:_b[3]+_xt, z1:_b[5]+_zt,sight:(_b[1]+_dy<1 && _b[4]+_dy>1)});
}

function bb_refresh_details() {
    global.walls = variable_clone(global.static_walls);
    var _school_details = !variable_struct_exists(global.map, "scene") || global.map.scene == "School";
    if (_school_details) {
        var _keys = variable_struct_get_names(global.P.details.props);
        for (var _i = 0; _i < array_length(_keys); _i++) {
            var _prop = global.P.details.props[$ _keys[_i]];
            for (var _j = 0; _j < array_length(_prop.colliders); _j++) bb_detail_wall(_prop.colliders[_j], 0);
        }
        for (var _i = 0; _i < array_length(global.G.exits); _i++) {
            var _e = global.G.exits[_i];
            for (var _j = 0; _j < array_length(_e.source.colliders); _j++) bb_detail_wall(_e.source.colliders[_j], _e.down ? -2 : 0);
        }
    }
    for (var _i=0; _i<array_length(global.E.colliders); _i++) bb_detail_wall(global.E.colliders[_i],0,true);
    bb_spatial_build();
    var _signature=0;
    for (var _i=0; _i<array_length(global.G.exits); _i++) if (global.G.exits[_i].down) _signature|=(1<<_i);
    if (variable_global_exists("path_ready") && global.path_ready && global.path_signature!=_signature) {
        // Entrance meshes are dynamic render/collision details.  The authored
        // floor graph is already built from the 682 walkable floor regions;
        // rebuilding the dense half-unit grid here caused a visible hitch on
        // the first wrong answer and on every exit trigger.
        global.path_signature=_signature;
        if (variable_global_exists("nav_routes")) global.nav_routes=[];
    }
}

function bb_draw_environment() {
    bb_detail_meshes(global.E.meshes);
    for (var _i=0; _i<array_length(global.E.billboards); _i++) {
        var _b=global.E.billboards[_i];
        if (bb_dist2(global.G.px,global.G.pz,_b.x,_b.z)>1600) continue;
        if (variable_struct_exists(_b,"deform")) {
            var _texture=_b.frames[0].texture;
            for (var _fi=1;_fi<array_length(_b.frames);_fi++) {
                if (_b.frames[_fi].time>global.G.secret_time) break;
                _texture=_b.frames[_fi].texture;
            }
            bb3d_draw_deformed_billboard(global.PS[$ _texture],_b.deform,global.G.yaw);
            continue;
        }
        bb3d_draw_billboard(global.PS[$ _b.texture],0,_b.x,_b.y,_b.z,_b.w,_b.h,global.G.px,global.G.pz,c_white);
    }
}

function bb_exit_lower(_e, _used) {
    _e.down = true;
    _e.used = _used;
    // Clamp to the hall side if a fast move or debug teleport crossed the closing wall.
    var _g = global.G, _s = _e.source, _b = _s.wall_bounds;
    var _cx = (_b[0]+_b[3])*0.5, _cz = (_b[2]+_b[5])*0.5;
    var _dx = sign(_cx-_s.origin[0]), _dz = sign(_cz-_s.origin[2]);
    var _along = (_g.px-_cx)*_dx + (_g.pz-_cz)*_dz;
    var _across = abs((_g.px-_cx)*_dz - (_g.pz-_cz)*_dx);
    if (_across < 3.5 && _along > -_g.radius-0.1 && _along < 5) {
        _g.px -= _dx * (_along+_g.radius+0.12);
        _g.pz -= _dz * (_along+_g.radius+0.12);
    }
}

function bb_exit_box_hit(_b, _x0, _z0, _x1, _z1, _r) {
    if (bb_aabb_hit(_x1, _z1, _r, _b[0], _b[2], _b[3], _b[5])) return true;
    return bb_ray_box(_x0, _z0, _x1-_x0, _z1-_z0, _b[0]-_r, _b[2]-_r, _b[3]+_r, _b[5]+_r) <= 1;
}

function bb_win_game() {
    var _g = global.G;
    if (_g.win) return;
    _g.win = true; _g.over_t = 0;
    _g.win_exit_delay = 0; _g.end_requested = false;
    var _channels = variable_struct_get_names(_g.voices);
    for (var _i = 0; _i < array_length(_channels); _i++) bb_voice_clear(_channels[_i]);
    audio_stop_all();
    _g.finale_sound = -1; _g.finale_switch = -1; _g.finale_loop = false;
    var _audio = global.P.details.win_audio;
    _g.win_sound = bb_sound_play(global.S.clips[$ _audio.guid], false, 10, _audio.gain);
    window_mouse_set_locked(false); window_set_cursor(cr_default);
}

function bb_boots_rect(_time) {
    if (_time < 0 || (_time >= 2 && _time < 15) || _time >= 17) return undefined;
    var _r = variable_clone(global.P.details.hud.boots.rect);
    _r[1] += (_time < 2) ? 375*_time : 750-375*(_time-15);
    return _r;
}

function bb_draw_hud_effects() {
    var _g = global.G, _hud = global.P.details.hud;
    if (_g.detention > 0) bb_yctp_text("You have detention! \n" + string(ceil(_g.detention)) + " seconds remain!", _hud.detention, false, false);
    if (_g.play_lock > 0) {
        bb_draw_rope(640, 480);
        bb_yctp_text(_hud.rope_instruction.text, _hud.rope_instruction, false, false);
        bb_yctp_text(string(5-_g.play_need) + "/5", _hud.rope_count, false, false);
    }
    var _r = bb_boots_rect(_g.boot_anim);
    if (!is_undefined(_r)) bb_ui_texture(_hud.boots.texture, _r);
}
