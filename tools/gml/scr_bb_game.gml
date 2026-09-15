function bb_game_init() {
    if (!variable_global_exists("vf_3d")) {
        bb3d_init();
    }
    if (!variable_global_exists("spr_wave")) {
        global.spr_wave = array_create(100, spr_baldi_idle);
        global.spr_slap = array_create(5, spr_baldi_idle);
    }
    if (!variable_global_exists("fnt_ui")) {
        global.fnt_ui = -1;
        global.fnt_small = -1;
        global.fnt_big = -1;
    }
    var _raw = bb_read_text("school_map.json");
    global.map = json_parse(_raw);
    bb3d_build_map(global.map);
    bb_build_collision(global.map);

    var _p = global.map.player;
    var _t = global.map.tutor;
    global.G = {
        px: _p[0],
        py: 1.0,
        pz: _p[2],
        yaw: 0,
        vx: 0,
        vz: 0,
        radius: 0.28,
        speed: 2.0,
        run_mul: 1.85,
        stamina: 100,
        stamina_max: 100,
        notebooks: 0,
        notebooks_needed: 7,
        state: "play",
        yctp_q: 0,
        yctp_a: 0,
        yctp_b: 0,
        yctp_op: "+",
        yctp_ans: 0,
        yctp_input: "",
        yctp_feedback: 0,
        yctp_corrupt: false,
        yctp_timer: 0,
        yctp_wrong: 0,
        pause: false,
        gameover: false,
        win: false,
        over_t: 0,
        mouse_ready: false,
        tutor_x: _t[0],
        tutor_y: _t[1],
        tutor_z: _t[2],
        tutor_wave: true,
        tutor_frame: 0,
        tutor_done: false,
        baldi_active: false,
        baldi_x: _t[0],
        baldi_y: 0.82,
        baldi_z: _t[2],
        baldi_anger: 0,
        baldi_cd: 1.5,
        baldi_frame: 0,
        baldi_moving: false,
        doors: [],
        notebooks_list: [],
        items: [],
        npcs: [],
        inv: [-1, -1, -1],
        inv_sel: 0,
        locked_until: 2,
        exit_open: false
    };

    var _doors = global.map.doors;
    var _i;
    for (_i = 0; _i < array_length(_doors); _i++) {
        var _d = _doors[_i];
        array_push(global.G.doors, {
            x: _d.x,
            z: _d.z,
            side: _d.side,
            open: false,
            t: 0,
            lock_cd: 0,
            kind: _d.kind
        });
    }

    var _nbs = global.map.notebooks;
    for (_i = 0; _i < array_length(_nbs); _i++) {
        var _n = _nbs[_i];
        array_push(global.G.notebooks_list, {
            x: _n.x,
            y: 0.55,
            z: _n.z,
            taken: false,
            spr: asset_get_index(_n.spr)
        });
    }

    var _items = global.map.items;
    for (_i = 0; _i < array_length(_items); _i++) {
        var _it = _items[_i];
        array_push(global.G.items, {
            x: _it.x,
            y: 0.35,
            z: _it.z,
            taken: false,
            kind: _it.kind,
            spr: asset_get_index(_it.spr)
        });
    }

    var _npcs = global.map.npcs;
    for (_i = 0; _i < array_length(_npcs); _i++) {
        var _npc = _npcs[_i];
        array_push(global.G.npcs, {
            x: _npc.x,
            y: _npc.y,
            z: _npc.z,
            kind: _npc.kind,
            spr: asset_get_index(_npc.spr),
            dir: random(360),
            wait: random(2),
            w: _npc.w,
            h: _npc.h
        });
    }

    audio_stop_all();
    audio_play_sound(snd_mus_school, 1, true);
    audio_play_sound(snd_bal_hi, 2, false);
    window_set_cursor(cr_none);
    window_mouse_set_locked(true);
}

function bb_build_collision(_map) {
    global.walls = [];
    global.floors = ds_map_create();
    var _i;
    var _quads = _map.quads;
    var _t = 0.07;
    for (_i = 0; _i < array_length(_quads); _i++) {
        var _q = _quads[_i];
        if (_q.k == "floor") {
            ds_map_set(global.floors, bb_key(_q.x, _q.z), 1);
        } else if (_q.k == "n") {
            array_push(global.walls, {x0: _q.x - 1, z0: _q.z - 1 - _t, x1: _q.x + 1, z1: _q.z - 1 + _t, door: false});
        } else if (_q.k == "s") {
            array_push(global.walls, {x0: _q.x - 1, z0: _q.z + 1 - _t, x1: _q.x + 1, z1: _q.z + 1 + _t, door: false});
        } else if (_q.k == "w") {
            array_push(global.walls, {x0: _q.x - 1 - _t, z0: _q.z - 1, x1: _q.x - 1 + _t, z1: _q.z + 1, door: false});
        } else if (_q.k == "e") {
            array_push(global.walls, {x0: _q.x + 1 - _t, z0: _q.z - 1, x1: _q.x + 1 + _t, z1: _q.z + 1, door: false});
        }
    }
}

function bb_blocked(_px, _pz, _r) {
    var _i;
    for (_i = 0; _i < array_length(global.walls); _i++) {
        var _w = global.walls[_i];
        if (bb_aabb_hit(_px, _pz, _r, _w.x0, _w.z0, _w.x1, _w.z1)) {
            return true;
        }
    }
    var _g = global.G;
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (_d.open) {
            continue;
        }
        var _box = bb_door_box(_d);
        if (bb_aabb_hit(_px, _pz, _r, _box[0], _box[1], _box[2], _box[3])) {
            return true;
        }
    }
    if (!bb_on_floor(_px, _pz)) {
        return true;
    }
    return false;
}

function bb_door_box(_d) {
    var _t = 0.08;
    switch (_d.side) {
        case "n": return [_d.x - 1, _d.z - 1 - _t, _d.x + 1, _d.z - 1 + _t];
        case "s": return [_d.x - 1, _d.z + 1 - _t, _d.x + 1, _d.z + 1 + _t];
        case "w": return [_d.x - 1 - _t, _d.z - 1, _d.x - 1 + _t, _d.z + 1];
        default: return [_d.x + 1 - _t, _d.z - 1, _d.x + 1 + _t, _d.z + 1];
    }
}

function bb_on_floor(_px, _pz) {
    var _tx = round(_px / 2) * 2;
    var _tz = round(_pz / 2) * 2;
    var _dx, _dz;
    for (_dx = -2; _dx <= 2; _dx += 2) {
        for (_dz = -2; _dz <= 2; _dz += 2) {
            if (ds_map_exists(global.floors, bb_key(_tx + _dx, _tz + _dz))) {
                var _fx = _tx + _dx;
                var _fz = _tz + _dz;
                if (_px >= _fx - 1.02 && _px <= _fx + 1.02 && _pz >= _fz - 1.02 && _pz <= _fz + 1.02) {
                    return true;
                }
            }
        }
    }
    return false;
}

function bb_game_update(_dt) {
    var _g = global.G;
    if (_g.gameover || _g.win) {
        _g.over_t += _dt;
        if (keyboard_check_pressed(vk_enter) || mouse_check_button_pressed(mb_left) || keyboard_check_pressed(vk_escape)) {
            window_mouse_set_locked(false);
            window_set_cursor(cr_default);
            audio_stop_all();
            room_goto(rm_title);
        }
        return;
    }
    if (keyboard_check_pressed(vk_escape)) {
        _g.pause = !_g.pause;
        window_mouse_set_locked(!_g.pause);
        window_set_cursor(_g.pause ? cr_default : cr_none);
    }
    if (_g.pause) {
        if (keyboard_check_pressed(ord("Q"))) {
            audio_stop_all();
            window_mouse_set_locked(false);
            window_set_cursor(cr_default);
            room_goto(rm_title);
        }
        return;
    }
    if (_g.state == "yctp") {
        bb_yctp_update();
        return;
    }

    if (!_g.mouse_ready) {
        _g.mouse_ready = true;
        window_mouse_set_locked(true);
    } else {
        var _mx = window_mouse_get_delta_x();
        _g.yaw -= _mx * 0.005;
    }

    var _ix = 0;
    var _iz = 0;
    if (keyboard_check(ord("A")) || keyboard_check(vk_left)) _ix -= 1;
    if (keyboard_check(ord("D")) || keyboard_check(vk_right)) _ix += 1;
    if (keyboard_check(ord("W")) || keyboard_check(vk_up)) _iz -= 1;
    if (keyboard_check(ord("S")) || keyboard_check(vk_down)) _iz += 1;
    var _len = sqrt(_ix * _ix + _iz * _iz);
    var _running = false;
    if (_len > 0) {
        _ix /= _len;
        _iz /= _len;
        var _spd = _g.speed;
        if (keyboard_check(vk_shift) && _g.stamina > 0 && _iz < 0) {
            _spd *= _g.run_mul;
            _g.stamina = max(0, _g.stamina - 28 * _dt);
            _running = true;
        }
        var _fx = -sin(_g.yaw);
        var _fz = -cos(_g.yaw);
        var _rx = cos(_g.yaw);
        var _rz = -sin(_g.yaw);
        var _dx = (_rx * _ix + _fx * (-_iz)) * _spd * _dt;
        var _dz = (_rz * _ix + _fz * (-_iz)) * _spd * _dt;
        if (!bb_blocked(_g.px + _dx, _g.pz, _g.radius)) {
            _g.px += _dx;
        }
        if (!bb_blocked(_g.px, _g.pz + _dz, _g.radius)) {
            _g.pz += _dz;
        }
    }
    if (!_running) {
        _g.stamina = min(_g.stamina_max, _g.stamina + 18 * _dt);
    }

    bb_update_doors(_dt);
    bb_update_pickups();
    bb_update_tutor(_dt);
    bb_update_baldi(_dt);
    bb_update_npcs(_dt);
    bb_update_items_use();
    bb_check_win();
}

function bb_door_touching(_d, _px, _pz, _r) {
    var _b = bb_door_box(_d);
    return bb_aabb_hit(_px, _pz, _r + 0.1, _b[0], _b[1], _b[2], _b[3]);
}

function bb_update_doors(_dt) {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (_d.lock_cd > 0) {
            _d.lock_cd -= _dt;
        }
        var _touch = bb_door_touching(_d, _g.px, _g.pz, _g.radius);
        var _locked = (_g.notebooks < 2);
        if (_touch) {
            if (_locked) {
                if (_d.lock_cd <= 0) {
                    audio_play_sound(snd_bal_doors, 3, false);
                    _d.lock_cd = 4;
                }
            } else {
                if (!_d.open) {
                    _d.open = true;
                    audio_play_sound(snd_swing, 2, false);
                }
                _d.t = 3;
            }
        } else if (_d.open) {
            _d.t -= _dt;
            if (_d.t <= 0) {
                _d.open = false;
            }
        }
    }
}

function bb_update_pickups() {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        if (_n.taken) {
            continue;
        }
        if (bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 0.85 * 0.85) {
            _n.taken = true;
            audio_play_sound(snd_bell, 3, false);
            bb_yctp_open();
            return;
        }
    }
    for (_i = 0; _i < array_length(_g.items); _i++) {
        var _it = _g.items[_i];
        if (_it.taken) {
            continue;
        }
        if (bb_dist2(_g.px, _g.pz, _it.x, _it.z) < 0.7 * 0.7) {
            var _slot = bb_inv_free();
            if (_slot != -1) {
                _it.taken = true;
                _g.inv[_slot] = _it.kind;
                audio_play_sound(snd_bell, 2, false);
            }
        }
    }
}

function bb_inv_free() {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < 3; _i++) {
        if (_g.inv[_i] == -1) {
            return _i;
        }
    }
    return -1;
}

function bb_update_items_use() {
    var _g = global.G;
    if (keyboard_check_pressed(ord("1"))) _g.inv_sel = 0;
    if (keyboard_check_pressed(ord("2"))) _g.inv_sel = 1;
    if (keyboard_check_pressed(ord("3"))) _g.inv_sel = 2;
    if (mouse_wheel_up()) _g.inv_sel = (_g.inv_sel + 2) mod 3;
    if (mouse_wheel_down()) _g.inv_sel = (_g.inv_sel + 1) mod 3;
    if (mouse_check_button_pressed(mb_right) || keyboard_check_pressed(ord("Q"))) {
        var _k = _g.inv[_g.inv_sel];
        if (_k == 1) {
            _g.stamina = _g.stamina_max;
            _g.inv[_g.inv_sel] = -1;
        } else if (_k == 2) {
            if (_g.baldi_active) {
                var _fx = -sin(_g.yaw);
                var _fz = -cos(_g.yaw);
                _g.baldi_x += _fx * 8;
                _g.baldi_z += _fz * 8;
                _g.baldi_cd = 1.2;
            }
            _g.inv[_g.inv_sel] = -1;
            audio_play_sound(snd_ohno, 2, false);
        }
    }
}

function bb_update_tutor(_dt) {
    var _g = global.G;
    if (!_g.tutor_wave) {
        return;
    }
    _g.tutor_frame += 28 * _dt;
    if (_g.tutor_frame >= 100) {
        _g.tutor_frame = 99;
        _g.tutor_wave = false;
        _g.tutor_done = true;
    }
}

function bb_update_baldi(_dt) {
    var _g = global.G;
    if (!_g.baldi_active || _g.state != "play") {
        return;
    }
    _g.baldi_cd -= _dt;
    if (_g.baldi_cd <= 0) {
        audio_play_sound(snd_bal_slap, 3, false);
        _g.baldi_frame = 0;
        _g.baldi_moving = true;
        var _delay = max(0.18, 1.15 - _g.baldi_anger * 0.11);
        _g.baldi_cd = _delay;
        var _dx = _g.px - _g.baldi_x;
        var _dz = _g.pz - _g.baldi_z;
        var _len = sqrt(_dx * _dx + _dz * _dz);
        if (_len > 0.001) {
            var _step = 1.35 + _g.baldi_anger * 0.42;
            _g.baldi_x += (_dx / _len) * _step;
            _g.baldi_z += (_dz / _len) * _step;
        }
    }
    _g.baldi_frame = min(4, _g.baldi_frame + 18 * _dt);
    if (bb_dist2(_g.px, _g.pz, _g.baldi_x, _g.baldi_z) < 1.05 * 1.05) {
        bb_gameover();
    }
}

function bb_update_npcs(_dt) {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        var _n = _g.npcs[_i];
        _n.wait -= _dt;
        if (_n.wait <= 0) {
            _n.dir = random(360);
            _n.wait = 1.5 + random(3);
        }
        var _spd = 1.1;
        if (_n.kind == "sweep") {
            _spd = 3.2;
        }
        var _nx = _n.x + lengthdir_x(_spd * _dt, _n.dir);
        var _nz = _n.z + lengthdir_y(_spd * _dt, _n.dir);
        if (!bb_blocked(_nx, _nz, 0.3)) {
            _n.x = _nx;
            _n.z = _nz;
        } else {
            _n.dir += 90 + random(80);
        }
        if (_n.kind == "bully" && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 1.1 * 1.1) {
            var _s = 0;
            for (_s = 0; _s < 3; _s++) {
                if (_g.inv[_s] != -1) {
                    _g.inv[_s] = -1;
                    break;
                }
            }
        }
        if (_n.kind == "sweep" && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 1.2 * 1.2) {
            var _dx = _g.px - _n.x;
            var _dz = _g.pz - _n.z;
            var _len = max(0.001, sqrt(_dx * _dx + _dz * _dz));
            var _px2 = _g.px + (_dx / _len) * 4 * _dt;
            var _pz2 = _g.pz + (_dz / _len) * 4 * _dt;
            if (!bb_blocked(_px2, _g.pz, _g.radius)) _g.px = _px2;
            if (!bb_blocked(_g.px, _pz2, _g.radius)) _g.pz = _pz2;
        }
    }
}

function bb_yctp_open() {
    var _g = global.G;
    _g.state = "yctp";
    _g.yctp_q = 0;
    _g.yctp_input = "";
    _g.yctp_feedback = 0;
    _g.yctp_wrong = 0;
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    audio_stop_sound(snd_mus_school);
    audio_play_sound(snd_mus_learn, 1, true);
    bb_yctp_make();
}

function bb_yctp_make() {
    var _g = global.G;
    _g.yctp_input = "";
    _g.yctp_feedback = 0;
    _g.yctp_corrupt = false;
    if (_g.notebooks >= 1 && _g.yctp_q == 2) {
        _g.yctp_a = 0;
        _g.yctp_b = 0;
        _g.yctp_op = "?";
        _g.yctp_ans = -99999;
        _g.yctp_corrupt = true;
        return;
    }
    if (_g.yctp_q < 2 || _g.notebooks < 1) {
        _g.yctp_a = irandom_range(1, 9);
        _g.yctp_b = irandom_range(1, 9);
        _g.yctp_op = "+";
        if (_g.yctp_q == 1) {
            _g.yctp_op = choose("+", "-");
            if (_g.yctp_op == "-" && _g.yctp_b > _g.yctp_a) {
                var _tmp = _g.yctp_a;
                _g.yctp_a = _g.yctp_b;
                _g.yctp_b = _tmp;
            }
        }
    } else {
        _g.yctp_a = irandom_range(2, 9);
        _g.yctp_b = irandom_range(2, 9);
        _g.yctp_op = "x";
    }
    if (_g.yctp_op == "+") {
        _g.yctp_ans = _g.yctp_a + _g.yctp_b;
    } else if (_g.yctp_op == "-") {
        _g.yctp_ans = _g.yctp_a - _g.yctp_b;
    } else {
        _g.yctp_ans = _g.yctp_a * _g.yctp_b;
    }
}

function bb_yctp_update() {
    var _g = global.G;
    if (_g.yctp_feedback != 0) {
        _g.yctp_timer -= 1;
        if (_g.yctp_timer <= 0) {
            if (_g.yctp_q >= 3) {
                bb_yctp_close();
            } else {
                bb_yctp_make();
            }
        }
        return;
    }
    var _ch = "";
    var _k;
    for (_k = 0; _k <= 9; _k++) {
        if (keyboard_check_pressed(ord(string(_k))) || keyboard_check_pressed(vk_numpad0 + _k)) {
            _ch = string(_k);
        }
    }
    if (keyboard_check_pressed(189) || keyboard_check_pressed(vk_subtract)) {
        if (_g.yctp_input == "") {
            _ch = "-";
        }
    }
    if (_ch != "" && string_length(_g.yctp_input) < 8) {
        _g.yctp_input += _ch;
    }
    if (keyboard_check_pressed(vk_backspace)) {
        _g.yctp_input = string_delete(_g.yctp_input, string_length(_g.yctp_input), 1);
    }
    if (keyboard_check_pressed(ord("C"))) {
        _g.yctp_input = "";
    }
    if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        bb_yctp_submit();
    }
}

function bb_yctp_submit() {
    var _g = global.G;
    var _ok = (_g.yctp_input == string(_g.yctp_ans));
    if (!_ok && _g.yctp_input != "") {
        var _digits = string_digits(_g.yctp_input);
        if (_digits != "") {
            var _val = real(_digits);
            if (string_char_at(_g.yctp_input, 1) == "-") {
                _val = -_val;
            }
            _ok = (_val == _g.yctp_ans);
        }
    }
    if (_ok) {
        _g.yctp_feedback = 1;
        audio_play_sound(choose(snd_praise1, snd_praise2, snd_praise3, snd_praise4, snd_praise5), 3, false);
    } else {
        _g.yctp_feedback = -1;
        _g.yctp_wrong += 1;
        _g.baldi_anger += 1.25;
        audio_play_sound(snd_ohno, 3, false);
    }
    _g.yctp_q += 1;
    _g.yctp_timer = 45;
}

function bb_yctp_close() {
    var _g = global.G;
    _g.notebooks += 1;
    _g.stamina = _g.stamina_max;
    _g.state = "play";
    audio_stop_sound(snd_mus_learn);
    audio_play_sound(snd_mus_school, 1, true);
    window_mouse_set_locked(true);
    window_set_cursor(cr_none);
    _g.mouse_ready = false;
    if (_g.yctp_wrong > 0) {
        _g.baldi_active = true;
        _g.baldi_x = _g.tutor_x;
        _g.baldi_z = _g.tutor_z;
        _g.baldi_cd = 1.8;
    } else if (_g.notebooks >= 2) {
        _g.baldi_active = true;
        _g.baldi_anger += 0.2;
        _g.baldi_x = _g.tutor_x;
        _g.baldi_z = _g.tutor_z;
        _g.baldi_cd = 2.2;
    }
    if (_g.notebooks >= _g.notebooks_needed) {
        _g.exit_open = true;
        audio_play_sound(snd_bal_hi, 2, false);
    }
}

function bb_gameover() {
    var _g = global.G;
    _g.gameover = true;
    _g.over_t = 0;
    audio_stop_all();
    audio_play_sound(snd_bal_screech, 5, false);
    audio_play_sound(snd_mus_hang, 1, true);
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
}

function bb_check_win() {
    var _g = global.G;
    if (_g.exit_open && bb_dist2(_g.px, _g.pz, global.map.player[0], global.map.player[2]) < 1.4 * 1.4) {
        _g.win = true;
        audio_stop_all();
        window_mouse_set_locked(false);
        window_set_cursor(cr_default);
    }
}

function bb_game_draw() {
    var _g = global.G;
    var _aspect = bb_base_w() / bb_base_h();
    bb3d_begin(_g.px, _g.py, _g.pz, _g.yaw, _aspect);
    bb3d_draw_sky(_g.px, _g.py, _g.pz);
    bb3d_draw_world();
    bb_draw_doors();
    bb_draw_entities();
    bb3d_end();
}

function bb3d_draw_sky(_px, _py, _pz) {
    var _s = 80;
    var _vb = global.vb_bill;
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _px - _s, _py - _s, _pz - _s, 0, 1, _px + _s, _py - _s, _pz - _s, 1, 1, _px + _s, _py + _s, _pz - _s, 1, 0, _px - _s, _py + _s, _pz - _s, 0, 0, c_white, 1);
    vertex_end(_vb);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(spr_tex_sky0, 0));
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _px + _s, _py - _s, _pz - _s, 0, 1, _px + _s, _py - _s, _pz + _s, 1, 1, _px + _s, _py + _s, _pz + _s, 1, 0, _px + _s, _py + _s, _pz - _s, 0, 0, c_white, 1);
    vertex_end(_vb);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(spr_tex_sky90, 0));
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _px + _s, _py - _s, _pz + _s, 0, 1, _px - _s, _py - _s, _pz + _s, 1, 1, _px - _s, _py + _s, _pz + _s, 1, 0, _px + _s, _py + _s, _pz + _s, 0, 0, c_white, 1);
    vertex_end(_vb);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(spr_tex_sky180, 0));
    vertex_begin(_vb, global.vf_3d);
    bb3d_quad(_vb, _px - _s, _py - _s, _pz + _s, 0, 1, _px - _s, _py - _s, _pz - _s, 1, 1, _px - _s, _py + _s, _pz - _s, 1, 0, _px - _s, _py + _s, _pz + _s, 0, 0, c_white, 1);
    vertex_end(_vb);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(spr_tex_sky270, 0));
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
}

function bb_draw_doors() {
    var _g = global.G;
    var _i;
    gpu_set_texrepeat(false);
    gpu_set_zwriteenable(true);
    gpu_set_ztestenable(true);
    gpu_set_alphatestenable(true);
    gpu_set_alphatestref(8);
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        var _spr = _d.open ? spr_tex_swing60 : spr_tex_swing0;
        var _vb = global.vb_bill;
        vertex_begin(_vb, global.vf_3d);
        bb3d_emit_piece(_vb, _d.side, _d.x, _d.z, c_white, 1);
        vertex_end(_vb);
        vertex_submit(_vb, pr_trianglelist, sprite_get_texture(_spr, 0));
    }
    gpu_set_texrepeat(true);
}

function bb_draw_entities() {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        if (!_n.taken) {
            bb3d_draw_billboard(spr_notebook, 0, _n.x, _n.y, _n.z, 0.72, 0.44, _g.px, _g.pz, c_white);
        }
    }
    for (_i = 0; _i < array_length(_g.items); _i++) {
        var _it = _g.items[_i];
        if (!_it.taken) {
            var _is = (_it.spr != -1) ? _it.spr : spr_zesty;
            bb3d_draw_billboard(_is, 0, _it.x, _it.y, _it.z, 0.35, 0.35, _g.px, _g.pz, c_white);
        }
    }
    if (!_g.baldi_active) {
        var _wf = clamp(floor(_g.tutor_frame), 0, 99);
        var _wspr = global.spr_wave[_wf];
        bb3d_draw_billboard(_wspr, 0, _g.tutor_x, _g.tutor_y, _g.tutor_z, 0.91, 1.64, _g.px, _g.pz, c_white);
    } else {
        var _sf = clamp(floor(_g.baldi_frame), 0, 4);
        bb3d_draw_billboard(global.spr_slap[_sf], 0, _g.baldi_x, _g.baldi_y, _g.baldi_z, 0.91, 1.64, _g.px, _g.pz, c_white);
    }
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        var _npc = _g.npcs[_i];
        var _ns = (_npc.spr != -1) ? _npc.spr : spr_principal;
        bb3d_draw_billboard(_ns, 0, _npc.x, _npc.y, _npc.z, _npc.w, _npc.h, _g.px, _g.pz, c_white);
    }
    bb3d_draw_billboard(spr_exit_sign, 0, 0, 1.75, 0, 0.5, 0.22, _g.px, _g.pz, c_white);
}

function bb_game_draw_gui() {
    var _g = global.G;
    var _gw = bb_base_w();
    var _gh = bb_base_h();
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    if (_g.gameover) {
        draw_sprite_stretched(spr_gameover, 0, 0, 0, _gw, _gh);
        draw_set_font(global.fnt_ui);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        if (_g.over_t > 1.2) {
            draw_text(_gw * 0.5, _gh - 36, "CLICK TO CONTINUE");
        }
        draw_set_halign(fa_left);
        return;
    }
    if (_g.win) {
        draw_sprite_stretched(spr_win, 0, 0, 0, _gw, _gh);
        return;
    }
    if (_g.state == "yctp") {
        bb_yctp_draw();
        return;
    }
    bb_draw_classic_hud(_g, _gw, _gh);
    if (_g.exit_open) {
        draw_set_font(global.fnt_small);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text(_gw * 0.5, 58, "FIND AN EXIT!");
        draw_set_halign(fa_left);
    }
    if (_g.pause) {
        draw_set_alpha(0.55);
        draw_set_color(c_black);
        draw_rectangle(0, 0, _gw, _gh, false);
        draw_set_alpha(1);
        draw_set_font(global.fnt_big);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        draw_text(_gw * 0.5, 180, "PAUSED");
        draw_set_font(global.fnt_ui);
        draw_text(_gw * 0.5, 240, "ESC resume   Q title   F11 fullscreen");
        draw_set_halign(fa_left);
    }
}

function bb_draw_classic_hud(_g, _gw, _gh) {
    draw_set_font(global.fnt_ui);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_black);
    draw_text(10, 7, "Notebooks");
    draw_text(10, 9, "Notebooks");
    draw_text(11, 8, "Notebooks");
    draw_set_color(c_white);
    draw_text(10, 8, "Notebooks");
    draw_set_color(c_black);
    var _nb = string(_g.notebooks) + "/" + string(_g.notebooks_needed);
    draw_text(10, 35, _nb);
    draw_text(10, 37, _nb);
    draw_set_color(c_white);
    draw_text(10, 36, _nb);

    var _bar_w = 180;
    var _bar_h = 16;
    var _bx = (_gw - _bar_w) * 0.5;
    var _by = 10;
    draw_set_color(make_colour_rgb(180, 0, 0));
    draw_rectangle(_bx, _by, _bx + _bar_w, _by + _bar_h, false);
    var _fill = clamp(_g.stamina / _g.stamina_max, 0, 1);
    if (_fill > 0) {
        draw_set_color(make_colour_rgb(40, 200, 40));
        draw_rectangle(_bx, _by, _bx + _bar_w * _fill, _by + _bar_h, false);
    }
    draw_set_color(c_black);
    draw_rectangle(_bx, _by, _bx + _bar_w, _by + _bar_h, true);
    if (_g.stamina <= 0) {
        draw_set_halign(fa_center);
        draw_set_font(global.fnt_small);
        draw_set_color(c_red);
        draw_text(_gw * 0.5, _by + _bar_h + 3, "YOU NEED REST!");
        draw_set_halign(fa_left);
        draw_set_font(global.fnt_ui);
    }

    var _slot_w = 192;
    var _slot_h = 114;
    var _sx = _gw - _slot_w - 6;
    var _sy = 4;
    draw_sprite_part(spr_item_slots, 0, 0, 0, _slot_w, _slot_h, _sx, _sy);
    var _i;
    for (_i = 0; _i < 3; _i++) {
        var _cx = _sx + 32 + _i * 64;
        var _cy = _sy + 58;
        if (_g.inv[_i] == 1) {
            draw_sprite_stretched(spr_zesty, 0, _cx - 22, _cy - 22, 44, 44);
        } else if (_g.inv[_i] == 2) {
            draw_sprite_stretched(spr_bsoda, 0, _cx - 22, _cy - 22, 44, 44);
        }
        if (_i == _g.inv_sel) {
            draw_set_color(c_white);
            draw_rectangle(_cx - 28, _cy - 28, _cx + 28, _cy + 28, true);
            draw_rectangle(_cx - 27, _cy - 27, _cx + 27, _cy + 27, true);
        }
    }
}

function bb_yctp_draw() {
    var _g = global.G;
    var _gw = bb_base_w();
    var _gh = bb_base_h();
    draw_sprite_stretched(spr_yctp, 0, 0, 0, _gw, _gh);
    draw_set_font(global.fnt_big);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_colour_rgb(20, 40, 20));
    var _eq;
    if (_g.yctp_corrupt) {
        _eq = "nblblblblblblblbl = " + _g.yctp_input;
    } else {
        var _op = _g.yctp_op;
        _eq = string(_g.yctp_a) + " " + _op + " " + string(_g.yctp_b) + " = " + _g.yctp_input;
    }
    draw_text(_gw * 0.52, _gh * 0.46, _eq);
    draw_set_font(global.fnt_small);
    draw_set_color(c_white);
    draw_text(_gw * 0.5, 36, "Problem " + string(_g.yctp_q + 1) + " of 3");
    if (_g.yctp_feedback == 1) {
        draw_sprite_ext(spr_check, 0, _gw * 0.5, _gh * 0.62, 0.5, 0.5, 0, c_white, 1);
    } else if (_g.yctp_feedback == -1) {
        draw_sprite_ext(spr_xmark, 0, _gw * 0.5, _gh * 0.62, 0.5, 0.5, 0, c_white, 1);
    }
    draw_set_valign(fa_top);
    draw_set_halign(fa_left);
}

function bb_game_cleanup() {
    bb3d_free_batches();
    if (variable_global_exists("floors") && ds_exists(global.floors, ds_type_map)) {
        ds_map_destroy(global.floors);
    }
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
}
