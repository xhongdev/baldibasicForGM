// Opt-in checks execute the real GML with the actual imported school.
function bb_test_assert(_ok, _message) {
    global.test_total += 1;
    if (!_ok) {
        global.test_failed += 1;
        show_debug_message("BB_TEST_FAIL: " + _message);
    }
}

function bb_run_selftests() {
    global.test_total = 0;
    global.test_failed = 0;
    var _saved = variable_clone(global.G);
    var _g = global.G;
    _g.notebooks = 7;
    bb_test_assert(array_length(_g.doors) == 23, "23 authored doors");
    bb_test_assert(array_length(_g.notebooks_list) == 7, "7 authored notebooks");
    bb_test_assert(ds_map_size(global.floors) == 682, "682 floor tiles");
    var _tex = variable_struct_get_names(global.map_textures);
    for (var _i = 0; _i < array_length(_tex); _i++) {
        bb_test_assert(sprite_exists(global.map_textures[$ _tex[_i]]), "texture loaded: " + _tex[_i]);
    }
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        var _d = _g.doors[_i];
        var _label = global.map.doors[_i].source_name;
        _d.open = false;
        _d.locked = true;
        _d.lock_cd = 15;
        bb_test_assert(bb_blocked_world(_d.cx, _d.cz, 0.28, true), _label + " blocks player when locked");
        bb_test_assert(bb_blocked_world(_d.cx, _d.cz, 0.3, false), _label + " blocks NPC when locked");
        _d.locked = false;
        _d.lock_cd = 0;
        _d.open = true;
        bb_test_assert(!bb_blocked_world(_d.cx, _d.cz, 0.35, true), _label + " clear opening");
        var _nx = (_d.side == "e") ? 1 : ((_d.side == "w") ? -1 : 0);
        var _nz = (_d.side == "s") ? 1 : ((_d.side == "n") ? -1 : 0);
        for (var _sign = -1; _sign <= 1; _sign += 2) {
            var _x = _d.cx - _nx * 0.7 * _sign, _z = _d.cz - _nz * 0.7 * _sign;
            var _p = bb_move_slide(_x, _z, _nx * 1.4 * _sign, _nz * 1.4 * _sign, 0.28, true);
            bb_test_assert(bb_dist2(_p[0], _p[1], _d.cx + _nx * 0.7 * _sign, _d.cz + _nz * 0.7 * _sign) < 0.001,
                _label + " player crosses side " + string(_sign));
        }
        // Confirm the renderer's exact plane and collision share the same bounds.
        for (var _vi = 0; _vi < 4; _vi++) {
            var _v = _d.v[_vi];
            bb_test_assert(_v[0] >= _d.bounds[0] - 0.001 && _v[0] <= _d.bounds[3] + 0.001
                && _v[2] >= _d.bounds[2] - 0.001 && _v[2] <= _d.bounds[5] + 0.001, _label + " vertex alignment");
        }
    }
    // Portal navigation must cross the offset classroom doors at high frame rates.
    var _rates = [30, 60, 144];
    for (var _ri = 0; _ri < 3; _ri++) {
        for (var _di = 0; _di < array_length(_g.doors); _di++) {
            var _d = _g.doors[_di];
            var _nx = (_d.side == "e") ? 2 : ((_d.side == "w") ? -2 : 0);
            var _nz = (_d.side == "s") ? 2 : ((_d.side == "n") ? -2 : 0);
            for (var _sign = 0; _sign <= 1; _sign++) {
                var _x = _d.x + _nx * _sign, _z = _d.z + _nz * _sign;
                var _tx = _d.x + _nx * (1 - _sign), _tz = _d.z + _nz * (1 - _sign);
                for (var _step = 0; _step < _rates[_ri] * 2; _step++) {
                    var _p = bb_nav_advance(_x, _z, _tx, _tz, 3 / _rates[_ri], 0.3, true);
                    _x = _p[0]; _z = _p[1];
                    if (bb_dist2(_x, _z, _tx, _tz) < 0.01) break;
                }
                bb_test_assert(bb_dist2(_x, _z, _tx, _tz) < 0.01,
                    global.map.doors[_di].source_name + " nav " + string(_rates[_ri]) + "fps side " + string(_sign));
            }
        }
    }
    // Travel from spawn to every notebook using actual navigation and collision.
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        var _n = _g.notebooks_list[_i];
        var _x = 0, _z = 2;
        for (var _step = 0; _step < 1200; _step++) {
            var _p = bb_nav_advance(_x, _z, _n.x, _n.z, 0.3, 0.3, true);
            if (bb_dist2(_p[0], _p[1], _x, _z) < 0.000001) break;
            _x = _p[0]; _z = _p[1];
            if (bb_dist2(_x, _z, _n.x, _n.z) < 0.1) break;
        }
        bb_test_assert(bb_dist2(_x, _z, _n.x, _n.z) < 0.1,
            "notebook route " + string(_i) + " ended at " + string(_x) + "," + string(_z));
    }
    // A half-wall adjacent to the first classroom must remain solid.
    bb_test_assert(bb_blocked_world(-1, -4.5, 0.28, true), "first classroom half-wall stays solid");
    _g.px = 0; _g.pz = -3.5; _g.yaw = pi * 0.5;
    _g.doors[8].open = false;
    bb_test_assert(bb_interaction_target(2).kind == "door", "first classroom crosshair hits door");
    // Exercise new item state without keyboard simulation.
    _g.inv = [1, -1, -1]; _g.inv_sel = 0;
    bb_test_assert(bb_use_item() && _g.stamina == 200 && _g.inv[0] == -1, "zesty consumption");
    _g.inv[0] = 7;
    bb_use_item();
    _g.baldi_active = true; _g.hear_pri = 0;
    bb_update_item_effects(29);
    bb_test_assert(!_g.alarms[0].rang, "alarm waits 30 seconds");
    bb_update_item_effects(1);
    bb_test_assert(_g.alarms[0].rang && _g.hear_pri == 8, "alarm hearing priority");
    _g.anti_hear = 30;
    var _hear_x = _g.hear_x;
    bb_hear_pri(100, 100, 9);
    bb_test_assert(_g.hear_x == _hear_x, "anti hearing suppresses sound targets");
    bb_start_playtime();
    bb_rope_tick(2.1, false);
    bb_test_assert(_g.play_need == 5 && _g.rope_delay > 1, "missed rope resets progress");
    _g.inv[0] = 9;
    bb_test_assert(bb_use_item() && _g.play_lock == 0, "scissors release rope");
    bb_test_soda_audio();
    global.G = _saved;
    bb_test_debug_menu();
    audio_stop_all();
    window_mouse_set_locked(false);
    window_set_cursor(cr_default);
    show_debug_message("BB_TEST_LOGIC: " + string(global.test_total) + " checks, " + string(global.test_failed) + " failures");
}

function bb_test_debug_menu() {
    var _original = global.G;
    global.G = variable_clone(_original);
    var _g = global.G;
    audio_stop_all();
    bb_test_assert(!_g.debug.open && !_g.debug.god && !_g.debug.noclip && !_g.debug.items, "cheats default off");
    var _tone = bb_sound_play(snd_antihearing);
    bb_debug_open();
    var _time = _g.nb_t, _px = _g.px;
    bb_game_update(0.1);
    bb_test_assert(_g.debug.open && _g.nb_t == _time && _g.px == _px, "open cheat menu blocks gameplay update");
    bb_test_assert(audio_is_paused(_tone), "cheat menu pauses audio");
    bb_debug_close();
    bb_test_assert(!audio_is_paused(_tone) && !_g.pause, "closing cheat menu resumes play audio");
    _g.pause = true; audio_pause_all();
    bb_debug_open(); bb_debug_close();
    bb_test_assert(_g.pause && audio_is_paused(_tone), "cheat menu preserves existing pause");
    _g.pause = false; audio_resume_all();
    _g.notebooks = 1; bb_yctp_open(); bb_audio_update(0.01);
    var _voice = _g.voices.math.handle;
    bb_debug_open(); bb_debug_close();
    bb_test_assert(_g.state == "yctp" && !audio_is_paused(_voice) && audio_is_paused(_tone), "pad voice resumes while world audio stays paused");
    bb_debug_open(); bb_debug_action("spawn");
    bb_test_assert(_g.debug.open && _g.state == "play", "teleport leaves pad but keeps cheat menu modal");
    bb_debug_close();
    bb_debug_action("toggle", "god"); bb_gameover();
    bb_test_assert(!_g.gameover, "god mode prevents Baldi game-over");
    bb_debug_action("toggle", "god"); bb_gameover();
    bb_test_assert(_g.gameover, "disabling god mode restores game-over");
    bb_debug_open(); bb_debug_action("spawn"); bb_debug_close();
    bb_test_assert(!_g.gameover && !_g.win && !bb_blocked_world(_g.px, _g.pz, _g.radius, true), "revive returns to safe spawn");
    _g.px = -0.5; _g.pz = -4.5;
    var _blocked = bb_debug_player_move(-1, 0);
    bb_debug_action("toggle", "noclip");
    var _free = bb_debug_player_move(-1, 0);
    bb_test_assert(_blocked[0] > -1 && _free[0] == -1.5, "noclip crosses wall only when enabled");
    _g.px = -1; _g.pz = -4.5;
    bb_debug_action("toggle", "noclip");
    bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true), "disabling noclip resolves wall overlap");
    bb_debug_action("slot", 1);
    for (var _i = 1; _i <= 10; _i++) {
        bb_debug_action("item", _i);
        bb_test_assert(_g.inv[1] == _i, "give item into chosen slot " + string(_i));
    }
    bb_debug_action("slot", 0); bb_debug_action("item", 4);
    bb_debug_action("toggle", "items"); bb_use_item();
    bb_test_assert(_g.inv[0] == 4 && array_length(_g.sprays) > 0, "infinite item use retains BSODA");
    bb_debug_action("toggle", "items"); bb_use_item();
    bb_test_assert(_g.inv[0] == -1, "normal consumption restored");
    bb_debug_action("books", 7);
    bb_test_assert(_g.exit_open && _g.notebooks == 7 && _g.notebooks_list[6].taken, "seven-book cheat enables exits and hides books");
    bb_debug_action("books", 0);
    bb_test_assert(!_g.exit_open && !_g.notebooks_list[0].taken && _g.exit_got == 0, "book reset restores notebooks and exit state");
    bb_debug_action("doors_open");
    var _unlocked = true;
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        if (_g.doors[_i].locked || !_g.doors[_i].open) _unlocked = false;
    }
    bb_test_assert(_unlocked && _g.debug.free_doors, "all doors open including initial notebook gates");
    bb_debug_action("toggle", "free_doors");
    var _gated = false;
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        if (_g.doors[_i].kind == "swing" && _g.doors[_i].locked) _gated = true;
    }
    bb_test_assert(_gated, "disabling free doors restores notebook gates");
    bb_debug_action("chase");
    bb_debug_action("toggle", "freeze_baldi");
    var _cd = _g.baldi_cd;
    bb_update_baldi(0.2);
    bb_test_assert(_g.baldi_cd == _cd, "paused Baldi AI keeps its timer");
    bb_debug_action("toggle", "freeze_npcs");
    var _wait = _g.npcs[0].wait;
    bb_update_npcs(0.2);
    bb_test_assert(_g.npcs[0].wait == _wait, "other NPC AI pauses");
    _g.detention = 30; _g.prin_chase = true;
    bb_debug_action("toggle", "no_rules");
    bb_test_assert(_g.detention == 0 && !_g.prin_chase, "no-punishment clears detention");
    bb_debug_open(); bb_debug_action("math");
    _g.yctp_corrupt = true;
    bb_debug_action("math_finish");
    bb_test_assert(_g.state == "play" && _g.yctp_marks[0] == 1 && _g.yctp_marks[2] == 1 && _g.debug.open, "finish-pad cheat accepts impossible questions and preserves overlay");
    for (var _i = 0; _i < array_length(_g.doors); _i++) {
        bb_debug_action("door", _i);
        bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true), "safe teleport to door " + string(_i));
    }
    for (var _i = 0; _i < array_length(_g.notebooks_list); _i++) {
        bb_debug_action("notebook", _i);
        var _n = _g.notebooks_list[_i];
        bb_test_assert(!bb_blocked_world(_g.px, _g.pz, _g.radius, true) && bb_dist2(_g.px, _g.pz, _n.x, _n.z) < 4, "notebook teleport arrives within pickup range " + string(_i));
    }
    for (var _tab = 0; _tab < 4; _tab++) {
        bb_debug_action("tab", _tab);
        var _pages = _g.debug.pages;
        for (var _page = 0; _page < _pages; _page++) {
            _g.debug.page = _page; bb_debug_layout();
            var _ok = true;
            for (var _i = 0; _i < array_length(_g.debug.buttons); _i++) {
                var _b = _g.debug.buttons[_i];
                if (_b.x1 < 0 || _b.y1 < 0 || _b.x2 > 640 || _b.y2 > 430) _ok = false;
            }
            bb_test_assert(_ok, "cheat page stays inside viewport " + string(_tab) + "/" + string(_page));
        }
    }
    bb_debug_close();
    audio_stop_all();
    global.G = _original;
}

function bb_test_soda_audio() {
    var _g = global.G;
    var _rates = [30, 60, 144];
    for (var _ri = 0; _ri < 3; _ri++) {
        _g.px = 0; _g.pz = 0; _g.state = "play"; _g.gameover = false;
        _g.baldi_active = true; _g.baldi_x = 0; _g.baldi_z = -0.55;
        _g.baldi_move = 0.2; _g.baldi_cd = 0; _g.baldi_wait = 1;
        _g.baldi_extra = 0; _g.sprays = [{x:0,z:0,dx:0,dz:-1,life:30}];
        for (var _step = 0; _step < _rates[_ri]; _step++) {
            bb_update_sprays(1/_rates[_ri]);
            bb_update_baldi(1/_rates[_ri]);
        }
        bb_test_assert(!_g.gameover && _g.baldi_z < -4, "point-blank soda holds Baldi at " + string(_rates[_ri]) + "fps");
        _g.sprays = [];
        bb_update_sprays(1/_rates[_ri]);
        bb_test_assert(!_g.baldi_sprayed, "soda releases on expiry");
    }
    _g.baldi_x = 0; _g.baldi_z = -2.3; _g.baldi_move = 0.2;
    _g.sprays = [{x:0,z:-0.7,dx:0,dz:-1,life:30}];
    bb_update_sprays(0.1); bb_update_baldi(0.1);
    bb_test_assert(_g.baldi_sprayed && !_g.gameover, "fast slap cannot cross spray between frames");
    _g.sprays = [{x:0,z:2.8,dx:0,dz:1,life:30}];
    bb_update_sprays(0.1);
    bb_test_assert(array_length(_g.sprays) == 1, "soda trigger survives a wall");
    _g.sprays = []; _g.baldi_sprayed = false;
    _g.spoop_mode = false; _g.baldi_wait = 0; _g.baldi_anger = 0;
    bb_activate_spoop();
    bb_test_assert(_g.baldi_wait > 2, "first wrong answer initializes slap interval");
    _g.baldi_cd = 0; _g.audio_log = [];
    for (var _step = 0; _step < 120; _step++) bb_update_baldi(1/60);
    var _slaps = 0;
    for (var _i = 0; _i < array_length(_g.audio_log); _i++) {
        if (_g.audio_log[_i].clip == snd_bal_slap) _slaps += 1;
    }
    bb_test_assert(_slaps >= 1 && _slaps <= 2, "no per-frame ruler audio after first wrong answer");
    bb_test_assert(bb_world_sound(snd_door_open, 1000, 1000) == -1, "distant door is inaudible");
    _g.spoop_mode = false; _g.notebooks = 1;
    bb_yctp_open(); bb_audio_update(0.01);
    var _intro = _g.voices.math.handle;
    bb_test_assert(_g.voices.math.queue[0] == global.S.bal_intro && _g.voices.math.head == 1, "math intro begins one voice queue");
    _g.yctp_input = string(_g.yctp_ans); bb_yctp_submit();
    bb_test_assert(!audio_is_playing(_intro) && _g.voices.math.head == 0, "answer interrupts previous speech");
    bb_audio_update(0.01);
    var _praise = _g.voices.math.handle;
    _g.yctp_input = "99999"; bb_yctp_submit();
    bb_audio_update(0.01);
    bb_test_assert(_g.spoop_mode && array_length(_g.voices.math.queue) == 0 && !audio_is_playing(_praise), "wrong answer clears all math speech");
    bb_yctp_close();
    bb_test_assert(array_length(_g.voices.math.queue) == 0, "closing pad leaves no deferred how-to audio");
    _g.gameover = false; _g.audio_log = [];
    bb_gameover(); bb_gameover();
    bb_test_assert(array_length(_g.audio_log) == 1 && _g.audio_log[0].clip == global.S.aud_buzz, "game-over plays source buzz only once");
}

function bb_test_pixel_near(_a, _b) {
    return abs(colour_get_red(_a)-colour_get_red(_b)) <= 2
        && abs(colour_get_green(_a)-colour_get_green(_b)) <= 2
        && abs(colour_get_blue(_a)-colour_get_blue(_b)) <= 2;
}

function bb_test_presentation_render() {
    var _mat = [matrix_get(matrix_world), matrix_get(matrix_view), matrix_get(matrix_projection)];
    var _saved = variable_clone(global.G);
    var _expected = surface_create(128, 128), _actual = surface_create(128, 128);
    // Compare real 3D atlas sprites to GameMaker's own 2D sprite renderer.
    var _sprites = [spr_zesty, spr_bsoda, spr_notebook, global.PS.item5];
    for (var _si = 0; _si < array_length(_sprites); _si++) {
        var _spr = _sprites[_si];
        surface_set_target(_expected);
        bb_ui_begin();
        matrix_set(matrix_world, matrix_build_identity());
        matrix_set(matrix_view, matrix_build_identity());
        matrix_set(matrix_projection, matrix_build_projection_ortho(128, -128, 0, 100));
        draw_clear(c_fuchsia);
        var _sx = 128/sprite_get_width(_spr), _sy = 128/sprite_get_height(_spr);
        draw_sprite_ext(_spr, 0, -64+sprite_get_xoffset(_spr)*_sx, -64+sprite_get_yoffset(_spr)*_sy, _sx, _sy, 0, c_white, 1);
        surface_reset_target();
        surface_set_target(_actual);
        bb3d_begin(0, 0, 0, 0, 1);
        draw_clear(c_fuchsia);
        var _span = 2*tan(degtorad(75*0.5));
        bb3d_draw_billboard(_spr, 0, 0, 0, -1, _span, _span, 0, 0, c_white);
        surface_reset_target(); bb3d_end();
        var _bad = 0;
        for (var _y = 8; _y < 128; _y += 8) {
            for (var _x = 8; _x < 128; _x += 8) {
                if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
            }
        }
        bb_test_assert(_bad <= 8, "atlas sprite matches 2D reference " + sprite_get_name(_spr) + " mismatches=" + string(_bad));
    }
    surface_free(_expected); surface_free(_actual);
    _expected = surface_create(640, 480); _actual = surface_create(640, 480);
    matrix_set(matrix_world, matrix_build_identity());
    matrix_set(matrix_view, matrix_build_lookat(320, 240, -10, 320, 240, 0, 0, 1, 0));
    // Explicit top-left GUI projection, independent of the window's letterboxing.
    matrix_set(matrix_view, matrix_build( -320, -240, 0, 0, 0, 0, 1, 1, 1));
    matrix_set(matrix_projection, matrix_build_projection_ortho(640, -480, 0, 100));
    surface_set_target(_expected); bb_ui_begin(); draw_clear_alpha(c_black, 0);
    bb_ui_texture("slots", global.P.hud.ItemSlots.rect);
    surface_reset_target();
    global.G.inv = [-1, -1, -1];
    surface_set_target(_actual); draw_clear(c_black); bb_present_hud(global.G, 640, 480); surface_reset_target();
    var _bad = 0, _checked = 0;
    for (var _y = 2; _y < 65; _y += 3) {
        for (var _x = 513; _x < 639; _x += 3) {
            if (((surface_getpixel_ext(_expected, _x, _y) >> 24) & 255) < 254) continue;
            _checked += 1;
            if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
        }
    }
    bb_test_assert(_checked > 50 && _bad == 0, "HUD frame is fully drawn without cropping or distortion");
    global.G.inv = [1, 4, 9];
    surface_set_target(_actual); draw_clear(c_black); bb_present_hud(global.G, 640, 480); surface_reset_target();
    surface_save(_actual, "bb_hud_check.png");
    bb_yctp_layout_init();
    global.G.state = "yctp"; global.G.yctp_q = 1; global.G.yctp_end = false;
    global.G.yctp_corrupt = false; global.G.yctp_marks = [1, -1, 0];
    surface_set_target(_expected); draw_clear(c_black); bb_ui_begin();
    bb_ui_texture(global.P.yctp.YCTP.texture, global.P.yctp.YCTP.rect);
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) bb_ui_texture(global.yctp_pad[_i].texture, global.yctp_pad[_i].rect);
    surface_reset_target();
    surface_set_target(_actual); draw_clear(c_black); bb_present_yctp(); surface_reset_target();
    for (var _i = 0; _i < array_length(global.yctp_pad); _i++) {
        var _b = global.yctp_pad[_i], _bad = 0;
        for (var _y = ceil(_b.y1)+3; _y < _b.y2-3; _y += 6) {
            for (var _x = ceil(_b.x1)+3; _x < _b.x2-3; _x += 6) {
                if (!bb_test_pixel_near(surface_getpixel(_expected, _x, _y), surface_getpixel(_actual, _x, _y))) _bad += 1;
            }
        }
        bb_test_assert(_bad == 0, "YCTP source button placement " + string(_b.v));
        bb_test_assert(bb_yctp_pad_at((_b.x1+_b.x2)*0.5, (_b.y1+_b.y2)*0.5) == _b.v, "YCTP visible button hit area " + string(_b.v));
    }
    surface_save(_actual, "bb_yctp_check.png");
    surface_free(_expected); surface_free(_actual);
    global.G = _saved;
    _actual = surface_create(128, 128);
    surface_set_target(_actual); bb3d_begin(0, 1, 2, 0, 1); draw_clear(c_fuchsia);
    bb_draw_exit_signs(); surface_reset_target(); bb3d_end();
    var _pixels = 0;
    for (var _y = 0; _y < 128; _y += 2) {
        for (var _x = 0; _x < 128; _x += 2) {
            if (surface_getpixel(_actual, _x, _y) != c_fuchsia) _pixels += 1;
        }
    }
    bb_test_assert(_pixels > 10, "authored entrance sign renders in spawn camera");
    surface_free(_actual);
    matrix_set(matrix_world, _mat[0]); matrix_set(matrix_view, _mat[1]); matrix_set(matrix_projection, _mat[2]);
    bb_ui_begin();
}

function bb_test_render() {
    // Read a known front-facing quad to verify winding against GM's projection.
    var _surface = surface_create(32, 32);
    surface_set_target(_surface);
    bb3d_begin(0, 1, 0, 0, 1);
    draw_clear(c_black);
    gpu_set_cullmode(cull_clockwise);
    vertex_begin(global.vb_bill, global.vf_3d);
    bb3d_quad(global.vb_bill, -1, 0, -1, 0, 1, 1, 0, -1, 1, 1,
        1, 2, -1, 1, 0, -1, 2, -1, 0, 0, c_red, 1);
    vertex_end(global.vb_bill);
    vertex_submit(global.vb_bill, pr_trianglelist, -1);
    surface_reset_target();
    bb_test_assert(surface_getpixel(_surface, 16, 16) == c_red, "front-face render winding");
    bb3d_end();
    // Verify an authored half-wall is visible from both the corridor and room.
    var _views = [[0, -4.5, pi * 0.5], [-2, -4.5, -pi * 0.5]];
    for (var _i = 0; _i < 2; _i++) {
        surface_set_target(_surface);
        bb3d_begin(_views[_i][0], 1, _views[_i][1], _views[_i][2], 1);
        draw_clear(c_fuchsia);
        bb3d_draw_world();
        surface_reset_target();
        bb_test_assert(surface_getpixel(_surface, 16, 16) != c_fuchsia, "source half-wall renders from side " + string(_i));
        bb3d_end();
    }
    surface_free(_surface);
}
