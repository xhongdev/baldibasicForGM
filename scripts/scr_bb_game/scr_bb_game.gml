function bb_game_init() {
    global.path_ready=false;
    global.path_signature=0;
    global.path_grids={};
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
    bb_nav_build();

    var _p = global.map.player;
    var _t = global.map.tutor;
    global.G = {
        px: _p[0],
        py: 1.0,
        pz: _p[2],
        yaw: 0,
        radius: 0.28,
        speed: 2.0,
        run_mul: 1.6,
        stamina: 100,
        stamina_max: 100,
        notebooks: 0,
        notebooks_needed: 7,
        mode: global.game_mode,
        anger_time: global.E.baldi.timeToAnger,
        anger_rate: global.E.baldi.angerRate,
        new_high_score: false,
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
        yctp_msg: "",
        yctp_marks: [0, 0, 0],
        yctp_end: false,
        yctp_face_visible: true,
        yctp_face_state: "idle",
        yctp_face_time: 0,
        yctp_music: -1,
        yctp_hang: -1,
        yctp_voice_stage: 0,
        yctp_bad1: "",
        yctp_bad2: "",
        yctp_bad3: "",
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
        baldi_sprayed: false,
        baldi_x: 0,
        baldi_y: 0.82,
        baldi_z: -24,
        baldi_home_x: 0,
        baldi_home_z: -24,
        baldi_anger: 0,
        baldi_extra: 0,
        baldi_wait: 0,
        baldi_cd: 3,
        baldi_move: 0,
        baldi_cool: 0,
        baldi_frame: 0,
        baldi_prev_x: 0,
        baldi_prev_z: -24,
        hear_x: 0,
        hear_z: -24,
        hear_pri: 0,
        anti_hear: 0,
        spoop_mode: false,
        failed_nbs: 0,
        doors: [],
        notebooks_list: [],
        items: [],
        props: [],
        alarms: [],
        boots: 0,
        boot_anim: -1,
        npcs: [],
        inv: [-1, -1, -1],
        inv_sel: 0,
        locked_until: 2,
        exit_open: false,
        exits: [],
        exit_got: 0,
        final_red: 0,
        sprays: [],
        play_lock: 0,
        play_need: 0,
        play_cool: 0,
        rope_delay: 0,
        rope_time: 0,
        jump_height: 0,
        jump_velocity: 0,
        rope_message: "",
        guilt: 0,
        guilt_type: "",
        prin_chase: false,
        detention: 0,
        det_n: 0,
        running: false,
        faculty: false,
        nb_t: 0,
        click_used: false
    };
    bb_debug_init();
    global.G.craft_inside=array_create(array_length(global.E.craft_triggers),false);

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
            silent_opens: 0,
            silent_close: false,
            kind: _d.kind,
            lock_start: variable_struct_exists(_d, "lock_start") ? _d.lock_start : false,
            locked: (_d.kind == "swing" && _d.lock_start),
            was_touch: false
        });
        if (variable_struct_exists(_d, "v")) {
            var _door = global.G.doors[array_length(global.G.doors) - 1];
            _door.v = _d.v;
            _door.bounds = _d.bounds;
            _door.cx = _d.cx;
            _door.cz = _d.cz;
            _door.w = _d.w;
        }
    }

    var _nbs = global.map.notebooks;
    for (_i = 0; _i < array_length(_nbs); _i++) {
        var _n = _nbs[_i];
        var _tint = c_lime;
        switch (_n.spr) {
            case "spr_nb_red": _tint = make_colour_rgb(220, 50, 50); break;
            case "spr_nb_blue": _tint = make_colour_rgb(50, 90, 220); break;
            case "spr_nb_yellow": _tint = make_colour_rgb(240, 210, 40); break;
            case "spr_nb_cyan": _tint = make_colour_rgb(40, 200, 220); break;
            case "spr_nb_salmon": _tint = make_colour_rgb(240, 140, 120); break;
            case "spr_nb_black": _tint = make_colour_rgb(40, 40, 40); break;
            default: _tint = make_colour_rgb(70, 200, 70); break;
        }
        array_push(global.G.notebooks_list, {
            x: _n.x,
            y: variable_struct_exists(_n, "y") ? _n.y : 0.78,
            z: _n.z,
            taken: false,
            respawn: 0,
            spr: spr_notebook,
            tint: _tint
        });
        var _appearance = global.P.notebooks[$ _n.source_id];
        var _book = global.G.notebooks_list[array_length(global.G.notebooks_list)-1];
        _book.spr = global.PS[$ _appearance.texture];
        _book.tint = c_white;
        _book.w = _appearance.w;
        _book.h = _appearance.h;
        _book.y = _appearance.y;
        _book.pickup_y = _n.y;
        _book.open_distance = _appearance.open_distance;
        _book.respawn_audio = variable_struct_exists(_appearance, "respawn_audio") ? _appearance.respawn_audio : "";
    }

    var _gameplay = json_parse(bb_read_text("school_gameplay.json"));
    var _items = _gameplay.items;
    for (_i = 0; _i < array_length(_items); _i++) {
        var _it = _items[_i];
        array_push(global.G.items, {
            x: _it.x,
            y: _it.y,
            z: _it.z,
            taken: !_it.active,
            reward: _it.reward,
            kind: _it.kind,
            spr: bb_item_spr(_it.kind)
        });
        var _item = global.G.items[array_length(global.G.items)-1];
        _item.w = 0.256; _item.h = 0.256;
        _item.pickup_y = _it.y;
        if (variable_struct_exists(global.P.pickups, _it.source_id)) {
            var _appearance = global.P.pickups[$ _it.source_id];
            _item.spr = global.PS[$ _appearance.texture];
            _item.w = _appearance.w; _item.h = _appearance.h;
            _item.y = _appearance.y;
            _item.open_distance = _appearance.open_distance;
        }
    }
    for (_i = 0; _i < array_length(_gameplay.props); _i++) {
        var _prop = _gameplay.props[_i];
        _prop.spr = bb_prop_spr(_prop.kind);
        _prop.detail = global.P.details.props[$ _prop.source_id];
        if (variable_struct_exists(global.P.props, _prop.source_id)) {
            var _appearance = global.P.props[$ _prop.source_id];
            _prop.spr = global.PS[$ _appearance.texture];
            _prop.w = _appearance.w; _prop.h = _appearance.h;
            _prop.y = _appearance.y;
        }
        _prop.playing = 0;
        array_push(global.G.props, _prop);
    }

    var _npcs = global.map.npcs;
    for (_i = 0; _i < array_length(_npcs); _i++) {
        var _npc = _npcs[_i];
        array_push(global.G.npcs, {
            x: _npc.x,
            y: _npc.y,
            z: _npc.z,
            home_x: _npc.x,
            home_z: _npc.z,
            kind: _npc.kind,
            spr: bb_npc_sprite(_npc.kind, asset_get_index(_npc.spr)),
            dir: random(360),
            wait: random(2),
            w: _npc.w,
            h: _npc.h,
            spd: 0,
            cool: 0,
            angry: false,
            stare: 0,
            crazy: 0,
            sprayed: false,
            live: false
        });
        bb_ai_init(global.G.npcs[array_length(global.G.npcs)-1]);
        if (_npc.kind == "sweep") {
            global.G.npcs[array_length(global.G.npcs) - 1].wait = 120 + random(60);
        }
        if (_npc.kind == "prize") {
            global.G.npcs[array_length(global.G.npcs) - 1].dir = 180;
        }
    }

    if (variable_struct_exists(global.map, "exits")) {
        var _ex = global.map.exits;
        for (_i = 0; _i < array_length(_ex); _i++) {
            var _source = undefined;
            for (var _j = 0; _j < array_length(global.P.details.entrances); _j++) {
                if (global.P.details.entrances[_j].name == _ex[_i].name) _source = global.P.details.entrances[_j];
            }
            array_push(global.G.exits, {x: _ex[_i].x, z: _ex[_i].z, name: _ex[_i].name, used: false, down: false, source:_source});
        }
    }
    bb_refresh_details();
    bb_grid_build();global.path_ready=true;

    if (variable_global_exists("dump_quit") && global.dump_quit) {
        bb_dump_runtime();
        game_end();
        return;
    }
    bb_audio_init();
    audio_stop_all();
    audio_play_sound(snd_mus_school, 1, true);
    bb_voice_replace("tutor", [snd_bal_hi]);
    window_set_cursor(cr_none);
    window_mouse_set_locked(true);
}

function bb_spr_info(_spr) {
    if (_spr == undefined || _spr < 0 || !sprite_exists(_spr)) {
        return "MISSING id=" + string(_spr);
    }
    var _nm = sprite_get_name(_spr);
    var _w = sprite_get_width(_spr);
    var _h = sprite_get_height(_spr);
    var _bad = "";
    if (_w <= 16 && _h <= 16) {
        _bad = " PLACEHOLDER_16x16";
    }
    return _nm + " " + string(_w) + "x" + string(_h) + _bad;
}

function bb_dump_line(_f, _s) {
    show_debug_message(_s);
    if (_f != -1) {
        file_text_write_string(_f, _s);
        file_text_writeln(_f);
    }
}

function bb_dump_runtime() {
    var _paths = [
        "D:/Github/baldibasicForGM/tools/gm_runtime_dump.txt",
        working_directory + "gm_runtime_dump.txt",
        program_directory + "gm_runtime_dump.txt",
        "gm_runtime_dump.txt"
    ];
    var _f = -1;
    var _i;
    for (_i = 0; _i < array_length(_paths); _i++) {
        _f = file_text_open_write(_paths[_i]);
        if (_f != -1) {
            break;
        }
    }
    if (_f == -1) {
        show_debug_message("dump file open failed, using debug log only");
    }
    var _g = global.G;
    bb_dump_line(_f, "=== GameMaker runtime dump (not Python) ===");
    bb_dump_line(_f, "working_directory=" + working_directory);
    bb_dump_line(_f, "PLAYER x=" + string(_g.px) + " y=" + string(_g.py) + " z=" + string(_g.pz) + " yaw=" + string(_g.yaw) + " fwd=(-sin(yaw),-cos(yaw)) yaw0=-Z");
    bb_dump_line(_f, "TUTOR x=" + string(_g.tutor_x) + " y=" + string(_g.tutor_y) + " z=" + string(_g.tutor_z) + " wave_spr=" + bb_spr_info(variable_global_exists("spr_wave") ? global.spr_wave[0] : -1));
    bb_dump_line(_f, "BALDI_HOME x=" + string(_g.baldi_home_x) + " z=" + string(_g.baldi_home_z) + " slap0=" + bb_spr_info(variable_global_exists("spr_slap") ? global.spr_slap[0] : -1));
    bb_dump_line(_f, "FLOORS " + string(ds_map_size(global.floors)) + " COLLISION_WALLS " + string(array_length(global.walls)));

    var _n = 0;
    var _s = 0;
    var _e = 0;
    var _w = 0;
    var _q;
    var _quads = global.map.quads;
    for (_i = 0; _i < array_length(_quads); _i++) {
        _q = _quads[_i];
        if (_q.k == "n") _n += 1;
        if (_q.k == "s") _s += 1;
        if (_q.k == "e") _e += 1;
        if (_q.k == "w") _w += 1;
    }
    bb_dump_line(_f, "WALL_QUADS n=" + string(_n) + " s=" + string(_s) + " e=" + string(_e) + " w=" + string(_w));
    bb_dump_line(_f, "TEX brick=" + bb_spr_info(spr_tex_brick) + " window=" + bb_spr_info(spr_tex_window) + " tile=" + bb_spr_info(spr_tex_tile) + " carpet=" + bb_spr_info(spr_tex_carpet) + " ceil=" + bb_spr_info(spr_tex_ceiling));

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== SPAWN NEIGHBORHOOD floors+walls x=-4..4 z=-8..4 ===");
    var _sx, _sz;
    for (_sz = 4; _sz >= -8; _sz -= 2) {
        for (_sx = -4; _sx <= 4; _sx += 2) {
            var _fk = bb_key(_sx, _sz);
            var _hasf = ds_map_exists(global.floors, _fk);
            var _sides = "";
            var _j;
            for (_j = 0; _j < array_length(_quads); _j++) {
                _q = _quads[_j];
                if (_q.x == _sx && _q.z == _sz && (_q.k == "n" || _q.k == "s" || _q.k == "e" || _q.k == "w")) {
                    var _pun = bb_map_wall_has_door(global.map, _q) ? "*" : "";
                    _sides += _q.k + _pun + "(" + _q.m + ") ";
                }
            }
            if (_hasf || _sides != "") {
                bb_dump_line(_f, "tile(" + string(_sx) + "," + string(_sz) + ") floor=" + string(_hasf) + " mat=" + (_hasf ? string(ds_map_find_value(global.floors, _fk)) : "-") + " walls=" + ((_sides == "") ? "-" : _sides));
            }
        }
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== ALL WALLS k x z m punched tex ===");
    for (_i = 0; _i < array_length(_quads); _i++) {
        _q = _quads[_i];
        if (_q.k != "n" && _q.k != "s" && _q.k != "e" && _q.k != "w") {
            continue;
        }
        var _ps = bb_map_wall_has_door(global.map, _q) ? "PUNCH" : "SOLID";
        var _ms = spr_tex_brick;
        if (_q.m == "window") {
            _ms = spr_tex_window;
        }
        bb_dump_line(_f, _q.k + " x=" + string(_q.x) + " z=" + string(_q.z) + " m=" + _q.m + " " + _ps + " " + bb_spr_info(_ms));
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== DOORS kind x z side lock_start locked tex ===");
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        var _tex = "spr_tex_swing0";
        if (_d.kind == "class") {
            _tex = "spr_tex_door";
        } else if (_d.kind == "faculty") {
            _tex = (variable_global_exists("spr_faculty") && global.spr_faculty != -1) ? "runtime_faculty" : "FALLBACK_spr_tex_door";
        }
        var _tspr = spr_tex_swing0;
        if (_d.kind == "class") {
            _tspr = spr_tex_door;
        } else if (_d.kind == "faculty") {
            _tspr = (variable_global_exists("spr_faculty") && global.spr_faculty != -1) ? global.spr_faculty : spr_tex_door;
        } else {
            _tspr = spr_tex_swing0;
        }
        bb_dump_line(_f, string(_i) + " " + _d.kind + " x=" + string(_d.x) + " z=" + string(_d.z) + " side=" + _d.side + " lock_start=" + string(_d.lock_start) + " locked=" + string(_d.locked) + " tex=" + bb_spr_info(_tspr) + " note=" + _tex);
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== NOTEBOOKS (7) x y z spr ===");
    for (_i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _nb = _g.notebooks_list[_i];
        bb_dump_line(_f, string(_i) + " x=" + string(_nb.x) + " y=" + string(_nb.y) + " z=" + string(_nb.z) + " " + bb_spr_info(_nb.spr));
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== ITEMS x y z kind spr ===");
    for (_i = 0; _i < array_length(_g.items); _i++) {
        var _it = _g.items[_i];
        bb_dump_line(_f, string(_i) + " x=" + string(_it.x) + " y=" + string(_it.y) + " z=" + string(_it.z) + " kind=" + string(_it.kind) + " " + bb_spr_info(_it.spr) + " name=" + bb_item_name(_it.kind));
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== NPCS kind x y z dir w h spr live ===");
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        var _npc = _g.npcs[_i];
        bb_dump_line(_f, _npc.kind + " x=" + string(_npc.x) + " y=" + string(_npc.y) + " z=" + string(_npc.z) + " dir=" + string(_npc.dir) + " w=" + string(_npc.w) + " h=" + string(_npc.h) + " live=" + string(_npc.live) + " " + bb_spr_info(_npc.spr));
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== EXITS ===");
    for (_i = 0; _i < array_length(_g.exits); _i++) {
        var _ex2 = _g.exits[_i];
        bb_dump_line(_f, _ex2.name + " x=" + string(_ex2.x) + " z=" + string(_ex2.z) + " sign=" + bb_spr_info(spr_exit_sign));
    }

    bb_dump_line(_f, "");
    bb_dump_line(_f, "=== RUNTIME SPRITES ===");
    bb_dump_line(_f, "spr_nb_green=" + bb_spr_info(variable_global_exists("spr_nb_green") ? global.spr_nb_green : -1));
    bb_dump_line(_f, "spr_faculty=" + bb_spr_info(variable_global_exists("spr_faculty") ? global.spr_faculty : -1));
    bb_dump_line(_f, "spr_faculty_open=" + bb_spr_info(variable_global_exists("spr_faculty_open") ? global.spr_faculty_open : -1));
    bb_dump_line(_f, "spr_swing_locked=" + bb_spr_info(variable_global_exists("spr_swing_locked") ? global.spr_swing_locked : -1));
    bb_dump_line(_f, "spr_npc_play=" + bb_spr_info(variable_global_exists("spr_npc_play") ? global.spr_npc_play : -1));
    bb_dump_line(_f, "spr_npc_bully=" + bb_spr_info(variable_global_exists("spr_npc_bully") ? global.spr_npc_bully : -1));
    bb_dump_line(_f, "spr_npc_sweep=" + bb_spr_info(variable_global_exists("spr_npc_sweep") ? global.spr_npc_sweep : -1));
    bb_dump_line(_f, "spr_npc_craft=" + bb_spr_info(variable_global_exists("spr_npc_craft") ? global.spr_npc_craft : -1));
    bb_dump_line(_f, "spr_npc_prize=" + bb_spr_info(variable_global_exists("spr_npc_prize") ? global.spr_npc_prize : -1));
    bb_dump_line(_f, "spr_npc_prin=" + bb_spr_info(variable_global_exists("spr_npc_prin") ? global.spr_npc_prin : -1));
    bb_dump_line(_f, "spr_tex_door=" + bb_spr_info(spr_tex_door));
    bb_dump_line(_f, "spr_tex_swing0=" + bb_spr_info(spr_tex_swing0));
    bb_dump_line(_f, "spr_notebook=" + bb_spr_info(spr_notebook));
    bb_dump_line(_f, "spr_nb_red=" + bb_spr_info(spr_nb_red));
    bb_dump_line(_f, "HUD spr_item_slots=" + bb_spr_info(spr_item_slots));
    bb_dump_line(_f, "YCTP spr_yctp=" + bb_spr_info(spr_yctp));
    file_text_close(_f);
    show_debug_message("wrote runtime dump");
}

function bb_build_collision(_map) {
    global.walls = [];
    if (variable_global_exists("floors") && ds_exists(global.floors, ds_type_map)) {
        ds_map_destroy(global.floors);
    }
    if (variable_global_exists("wall_edge") && ds_exists(global.wall_edge, ds_type_map)) {
        ds_map_destroy(global.wall_edge);
    }
    global.floors = ds_map_create();
    global.wall_edge = ds_map_create();
    var _i;
    var _quads = _map.quads;
    var _t = 0.08;
    for (_i = 0; _i < array_length(_quads); _i++) {
        var _q = _quads[_i];
        if (bb_map_wall_has_door(_map, _q)) {
            continue;
        }
        if (_q.k == "floor") {
            ds_map_set(global.floors, bb_key(_q.x, _q.z), _q.m);
        } else if (_q.k == "wall" && variable_struct_exists(_q, "bounds")) {
            if (variable_struct_exists(global.P.details.dynamic_ids, _q.source_id)) continue;
            var _b = _q.bounds;
            // Elevated cafeteria/entrance walls must not become ground-level barriers.
            if (_b[1] < 1 && _b[4] > 1) {
                var _xt = (_b[3] - _b[0] < 0.001) ? _t : 0;
                var _zt = (_b[5] - _b[2] < 0.001) ? _t : 0;
                array_push(global.walls, {x0: _b[0] - _xt, z0: _b[2] - _zt, x1: _b[3] + _xt, z1: _b[5] + _zt});
            }
        } else if (_q.k == "n") {
            array_push(global.walls, {x0: _q.x - 1, z0: _q.z - 1 - _t, x1: _q.x + 1, z1: _q.z - 1 + _t});
            ds_map_set(global.wall_edge, bb_key(_q.x, _q.z) + ",n", 1);
        } else if (_q.k == "s") {
            array_push(global.walls, {x0: _q.x - 1, z0: _q.z + 1 - _t, x1: _q.x + 1, z1: _q.z + 1 + _t});
            ds_map_set(global.wall_edge, bb_key(_q.x, _q.z) + ",s", 1);
        } else if (_q.k == "w") {
            array_push(global.walls, {x0: _q.x - 1 - _t, z0: _q.z - 1, x1: _q.x - 1 + _t, z1: _q.z + 1});
            ds_map_set(global.wall_edge, bb_key(_q.x, _q.z) + ",w", 1);
        } else if (_q.k == "e") {
            array_push(global.walls, {x0: _q.x + 1 - _t, z0: _q.z - 1, x1: _q.x + 1 + _t, z1: _q.z + 1});
            ds_map_set(global.wall_edge, bb_key(_q.x, _q.z) + ",e", 1);
        }
    }
    global.static_walls = variable_clone(global.walls);
}

function bb_blocked(_px, _pz, _r) {
    return bb_blocked_world(_px, _pz, _r, true);
}

function bb_door_hw(_d) {
    if (variable_struct_exists(_d, "w")) return _d.w * 0.5;
    if (_d.kind == "swing") {
        return 1.0;
    }
    return 0.5;
}

function bb_door_box(_d) {
    var _t = 0.08;
    if (variable_struct_exists(_d, "bounds")) {
        var _b = _d.bounds;
        var _xt = (_b[3] - _b[0] < 0.001) ? _t : 0;
        var _zt = (_b[5] - _b[2] < 0.001) ? _t : 0;
        return [_b[0] - _xt, _b[2] - _zt, _b[3] + _xt, _b[5] + _zt];
    }
    var _hw = bb_door_hw(_d);
    switch (_d.side) {
        case "n": return [_d.x - _hw, _d.z - 1 - _t, _d.x + _hw, _d.z - 1 + _t];
        case "s": return [_d.x - _hw, _d.z + 1 - _t, _d.x + _hw, _d.z + 1 + _t];
        case "w": return [_d.x - 1 - _t, _d.z - _hw, _d.x - 1 + _t, _d.z + _hw];
        default: return [_d.x + 1 - _t, _d.z - _hw, _d.x + 1 + _t, _d.z + _hw];
    }
}

function bb_door_jamb_box(_d, _sign) {
    var _t = 0.08;
    var _hw = bb_door_hw(_d);
    if (_sign < 0) {
        switch (_d.side) {
            case "n": return [_d.x - 1, _d.z - 1 - _t, _d.x - _hw, _d.z - 1 + _t];
            case "s": return [_d.x - 1, _d.z + 1 - _t, _d.x - _hw, _d.z + 1 + _t];
            case "w": return [_d.x - 1 - _t, _d.z + _hw, _d.x - 1 + _t, _d.z + 1];
            default: return [_d.x + 1 - _t, _d.z - 1, _d.x + 1 + _t, _d.z - _hw];
        }
    }
    switch (_d.side) {
        case "n": return [_d.x + _hw, _d.z - 1 - _t, _d.x + 1, _d.z - 1 + _t];
        case "s": return [_d.x + _hw, _d.z + 1 - _t, _d.x + 1, _d.z + 1 + _t];
        case "w": return [_d.x - 1 - _t, _d.z - 1, _d.x - 1 + _t, _d.z - _hw];
        default: return [_d.x + 1 - _t, _d.z + _hw, _d.x + 1 + _t, _d.z + 1];
    }
}

function bb_door_face(_d) {
    if (variable_struct_exists(_d, "cx")) return [_d.cx, _d.cz];
    switch (_d.side) {
        case "n": return [_d.x, _d.z - 1];
        case "s": return [_d.x, _d.z + 1];
        case "w": return [_d.x - 1, _d.z];
        default: return [_d.x + 1, _d.z];
    }
}

function bb_look_at(_x, _z, _maxd) {
    var _g = global.G;
    var _dx = _x - _g.px;
    var _dz = _z - _g.pz;
    var _dist = sqrt(_dx * _dx + _dz * _dz);
    if (_dist < 0.12 || _dist > _maxd) {
        return false;
    }
    var _fx = -sin(_g.yaw);
    var _fz = -cos(_g.yaw);
    return ((_dx * _fx + _dz * _fz) / _dist) > 0.55;
}

function bb_door_looking(_d) {
    var _f = bb_door_face(_d);
    return bb_look_at(_f[0], _f[1], 3.0);
}

function bb_on_floor(_px, _pz) {
    var _tx = round(_px / 2) * 2;
    var _tz = round(_pz / 2) * 2;
    if (ds_map_exists(global.floors,bb_key(_tx,_tz))) return true;
    var _dx, _dz;
    for (_dx = -2; _dx <= 2; _dx += 2) {
        for (_dz = -2; _dz <= 2; _dz += 2) {
            if (ds_map_exists(global.floors, bb_key(_tx + _dx, _tz + _dz))) {
                var _fx = _tx + _dx;
                var _fz = _tz + _dz;
                if (_px >= _fx - 1.05 && _px <= _fx + 1.05 && _pz >= _fz - 1.05 && _pz <= _fz + 1.05) {
                    return true;
                }
            }
        }
    }
    return false;
}

function bb_game_update(_dt) {
    var _g = global.G;
    var _old_x = _g.px, _old_z = _g.pz;
    _dt = clamp(_dt, 0, 0.1);
    if (bb_debug_update()) return;
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
    if (_g.state == "yctp") {
        bb_yctp_update(_dt);
        return;
    }
    if (keyboard_check_pressed(vk_escape)) {
        _g.pause = !_g.pause;
        if (_g.pause) audio_pause_all(); else audio_resume_all();
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
    if (!_g.mouse_ready) {
        _g.mouse_ready = true;
        window_mouse_set_locked(true);
    } else {
        var _mx = window_mouse_get_delta_x();
        _g.yaw -= _mx * 0.005 * global.mouse_sensitivity;
    }

    if (_g.detention > 0) {
        _g.detention -= _dt;
        if (_g.detention < 0) {
            _g.detention = 0;
        }
    }

    var _ix = 0;
    var _iz = 0;
    if (_g.play_lock <= 0) {
        if (keyboard_check(ord("A")) || keyboard_check(vk_left)) _ix -= 1;
        if (keyboard_check(ord("D")) || keyboard_check(vk_right)) _ix += 1;
        if (keyboard_check(ord("W")) || keyboard_check(vk_up)) _iz -= 1;
        if (keyboard_check(ord("S")) || keyboard_check(vk_down)) _iz += 1;
    }
    var _len = sqrt(_ix * _ix + _iz * _iz);
    var _running = false;
    var _moved = false;
    if (_len > 0) {
        _ix /= _len;
        _iz /= _len;
        var _spd = _g.speed;
        if (keyboard_check(vk_shift) && _g.stamina > 0 && _g.play_lock <= 0) {
            _spd = _g.speed * _g.run_mul;
            _running = true;
        }
        if (_g.debug.fast) _spd *= 3;
        var _fx = -sin(_g.yaw);
        var _fz = -cos(_g.yaw);
        var _rx = cos(_g.yaw);
        var _rz = -sin(_g.yaw);
        var _dx = (_rx * _ix + _fx * (-_iz)) * _spd * _dt;
        var _dz = (_rz * _ix + _fz * (-_iz)) * _spd * _dt;
        var _sl = bb_debug_player_move(_dx, _dz);
        if (abs(_sl[0] - _g.px) + abs(_sl[1] - _g.pz) > 0.0001) {
            _moved = true;
        }
        _g.px = _sl[0];
        _g.pz = _sl[1];
    }
    if (_moved && _running) {
        _g.stamina -= 10 * _dt;
        if (_g.stamina < 0 && _g.stamina > -5) {
            _g.stamina = -5;
        }
        if (_g.play_lock <= 0) {
            _g.guilt = 0.1;
            _g.guilt_type = "running";
        }
    } else if (!_moved && _g.stamina < _g.stamina_max) {
        _g.stamina += 10 * _dt;
        if (_g.stamina > _g.stamina_max) {
            _g.stamina = _g.stamina_max;
        }
    }
    _g.running = _running;
    if (_g.debug.stamina) _g.stamina = _g.stamina_max;
    if (_g.guilt > 0) {
        _g.guilt -= _dt;
    }

    _g.faculty = bb_region_contains(global.E.faculty,_g.px,_g.pz);
    if (_g.faculty && _g.detention <= 0) {
        if (1 >= _g.guilt) {
            _g.guilt = 1;
            _g.guilt_type = "faculty";
        }
    }
    if (_g.debug.no_rules) { _g.guilt = 0; _g.prin_chase = false; }
    else if (_g.detention>0 && !bb_region_contains(global.E.office,_g.px,_g.pz)) {
        _g.guilt=_g.detention;_g.guilt_type="escape";
    }

    _g.nb_t += _dt;
    bb_update_notebook_respawns(_dt);
    _g.click_used = false;
    bb_update_doors(_dt);
    bb_update_pickups();
    if (_g.state != "play") return;
    bb_update_items_use();
    bb_update_item_effects(_dt);
    bb_update_tutor(_dt);
    bb_update_sprays(_dt);
    bb_update_baldi(_dt);
    if (_g.gameover) return;
    bb_update_npcs(_dt);
    bb_check_exits(_old_x, _old_z);
    if (_g.win) return;
    bb_audio_update(_dt);
}

function bb_npc_sprite(_kind, _fallback) {
    var _s = -1;
    switch (_kind) {
        case "playtime": _s = variable_global_exists("spr_npc_play") ? global.spr_npc_play : -1; break;
        case "bully": _s = variable_global_exists("spr_npc_bully") ? global.spr_npc_bully : -1; break;
        case "sweep": _s = variable_global_exists("spr_npc_sweep") ? global.spr_npc_sweep : -1; break;
        case "crafters": _s = variable_global_exists("spr_npc_craft") ? global.spr_npc_craft : -1; break;
        case "prize": _s = variable_global_exists("spr_npc_prize") ? global.spr_npc_prize : -1; break;
        case "principal": _s = variable_global_exists("spr_npc_prin") ? global.spr_npc_prin : -1; break;
    }
    if (_s != -1) {
        return _s;
    }
    return _fallback;
}

function bb_near_faculty(_x, _z) {
    var _spots = [[-16, -8], [-6, -18], [-14, -32]];
    var _i;
    for (_i = 0; _i < 3; _i++) {
        if (bb_dist2(_x, _z, _spots[_i][0], _spots[_i][1]) < 25) {
            return true;
        }
    }
    return false;
}

function bb_door_touching(_d, _px, _pz, _r) {
    var _b = bb_door_box(_d);
    return bb_aabb_hit(_px, _pz, _r + 0.1, _b[0], _b[1], _b[2], _b[3]);
}

function bb_swing_blocked(_d) {
    var _g = global.G;
    if (_g.debug.free_doors) return false;
    return (_d.lock_start && _g.notebooks < 2) || (_d.lock_cd > 0);
}

function bb_door_try_open(_d, _hear) {
    var _g = global.G;
    if (_d.kind == "swing") {
        _d.locked = bb_swing_blocked(_d);
    }
    if (_d.locked || _d.lock_cd > 0) {
        return false;
    }
    if (_d.kind == "swing") {
        if (!_d.open && _hear) {
            bb_world_sound(snd_swing, _d.x, _d.z);
            bb_hear_pri(_d.x, _d.z, 1);
        } else if (!_d.open) {
            bb_world_sound(snd_swing, _d.x, _d.z);
        }
        _d.open = true;
        _d.t = 2;
        return true;
    }
    if (!_d.open) {
        _d.silent_close = (_d.silent_opens > 0);
        if (!_d.silent_close) bb_world_sound(snd_door_open, _d.x, _d.z);
        if (_hear && !_d.silent_close) {
            bb_hear_pri(_d.x, _d.z, 1);
        }
    }
    if (_hear && _d.silent_opens > 0) _d.silent_opens -= 1;
    _d.open = true;
    _d.t = 3;
    return true;
}

function bb_update_doors(_dt) {
    var _g = global.G;
    var _i;
    var _click = (_g.play_lock <= 0 && mouse_check_button_pressed(mb_left));
    var _target = bb_interaction_target(3);
    for (_i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        if (_g.debug.free_doors) { _d.lock_cd = 0; _d.locked = false; }
        if (_d.lock_cd > 0) {
            _d.lock_cd -= _dt;
            if (_d.lock_cd <= 0) {
                _d.lock_cd = 0;
                _d.locked = false;
            }
        }
        if (_d.kind == "swing") {
            _d.locked = bb_swing_blocked(_d);
        }
        var _touch = bb_door_touching(_d, _g.px, _g.pz, _g.radius);
        var _std = (_d.kind == "class" || _d.kind == "faculty");
        if (_std) {
            if (_click && _target.kind == "door" && _target.index == _i) {
                bb_door_try_open(_d, true);
                _g.click_used = true;
            }
        } else {
            if (_touch) {
                if (bb_swing_blocked(_d)) {
                    if (!_d.was_touch && _d.lock_start && _g.notebooks < 2 && _g.lock_voice_cd <= 0) {
                        bb_voice_replace("tutor", [snd_bal_doors]);
                        _g.lock_voice_cd = audio_sound_length(snd_bal_doors) + 1;
                    }
                } else {
                    if (!_d.open) {
                        bb_world_sound(snd_swing, _d.x, _d.z);
                        bb_hear_pri(_d.x, _d.z, 1);
                    }
                    _d.open = true;
                    _d.t = 2;
                }
            }
            _d.was_touch = _touch;
        }
        if (_d.open) {
            if (_touch) {
                _d.t = _std ? 3 : 2;
            } else {
                _d.t -= _dt;
                if (_d.t <= 0) {
                    _d.open = false;
                    if (_std && !_d.silent_close) {
                        bb_world_sound(snd_door_close, _d.x, _d.z);
                    }
                }
            }
        }
    }
}

function bb_update_pickups() {
    var _g = global.G;
    if (_g.play_lock > 0 || !mouse_check_button_pressed(mb_left) || _g.click_used) {
        return;
    }
    var _target = bb_interaction_target(3);
    if (_target.kind == "notebook" && bb_pickup_in_range(_g.notebooks_list[_target.index])) {
        bb_collect_notebook(_target.index);
    } else if (_target.kind == "item" && bb_pickup_in_range(_g.items[_target.index])) {
        var _it = _g.items[_target.index];
        _it.taken = true;
        bb_collect_item(_it.kind);
    }
}

function bb_pickup_in_range(_pickup) {
    return bb_dist2(global.G.px, global.G.pz, _pickup.x, _pickup.z)
        + sqr(global.G.py - _pickup.pickup_y) < sqr(_pickup.open_distance);
}

function bb_collect_notebook(_index) {
    var _g = global.G;
    if (_g.state != "play" || _g.notebooks_list[_index].taken) return;
    _g.notebooks_list[_index].taken = true;
    _g.notebooks_list[_index].respawn = 120;
    _g.notebooks += 1;
    bb_yctp_open();
}

function bb_update_notebook_respawns(_dt) {
    var _g = global.G;
    if (_g.mode != "endless") return;
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        if (!_n.taken) continue;
        // NotebookScript lowers collected books to Unity Y=-20. Its distance
        // check includes that height and only counts time beyond 60 units.
        if (_n.respawn > 0 && bb_dist2(_g.px, _g.pz, _n.x, _n.z) + sqr(_g.py + 4) > 144) {
            _n.respawn = max(0, _n.respawn - _dt);
        }
        if (_n.respawn <= 0) {
            _n.taken = false;
            if (_n.respawn_audio != "") bb_world_sound(global.S.clips[$ _n.respawn_audio], _n.x, _n.z);
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

function bb_inv_has() {
    var _g = global.G;
    var _i;
    for (_i = 0; _i < 3; _i++) {
        if (_g.inv[_i] != -1) {
            return true;
        }
    }
    return false;
}

function bb_inv_take_random() {
    var _g = global.G;
    var _opts = [];
    var _i;
    for (_i = 0; _i < 3; _i++) {
        if (_g.inv[_i] != -1) {
            array_push(_opts, _i);
        }
    }
    if (array_length(_opts) == 0) {
        return false;
    }
    var _s = _opts[irandom(array_length(_opts) - 1)];
    _g.inv[_s] = -1;
    return true;
}

function bb_update_items_use() {
    var _g = global.G;
    if (keyboard_check_pressed(ord("1"))) _g.inv_sel = 0;
    if (keyboard_check_pressed(ord("2"))) _g.inv_sel = 1;
    if (keyboard_check_pressed(ord("3"))) _g.inv_sel = 2;
    if (mouse_wheel_up()) _g.inv_sel = (_g.inv_sel + 2) mod 3;
    if (mouse_wheel_down()) _g.inv_sel = (_g.inv_sel + 1) mod 3;
    if (mouse_check_button_pressed(mb_right) || keyboard_check_pressed(ord("Q"))) {
        bb_use_item();
    }
}

function bb_update_sprays(_dt) {
    var _g = global.G;
    _g.baldi_sprayed = false;
    for (var _n = 0; _n < array_length(_g.npcs); _n++) _g.npcs[_n].sprayed = false;
    for (var _i = array_length(_g.sprays) - 1; _i >= 0; _i--) {
        var _s = _g.sprays[_i];
        _s.life -= _dt;
        _s.prev_x = _s.x;
        _s.prev_z = _s.z;
        _s.x += _s.dx * 4 * _dt;
        _s.z += _s.dz * 4 * _dt;
        // The Unity spray is a trigger with a 30-second life; hitting a wall
        // does not destroy it. Pushed characters still collide with the world.
        if (_s.life <= 0) {
            array_delete(_g.sprays, _i, 1);
            continue;
        }
        if (_g.baldi_active && !_g.baldi_sprayed && bb_point_segment_dist2(_g.baldi_x, _g.baldi_z, _s.prev_x, _s.prev_z, _s.x, _s.z) <= sqr(1.28)) {
            bb_soda_push_baldi(_s, _dt);
        }
        for (var _n = 0; _n < array_length(_g.npcs); _n++) {
            var _npc = _g.npcs[_n];
            if (!_npc.live || _npc.sprayed || _npc.kind == "bully") continue;
            if (bb_point_segment_dist2(_npc.x, _npc.z, _s.prev_x, _s.prev_z, _s.x, _s.z) <= sqr(1.3)) {
                _npc.sprayed = true;
                bb_npc_touch_doors(_npc.x, _npc.z, 0.4);
                var _np = bb_move_slide(_npc.x, _npc.z, _s.dx * 4 * _dt, _s.dz * 4 * _dt, 0.3, true);
                _npc.x = _np[0];
                _npc.z = _np[1];
            }
        }
    }
}

function bb_spray_contact(_ax, _az, _bx, _bz, _radius) {
    for (var _i = 0; _i < array_length(global.G.sprays); _i++) {
        var _s = global.G.sprays[_i];
        if (_s.life > 0 && bb_point_segment_dist2(_s.x, _s.z, _ax, _az, _bx, _bz) <= sqr(_radius)) return _i;
    }
    return -1;
}

function bb_soda_push_baldi(_s, _dt) {
    var _g = global.G;
    _g.baldi_sprayed = true;
    bb_npc_touch_doors(_g.baldi_x, _g.baldi_z, 0.4);
    var _p = bb_move_slide(_g.baldi_x, _g.baldi_z, _s.dx * 4 * _dt, _s.dz * 4 * _dt, 0.28, true);
    _g.baldi_x = _p[0]; _g.baldi_z = _p[1];
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

function bb_activate_spoop() {
    var _g = global.G;
    if (_g.spoop_mode) {
        return;
    }
    _g.spoop_mode = true;
    _g.tutor_wave = false;
    _g.baldi_active = true;
    _g.baldi_x = _g.baldi_home_x;
    _g.baldi_z = _g.baldi_home_z;
    _g.baldi_cd = 3;
    bb_baldi_recalc_wait();
    bb_voice_clear("math");
    bb_voice_clear("tutor");
    _g.hear_x = _g.px;
    _g.hear_z = _g.pz;
    _g.hear_pri = 0;
    var _i;
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        _g.npcs[_i].live = true;
    }
    for (_i = 0; _i < array_length(_g.exits); _i++) {
        bb_exit_lower(_g.exits[_i], false);
    }
    bb_refresh_details();
    audio_stop_sound(snd_mus_learn);
    audio_stop_sound(snd_mus_school);
    var _hang = bb_sound_play(global.S.aud_Hang, false, 1);
    if (_g.state == "yctp") _g.yctp_hang = _hang;
}

function bb_update_npcs(_dt) {
    var _g = global.G;
    var _i;
    if (_g.play_lock > 0) {
        bb_update_playtime_minigame(_dt);
    }
    if (!_g.spoop_mode || _g.debug.freeze_npcs) {
        return;
    }
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        var _n = _g.npcs[_i];
        if (!_n.live || _n.sprayed) {
            continue;
        }
        _n.sense_time-=_dt;
        if (_n.sense_time<=0) { _n.sense_time=.05;_n.sees=bb_los(_n.x,_n.z,_g.px,_g.pz); }
        switch (_n.kind) {
            case "principal": bb_ai_principal(_n, _dt); break;
            case "playtime": bb_ai_playtime(_n, _dt); break;
            case "bully": bb_ai_bully(_n, _dt); break;
            case "sweep": bb_ai_sweep(_n, _dt); break;
            case "crafters": bb_ai_crafters(_n, _dt); break;
            case "prize": bb_ai_prize(_n, _dt); break;
        }
    }
}

function bb_npc_wander(_n, _dt, _spd) {
    _n.wait -= _dt;
    if (_n.wait <= 0) {
        _n.dir = random(360);
        _n.wait = 1.4 + random(3);
    }
    var _nx = _n.x + lengthdir_x(_spd * _dt, _n.dir);
    var _nz = _n.z + lengthdir_y(_spd * _dt, _n.dir);
    bb_npc_touch_doors(_n.x, _n.z, 0.4);
    var _sl = bb_move_slide(_n.x, _n.z, _nx - _n.x, _nz - _n.z, 0.3, true);
    if (bb_dist2(_sl[0], _sl[1], _n.x, _n.z) < 0.0001) {
        _n.dir += 90 + random(80);
    } else {
        _n.x = _sl[0];
        _n.z = _sl[1];
        bb_npc_touch_doors(_n.x, _n.z, 0.4);
    }
}

function bb_npc_go(_n, _tx, _tz, _spd, _dt) {
    bb_npc_touch_doors(_n.x, _n.z, 0.4);
    var _pos = bb_nav_advance(_n.x, _n.z, _tx, _tz, _spd * _dt, 0.3, true);
    _n.x = _pos[0];
    _n.z = _pos[1];
    bb_npc_touch_doors(_n.x, _n.z, 0.4);
}

function bb_npc_principal(_n, _dt) {
    var _g = global.G;
    var _run = 6;
    if (_g.prin_chase) {
        bb_npc_go(_n, _g.px, _g.pz, _run, _dt);
        if (bb_dist2(_n.x, _n.z, _g.px, _g.pz) < 1.0) {
            bb_give_detention(_n);
        }
        return;
    }
    if (_n.cool > 0) {
        _n.cool -= _dt;
    }
    bb_npc_wander(_n, _dt, _run * 0.95);
    if (_n.cool <= 0 && _g.guilt > 0 && bb_los(_n.x, _n.z, _g.px, _g.pz)) {
        _n.stare += _dt;
        if (_n.stare > 0.5) {
            _g.prin_chase = true;
            var _warning = global.S.audNoRunning;
            if (_g.guilt_type == "faculty") _warning = global.S.audNoFaculty;
            if (_g.guilt_type == "drink") _warning = global.S.audNoDrinking;
            if (_g.guilt_type == "escape") _warning = global.S.audNoEscaping;
            bb_voice_replace("principal", [_warning]);
        }
    } else {
        _n.stare = 0;
    }
}

function bb_give_detention(_n) {
    var _g = global.G;
    if (_g.debug.no_rules) { _g.prin_chase = false; return; }
    _g.prin_chase = false;
    _g.det_n += 1;
    var _t = 15;
    if (_g.det_n == 2) _t = 30;
    else if (_g.det_n == 3) _t = 45;
    else if (_g.det_n == 4) _t = 60;
    else if (_g.det_n >= 5) _t = 99;
    _g.detention = _t;
    _g.px = 1;
    _g.pz = -32;
    _g.yaw = 0;
    _g.guilt = 0;
    bb_end_playtime();
    _n.x = 1;
    _n.z = -34;
    _n.cool = 5;
    _n.stare = 0;
    var _door = bb_office_door();
    if (_door != -1) {
        _g.doors[_door].lock_cd = _t;
        _g.doors[_door].locked = true;
        _g.doors[_door].open = false;
    }
    bb_hear_pri(1, -32, 8);
    bb_voice_replace("principal", [global.S.aud_Delay, global.S[$ "audTimes" + string(min(4, _g.det_n-1))],
        global.S.audDetention, global.S[$ "audScolds" + string(irandom(2))]]);
}

function bb_npc_playtime(_n, _dt) {
    var _g = global.G;
    if (_g.play_lock > 0) {
        return;
    }
    if (_n.cool > 0) {
        _n.cool -= _dt;
        bb_npc_wander(_n, _dt, 3);
        return;
    }
    var _see = bb_los(_n.x, _n.z, _g.px, _g.pz) && bb_dist2(_n.x, _n.z, _g.px, _g.pz) < 16 * 16;
    if (_see) {
        bb_npc_go(_n, _g.px, _g.pz, 4, _dt);
        if (bb_dist2(_n.x, _n.z, _g.px, _g.pz) < 1.0) {
            bb_start_playtime();
        }
    } else {
        bb_npc_wander(_n, _dt, 3);
    }
}

function bb_update_playtime_minigame(_dt) {
    bb_rope_tick(_dt, keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_left) || keyboard_check_pressed(ord("E")));
}

function bb_npc_bully(_n, _dt) {
    var _g = global.G;
    _n.wait -= _dt;
    if (_n.wait <= -180) {
        _n.x = 8 + random(20) - 10;
        _n.z = -20 + random(30) - 15;
        if (bb_blocked_world(_n.x, _n.z, 0.4, false)) {
            _n.x = 0;
            _n.z = 0;
        }
        _n.wait = 0;
    }
    if (bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 1.15 * 1.15) {
        if (bb_inv_has()) {
            bb_inv_take_random();
            _n.wait = -180;
            _n.x = 40;
            _n.z = 40;
        }
    }
}

function bb_npc_sweep(_n, _dt) {
    var _g = global.G;
    if (!_n.angry) {
        _n.wait -= _dt;
        if (_n.wait <= 0) {
            _n.angry = true;
            _n.wait = 30;
        }
        return;
    }
    _n.wait -= _dt;
    bb_npc_wander(_n, _dt, 10);
    if (_g.boots <= 0 && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 1.3 * 1.3) {
        var _sl = bb_move_slide(_g.px, _g.pz, lengthdir_x(4 * _dt, _n.dir), lengthdir_y(4 * _dt, _n.dir), _g.radius, true);
        _g.px = _sl[0];
        _g.pz = _sl[1];
    }
    if (_g.baldi_active && bb_dist2(_g.baldi_x, _g.baldi_z, _n.x, _n.z) < 1.4 * 1.4) {
        var _bp = bb_move_slide(_g.baldi_x, _g.baldi_z, lengthdir_x(4 * _dt, _n.dir), lengthdir_y(4 * _dt, _n.dir), 0.28, false);
        _g.baldi_x = _bp[0];
        _g.baldi_z = _bp[1];
    }
    if (_n.wait <= 0) {
        _n.angry = false;
        _n.wait = 120 + random(60);
        _n.x = _n.home_x;
        _n.z = _n.home_z;
    }
}

function bb_npc_crafters(_n, _dt) {
    var _g = global.G;
    if (_g.notebooks < 7) {
        if (bb_los(_n.x, _n.z, _g.px, _g.pz)) {
            var _dx = _n.x - _g.px;
            var _dz = _n.z - _g.pz;
            var _ang = darctan2(_dz, _dx);
            bb_npc_go(_n, _n.x + lengthdir_x(4, _ang), _n.z + lengthdir_y(4, _ang), 3.5, _dt);
        }
        return;
    }
    if (_n.angry) {
        bb_npc_go(_n, _g.px, _g.pz, 9, _dt);
        if (bb_dist2(_n.x, _n.z, _g.px, _g.pz) < 1.1 * 1.1) {
            _g.px = 0;
            _g.pz = -15;
            if (_g.baldi_active) {
                _g.baldi_x = 0;
                _g.baldi_z = -24;
                bb_hear_pri(0, -15, 8);
            }
            _n.x = 80;
            _n.z = 80;
            _n.angry = false;
        }
        return;
    }
    var _looking = false;
    var _fx = -sin(_g.yaw);
    var _fz = -cos(_g.yaw);
    var _tx = _n.x - _g.px;
    var _tz = _n.z - _g.pz;
    var _tl = max(0.001, sqrt(_tx * _tx + _tz * _tz));
    if ((_fx * _tx + _fz * _tz) / _tl > 0.72 && _tl < 14 && bb_los(_g.px, _g.pz, _n.x, _n.z)) {
        _looking = true;
    }
    if (_looking) {
        _n.stare += _dt;
        if (_n.stare > 1) {
            _n.angry = true;
        }
    } else {
        _n.stare = max(0, _n.stare - _dt);
    }
}

function bb_npc_prize(_n, _dt) {
    var _g = global.G;
    if (_n.crazy > 0) {
        _n.crazy = max(0, _n.crazy - _dt);
        _n.dir += 180 * _dt;
        _n.spd = 0;
        return;
    }
    var _see = bb_los(_n.x, _n.z, _g.px, _g.pz);
    if (_see) {
        var _want = darctan2(_g.pz - _n.z, _g.px - _n.x);
        var _diff = angle_difference(_want, _n.dir);
        _n.dir += clamp(_diff, -40 * _dt, 40 * _dt);
        _n.spd = min(5.5, _n.spd + 2.2 * _dt);
    } else {
        _n.spd = max(0.6, _n.spd - 1.5 * _dt);
        _n.wait -= _dt;
        if (_n.wait <= 0) {
            _n.dir += random(60) - 30;
            _n.wait = 2;
        }
    }
    var _nx = lengthdir_x(_n.spd * _dt, _n.dir);
    var _nz = lengthdir_y(_n.spd * _dt, _n.dir);
    bb_npc_touch_doors(_n.x, _n.z, 0.45);
    var _sl = bb_move_slide(_n.x, _n.z, _nx, _nz, 0.35, true);
    if (bb_dist2(_sl[0], _sl[1], _n.x, _n.z) < 0.0002 && _n.spd > 2) {
        _n.spd = 0.4;
    }
    _n.x = _sl[0];
    _n.z = _sl[1];
    bb_npc_touch_doors(_n.x, _n.z, 0.45);
    if (_g.boots <= 0 && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 1.05 * 1.05 && _n.spd > 0.8) {
        var _ps = bb_move_slide(_g.px, _g.pz, lengthdir_x(_n.spd * _dt, _n.dir), lengthdir_y(_n.spd * _dt, _n.dir), _g.radius, true);
        _g.px = _ps[0];
        _g.pz = _ps[1];
    }
}

function bb_yctp_open() {
    var _g = global.G;
    if (_g.state == "yctp") return;
    audio_stop_sound(snd_bal_hi);
    audio_stop_sound(snd_bal_prize);
    bb_voice_clear("tutor");
    bb_voice_clear("math");
    audio_pause_all();
    _g.state = "yctp";
    _g.yctp_q = 0;
    _g.yctp_input = "";
    _g.yctp_feedback = 0;
    _g.yctp_wrong = 0;
    _g.yctp_msg = "";
    _g.yctp_marks = [0, 0, 0];
    _g.yctp_end = false;
    _g.yctp_face_visible = !_g.spoop_mode;
    _g.yctp_face_state = "idle";
    _g.yctp_face_time = 0;
    _g.yctp_hang = -1;
    _g.yctp_music = -1;
    bb_yctp_layout_init();
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    if (!_g.spoop_mode) {
        audio_stop_sound(snd_mus_school);
        _g.yctp_music = bb_sound_play(global.S.learnMusic, true, 1, global.A.music.learnMusic.gain);
        if (_g.notebooks == 1) {
            bb_voice_queue("math", [global.S.bal_intro, global.S.bal_howto]);
        }
    }
    bb_yctp_make();
}

function bb_yctp_make() {
    var _g = global.G;
    _g.yctp_input = "";
    _g.yctp_feedback = 0;
    _g.yctp_corrupt = false;
    _g.yctp_q += 1;
    if (_g.yctp_q > 3) {
        _g.yctp_end = true;
        _g.yctp_timer = 5;
        if (!_g.spoop_mode) {
            _g.yctp_msg = "WOW! YOU EXIST!";
        } else if (_g.mode == "endless" && _g.yctp_wrong == 0) {
            _g.yctp_msg = choose("That's more like it...", "Keep up the good work or see me after class...");
        } else if (_g.mode == "story" && _g.yctp_wrong >= 3) {
            _g.yctp_msg = "I HEAR MATH THAT BAD";
            bb_hear_pri(_g.px, _g.pz, 7);
            _g.failed_nbs += 1;
        } else {
            _g.yctp_msg = choose("I GET ANGRIER FOR EVERY PROBLEM YOU GET WRONG", "I HEAR EVERY DOOR YOU OPEN");
        }
        return;
    }
    if (_g.yctp_q <= 2 || (_g.mode == "story" ? _g.notebooks <= 1 : _g.notebooks != 2)) {
        _g.yctp_a = irandom_range(0, 9);
        _g.yctp_b = irandom_range(0, 9);
        if (irandom(1) == 0) {
            _g.yctp_op = "+";
            _g.yctp_ans = _g.yctp_a + _g.yctp_b;
        } else {
            _g.yctp_op = "-";
            _g.yctp_ans = _g.yctp_a - _g.yctp_b;
        }
    } else {
        _g.yctp_corrupt = true;
        _g.yctp_ans = -99999;
        _g.yctp_bad1 = string(irandom_range(1, 9999)) + "+(" + string(irandom_range(1, 9999)) + "X" + string(irandom_range(1, 9999)) + "=";
        _g.yctp_bad2 = "(" + string(irandom_range(1, 9999)) + "/" + string(irandom_range(1, 9999)) + ")+" + string(irandom_range(1, 9999)) + "=";
        _g.yctp_bad3 = string(irandom_range(1, 9999)) + "+(" + string(irandom_range(1, 9999)) + "X" + string(irandom_range(1, 9999)) + "=";
    }
    bb_math_voice_problem();
}

function bb_yctp_update(_dt) {
    var _g = global.G;
    bb_audio_update(_dt);
    bb_yctp_face_update(_dt);
    if (_g.yctp_end) {
        _g.yctp_timer -= _dt;
        if (_g.yctp_timer <= 0) {
            bb_yctp_close();
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
    if (keyboard_check_pressed(vk_enter)) {
        bb_yctp_submit();
        return;
    }
    if (mouse_check_button_pressed(mb_left) && variable_global_exists("yctp_pad")) {
        var _hit = bb_yctp_pad_hit();
        if (!is_undefined(_hit)) {
            if (_hit >= 0 && _hit <= 9 && string_length(_g.yctp_input) < 8) {
                _g.yctp_input += string(_hit);
            } else if (_hit == -1 && _g.yctp_input == "") {
                _g.yctp_input = "-";
            } else if (_hit == -2) {
                _g.yctp_input = "";
            } else if (_hit == -3) {
                bb_yctp_submit();
            }
        }
    }
}

function bb_yctp_submit() {
    var _g = global.G;
    if (_g.yctp_end) return;
    bb_voice_clear("math");
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
    if (_ok && !_g.yctp_corrupt) {
        _g.yctp_feedback = 1;
        _g.yctp_marks[_g.yctp_q - 1] = 1;
        if (!_g.spoop_mode) bb_voice_queue("math", [global.S[$ "bal_praises" + string(irandom(4))]]);
    } else {
        _g.yctp_feedback = -1;
        _g.yctp_marks[_g.yctp_q - 1] = -1;
        _g.yctp_wrong += 1;
        if (!_g.spoop_mode) {
            _g.yctp_face_state = "frown";
            _g.yctp_face_time = 0;
            bb_activate_spoop();
        }
        if (_g.yctp_q == 3 || _g.mode == "endless") {
            bb_get_angry(1);
        } else {
            bb_get_temp_angry(0.25);
        }
    }
    bb_yctp_make();
}

function bb_yctp_close() {
    var _g = global.G;
    if (_g.state != "yctp") return;
    if (_g.mode == "endless" && _g.yctp_wrong == 0) {
        // The source changes Baldi's stored anger even before he is active;
        // a perfect first notebook must not activate spoop mode.
        _g.baldi_anger -= 1;
        bb_baldi_recalc_wait();
    }
    if (_g.stamina < 100) {
        _g.stamina = 100;
    }
    _g.state = "play";
    bb_voice_clear("math");
    audio_stop_sound(snd_mus_learn);
    _g.yctp_music = -1;
    _g.yctp_hang = -1;
    audio_resume_all();
    window_mouse_set_locked(true);
    window_set_cursor(cr_none);
    _g.mouse_ready = false;
    if (!_g.spoop_mode) {
        audio_play_sound(snd_mus_school, 1, true);
    }
    if (_g.notebooks == 1 && !_g.spoop_mode) {
        for (var _i = 0; _i < array_length(_g.items); _i++) {
            if (_g.items[_i].reward) _g.items[_i].taken = false;
        }
        bb_voice_replace("tutor", [global.S.aud_Prize]);
    }
    if (_g.mode == "story" && _g.notebooks >= 7) {
        if (!_g.exit_open) bb_voice_replace("tutor", [global.S.aud_AllNotebooks]);
        _g.exit_open = true;
        var _e;
        for (_e = 0; _e < array_length(_g.exits); _e++) {
            _g.exits[_e].down = false;
        }
        bb_refresh_details();
    }
}

function bb_gameover() {
    var _g = global.G;
    if (_g.debug.god) return;
    if (_g.gameover) return;
    _g.gameover = true;
    _g.over_t = 0;
    if (_g.mode == "endless") {
        _g.new_high_score = (_g.notebooks > global.high_books);
        global.high_books = max(global.high_books, _g.notebooks);
        bb_settings_save();
    }
    audio_stop_all();
    bb_sound_play(global.S.aud_buzz, false, 5);
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
}

function bb_check_exits(_old_x = undefined, _old_z = undefined) {
    var _g = global.G;
    if (_g.mode != "story" || !_g.exit_open || _g.win || _g.gameover || _g.state != "play") {
        return;
    }
    if (is_undefined(_old_x)) { _old_x = _g.px; _old_z = _g.pz; }
    var _i;
    for (_i = 0; _i < array_length(_g.exits); _i++) {
        var _e = _g.exits[_i];
        if (_e.used || _e.down) {
            continue;
        }
        if (_g.exit_got < 3) {
            if (bb_exit_box_hit(_e.source.near, _old_x, _old_z, _g.px, _g.pz, _g.radius)) {
                bb_exit_lower(_e, true);
                bb_refresh_details();
                _g.exit_got += 1;
                _g.final_red = min(3, _g.exit_got);
                bb_hear_pri(_e.x, _e.z, 8);
                bb_finale_audio(_g.exit_got);
            }
        } else if (bb_exit_box_hit(_e.source.finish, _old_x, _old_z, _g.px, _g.pz, _g.radius)) {
            bb_win_game();
            return;
        }
    }
}

function bb_game_draw() {
    var _g = global.G;
    var _aspect = bb_base_w() / bb_base_h();
    var _yaw = _g.yaw;
    if (keyboard_check(vk_space) && _g.play_lock <= 0 && _g.state == "play" && !_g.pause) {
        _yaw += pi;
    }
    bb3d_begin(_g.px, _g.py + _g.jump_height, _g.pz, _yaw, _aspect);
    if (_g.final_red > 0) {
        draw_clear(make_colour_rgb(40, 0, 0));
    }
    bb3d_draw_sky(_g.px, _g.py, _g.pz);
    bb3d_draw_world();
    bb_draw_entrances();
    bb_draw_environment();
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
        var _spr = spr_tex_swing0;
        if (_d.kind == "class") {
            _spr = _d.open ? spr_tex_door_open : spr_tex_door;
        } else if (_d.kind == "faculty") {
            if (variable_global_exists("spr_faculty") && global.spr_faculty != -1) {
                _spr = _d.open ? global.spr_faculty_open : global.spr_faculty;
            } else {
                _spr = _d.open ? spr_tex_door_open : spr_tex_door;
            }
        } else if (_d.lock_cd > 0 && variable_global_exists("spr_swing_locked") && global.spr_swing_locked != -1) {
            _spr = global.spr_swing_locked;
        } else {
            _spr = _d.open ? spr_tex_swing60 : spr_tex_swing0;
        }
        var _hw = bb_door_hw(_d);
        if (!variable_struct_exists(_d, "v") && _d.kind != "swing" && _hw < 0.99) {
            var _jvb = global.vb_bill;
            vertex_begin(_jvb, global.vf_3d);
            bb3d_emit_jamb(_jvb, _d.side, _d.x, _d.z, -1, -_hw, c_white, 1);
            bb3d_emit_jamb(_jvb, _d.side, _d.x, _d.z, _hw, 1, c_white, 1);
            vertex_end(_jvb);
            vertex_submit(_jvb, pr_trianglelist, sprite_get_texture(spr_tex_brick, 0));
        }
        var _vb = global.vb_bill;
        vertex_begin(_vb, global.vf_3d);
        if (variable_struct_exists(_d, "v")) {
            bb3d_emit_vertices(_vb, _d.v, [1, 1, 0, 0], c_white);
        } else {
            bb3d_emit_door(_vb, _d.side, _d.x, _d.z, _hw, c_white, 1);
        }
        vertex_end(_vb);
        vertex_submit(_vb, pr_trianglelist, sprite_get_texture(_spr, 0));
    }
    gpu_set_texrepeat(true);
}

function bb_draw_notebook_3d(_x, _y, _z, _spr, _phase, _tint) {
    if (_spr < 0) {
        _spr = spr_notebook;
    }
    if (is_undefined(_tint)) {
        _tint = c_white;
    }
    var _bob = sin(_phase) * 0.1;
    var _h = 0.34;
    var _w = 0.56;
    bb3d_draw_billboard(_spr, 0, _x, _y + _bob, _z, _w, _h, global.G.px, global.G.pz, _tint);
}

function bb_draw_entities() {
    var _g = global.G;
    var _i;
    bb_draw_item_world();
    for (_i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        if (!_n.taken) {
            bb3d_draw_billboard(_n.spr, 0, _n.x, _n.y + sin(_g.nb_t*pi/3)*0.1, _n.z, _n.w, _n.h, _g.px, _g.pz, c_white);
        }
    }
    for (_i = 0; _i < array_length(_g.items); _i++) {
        var _it = _g.items[_i];
        if (!_it.taken) {
            var _is = (_it.spr != -1) ? _it.spr : spr_zesty;
            var _ibob = sin(_g.nb_t*pi/3) * 0.1;
            bb3d_draw_billboard(_is, 0, _it.x, _it.y + _ibob, _it.z, _it.w, _it.h, _g.px, _g.pz, c_white);
        }
    }
    for (_i = 0; _i < array_length(_g.sprays); _i++) {
        var _s = _g.sprays[_i];
        bb3d_draw_billboard(global.PS.spray, 0, _s.x, 0.8, _s.z, 1.28, 1.28, _g.px, _g.pz, c_white);
    }
    if (!_g.spoop_mode) {
        var _wf = clamp(floor(_g.tutor_frame), 0, 99);
        var _wspr = global.spr_wave[_wf];
        bb3d_draw_char(_wspr, 0, _g.tutor_x, _g.tutor_y, _g.tutor_z, 1.64, _g.px, _g.pz, c_white);
    } else {
        var _sf = clamp(floor(_g.baldi_frame), 0, 4);
        bb3d_draw_char(global.spr_slap[_sf], 0, _g.baldi_x, _g.baldi_y, _g.baldi_z, 1.64, _g.px, _g.pz, c_white);
    }
    for (_i = 0; _i < array_length(_g.npcs); _i++) {
        var _npc = _g.npcs[_i];
        if (!_npc.live || !_npc.visible) {
            continue;
        }
        var _ns = (_npc.spr != -1) ? _npc.spr : spr_principal;
        if (_npc.kind == "prize") _ns=bb_prize_view_sprite(_npc,_g.px,_g.pz);
        var _nh = (_npc.h > 0.1) ? _npc.h : 1.64;
        bb3d_draw_billboard(_ns, 0, _npc.x, _npc.y, _npc.z, _npc.w, _nh, _g.px, _g.pz, c_white);
    }
    bb_draw_exit_signs();
}

function bb_prize_view_sprite(_npc,_px,_pz) {
    if (!variable_struct_exists(_npc.source,"views")) return (_npc.spr!=-1)?_npc.spr:spr_prize;
    var _to_player=darctan2(_pz-_npc.z,_px-_npc.x)+_npc.dir;
    var _view=floor(((_to_player+11.25) mod 360 + 360) mod 360 / 22.5);
    return global.PS[$ _npc.source.views[_view]];
}

function bb_item_name(_k) {
    switch (_k) {
        case 1: return "Energy flavored Zesty Bar";
        case 2: return "Yellow Door Lock";
        case 3: return "Principal's Keys";
        case 4: return "BSODA";
        case 5: return "Quarter";
        case 6: return "Baldi Anti Hearing and Disorienting Tape";
        case 7: return "Alarm Clock";
        case 8: return "WD-NoSquee (Door Type)";
        case 9: return "Safety Scissors";
        case 10: return "Big Ol' Boots";
        default: return "Nothing";
    }
}

function bb_item_spr(_k) {
    if (_k >= 1 && _k <= 10 && variable_global_exists("PS")) return global.PS[$ "item" + string(_k)];
    switch (_k) {
        case 1: return spr_zesty;
        case 2: return spr_door_lock;
        case 3: return spr_key;
        case 4: return spr_bsoda;
        case 5: return spr_quarter;
        case 6: return spr_tape;
        case 7: return spr_alarm;
        case 8: return spr_nosquee;
        case 9: return spr_scissors;
        case 10: return spr_boots;
        default: return -1;
    }
}

function bb_game_draw_gui() {
    bb_ui_begin();
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
        if (_g.mode == "endless") {
            draw_text(_gw * 0.5, 48, "Score: " + string(_g.notebooks) + " Notebooks");
            draw_text(_gw * 0.5, 76, _g.new_high_score ? "NEW HIGH SCORE!" : "High Score: " + string(global.high_books));
        }
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
    if (_g.final_red > 0) {
        draw_set_alpha(0.18 + _g.final_red * 0.12);
        draw_set_color(make_colour_rgb(180, 0, 0));
        draw_rectangle(0, 0, _gw, _gh, false);
        draw_set_alpha(1);
    }
    bb_draw_classic_hud(_g, _gw, _gh);
    if (_g.exit_open) {
        draw_set_font(global.fnt_small);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        //draw_text(_gw * 0.5, 58, "FIND ALL 4 EXITS!");
        draw_set_halign(fa_left);
    }
    bb_draw_hud_effects();
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
    bb_present_hud(_g, _gw, _gh);
}

function bb_yctp_pad_hit() {
    return bb_yctp_pad_at(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0));
}

function bb_yctp_pad_at(_mx, _my) {
    var _i;
    for (_i = 0; _i < array_length(global.yctp_pad); _i++) {
        var _b = global.yctp_pad[_i];
        if (_mx >= _b.x1 && _mx <= _b.x2 && _my >= _b.y1 && _my <= _b.y2) {
            return _b.v;
        }
    }
    return undefined;
}

function bb_yctp_draw() {
    bb_present_yctp();
}

function bb_game_cleanup() {
    audio_stop_all();
    bb3d_free_batches();
    if (variable_global_exists("floors") && ds_exists(global.floors, ds_type_map)) {
        ds_map_destroy(global.floors);
        global.floors=-1;
    }
    if (variable_global_exists("wall_edge") && ds_exists(global.wall_edge, ds_type_map)) {
        ds_map_destroy(global.wall_edge);
        global.wall_edge=-1;
    }
    if (variable_global_exists("nav_n") && ds_exists(global.nav_n, ds_type_map)) {
        ds_map_destroy(global.nav_n);
        global.nav_n=-1;
    }
    if (variable_global_exists("nav_portals") && ds_exists(global.nav_portals, ds_type_map)) {
        ds_map_destroy(global.nav_portals);
        global.nav_portals=-1;
    }
    if (variable_global_exists("wall_cells") && ds_exists(global.wall_cells, ds_type_map)) ds_map_destroy(global.wall_cells);
    global.wall_cells=-1;
    global.path_ready=false;
    global.path_grids={};
    global.path_grid=undefined;
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
}
