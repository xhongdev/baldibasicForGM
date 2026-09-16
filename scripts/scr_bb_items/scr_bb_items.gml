// Classic 1.4.3 item IDs match GameControllerScript.UseItem (empty slot is -1).
function bb_collect_item(_kind) {
    var _g = global.G;
    var _slot = bb_inv_free();
    if (_slot == -1) _slot = _g.inv_sel;
    _g.inv[_slot] = _kind;
}

// Exact ray/AABB entry distance, used for both targeting and wall occlusion.
function bb_ray_box(_x, _z, _dx, _dz, _x0, _z0, _x1, _z1) {
    var _lo = 0, _hi = 100000;
    if (abs(_dx) < 0.000001) {
        if (_x < _x0 || _x > _x1) return 100000;
    } else {
        var _a = (_x0 - _x) / _dx, _b = (_x1 - _x) / _dx;
        _lo = max(_lo, min(_a, _b));
        _hi = min(_hi, max(_a, _b));
    }
    if (abs(_dz) < 0.000001) {
        if (_z < _z0 || _z > _z1) return 100000;
    } else {
        var _a = (_z0 - _z) / _dz, _b = (_z1 - _z) / _dz;
        _lo = max(_lo, min(_a, _b));
        _hi = min(_hi, max(_a, _b));
    }
    return (_hi >= _lo) ? _lo : 100000;
}

function bb_target_point(_hit, _kind, _index, _x, _z, _radius, _fx, _fz) {
    var _dx = _x - global.G.px, _dz = _z - global.G.pz;
    var _along = _dx * _fx + _dz * _fz;
    var _across = abs(_dx * _fz - _dz * _fx);
    if (_along >= 0 && _along < _hit.distance && _across <= _radius) {
        _hit.kind = _kind;
        _hit.index = _index;
        _hit.distance = _along;
    }
}

function bb_view_yaw() {
    var _g = global.G;
    return _g.yaw + ((keyboard_check(vk_space) && _g.play_lock <= 0) ? pi : 0);
}

function bb_interaction_target(_range) {
    var _g = global.G;
    var _yaw = bb_view_yaw();
    var _fx = -sin(_yaw), _fz = -cos(_yaw);
    var _hit = {kind: "", index: -1, distance: _range + 0.0001};
    for (var _i = 0; _i < array_length(global.walls); _i++) {
        var _w = global.walls[_i];
        // Furniture below the camera blocks movement, but not the horizontal
        // interaction ray to a notebook resting on its top.
        if (variable_struct_exists(_w, "sight") && !_w.sight) continue;
        _hit.distance = min(_hit.distance, bb_ray_box(_g.px, _g.pz, _fx, _fz, _w.x0, _w.z0, _w.x1, _w.z1));
    }
    // Door jambs remain solid when the door is open.
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (_d.kind == "swing" || variable_struct_exists(_d, "v")) continue;
        for (var _s = -1; _s <= 1; _s += 2) {
            var _b = bb_door_jamb_box(_d, _s);
            _hit.distance = min(_hit.distance, bb_ray_box(_g.px, _g.pz, _fx, _fz, _b[0], _b[1], _b[2], _b[3]));
        }
    }
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        var _b = bb_door_box(_g.doors[_i]);
        var _t = bb_ray_box(_g.px, _g.pz, _fx, _fz, _b[0], _b[1], _b[2], _b[3]);
        if (_t < _hit.distance) {
            _hit = {kind: "door", index: _i, distance: _t};
        }
    }
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        if (!_n.taken) bb_target_point(_hit, "notebook", _i, _n.x, _n.z, 0.28, _fx, _fz);
    }
    for (var _i = 0; _i < array_length(_g.items); _i++) {
        var _it = _g.items[_i];
        if (!_it.taken) bb_target_point(_hit, "item", _i, _it.x, _it.z, 0.22, _fx, _fz);
    }
    for (var _i = 0; _i < array_length(_g.props); _i++) {
        var _p = _g.props[_i];
        if (!_p.active || bb_dist2(_g.px, _g.pz, _p.x, _p.z) > _range * _range) continue;
        // Vending machines are solid. Target the same front surface that
        // occludes the ray, rather than their center behind that surface.
        var _colliders = _p.detail.colliders;
        for (var _ci = 0; _ci < array_length(_colliders); _ci++) {
            var _b = _colliders[_ci];
            var _t = bb_ray_box(_g.px, _g.pz, _fx, _fz, _b[0], _b[2], _b[3], _b[5]);
            if (_t <= _hit.distance + 0.0001) _hit = {kind:"prop", index:_i, distance:_t};
        }
        bb_target_point(_hit, "prop", _i, _p.x, _p.z, _p.w * 0.5, _fx, _fz);
    }
    for (var _i = 0; _i < array_length(_g.npcs); _i++) {
        var _n = _g.npcs[_i];
        if (_n.live && _n.visible) bb_target_point(_hit, "npc", _i, _n.x, _n.z, 0.35, _fx, _fz);
    }
    return _hit;
}

function bb_office_door() {
    var _best = -1, _dist = 100000;
    for (var _i = 0; _i < array_length(global.G.doors); _i++) {
        var _d = global.G.doors[_i];
        if (_d.kind == "swing") continue;
        var _dd = bb_dist2(_d.x, _d.z, 6, -32);
        if (_dd < _dist) { _dist = _dd; _best = _i; }
    }
    return _best;
}

function bb_use_item() {
    var _g = global.G;
    var _kind = _g.inv[_g.inv_sel];
    if (_kind < 1) return false;
    var _hit = bb_interaction_target(2);
    var _used = false;
    switch (_kind) {
        case 1:
            _g.stamina = _g.stamina_max * 2;
            _used = true;
            break;
        case 2:
            if (_hit.kind == "door") {
                var _d = _g.doors[_hit.index];
                if (_d.kind == "swing") {
                    _d.lock_cd = 15;
                    _d.locked = true;
                    _d.open = false;
                    _used = true;
                }
            }
            break;
        case 3:
            if (_hit.kind == "door") {
                var _d = _g.doors[_hit.index];
                if (_d.kind != "swing" && (_d.locked || _d.lock_cd > 0)) {
                    _d.lock_cd = 0;
                    _d.locked = false;
                    bb_door_try_open(_d, true);
                    if (_hit.index == bb_office_door()) _g.detention = 0;
                    _used = true;
                }
            }
            break;
        case 4:
            var _yaw = bb_view_yaw();
            array_push(_g.sprays, {x: _g.px, z: _g.pz, dx: -sin(_yaw), dz: -cos(_yaw), life: 30});
            if (_g.guilt <= 1) { _g.guilt = 1; _g.guilt_type = "drink"; }
            bb_sound_play(global.S.aud_Soda);
            _used = true;
            break;
        case 5:
        case 6:
            if (_hit.kind == "prop") {
                var _p = _g.props[_hit.index];
                if (_kind == 5 && (_p.kind == "soda" || _p.kind == "zesty")) {
                    var _product = (_p.kind == "soda") ? 4 : 1;
                    if (_g.debug.items) {
                        var _slot = bb_inv_free();
                        if (_slot == -1) _slot = (_g.inv_sel+1) mod 3;
                        _g.inv[_slot] = _product;
                    } else {
                        _g.inv[_g.inv_sel] = -1;
                        bb_collect_item(_product);
                    }
                    return true;
                }
                if ((_kind == 5 && _p.kind == "phone") || (_kind == 6 && _p.kind == "tape")) {
                    _p.playing = 30;
                    if (_g.baldi_active) {
                        _g.anti_hear = 30;
                        _g.hear_pri = 0;
                        bb_baldi_wander();
                    }
                    audio_stop_sound(snd_antihearing);
                    audio_play_sound(snd_antihearing, 2, false);
                    _used = true;
                }
            }
            break;
        case 7:
            var _alarm = global.P.details.alarm_drop;
            var _tick = global.S.clips[$ _alarm.tick_audio];
            array_push(_g.alarms, {x: _g.px, z: _g.pz, time: 30, life: 35, rang: false,
                sound: bb_world_loop(_tick, _g.px, _g.pz, 2, 100)});
            _used = true;
            break;
        case 8:
            if (_hit.kind == "door" && _g.doors[_hit.index].kind != "swing") {
                _g.doors[_hit.index].silent_opens = 4;
                bb_sound_play(global.S.aud_Spray);
                _used = true;
            }
            break;
        case 9:
            if (_g.play_lock > 0) {
                bb_end_playtime("cut");
                _used = true;
            } else if (_hit.kind == "npc" && _g.npcs[_hit.index].kind == "prize") {
                _g.npcs[_hit.index].crazy = 15;
                _g.npcs[_hit.index].spd = 0;
                _used = true;
            }
            break;
        case 10:
            _g.boots = 15;
            _g.boot_anim = 0;
            _used = true;
            break;
    }
    if (_used && !_g.debug.items) _g.inv[_g.inv_sel] = -1;
    return _used;
}

function bb_update_item_effects(_dt) {
    var _g = global.G;
    _g.boots = max(0, _g.boots - _dt);
    if (_g.boot_anim >= 0) {
        _g.boot_anim += _dt;
        if (_g.boot_anim >= 17) _g.boot_anim = -1;
    }
    _g.anti_hear = max(0, _g.anti_hear - _dt);
    for (var _i = 0; _i < array_length(_g.props); _i++) {
        _g.props[_i].playing = max(0, _g.props[_i].playing - _dt);
    }
    for (var _i = array_length(_g.alarms) - 1; _i >= 0; _i--) {
        var _a = _g.alarms[_i];
        _a.time -= _dt;
        _a.life -= _dt;
        if (_a.sound != -1 && audio_is_playing(_a.sound)) {
            audio_sound_gain(_a.sound, bb_world_gain(_a.x, _a.z, 100), 0);
        }
        if (!_a.rang && _a.time <= 0) {
            _a.rang = true;
            if (_a.sound != -1) audio_stop_sound(_a.sound);
            if (_g.baldi_active) bb_hear_pri(_a.x, _a.z, 8);
            var _ring = global.P.details.alarm_drop.ring_audio;
            _a.sound = bb_world_sound(global.S.clips[$ _ring], _a.x, _a.z, 3, 100);
        }
        if (_a.life <= 0) {
            if (_a.sound != -1) audio_stop_sound(_a.sound);
            array_delete(_g.alarms, _i, 1);
        }
    }
}

function bb_prop_spr(_kind) {
    switch (_kind) {
        case "soda": return spr_prop_soda;
        case "zesty": return spr_prop_zesty;
        case "phone": return spr_prop_phone;
        case "tape": return spr_prop_tape;
    }
    return -1;
}

function bb_draw_item_world() {
    var _g = global.G;
    for (var _i = 0; _i < array_length(_g.props); _i++) {
        var _p = _g.props[_i];
        if (!_p.active) continue;
        if (array_length(_p.detail.meshes) > 0) {
            bb_detail_meshes(_p.detail.meshes);
            continue;
        }
        var _spr = (_p.kind == "tape" && _p.playing > 0) ? spr_prop_tape_closed : _p.spr;
        bb3d_draw_billboard(_spr, 0, _p.x, _p.y, _p.z, _p.w, _p.h, _g.px, _g.pz, c_white);
    }
    for (var _i = 0; _i < array_length(_g.alarms); _i++) {
        var _a = _g.alarms[_i];
        var _drop = global.P.details.alarm_drop;
        bb3d_draw_billboard(global.PS[$ _drop.texture], 0, _a.x, _drop.y, _a.z,
            _drop.w, _drop.h, _g.px, _g.pz, c_white);
    }
}

function bb_start_playtime() {
    var _g = global.G;
    _g.play_lock = 1;
    _g.play_need = 5;
    _g.rope_delay = 1;
    _g.rope_time = 0;
    _g.rope_wait_sound = -1;
    _g.rope_wait_time = 0;
    _g.jump_height = 0;
    _g.jump_velocity = 0;
    _g.rope_message = "Ready? Jump with SPACE!";
    bb_playtime_sound("aud_ReadyGo");
}

function bb_playtime_sound(_name, _index=-1) {
    for (var _i=0; _i<array_length(global.G.npcs); _i++) {
        var _n=global.G.npcs[_i];
        if (_n.kind=="playtime") return bb_ai_sound(_n,_name,true,_index);
    }
    return -1;
}

function bb_end_playtime(_reason="release") {
    var _g = global.G;
    _g.play_lock = 0;
    _g.rope_wait_sound = -1;
    _g.rope_wait_time = 0;
    _g.jump_height = 0;
    _g.jump_velocity = 0;
    for (var _i = 0; _i < array_length(_g.npcs); _i++) {
        if (_g.npcs[_i].kind == "playtime") _g.npcs[_i].cool = 15;
    }
    if (_reason=="cut") bb_playtime_sound("aud_Sad");
    if (_reason=="success") bb_playtime_sound("aud_Congrats");
}

function bb_rope_tick(_dt, _jump) {
    var _g = global.G;
    // CameraScript: velocity 5, gravity 10 in Unity's five-times-larger world.
    if (_jump && _g.jump_height <= 0) _g.jump_velocity = 1;
    if (_g.rope_wait_time > 0) {
        if (_g.rope_wait_sound != -1) {
            if (audio_is_playing(_g.rope_wait_sound)) return;
            _g.rope_wait_time = 0;
        } else {
            _g.rope_wait_time = max(0, _g.rope_wait_time-_dt);
        }
        if (_g.rope_wait_time > 0) return;
        _g.rope_wait_sound = -1;
        _g.rope_delay = 0.01;
    }
    while (_dt > 0.000001 && _g.play_lock > 0) {
        var _step = min(_dt, 0.01);
        _dt -= _step;
        _g.jump_height = max(0, _g.jump_height + _g.jump_velocity * _step - _step * _step);
        _g.jump_velocity -= 2 * _step;
        if (_g.jump_height <= 0) _g.jump_velocity = 0;
        if (_g.rope_delay > 0) {
            _g.rope_delay -= _step;
            if (_g.rope_delay <= 0) {
                _g.rope_time = 1;
                _g.rope_message = "Jump!";
            }
        } else {
            _g.rope_time -= _step;
            if (_g.rope_time <= 0) {
                if (_g.jump_height > 0.04) {
                    _g.play_need -= 1;
                    _g.rope_delay = 0.5;
                    if (_g.play_need <= 0) bb_end_playtime("success");
                    else bb_playtime_sound("aud_Numbers",4-_g.play_need);
                } else {
                    _g.play_need = 5;
                    _g.rope_wait_time = audio_sound_length(global.S.clips[$ global.E.npcs.playtime.audio.aud_Oops]);
                    _g.rope_delay = _g.rope_wait_time;
                    _g.rope_message = "Oops! Try again!";
                    _g.rope_wait_sound = bb_playtime_sound("aud_Oops");
                }
            }
        }
    }
}

function bb_draw_rope(_w, _h) {
    var _g = global.G;
    if (_g.rope_delay > 0 || _g.rope_wait_sound != -1) return;
    var _phase = 1 - clamp(_g.rope_time, 0, 1);
    var _frames = global.P.details.rope_frames, _texture = _frames[0].texture;
    for (var _i = 1; _i < array_length(_frames); _i++) {
        if (_frames[_i].time > _phase) break;
        _texture = _frames[_i].texture;
    }
    bb_ui_texture(_texture, global.P.details.hud.rope.rect);
}
